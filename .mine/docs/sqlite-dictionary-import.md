# Importación secuencial de diccionarios en SQLite

## Decisión

Usaremos una única base de datos SQLite general y escribiremos directamente en
ella. No se creará una base temporal por diccionario ni habrá un merge al
final.

La importación será secuencial:

```text
extraer ZIP completo
  -> validar inventario e index.json
  -> crear una versión invisible del diccionario
  -> decodificar e insertar un banco
  -> COMMIT del banco
  -> repetir con el banco siguiente
  -> completar FTS y datos derivados pendientes
  -> publicar la versión con una transacción breve
  -> continuar con el siguiente diccionario
```

No se ejecutará ni se tomará como autoridad `.reference/go_loader`. Es una
muestra externa no confiable. Cualquier idea que resulte útil deberá volver a
especificarse aquí y probarse en este proyecto.

## Por qué elegimos la base general

Importar primero en otra base y hacer merge tiene una ventaja: la base general
no recibe filas parciales. Sin embargo, para nuestro caso cuesta más:

- Escribe todos los datos una vez en la base temporal y otra vez en la general.
- Necesita espacio adicional en disco.
- El merge final vuelve a actualizar todos los índices de la base general.
- Retrasa la disponibilidad del diccionario hasta terminar una segunda copia
  potencialmente larga.
- `ATTACH` añade reglas operativas y no aporta atomicidad entre varias bases en
  modo WAL si una transacción modifica más de una de ellas.

La base general evita esa segunda escritura. La invisibilidad de una versión
en importación proporciona el aislamiento lógico que habría dado la base
temporal.

## Concurrencia necesaria y concurrencia innecesaria

No necesitamos:

- Extraer varios ZIP simultáneamente.
- Importar varios diccionarios simultáneamente.
- Empezar a insertar un diccionario mientras todavía se está extrayendo.
- Tener más de un escritor SQLite.

Sí necesitamos que el trabajo secuencial se ejecute fuera del hilo que atiende
la UI. Habrá como máximo un worker de importación y una conexión escritora. Las
consultas de la UI usarán conexiones lectoras distintas.

SQLite permite varios lectores pero solo un escritor. En modo WAL los lectores
pueden seguir consultando una instantánea consistente mientras el escritor
confirma bancos nuevos. Las transacciones de lectura deben ser cortas para no
impedir checkpoints y hacer crecer indefinidamente el WAL.

Las escrituras originadas por la UI se serializarán con el importador. Pueden
esperar mediante una cola de aplicación o un `busy_timeout`; no se debe abrir un
segundo camino de escritura sin coordinación. Las lecturas normales no se
bloquean deliberadamente durante la importación ni durante la publicación.

Referencias oficiales:

