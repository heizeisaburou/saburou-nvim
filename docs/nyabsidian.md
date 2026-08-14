---
id: nyabsidian
aliases: []
tags: []
---

# Nyabsidian — tu carpeta como vault de Obsidian

> [!NOTE]
>
> Nyabsidian convierte **cualquier carpeta** en un vault de Obsidian: crea un archivo
> `.nyabsidian` en ella y esa carpeta gana todas las capacidades de obsidian.nvim —enlaces wiki,
> renombrado de notas, notas diarias, plantillas, frontmatter…— con configuración propia de esa
> carpeta.

## Qué ganas

En las carpetas con `.nyabsidian` (y con la config global en cualquier otra), sobre tus notas `.md`
tienes:

- **LSP de Obsidian (obsidian-ls)**: mucho más completo que un LSP de markdown genérico —
  completado, referencias y renombrado inteligente de enlaces.
- **Renombrar notas sin romper nada**: `:ObsidianRename` cambia el nombre de la nota y actualiza
  todos los `[[enlaces]]` que apuntaban a ella.
- **Enlaces wiki**: escribe `[[` y te completa con las notas del vault; `gf` (o `<CR>`) sobre un
  enlace salta a la nota.
- **Panel de propiedades y backlinks**: en la parte inferior de cada nota ves sus propiedades y
  qué notas enlazan a ella.
- **Frontmatter automático** (opcional, por carpeta): al guardar se generan `id`, `aliases` y
  `tags` conservando el resto de metadatos de la nota.
- **Notas diarias, plantillas y adjuntos** con carpeta y reglas propias por vault.
- **Adjuntos completos**: abre y renombra imágenes, PDF y cualquier otro archivo local sin
  depender de las limitaciones de obsidian-ls.

## Cómo funciona

- **El archivo ES el marcador**: la carpeta donde guardes un `.nyabsidian` es la raíz del vault.
  No hacen falta `.obsidian` ni otros indicadores.
- **Config por carpeta**: el `.nyabsidian` es un archivo Lua que devuelve opciones. Lo que no
  definas lo decide la config global.
- **En vivo**: guarda cambios en un `.nyabsidian` y aplican sin reiniciar Neovim.
- **Vaults anidados**: si hay un vault dentro de otro, gana el más específico (la carpeta más
  profunda).
- **Sesiones restauradas**: después de `rs`, todas las notas cargadas recuperan sus autocmds,
  obsidian-ls, footer y Tree-sitter aunque su `FileType` ocurriera antes de cargar el plugin.

El archivo `.nyabsidian` es Lua y devuelve un fragmento de opciones. Se valida con la
configuración de obsidian.nvim y se fusiona por clave con los defaults; funciones como
`frontmatter.func`, `note_id_func` o `callbacks` son valores válidos. Un error de sintaxis,
ejecución o un resultado que no sea una tabla produce un aviso y usa los defaults.

## Empezar

1. `:NyabsidianMake` — abre un archivo nuevo con la plantilla.
2. Guárdalo como `.nyabsidian` en la carpeta que quieras convertir en vault (`:w` te pide la ruta
   y gestiona conflictos si ya existe).
3. Listo: abre cualquier `.md` de esa carpeta y tendrás las capacidades de Obsidian.

## Configurar una carpeta

Edita su `.nyabsidian` y descomenta o añade lo que quieras:

| Clave                                  | Qué hace                                                     | Ejemplo                                         |
| -------------------------------------- | ------------------------------------------------------------ | ----------------------------------------------- |
| `frontmatter.enabled`                  | Genera `id`/`aliases`/`tags` al guardar                      | `frontmatter = { enabled = true }`              |
| `frontmatter.func`                     | Construye el frontmatter a medida (función por nota)         | la función de ejemplo de la plantilla           |
| `link.style`                           | Enlaces `wiki` (`[[nota]]`) o `markdown` (`[nota](nota.md)`) | `link = { style = "markdown" }`                 |
| `templates.folder`                     | Carpeta de plantillas del vault                              | `templates = { folder = "Templates" }`          |
| `daily_notes.folder`                   | Carpeta de las notas diarias                                 | `daily_notes = { folder = "Diario" }`           |
| `daily_notes.default_tags`             | Tags que llevan las notas diarias                            | `daily_notes = { default_tags = { "diario" } }` |
| `attachments.folder`                   | Carpeta para adjuntos e imágenes                             | `attachments = { folder = "Adjuntos" }`         |
| `nyabsidian.attachment_paths.vault`    | Reescritura de adjuntos internos (propia)                    | `"preserve"` o `"simplify"`                     |
| `nyabsidian.attachment_paths.external` | Reescritura de adjuntos externos (propia)                    | `"preserve"` o `"absolute"`                     |

