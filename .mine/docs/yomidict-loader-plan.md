# Plan del cargador Yomidict

## Objetivo y límites

El cargador debe leer un Yomidict extraído, validar su formato y entregar sus
entradas una a una al almacenamiento SQLite. No debe cargar un banco completo ni 
un diccionario completo en memoria.

Este documento no autoriza a ejecutar ni copiar `.reference/go_loader`. Ese
proyecto es únicamente una muestra externa no confiable. Las afirmaciones sobre
el formato que usemos deben estar respaldadas por fixtures propios, los schemas
oficiales o [yomidict-assertions.md](./yomidict-assertions.md), y después quedar
cubiertas por tests de este repositorio.

La extracción segura sigue perteneciendo a `container`. Yomidict no debe volver
a implementar ZIP, rutas, symlinks, límites de expansión ni instalación
atómica.

## No usar el mismo modelo para JSON y SQLite

Hay tres representaciones con responsabilidades distintas:

1. **Formato fuente Yomidict.** Es el contrato externo: `index.json`, tuplas
   posicionales, diferencias entre versiones, campos opcionales y contenido
   estructurado recursivo.
2. **Valores semánticos de importación.** Son valores Go de una sola entrada,
   por ejemplo `Term`, `Tag` o `Kanji`. Ocultan las posiciones del array pero
   conservan toda la información necesaria. Pueden coincidir con la salida del
   decoder; no forman un `Dictionary` gigante.
3. **Esquema y resultados SQL.** Normalizan relaciones, guardan órdenes en
   columnas `ord` y devuelven DTOs pensados para cada consulta de la UI.

No se debe forzar el modelo SQLite sobre el decoder. Una tupla Yomidict puede
contener arrays y árboles que terminan repartidos entre varias tablas; una fila
SQL no puede representar fielmente esa entrada por sí sola. En la dirección
contraria, una consulta de búsqueda suele unir y resumir varias filas y tampoco
es una entrada fuente.

La primera implementación puede evitar una capa ceremonial adicional:

```text
JSON posicional -> Term/Tag/Kanji de una entrada -> INSERTs normalizados
SQLite -> DTO específico de consulta -> UI
```

Solo hará falta implementar el camino inverso SQL -> Yomidict si decidimos
exportar diccionarios. No debe diseñarse ahora por adelantado.

## Paquetes propuestos

```text
yomidict
  index y tipos semánticos
  descubrimiento y orden numérico de bancos
  decoders streaming por familia
  validación del formato

dictionarydb
  migraciones y esquema SQLite
  worker escritor único
  importación transaccional por banco
  publicación y recuperación de versiones
  consultas utilizadas por la aplicación

aplicación
  container.Uncompress
  yomidict.OpenDir
  dictionarydb.Import
  progreso, cancelación y mensajes para la UI
```

`yomidict` no importa un driver SQLite. `dictionarydb` no abre ZIP ni interpreta
rutas internas de un archivo comprimido.

## API inicial de Yomidict

Los nombres son una propuesta de trabajo, no un compromiso irreversible.

```go
type BankKind uint8

const (
	TermBank BankKind = iota
	TermMetaBank
	KanjiBank
	KanjiMetaBank
	TagBank
)

type Bank struct {
	Kind   BankKind
	Number uint64
	Path   string
}

type Source struct {
	Root  string
	Index Index
	Banks []Bank
}

func OpenDir(root string) (*Source, error)
func ReadIndex(r io.Reader) (Index, error)
func DiscoverBanks(root string) ([]Bank, error)

func DecodeTermBank(ctx context.Context, r io.Reader, yield func(Term) error) error
func DecodeTermMetaBank(ctx context.Context, r io.Reader, yield func(TermMeta) error) error
func DecodeKanjiBank(ctx context.Context, r io.Reader, yield func(Kanji) error) error
func DecodeKanjiMetaBank(ctx context.Context, r io.Reader, yield func(KanjiMeta) error) error
func DecodeTagBank(ctx context.Context, r io.Reader, yield func(Tag) error) error
```

Cada decoder verifica el array superior, lee una entrada cada vez, comprueba la
aridad posicional y llama a `yield` antes de continuar. El error debe incluir
familia, número de banco e índice de entrada; un mensaje que solo diga
`invalid character` no es suficiente para localizar un diccionario roto.

