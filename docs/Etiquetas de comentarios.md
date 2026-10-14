# Etiquetas de comentarios

## Brief

Palabras que se escriben en un comentario para decir qué clase de comentario es: si falta algo, si está mal, si es provisional, si es un aviso. El editor las resalta con su color y su icono, y `<leader>ft` las lista todas para saltar a cualquiera.

Se escriben en mayúsculas y entre dos puntos, uno a cada lado de la palabra. En este documento los ejemplos empiezan por `/` en vez de por dos puntos, para que no aparezcan en el buscador de etiquetas.

```text
-- /TODO: atajo para abrir la nota del día.
```

Cada etiqueta tiene alias que valen lo mismo, con el mismo color y el mismo icono: `BUG` es `FIX`, `TEMP` es `PROVISIONAL`. La configuración está en [`lua/lzy/todo-comments.lua`](/lua/lzy/todo-comments.lua), que también explica cada una en su comentario. Este documento es la versión larga: cuándo usar cada una y cómo elegir entre las que se parecen.

## Cómo elegir

Hay seis grupos. Se responden estas preguntas en orden y vale la primera que diga que sí:

1. ¿Es un parche: código ya puesto que toca o rodea algo por un camino que no es el normal? → [Parches](#parches)
2. ¿Queda trabajo por hacer? → [Pendiente](#pendiente)
3. ¿Hay que tener cuidado antes de tocarlo? → [Avisos](#avisos)
4. ¿Solo da contexto? → [Información](#información)
5. ¿No es serio? → [Desahogo](#desahogo)
6. ¿Solo marca una sección del código? → [Marcadores de estructura](#marcadores-de-estructura)

El orden va de lo que más conviene poder encontrar después a lo que menos. Los parches van primero porque casi todos dejan algo pendiente (quitarlos, revisarlos), y su etiqueta dice además qué puede romperse, que es lo que importa al tocarlos. El desahogo va casi al final porque un chiste no quita que haya trabajo: si lo hay, manda la etiqueta seria.

## Cuál elegir

Lo que importa no es saberse la lista, sino elegir bien entre las que se parecen. La tabla sigue el orden de los grupos y vale la primera fila que encaje.

| Si… | Usa |
| --- | --- |
| sustituye funciones de otro desde fuera, al ejecutar | `MONKEYPATCH` |
| edita una copia del código de otro que vive en el repo | `PATCH` |
| rodea un fallo de una dependencia sin tocar su código | `UPSTREAM` |
| arregla deprisa algo nuestro que se rompió en uso | `HOTFIX` |
| es un truco nuestro que puede romperse | `HACK` |
| está mal: falla o da un resultado incorrecto | `FIX` |
| falta hacerlo y se sabe qué es | `TODO` |
| falta hacerlo, pero ahora no se puede porque depende de algo de fuera | `BLOCKED` |
| funciona, pero es una solución para poder seguir; la buena se decide cuando se sepa más | `PROVISIONAL` |
| funciona, es un atajo feo y ya se sabe cuál es la solución buena | `DEBT` |
| es código falso que solo aparenta | `STUB` |
| todavía no hay nada, solo el hueco | `PLACEHOLDER` |
| funciona y está bien, aunque podría estar mejor | `IMPROVE` |
| es una idea nueva para más adelante | `FUTURE` |
| depende de algo que nadie ha comprobado | `ASSUME` |
| se sabe que no hace algo, y se ha decidido así | `LIMIT` |
| no es serio | `XD` |

## Las que se confunden

Las cuatro que dicen "esto no es lo definitivo" se distinguen por qué se sabe y qué funciona:

|               | ¿Funciona de verdad? | ¿Se sabe cuál es la buena? |
| ------------- | -------------------- | -------------------------- |
| `PROVISIONAL` | sí                   | no, todavía                |
| `DEBT`        | sí                   | sí, y no se ha hecho       |
| `STUB`        | no, solo aparenta    | da igual: es un sustituto  |
| `PLACEHOLDER` | no hay nada          | no se ha decidido qué va   |

Los cinco parches se distinguen por qué tocan y qué los rompe:

|  | ¿Toca código de otro? | ¿Por qué existe? | ¿Qué lo rompe? |
| --- | --- | --- | --- |
| `MONKEYPATCH` | sí: lo sustituye al ejecutar | cualquier motivo | que el otro cambie esa función por dentro |
| `PATCH` | sí: edita una copia | cualquier motivo | actualizar desde el original sin volver a aplicarlo |
| `UPSTREAM` | no | un fallo de una dependencia | nada: se quita cuando lo arreglen |
| `HOTFIX` | no | algo nuestro que se rompió | nada, pero pide revisarlo con calma |
| `HACK` | no | un atajo nuestro, sin fallo | que cambie aquello en lo que se apoya |

Si lo absurdo de un truco es lo que llama la atención, pero no puede romperse, no es `HACK` sino `XD`.

Y las tres que dicen "esto podría ser distinto" se distinguen por si hay que hacer algo:

|            | ¿Hay que cambiarlo?                           |
| ---------- | --------------------------------------------- |
| `REFACTOR` | sí: la forma estorba                          |
| `IMPROVE`  | no hace falta: se podría, y ahora no compensa |
| `LIMIT`    | no: se ha decidido dejarlo así                |

## Parches

Tocan o rodean algo por un camino que no es el normal. Todos son código que ya funciona. Se elige con estas preguntas, en orden:

1. ¿Se toca código de otro (un plugin, una biblioteca, Neovim)?
	- Se sustituyen sus funciones desde fuera, al ejecutar → `MONKEYPATCH`
	- Se edita una copia de su código que vive en el repo → `PATCH`
2. ¿No se toca, pero se rodea un fallo suyo hasta que lo arreglen? → `UPSTREAM`
3. ¿Es cosa nuestra?
	- Arreglo urgente de algo que se rompió en uso → `HOTFIX`
	- Truco por un camino no previsto, que puede romperse → `HACK`

La técnica va antes que la causa porque lo que más importa al leer un parche es qué lo puede romper. Tocar el código de otro se rompe en cuanto ese otro cambia, aunque el motivo fuera un fallo suyo: un fallo de un plugin arreglado con un monkey patch es `MONKEYPATCH`, y la incidencia se enlaza en el texto.

### MONKEYPATCH

Un _monkey patch_ es cambiar el código de otro desde fuera mientras el programa corre, sin tocar sus archivos: se sustituye una de sus funciones por una nuestra. En Lua basta con asignar `require("plugin").funcion = function() ... end`. Quien lea el código del plugin no sabrá que aquí se cambia, y se rompe en cuanto el plugin cambie esa función por dentro.

Alias: `MONKEY_PATCH`, `MONKEYPATCHED`, `DUCKPUNCH`. _Duck punching_ es otro nombre para lo mismo.

```text
/MONKEYPATCH: se sustituye `open` del picker de obsidian.nvim para que use
nuestras opciones de Telescope.
```

### PATCH

Código de otro copiado en el repo y modificado, o un archivo `.patch` que se aplica sobre el suyo. Un _parche_ es eso: un cambio que se pone encima del código original. Al actualizar desde el original hay que volver a aplicar el cambio, así que conviene decir de qué versión viene y qué se cambió.

Alias: `PATCHED`.

```text
/PATCH: copiado de mini.nvim 0.14; solo cambia el cálculo del ancho.
```

No es `MONKEYPATCH`: aquí el código de otro se edita; allí se sustituye desde fuera sin tocar sus archivos.

### UPSTREAM

Rodeo para un fallo de una dependencia (un plugin, una herramienta, el propio Neovim) que se quita cuando lo arreglen ellos. _Upstream_ es el proyecto original del que dependemos, "río arriba". Conviene enlazar la incidencia y decir cuándo se puede quitar.

Alias: `WORKAROUND`. Un _workaround_ es justo eso: un rodeo para esquivar un fallo que no es nuestro.

```text
/UPSTREAM: render-markdown#123; quitar cuando salga la 8.14.
```

Su código no se toca; si se tocara, sería `MONKEYPATCH` o `PATCH`.

### HOTFIX

Arreglo urgente de algo que se rompió en pleno uso, hecho deprisa y lo más pequeño posible para que vuelva a funcionar ya; pide revisarlo con calma después. _Hot_ porque se aplica en caliente, con todo en marcha.

Alias: `QUICKFIX`, `HOTPATCH`. _Quickfix_ es "arreglo rápido", y no tiene que ver con la lista quickfix de Vim.

```text
/HOTFIX: se ignoran las notas sin título, que tumbaban el picker; falta ver
por qué llegan así.
```

No es `FIX`: aquello sigue roto; esto ya funciona. No es `DEBT`: la deuda es un atajo elegido con calma; esto es una urgencia.

### HACK

Un _hack_ es un truco: conseguir que algo funcione por un camino que el sistema no tenía previsto. No tiene nada que ver con atacar ni vulnerar nada; la palabra viene de la jerga de programadores, donde un hack es una solución ingeniosa.

Aquí marca uno que se apoya en algo que no debería, como un detalle interno de un plugin o un comportamiento no documentado, así que puede dejar de funcionar sin aviso.

```text
/HACK: se lee un campo privado de render-markdown.
```

No es `UPSTREAM`: no esquiva un fallo de nadie, es un atajo nuestro.

## Pendiente

Trabajo que falta, de más a menos urgente.

### FIX

Está mal: falla, da un resultado incorrecto o rompe algo.

Alias: `FIXME`, `BUG`, `FIXIT`, `ISSUE`, `PANIC`, `ERROR`.

```text
/FIX: con un `.md` vacío devuelve nil y el llamante no lo comprueba.
```

### TODO

Falta hacerlo y está claro qué es. Si no está claro qué es, es `PROVISIONAL` o `PLACEHOLDER`.

```text
/TODO: atajo para abrir la nota del día.
```

### BLOCKED

No se puede avanzar hasta que pase algo de fuera: una decisión, otra pieza del proyecto, una respuesta. Un `TODO` dice "falta hacerlo"; esto dice "ahora no se puede". Conviene decir qué se espera.

Alias: `BLOCKER`, `WAITING`.

```text
/BLOCKED: hasta decidir si nyabsidian sigue sobre Neovim o va aparte.
```

### PROVISIONAL

Solución puesta para poder seguir montando el resto, sabiendo que no es la definitiva. La buena se decidirá cuando se sepa lo suficiente, y esto evita tener que conjeturarla ahora. Conviene decir qué falta saber.

Alias: `TEMP`, `TEMPORARY`, `INTERIM`, `SCAFFOLD`. _Scaffold_ es "andamio": se pone para poder construir y se quita cuando el edificio se sostiene solo. _Interim_ no es una abreviatura sino una palabra inglesa, "interino": lo que ocupa el puesto mientras llega lo definitivo.

```text
/PROVISIONAL: las rutas van fijas hasta saber si habrá varios vaults.
/PROVISIONAL: se guarda en JSON; el formato se decide cuando sepamos qué
consultas hacen falta.
```

No es `DEBT`: en la deuda la buena ya se conoce y no se ha hecho; aquí todavía no se conoce. No es `STUB`: esto funciona de verdad.

### DEBT

Atajo feo hecho a sabiendas: se sabe cuál es la solución buena y no se ha hecho todavía. Es lo que se llama _deuda técnica_: se ahorra tiempo ahora a cambio de un trabajo que habrá que pagar más adelante.

Alias: `UGLY`.

```text
/DEBT: se copia la tabla entera en cada llamada; habría que cachearla.
```

### REFACTOR

Hay que reestructurarlo: funciona, pero la forma estorba. Está duplicado, mezcla responsabilidades o cuesta de leer.

Alias: `CLEANUP`, `REORGANIZE`, `REWRITE`.

```text
/REFACTOR: estas tres funciones hacen lo mismo con otro nombre de campo.
```

### PERF

Es lento, o lo será cuando crezca.

Alias: `OPTIM`, `PERFORMANCE`, `OPTIMIZE`.

```text
/PERF: recorre todo el vault en cada pulsación.
```

### STUB

Código falso que ocupa el lugar del de verdad, para que lo de alrededor se pueda escribir o probar antes de que exista.

Alias: `MOCK`. Los dos son código falso, pero no son lo mismo:

- Un _stub_ solo responde: devuelve siempre lo mismo (una nota de ejemplo, `true`) o no hace nada.
- Un _mock_ además vigila cómo lo usan: apunta con qué argumentos y cuántas veces lo llaman, para que una prueba pueda comprobarlo después.

Comparten etiqueta porque en los dos casos el código no es real.

```text
/STUB: siempre devuelve la misma nota de ejemplo.
```

### PLACEHOLDER

Hueco por rellenar: aquí irá algo y todavía no hay nada.

Alias: `PLACEHOLDERS`, `TBD`, `TOBEFILLED`, `TOBEIMPLEMENTED`, `FILLME`. _TBD_ es _to be determined_, "por determinar": aún no se ha decidido qué va.

```text
/TBD: texto de ayuda del comando.
```

### IMPROVE

Funciona y está bien, pero podría estar mejor; ahora mismo no compensa hacerlo. No es un defecto: si nunca se hace, no pasa nada.

Alias: `POLISH`, `ENHANCE`.

```text
/IMPROVE: el aviso podría decir también la línea exacta.
```

No es `REFACTOR`: eso pide cambiarlo; esto solo anota que se podría.

### FUTURE

Idea o plan para más adelante: algo nuevo, no algo que esté mal.

Alias: `NEXT`, `ROADMAP`, `UPCOMING`, `PROPOSAL`.

```text
/FUTURE: exportar las notas a PDF.
```

_Roadmap_ es "hoja de ruta": la lista ordenada de pasos previstos para llegar a un objetivo. Sirve para dejar dicho en qué paso del plan está un código y qué viene después, así quien lo lea sabe por qué hoy está incompleto y no lo "arregla" en la dirección equivocada.

```text
/ROADMAP: 1) enlaces entre notas (esto), 2) enlaces a encabezados,
3) enlaces a bloques. Por eso aquí aún no se mira lo que va tras el `#`.
```

## Avisos

Cuidado al tocar esto.

### SECURITY

Afecta a la seguridad o a la privacidad.

Alias: `VULN`, `AUTH`, `SECRET`, `PRIVACY`.

```text
/SECURITY: el token se escribe en el log.
```

### WARN

Algo que no es evidente y que conviene saber antes de cambiar el código.

Alias: `WARNING`, `XXX`. _XXX_ es una convención antigua con el mismo sentido: "ojo aquí".

```text
/WARN: el orden importa; prettier tiene que ir antes que la restauración.
```

### ASSUME

Suposición de la que depende el código y que nadie ha comprobado. Deja escrita la conjetura para poder verificarla más adelante, o para encontrarla cuando algo falle por su culpa.

Alias: `ASSUMPTION`, `ASSUMES`.

```text
/ASSUME: el vault nunca tiene enlaces simbólicos.
/ASSUME: las fechas del frontmatter vienen siempre en ISO 8601.
```

No es `PROVISIONAL`: aquello es una solución temporal; esto es una premisa que, si resulta falsa, rompe el código aunque nadie lo haya tocado.

### DEPRECATED

Sigue aquí pero no hay que usarlo: va a desaparecer o ya hay otra cosa.

Alias: `OLD`, `OBSOLETE`, `REMOVE`.

```text
/DEPRECATED: usar `open_note`.
```

## Información

Contexto, sin trabajo pendiente.

### NOTE

Explicación de por qué el código es así.

Alias: `REMARK`, `ANNOTATION`, `COMM`. _Comm_ es la abreviatura de _comment_, "comentario".

```text
/NOTE: Obsidian guarda las fechas en UTC.
```

### INFO

Dato de referencia, más secundario que una nota.

Alias: `HINT`.

```text
/INFO: el formato viene de la especificación de CommonMark, sección 4.5.
```

### REVIEW

Hay que revisarlo o hablarlo: una duda, algo que no está comprobado.

Alias: `QUESTION`, `EXPLAIN`, `DISCUSS`, `VERIFY`.

```text
/REVIEW: ¿hace falta esto si el plugin ya lo hace?
```

### DOCS

Sobre documentación: qué documento lo explica o qué falta documentar.

Alias: `DOCUMENTATION`, `README`, `GUIDE`.

```text
/DOCS: el flujo completo está en docs/language-dependencies.md.
```

### TEST

Sobre pruebas: qué la cubre, o su estado.

Alias: `TESTING`, `PASSED`, `FAILED`.

```text
/TEST: lo cubre spec/conform_markdown_spec.lua.
```

### UNUSED

Código que se queda aunque nadie lo use todavía.

Alias: `UNREFERENCED`, `UNIMPORT`.

```text
/UNUSED: lo usará el comando de exportar.
```

### LIMIT

Limitación conocida y aceptada a propósito: se sabe y no hay intención de quitarla, porque no compensa o porque es el precio de otra cosa. Evita que alguien la tome por un fallo y la "arregle".

Alias: `LIMITATION`, `KNOWN`.

```text
/LIMIT: un bloque de código sangrado dentro de un ítem de lista sigue
pasando a tabs; sin un parser no se distingue de la propia lista.
```

No es `IMPROVE`: aquello se podría mejorar; esto se ha decidido dejarlo.

### COMPAT

Código que solo existe por compatibilidad con otra versión, otro sistema o un formato antiguo. Conviene decir cuándo se podrá borrar.

Alias: `COMPATIBILITY`, `LEGACY`. _Legacy_ es "heredado": lo que viene de antes y se mantiene por quien aún depende de ello.

```text
/COMPAT: Neovim 0.10; quitar al exigir la 0.12.
```

### DONE

Algo que estaba pendiente y ya está hecho, dejado como registro.

Alias: `COMPLETED`, `FINISHED`, `OK`, `CHECKED`.

```text
/DONE: ya acepta rutas con espacios.
```

## Desahogo

Fuera de registro.

### XD

Lo que no es serio ni pretende serlo. El programador está harto, lleva semanas dando vueltas a lo mismo y lo deja de cualquier manera para poder avanzar; o suelta un chiste malo; o da con un truco tan absurdo que no debería funcionar, y funciona.

```text
/XD: tres semanas con esto. Funciona. No preguntes.
/XD: si lees esto, el café se ha acabado.
/XD: sumar cero arregla el redondeo. No sé por qué. Nadie lo sabe.
```

Alias, cada uno con su matiz:

- `WTF`, _what the fuck_: "no entiendo por qué esto funciona".
- `MAGIC`: "funciona, no sé por qué, mejor no tocarlo".
- `MEH`: "está regular, ya si eso".

Si lo absurdo además puede romperse, es `HACK` y no esto: el XD avisa de que no es serio, no de que sea frágil.

## Marcadores de estructura

No señalan trabajo ni avisos: marcan secciones del código para orientarse en él.

### CATEGORY

Encabezado de un grupo de cosas relacionadas.

Alias: `GROUP`, `CAT`, `GRP`.

```text
/CATEGORY: atajos de ventanas.
```

### CONSTRUCTOR

Un _constructor_ es la función que crea un valor nuevo y lo deja listo para usar: le pone su estado inicial y lo devuelve. No es exclusivo de la programación orientada a objetos; existe en cualquier lenguaje aunque no se llame así: en Lua es el típico `M.new(opts)` que devuelve una tabla, en Go `NewServer()`, en C `buffer_create()`.

Alias: `CONSTRUCTORS`, `INIT`, `INITIALIZE`, `NEW`.

```text
/CONSTRUCTOR: crea el workspace y registra sus autocomandos.
```

### GETTER

Un _getter_ es una función que solo lee y devuelve un dato de un objeto o de un módulo, sin cambiar nada.

Alias: `GETTERS`, `GET`, `PROPERTY`, `PROPERTIES`, `FETCH`.

```text
/GETTER: accesos a la configuración.
```

### SETTER

Un _setter_ es una función que cambia un dato de un objeto o de un módulo.

Alias: `SETTERS`, `SET`, `STORE`.

```text
/SETTER: cambios de la configuración.
```