## Comandos

Comandos de Nyabsidian:

| Comando                  | Qué hace                                            |
| ------------------------ | --------------------------------------------------- |
| `:NyabsidianMake`        | Abre un buffer con la plantilla de `.nyabsidian`    |
| `:NyabsidianInfo`        | Estado de la carpeta actual y sus vaults            |
| `:NyabsidianRefresh`     | Redescubre las carpetas que son vaults              |
| `:NyabsidianFrontmatter` | Regenera el frontmatter de la nota actual (forzado) |
| `:NyabsidianDebug`       | Diagnóstico del LSP                                 |
| `:NyabsidianCopyPath`    | Copia el path absoluto de la nota o enlace          |
| `:NyabsidianConvertLink` | Cambia el formato del enlace bajo el cursor         |
| `:NyabsidianFetchTitle`  | Usa el título de una web como label Markdown        |

Y los del propio obsidian.nvim, disponibles dentro de cualquier nota:

| Comando                                                                            | Qué hace                                             |
| ---------------------------------------------------------------------------------- | ---------------------------------------------------- |
| `:ObsidianNew`                                                                     | Crea una nota nueva en el vault                      |
| `:ObsidianRename`                                                                  | Renombra la nota y actualiza todos sus enlaces       |
| `:ObsidianQuickSwitch`                                                             | Cambia rápido de nota                                |
| `:ObsidianSearch`                                                                  | Busca notas (con grep del contenido)                 |
| `:ObsidianFollowLink`                                                              | Sigue el enlace bajo el cursor                       |
| `:ObsidianLink` / `:ObsidianLinkNew`                                               | Crea un enlace a una nota existente / nueva          |
| `:ObsidianToday` / `:ObsidianYesterday` / `:ObsidianTomorrow` / `:ObsidianDailies` | Notas diarias                                        |
| `:ObsidianTemplate` / `:ObsidianNewFromTemplate`                                   | Inserta / crea nota desde plantilla                  |
| `:ObsidianTOC`                                                                     | Tabla de contenidos de la nota                       |
| `:ObsidianPasteImg`                                                                | Pega una imagen desde el portapapeles a los adjuntos |
| `:ObsidianTags`                                                                    | Lista las etiquetas del vault                        |
| `:ObsidianToggleCheckbox`                                                          | Marca/desmarca casillas de tareas                    |
| `:ObsidianWorkspace`                                                               | Cambia de vault                                      |
| `:ObsidianCheck`                                                                   | Estado y opciones del plugin                         |

## Teclas rápidas

Dentro de cualquier nota (`<leader>` es la barra espaciadora):

| Tecla        | Qué hace                                                                        |
| ------------ | ------------------------------------------------------------------------------- |
| `<CR>`       | **Acción inteligente**: sigue enlaces, togglea/crea checkboxes, pliega headings |
| `]o` / `[o`  | Siguiente / anterior enlace de la nota                                          |
| `<leader>nn` | Nueva nota                                                                      |
| `<leader>nr` | Renombrar la nota o el heading bajo el cursor (actualiza sus enlaces)           |
| `<leader>ns` | Cambiar rápido de nota                                                          |
| `<leader>nb` | Qué notas enlazan a la actual                                                   |
| `<leader>nl` | Enlazar la selección a una nota nueva                                           |
| `<leader>nL` | Enlazar a una nota existente                                                    |
| `<leader>nd` | Notas diarias                                                                   |
| `<leader>nt` | Insertar plantilla                                                              |
| `<leader>nT` | Listar tags del vault                                                           |
| `<leader>nf` | Seguir el enlace bajo el cursor                                                 |
| `<leader>nx` | Toggle de checkbox en la línea                                                  |
| `<leader>np` | Pegar imagen del portapapeles                                                   |
| `<leader>nc` | Copiar el path absoluto de la nota o del enlace bajo el cursor                  |
| `<leader>nC` | Elegir el formato del enlace bajo el cursor                                     |
| `<leader>nu` | Usar el título de una web como label del enlace                                 |
| `gd`         | Ir a una nota/heading o abrir el adjunto bajo el cursor                         |
| `gx`         | Abrir una URL o un adjunto con Neovim o con la aplicación del sistema           |
| `K`          | Hover con metadatos y un extracto breve de la nota enlazada                     |
| `<C-A-r>`    | Rename LSP del componente exacto del enlace o tag bajo el cursor                |

> [!NOTE]
>
> El ciclo de checkbox por defecto es `" "` → `~` → `!` → `>` → `x`: el primer toggle de una
> casilla vacía la deja en `~` (pendiente), no en `x` (hecho).

