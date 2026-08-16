# marksman

El soporte de Markdown **fuera** de un vault: cualquier carpeta con notas, o un repo con `docs/`.
Dentro de un vault manda [[nyabsidian]].

## Sintaxis Wiki

Marksman permite dos estilos de enlace Wiki:

- `[[mi-nota]]` — el nombre en minúsculas y con guiones.
- `[[Mi nota]]` — el nombre del archivo tal cual (_file stem_).

Por defecto se usa el primero. Para cambiarlo, crea un `.marksman.toml` en la raíz del proyecto:

```toml
[completion.wiki]
style = "file-stem"
```

Valores disponibles:

```text
file-path
file-stem
```

Ese archivo **manda sobre todo el proyecto**: el completado, el rename y la reescritura de enlaces
escriben en el estilo que declares ahí.

## Cómo escribir un enlace

Escribe `[[` o `[texto](` y el completado te ofrece las notas y las carpetas del proyecto. Cada
sintaxis inserta lo que le corresponde:

| escribes    | sale                          |
| ----------- | ----------------------------- |
| `[[`        | `[[Mi nota]]`                 |
| `[texto](`  | `[texto](/docs/Mi%20nota.md)` |

Un enlace Wiki lleva el espacio tal cual. Uno Markdown lo lleva como `%20`, porque un espacio
suelto **corta el destino** y el enlace se rompe en GitHub. Si prefieres verlo legible, los
ángulos también valen: `[texto](</docs/Mi nota.md>)`.

## Al leer se acepta casi todo

No hace falta que aciertes con la forma exacta. Para un archivo `Mi nota.md` funcionan todas:

```text
[[Mi nota]]   [[mi nota]]   [[mi-nota]]   [[Mi%20nota]]   [[carpeta/Mi nota]]
```

Lo que **no** resuelve es un nombre que no corresponda a ningún archivo. Si tu nota se llama
`Mi nota larga.md`, `[[mi-nota]]` no existe aunque su título diga otra cosa: la identidad de una
nota es el nombre de su archivo.

## Atajos

| tecla       | qué hace                                              |
| ----------- | ----------------------------------------------------- |
| `<CR>`      | seguir el enlace, plegar el heading o marcar la tarea |
| `gd`        | ir a la definición                                    |
| `K`         | previsualizar la nota enlazada                        |
| `<C-A-r>`   | renombrar (actualiza los enlaces de todo el proyecto) |
| `<leader>nf`| seguir el enlace bajo el cursor                       |
| `<leader>nb`| ver qué notas enlazan a esta                          |
| `<leader>nx`| marcar/desmarcar tarea                                |
| `<leader>ns`| copia inteligente                                     |

La **copia inteligente** copia lo que haya bajo el cursor sin sus delimitadores: el contenido de
un bloque de código, el destino o la etiqueta de un enlace, el texto en negrita... Y sobre un
heading copia un enlace listo para pegar.

## Comandos

| comando              | qué hace                                                     |
| -------------------- | ------------------------------------------------------------ |
| `:MarksmanFollowLink`| seguir el enlace bajo el cursor                              |
| `:MarksmanBacklinks` | qué notas enlazan a esta                                      |
| `:MarksmanRelink`    | poner todos los enlaces del proyecto en su forma canónica     |

`:MarksmanRelink` es útil después de cambiar el estilo en `.marksman.toml`: te dice cuántos
enlaces va a tocar y en qué estilo, y espera tu confirmación. Nunca toca un enlace externo, ni
uno que no resuelva, ni uno ambiguo.

## Crear una nota

Escribe un enlace a una nota que no existe y pulsa `<CR>`. Te pregunta el nombre —con el del
enlace ya puesto, así que basta con aceptar— y crea el archivo. Si cambias el nombre, el enlace se
reapunta solo.

## Avisos

Se marcan los enlaces que no llevan a ninguna parte y los ambiguos (más de una nota responde a ese
nombre). Dentro de un bloque de código no se avisa de nada: ahí un `[[ejemplo]]` es texto, no un
enlace.