`OpenDir` carga únicamente `index.json` y el inventario de nombres. No decodifica
los bancos. Las familias de bancos son independientes y sus números se ordenan
como enteros, no lexicográficamente.

## API inicial del almacenamiento

```go
type Store struct {
	// conexión escritora y pool lector, privados
}

type ImportID int64

func OpenStore(path string, options StoreOptions) (*Store, error)
func (s *Store) Migrate(ctx context.Context) error
func (s *Store) BeginDictionary(ctx context.Context, source SourceMetadata) (ImportID, error)
func (s *Store) ImportBank(ctx context.Context, id ImportID, bank yomidict.Bank) error
func (s *Store) FinalizeDictionary(ctx context.Context, id ImportID) error
func (s *Store) FailDictionary(ctx context.Context, id ImportID, cause error) error
func (s *Store) RecoverInterruptedImports(ctx context.Context) error
```

`ImportBank` abre el archivo, inicia la transacción, prepara los statements,
invoca el decoder correspondiente e inserta cada valor recibido. Solo confirma
después de consumir y validar el banco entero.

Puede ser útil separar internamente los sinks por familia:

```go
func insertTerm(ctx context.Context, tx *sql.Tx, versionID int64, term yomidict.Term) error
func insertTermMeta(ctx context.Context, tx *sql.Tx, versionID int64, meta yomidict.TermMeta) error
func insertKanji(ctx context.Context, tx *sql.Tx, versionID int64, kanji yomidict.Kanji) error
func insertKanjiMeta(ctx context.Context, tx *sql.Tx, versionID int64, meta yomidict.KanjiMeta) error
func insertTag(ctx context.Context, tx *sql.Tx, versionID int64, tag yomidict.Tag) error
```

No se creará un tipo `DatabaseDictionary` con todas las filas en slices. El
almacenamiento recibe una entrada y la consume antes de pedir la siguiente.

## Tipos fuente que necesitaremos

- `Index`, incluyendo `format`/`version`, `revision`, `sequenced`, idiomas,
  frecuencia y metadatos opcionales.
- `Term`, con término, lectura, tags, reglas, score, secuencia y definiciones.
- Variantes de definición: texto, imagen, deinflection y contenido estructurado.
- Árbol de contenido estructurado que conserve orden, atributos, estilos y
  referencias a recursos.
- `TermMeta` discriminado al menos para frecuencia, pitch e IPA según el formato
  que decidamos soportar.
- `Kanji`, significados y estadísticas.
- `KanjiMeta`.
- `Tag`.

Los valores `string | number`, escalares opcionales y diferencias entre formato
1 y formato 2/3 deben normalizarse de manera explícita. La ausencia de un campo
no siempre equivale a su valor cero; se usarán punteros o tipos opcionales cuando
esa distinción llegue hasta SQLite.

## Tests de Yomidict

### Índice e inventario

- Rechaza directorio vacío, `index.json` ausente, ilegible o con JSON truncado.
- Valida campos obligatorios y versiones soportadas.
- Comprueba la precedencia entre `format` y el alias histórico `version`.
- Descubre todas las familias sin exigir que una excluya a las demás.
- Ordena `bank_2` antes de `bank_10`.
- Rechaza números duplicados, cero, huecos y nombres casi válidos.
- Ignora recursos permitidos que no sean bancos sin confundirlos con JSON de
  banco.

### Decoder streaming común

- Rechaza una raíz que no sea array, arrays sin cerrar y basura después del
  cierre.
- No llama a `yield` después del primer error.
- Propaga el error de `yield` sin seguir leyendo.
- Atiende `context.Canceled` entre entradas.
- Incluye banco e índice de entrada en cada error.
- Una entrada grande no obliga a conservar las anteriores.
- Un lector artificial que entrega fragmentos pequeños produce el mismo
  resultado que un `bytes.Reader`.

### Tuplas y familias

- Acepta exactamente la aridad documentada y rechaza una posición ausente o
  adicional.
- Rechaza el tipo JSON incorrecto en cada posición, incluido `null` donde no se
  permita.