Los enlaces jerárquicos como `[[nota#Header#Subheader]]` funcionan con `<CR>`, `gd` y
`:Obsidian follow_link`. Si el heading no existe pero la nota sí, se muestra el error y la
navegación cae en la nota. El rename LSP (`<C-A-r>`) distingue el componente bajo el cursor:
nota, header o subheader; también puede iniciarse directamente sobre una declaración de heading.
No hace falta escribir los ancestros comunes: `[[nota#FatherA#Child]]` es suficiente si esa cadena
desambigua `Child`; solo se anteponen más headings cuando todavía quedan varios destinos.
El cuadro de rename parte del nombre real (`FatherA`, no `fathera`): ese texto se aplica
literalmente al heading, mientras los enlaces se escriben con su anchor canónico
(`My Father A` → `my-father-a`).

Sobre un tag, `<C-A-r>` renombra la rama completa en cuerpo y frontmatter. Por ejemplo, cambiar
`#proyecto` a `#trabajo` convierte `#proyecto/urgente` en `#trabajo/urgente`; los bloques de código
quedan fuera. Es la misma jerarquía que usa la búsqueda de tags de Obsidian.

La acción inteligente solo devuelve `za` sobre headings y frontmatter cuando el folding Markdown
está activo. Sin folding devuelve Enter normal, evitando que `checkbox.create_new` convierta un
heading en una tarea.

También se manejan las referencias Markdown `[texto][id]`, `[id][]` y `[id]` con una definición
`[id]: destino "description"`. La definición pertenece a la nota actual y sus tres componentes
son independientes:

- `id` tiene rename global sobre la definición y todos sus usos, y se ofrece en completion al
  escribir una referencia;
- un destino local completa notas del vault y conserva `<...>` y cualquier fragment al reemplazar
  únicamente el path; navegación y rename usan Nyabsidian;
- una URL externa se delega en obsidian.nvim;
- `description` tiene prepareRename/rename local sobre el texto interior y conserva sus
  delimitadores originales: `"..."`, `'...'` o `(...)`.

`gd` sobre `[texto][id]`, `[id][]` o `[id]` salta a su declaración `[id]: destino`, no atraviesa
esa declaración hasta la nota. `gd` sobre el destino de la declaración sí salta a la nota.

`K` devuelve únicamente Markdown renderizable de la nota, sin ruta, sintaxis de definición ni
mensajes técnicos. Si existe cuerpo, muestra su extracto. Si la nota solo contiene frontmatter,
muestra un aviso visual de nota vacía con su nombre y las propiedades no vacías, nunca un encabezado
que pueda confundirse con contenido real. Un destino que declara `.md`
exige una nota cuyo archivo termine exactamente en `.md`: nunca se acepta por similitud un archivo
residual `.md.md`. Los adjuntos se delegan y por ahora no fabrican una preview propia.
Los handlers propios se fusionan o delegan con los de obsidian.nvim, de modo que una futura
implementación upstream puede convivir con ellos sin duplicar resultados.

### Contrato consolidado para referencias CommonMark

El ejemplo canónico es:

```markdown
[algoa]: other_a.md "Descripción opcional"
```

Nyabsidian debe tratar identificador, destino y descripción como rangos LSP independientes;
completar notas solo en destinos locales; completar identificadores ya definidos en los usos;
mantener intactas las URLs externas; mostrar hover de la nota desde cualquier forma de enlace; y
no asumir una preview para adjuntos. La gramática propia se limita deliberadamente a definiciones
de una línea. Conform debe neutralizar cualquier expansión multilínea introducida por Prettier.

`<leader>nb` abre siempre el selector de backlinks: no salta directamente al destino cuando solo
hay uno y también muestra el selector vacío cuando no existe ninguno. Así la acción conserva el
mismo significado de revisión con cero, uno o varios resultados.

## Adjuntos

`<CR>`, `gd` y `gx` comparten un único resolvedor de vault. Los archivos de texto se abren dentro
de Neovim; imágenes, PDF, audio, vídeo y demás binarios se abren con la aplicación del sistema.
La decisión se toma por el contenido, no mediante una lista cerrada de extensiones: un `.mp4`
textual entra en Neovim y cualquier formato no textual se delega al opener/MIME del sistema.
Marksman usa el mismo clasificador y opener. En sistemas sin el ejecutable `file`, como una
instalación normal de Windows, el fallback inspecciona firmas binarias, BOM, NUL y bytes de
control; la delegación final sigue siendo `vim.ui.open()` para conservar `xdg-open`, `open` o la
asociación de Windows según la plataforma.
`attachments.folder` solo decide dónde se añaden o pegan archivos nuevos: nunca altera la
resolución de un enlace existente.