- [WAL y concurrencia](https://www.sqlite.org/wal.html)
- [Transacciones y límite de un escritor](https://www.sqlite.org/lang_transaction.html)
- [Bases adjuntas](https://www.sqlite.org/lang_attach.html)
- [Foreign keys e índices asociados](https://www.sqlite.org/foreignkeys.html)

Como usaremos WAL con varias conexiones, la versión real de SQLite debe
comprobarse al elegir el driver. La documentación oficial de SQLite indica que
el fallo WAL-reset está corregido en 3.51.3 y en los backports 3.50.7 y 3.44.6.
No se desplegará una versión vulnerable.

## Visibilidad mediante versiones

No basta con una columna `status` si algún día se actualiza un diccionario ya
instalado: la versión anterior debe seguir disponible mientras entra la nueva.
El modelo mínimo será equivalente a este:

```text
dictionary_source
  id
  stable_key
  active_version_id -> dictionary_version.id, nullable

dictionary_version
  id
  source_id
  status             importing | ready | failed
  title
  revision
  format
  expected_banks
  imported_banks
  started_at
  finished_at

term, tag, kanji, metadata, definitions, ...
  dictionary_version_id
```

Todas las consultas de producto parten de `dictionary_source.active_version_id` o de una vista que haga ese join. Nunca filtran solo por el título ni consultan
versiones `importing` directamente.

Para el primer diccionario, `active_version_id` permanece a `NULL` hasta que la
importación completa termina. Para una actualización, sigue apuntando a la
versión anterior. Publicar consiste en una transacción corta que:

1. Comprueba que están confirmados todos los bancos esperados.
2. Comprueba que los datos derivados obligatorios están listos.
3. Marca la nueva versión como `ready`.
4. Cambia `active_version_id` a la nueva versión.

Un lector observa la versión anterior o la nueva, nunca una mezcla. La versión
anterior se puede borrar después, fuera de la transacción de publicación.

## Una transacción por banco, sin cargar el banco completo

Cada `*_bank_N.json` se abre de forma individual. Un `json.Decoder` consume el
array superior entrada a entrada:

```text
abrir archivo
BEGIN
preparar INSERTs
leer '['
mientras haya otra entrada:
	decodificar una tupla
	validar esa tupla
	insertar su fila y sus hijos ordenados
leer ']'
registrar el banco como importado
COMMIT
cerrar archivo
```

La memoria queda acotada aproximadamente a una entrada, su contenido
estructurado y los buffers de SQLite/JSON. No existe un `[]Term` con todo el
banco ni una estructura que contenga el diccionario completo.

Si una entrada es inválida, se revierte el banco actual entero. Los bancos ya
confirmados permanecen en disco, pero siguen invisibles porque su versión está
en `importing`. Después se marca la versión como `failed` o se deja información
suficiente para reanudarla de forma explícita.

## Índices, FTS y datos derivados

Los índices B-tree globales se crean una sola vez mediante migraciones, antes de
aceptar importaciones. SQLite los actualiza automáticamente con cada `INSERT`.
No se deben eliminar y reconstruir mientras la UI está usando la base.

Cada foreign key hija utilizada para borrar o reemplazar una versión tendrá su
índice correspondiente. `PRAGMA foreign_keys=ON` se configura en todas las
conexiones.

FTS y cualquier tabla derivada necesaria para consultar una entrada deben
actualizarse dentro de la misma transacción del banco que crea esa entrada, o en
pasadas posteriores todavía invisibles. La versión no se publica hasta que
estas pasadas hayan terminado.

No se deja una construcción grande de índices para la transacción final. La
transacción final solo valida contadores y cambia el puntero activo. Las
limpiezas grandes de versiones fallidas o antiguas también se hacen después y
fuera del camino crítico de publicación.

## Fallos e interrupciones

- Un error de parseo revierte únicamente el banco actual.
- Un cierre o `Ctrl+C` hace que SQLite revierta la transacción abierta. Los
  bancos anteriores siguen confirmados pero ocultos.
- Al iniciar la aplicación se buscan versiones `importing` abandonadas. La
  primera implementación puede eliminarlas y empezar de nuevo; reanudar por
  banco es una optimización posterior.
- Una versión `failed` nunca se convierte en activa.
- Un fallo durante la publicación deja activo el diccionario anterior, porque
  el cambio del puntero ocurre dentro de una única transacción.
- La falta de espacio, `SQLITE_BUSY`, errores de I/O y cancelación deben cerrar
  explícitamente la transacción con rollback antes de devolver el error.

## Disponibilidad observada por la UI

Después de publicar el primer diccionario, la UI ya puede consultarlo mientras
el worker extrae e importa el segundo. Durante los commits por banco del segundo
diccionario, las conexiones lectoras continúan viendo sus instantáneas del
primero.

Una consulta que ya había comenzado antes de la publicación puede seguir viendo
la instantánea anterior hasta terminar. La siguiente consulta verá el nuevo
diccionario. Ese comportamiento es correcto y evita bloquear toda la UI.

## Qué medir antes de optimizar más

- Tiempo de extracción por diccionario.
- Tiempo de decodificación e inserción por familia de banco.
- Duración máxima de una transacción de banco.
- Latencia p50/p95 de las consultas UI mientras se importa.
- Tamaño y duración de los checkpoints WAL.
- Memoria máxima del proceso durante el banco más grande.

Solo estas medidas justificarán dividir una transacción de banco, cambiar el
checkpointing o introducir más paralelismo.