- Cubre formato 1 y formato 2/3 por separado allí donde cambien las tuplas.
- `term_bank`: texto, tags vacíos y múltiples, reglas, score, sequence y todas
  las variantes de definición.
- Contenido estructurado: texto, arrays, anidamiento, atributos, estilos,
  imágenes y tags desconocidos según la política que decidamos.
- `term_meta_bank`: cada discriminador soportado y discriminador desconocido.
- Frecuencia: número, string y objeto, conservando ausencia frente a cero.
- Pitch/IPA: escalares frente a arrays y campos opcionales.
- `kanji_bank`: lecturas vacías, varios significados y mapa de estadísticas.
- `kanji_meta_bank`: variantes permitidas y rechazadas.
- `tag_bank`: nombre, categoría, orden, notas y score.
- Los arrays ordenados sobreviven con el mismo orden semántico.

Todos estos tests usarán strings JSON mínimos escritos por nosotros. Los casos
complejos tendrán fixtures revisables dentro del repositorio; no dependerán de
un corpus externo ni del proyecto de referencia.

## Tests de SQLite e importación

### Esquema

- Las migraciones son repetibles y dejan la versión esperada.
- Todas las conexiones activan WAL, foreign keys y la política de espera.
- Las foreign keys son válidas (`PRAGMA foreign_key_check`).
- Las columnas que conservan orden tienen una restricción o índice adecuado.
- Existen índices para las búsquedas reales y para las claves hijas usadas en
  limpieza.

### Atomicidad por banco

- Un banco válido confirma todas sus filas.
- Un error provocado a mitad del banco deja cero filas de ese banco.
- Los bancos confirmados anteriormente permanecen, pero la versión sigue
  invisible.
- Un error al insertar un hijo revierte también su entrada padre.
- El registro de banco importado se confirma en la misma transacción que sus
  filas.

### Publicación

- Una importación incompleta no aparece en `ListDictionaries` ni en búsquedas.
- Finalizar sin todos los bancos falla y no cambia `active_version_id`.
- La publicación hace visible todo el diccionario en una sola transacción.
- Al actualizar, la versión anterior permanece visible durante toda la carga.
- Si falla la publicación, la versión anterior continúa activa.
- Una consulta iniciada antes de publicar conserva su snapshot; una nueva ve la
  versión publicada.

### UI durante la importación

- Una conexión lectora consulta un diccionario activo mientras otra conexión
  mantiene una transacción de banco abierta.
- Solo existe un escritor coordinado.
- Una escritura de UI sigue la política elegida de cola/timeout y no produce un
  segundo escritor descontrolado.
- Las transacciones de lectura se cierran y no provocan crecimiento indefinido
  del WAL.

### Interrupción y recuperación

- Cancelar durante un banco revierte ese banco.
- Las versiones `importing` abandonadas se detectan al reiniciar.
- La limpieza elimina hijos sin violar foreign keys.
- Una versión `failed` jamás queda activa.
- Reintentar el mismo diccionario crea o reutiliza una versión de forma
  definida, sin duplicar datos visibles.

### Fidelidad mínima de ida y consulta

- Insertar una entrada de cada familia y consultarla conserva todos los campos
  relevantes.
- El orden de definiciones, nodos, tags y otros arrays se reconstruye mediante
  `ord`, nunca mediante `rowid`.
- FTS o las tablas derivadas devuelven resultados únicamente de versiones
  activas.
- Los recursos grandes siguen en disco y la base conserva una referencia
  confinada al directorio del diccionario.

## Orden de implementación

1. `Index`, `OpenDir` y descubrimiento numérico de bancos.
2. Infraestructura común del decoder streaming y contexto.
3. `Tag` y `Term` simple, todavía sin contenido estructurado complejo.
4. Migraciones, catálogo de versiones e índices globales.
5. Importación transaccional de un banco y consultas que filtren por versión
   activa.
6. Publicación atómica, fallo y recuperación de importaciones interrumpidas.
7. Resto de familias y variantes de metadatos.
8. Contenido estructurado e imágenes.
9. FTS y consultas concretas de la UI.
10. Medición con diccionarios reales y optimización basada en resultados.

Cada paso debe terminar con tests antes de ampliar el siguiente. No se añade
paralelismo de importación salvo que las mediciones demuestren que el worker
secuencial es insuficiente.