El resolvedor reproduce el ranking de la app Obsidian: paths exactos primero; para un basename
duplicado, candidatos bajo la carpeta de la nota antes que el resto y, después, el path más corto.
La búsqueda no distingue mayúsculas/minúsculas y no entra en vaults anidados.

El rename LSP muestra como valor inicial una ubicación editable, no únicamente el basename. Para
un archivo interno usa su path desde la raíz del vault; para uno externo conserva su forma
explícita. El contenido editado conserva esa gramática: cualquier path ordinario, incluido un
basename, parte de la raíz del vault; `./` y `../` parten de la carpeta de la nota.

```text
new.png                  rename + move a la raíz del vault
archive/deep/new.png     rename + move desde la raíz del vault
./new.png                rename + move junto a la nota actual
```

Si se omite la extensión se conserva la anterior y las carpetas necesarias se crean. Todas las
referencias wiki, Markdown y Canvas se actualizan por identidad, preservando embeds, labels,
dimensiones, títulos, fragments y URL encoding. Por defecto también conservan su clase de path;
`link.format` solo canonicaliza adjuntos si se activa expresamente `vault = "simplify"`.

### Políticas propias de Nyabsidian

Estas opciones no existen en obsidian.nvim. Viven deliberadamente bajo la clave `nyabsidian` del
archivo `.nyabsidian`:

```lua
return {
  nyabsidian = {
    attachment_paths = {
      vault = "preserve",
      external = "preserve",
    },
  },
}
```

Las dos usan `preserve` por defecto:

- `vault = "preserve"`: cada referencia interna conserva su sistema de coordenadas. Un absoluto
  continúa absoluto, `file://` continúa URI, `./`/`../` continúa relativo a su nota, un path de
  vault continúa relativo al vault y un basename continúa corto mientras no pierda identidad.
- `vault = "simplify"`: las referencias internas se canonicalizan mediante `link.format` del
  workspace (`shortest`, `relative` o `absolute`).
- `external = "preserve"`: los absolutos externos permanecen absolutos, las URI permanecen URI y
  los relativos externos se recalculan desde cada nota, pero continúan siendo relativos.
- `external = "absolute"`: toda referencia a un destino externo se convierte en un path absoluto
  del sistema.

`preserve` no significa dejar una referencia rota sin modificar: el target se actualiza para
seguir al archivo, pero no cambia arbitrariamente de absoluto a relativo ni al contrario. Si un
basename interno deja de ser seguro por una colisión, se amplía al path de vault necesario.

### Acciones de paths

`<leader>nc` (`:NyabsidianCopyPath`) hace un yank characterwise del path absoluto ya resuelto en
los registros `"` y `0` de Neovim, sin añadir un salto de línea. Sobre un enlace copia la nota o
adjunto de destino; fuera de un enlace copia la nota actual. No fuerza el clipboard del sistema:
la sincronización global de Neovim o `<leader>cs` se ocupan de ello cuando interesa.

`<leader>nC` (`:NyabsidianConvertLink`) cambia únicamente la referencia bajo el cursor. No modifica
otros enlaces de la nota ni del vault. El selector ofrece solo representaciones válidas:

| Destino         | Formatos disponibles                                          |
| --------------- | ------------------------------------------------------------- |
| Nota interna    | más corto seguro, desde la raíz del vault, relativo a la nota |
| Nota externa    | absoluto del sistema, relativo a la nota                      |
| Adjunto interno | los tres anteriores, absoluto del sistema y URI `file://`     |
| Adjunto externo | absoluto del sistema, relativo a la nota y URI `file://`      |

"Más corto" usa el basename solo si sigue identificando inequívocamente el destino; también
considera las colisiones de nombres y aliases entre notas. La conversión conserva el estilo wiki
o Markdown, embeds, labels, headings/fragments, dimensiones, títulos y URL encoding. Un relativo
en la misma carpeta se escribe explícitamente como `./archivo`.

## Frontera con Markdown general

Dentro de `.obsidian/` o `.nyabsidian` manda siempre la semántica del vault descrita aquí. Fuera
del vault no se reutilizan su búsqueda por basename ni sus paths desde la raíz: ese contrato se
está diseñando por separado en [Marksman](marksman.md).

## Notas

- Una nota con el frontmatter malformado (corchetes `[`/`{` sin cerrar) **no se reescribe al
  guardar**: se avisa y el archivo queda intacto.
- Si una carpeta no se comporta como vault, comprueba que su `.nyabsidian` es Lua válido y mira
  `:NyabsidianInfo`.
