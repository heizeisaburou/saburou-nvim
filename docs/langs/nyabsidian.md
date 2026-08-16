# nyabsidian

El soporte de notas **dentro de un vault**. Fuera de uno manda [[marksman]].

## Qué convierte una carpeta en vault

Cualquiera de estas dos, en la raíz:

- `.obsidian/` — si ya usas la app de Obsidian.
- `.nyabsidian` — un archivo Lua que devuelve una tabla. Con `return {}` basta.

Dentro de un vault, marksman se aparta y de las notas se encarga obsidian-ls.

## Nombres de nota

Una nota se llama **exactamente como la escribiste**: "Mi Nota Chula" crea `Mi Nota Chula.md`, con
sus espacios y sus mayúsculas. Ni ids generados ni guiones.

Vale tanto si la creas con `<leader>nn` como si sigues un `[[Mi Nota Chula]]` que todavía no
existe. Si el nombre ya está ocupado, se añade un número: `Mi Nota Chula 2`.

## Cómo escribir un enlace

Escribe `[[` o `[texto](` y el completado te ofrece las notas y carpetas del vault:

| escribes    | sale                          |
| ----------- | ----------------------------- |
| `[[`        | `[[Mi nota]]`                 |
| `[texto](`  | `[texto](/docs/Mi%20nota.md)` |

Un enlace Wiki lleva el espacio tal cual. Uno Markdown lo lleva como `%20`, porque un espacio
suelto **corta el destino** y el enlace se rompe en GitHub. Si prefieres verlo legible, los
ángulos también valen: `[texto](</docs/Mi nota.md>)`.

Los enlaces se escriben con la forma más corta que sea inequívoca. Si hay dos notas con el mismo
nombre, se añaden sólo las carpetas necesarias para distinguirlas: `[[carpeta/Mi nota]]`, no la
ruta entera.

## Al leer se acepta casi todo

```text
[[Mi nota]]   [[mi nota]]   [[MI NOTA]]   [[Mi%20nota]]   [[carpeta/Mi nota]]   [[/carpeta/Mi nota]]
```

La barra inicial es la raíz del vault. El `.md` es opcional al leer, y las mayúsculas dan igual
—también con acentos—. Los headings igual: `[[Nota#Mi Heading]]` y `[[Nota#mi-heading]]` llevan al
mismo sitio.

Los adjuntos también: `[[imagen.png]]` enlaza y `![[imagen.png]]` incrusta. El `!` significa
incrustar, no "adjunto".

## Atajos

| tecla        | qué hace                                        |
| ------------ | ----------------------------------------------- |
| `<CR>`       | seguir el enlace, plegar el heading o marcar la tarea |
| `<leader>nn` | nota nueva                                      |
| `<leader>nq` | cambiar de nota                                 |
| `<leader>nr` | renombrar la nota (actualiza los enlaces)       |
| `<leader>nb` | qué notas enlazan a esta                        |
| `<leader>nf` | seguir el enlace bajo el cursor                 |
| `<leader>nl` | enlazar la selección a una nota nueva           |
| `<leader>nL` | enlazar a una nota existente                    |
| `<leader>nd` | notas diarias                                   |
| `<leader>nt` | insertar plantilla                              |
| `<leader>nT` | tags del vault                                  |
| `<leader>nx` | marcar/desmarcar tarea                          |
| `<leader>np` | pegar imagen del portapapeles                   |
| `<leader>nc` | copiar la ruta absoluta del enlace              |
| `<leader>nC` | cambiar el formato del enlace                   |
| `<leader>nu` | poner de etiqueta el título de la página web    |
| `<leader>ns` | copia inteligente                               |

La **copia inteligente** copia lo que haya bajo el cursor sin sus delimitadores: el contenido de
un bloque de código, el destino o la etiqueta de un enlace, el texto en negrita... Sobre un heading
copia `[[Nota#Ese Heading]]`, listo para pegar. Y si no hay nada concreto, copia un enlace a la
nota donde estás.

## Comandos

| comando                 | qué hace                                                |
| ----------------------- | ------------------------------------------------------- |
| `:NyabsidianRelink`     | poner todos los enlaces del vault en su forma canónica   |
| `:NyabsidianSmartCopy`  | copia inteligente                                       |
| `:NyabsidianConvertLink`| cambiar el formato del enlace bajo el cursor            |
| `:NyabsidianCopyPath`   | copiar la ruta absoluta                                 |
| `:NyabsidianFetchTitle` | usar el título de la web como etiqueta                  |
| `:NyabsidianFrontmatter`| gestionar el frontmatter                                |
| `:NyabsidianRefresh`    | releer los vaults                                       |
| `:NyabsidianInfo`       | ver qué vaults hay activos                              |

`:NyabsidianRelink` te dice cuántos enlaces va a tocar y espera confirmación. Nunca toca un enlace
externo, ni uno que no resuelva, ni uno ambiguo.

## Enlaces que se arreglan solos

Si creas una nota con un nombre que ya existía en otra carpeta, los `[[Nombre]]` que ya había
dejarían de saber a cuál apuntan. Se amplían solos a `[[carpeta/Nombre]]` para que sigan señalando
la suya, conservando el `|alias` si lo tenían.

Al revés no ocurre solo: si borras la nota que colisionaba, los enlaces se quedan largos hasta que
ejecutes `:NyabsidianRelink`.

## Avisos

Se marcan las notas que no existen todavía y los enlaces que aquí funcionan pero se romperían al
publicar en GitHub: un espacio sin escapar en un destino Markdown, un `.md` que falta, o un nombre
suelto que sólo encontramos porque buscamos por todo el vault.

Dentro de un bloque de código no se avisa de nada, ni se sigue ningún enlace: ahí un `[[ejemplo]]`
es texto sobre enlaces, no un enlace.
