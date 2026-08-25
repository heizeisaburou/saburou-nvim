# marksman

Volver a [README.md](/README.md)  
<https://github.com/artempyanykh/marksman>

## Brief

El soporte de Markdown **fuera** de un vault: cualquier carpeta con notas, o un repo con
`docs/`. Dentro de un vault manda [nyabsidian](/docs/langs/nyabsidian.md).

## Sintaxis Wiki

Marksman permite dos estilos de enlace Wiki:

- `[[mi-nota]]` — el nombre en minúsculas y con guiones.
- `[[Mi nota]]` — el nombre del archivo tal cual (_file stem_).

Por defecto se usa el primero. Para cambiarlo, crea un `.marksman.toml` en la raíz del
proyecto:

```toml
[completion.wiki]
style = "file-stem"
```

Valores disponibles:

```text
file-path
file-stem
```

Ese archivo **manda sobre todo el proyecto**: el completado, el rename y la reescritura
de enlaces escriben en el estilo que declares ahí.

## Cómo escribir un enlace

Escribe `[[` o `[texto](` y el completado te ofrece las notas y las carpetas del
proyecto. Cada sintaxis inserta lo que le corresponde:

| escribes   | sale                          |
| ---------- | ----------------------------- |
| `[[`       | `[[Mi nota]]`                 |
| `[texto](` | `[texto](/docs/Mi%20nota.md)` |

Un enlace Wiki lleva el espacio tal cual. Uno Markdown lo lleva como `%20`, porque un
espacio suelto **corta el destino** y el enlace se rompe en GitHub.

### Si el `%20` te molesta

Los ángulos son la otra forma válida de escribir el mismo destino, y ahí el espacio
va literal:

```markdown
[texto](/docs/Mi%20nota.md) ← lo que inserta el completado
[texto](</docs/Mi nota.md>) ← lo mismo, legible
```

Las dos funcionan igual en todas partes: seguir el enlace, previsualizar, renombrar y
los diagnósticos. Si escribes `[texto](<` el completado te ofrece las notas sin escapar
nada, y si renombras la nota el enlace se queda con la ruta legible en vez de
recuperar el `%20`.

Lo que **no** cambia es qué inserta el completado por defecto: `%20`. Los ángulos son cosa
tuya, y sólo hace falta escribir el `<` a mano una vez por enlace.

## Un enlace lleva dos formas de escribir un espacio, y no es un fallo

Esto sorprende, así que vale la pena decirlo:

```markdown
[texto](/docs/Mi%20nota.md#mi-heading) ^^^ %20 aquí ^ ^ guiones aquí
```

No es una incoherencia: son dos cosas distintas.

Lo de la izquierda es **el nombre de un archivo que existe**. El archivo se llama
`Mi nota.md`, con espacio, y en una ruta el espacio se escribe `%20` (o entre ángulos,
ver arriba). Escribir `/docs/Mi-nota.md` no sería el mismo nombre de otra forma: sería
el nombre de **otro** archivo, uno que no existe.

Lo de la derecha es **un identificador que se fabrica** a partir del texto del heading.
No hay ningún sitio donde ponga `mi-heading`: lo calculan GitHub y marksman a partir de
`## Mi heading`, pasando a minúsculas y cambiando los espacios por guiones. Es la única
forma que resuelve, así que ahí un `%20` no llevaría a ninguna parte.

Resumiendo: a la izquierda mandan tus nombres de archivo, a la derecha manda GitHub.
Al **leer**, de todos modos, se acepta cualquiera de las dos (`#Mi heading` y `#mi-heading`
van al mismo sitio).

## Al leer se acepta casi todo

No hace falta que aciertes con la forma exacta. Para un archivo `Mi nota.md` funcionan
todas:

```text
[[Mi nota]]   [[mi nota]]   [[mi-nota]]   [[Mi%20nota]]   [[carpeta/Mi nota]]
```

Con un destino Markdown la tolerancia es menor, y por lo dicho arriba: ahí no se
busca una nota, se abre una ruta. `[texto](/docs/Mi%20nota.md)` y
`[texto](</docs/Mi nota.md>)` valen las dos, pero `/docs/mi-nota.md` no, porque no hay
ningún archivo que se llame así.

Lo que **no** resuelve es un nombre que no corresponda a ningún archivo. Si tu nota se
llama `Mi nota larga.md`, `[[mi-nota]]` no existe aunque su título diga otra cosa: la
identidad de una nota es el nombre de su archivo.

## Atajos

| tecla        | qué hace                                              |
| ------------ | ----------------------------------------------------- |
| `<CR>`       | seguir el enlace, plegar el heading o marcar la tarea |
| `gd`         | ir a la definición                                    |
| `K`          | previsualizar la nota enlazada                        |
| `<C-A-r>`    | renombrar (actualiza los enlaces de todo el proyecto) |
| `<leader>nf` | seguir el enlace bajo el cursor                       |
| `<leader>nb` | ver qué notas enlazan a esta                          |
| `<leader>nx` | marcar/desmarcar tarea                                |
| `<leader>ns` | copia inteligente                                     |

La **copia inteligente** copia lo que haya bajo el cursor sin sus delimitadores: el
contenido de un bloque de código, el destino o la etiqueta de un enlace, el texto en
negrita... Y sobre un heading copia un enlace listo para pegar.

## Comandos

| comando               | qué hace                                                  |
| --------------------- | --------------------------------------------------------- |
| `:MarksmanFollowLink` | seguir el enlace bajo el cursor                           |
| `:MarksmanBacklinks`  | qué notas enlazan a esta                                  |
| `:MarksmanRelink`     | poner todos los enlaces del proyecto en su forma canónica |

`:MarksmanRelink` es útil después de cambiar el estilo en `.marksman.toml`: te dice
cuántos enlaces va a tocar y en qué estilo, y espera tu confirmación. Nunca toca un
enlace externo, ni uno que no resuelva, ni uno ambiguo.

## Crear una nota

Escribe un enlace a una nota que no existe y pulsa `<CR>`. Te pregunta el nombre —con
el del enlace ya puesto, así que basta con aceptar— y crea el archivo. Si cambias el
nombre, el enlace se reapunta solo.

## Avisos

Se marcan los enlaces que no llevan a ninguna parte y los ambiguos (más de una nota
responde a ese nombre). Dentro de un bloque de código no se avisa de nada: ahí un
`[[ejemplo]]` es texto, no un enlace.
