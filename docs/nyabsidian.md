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

## Cómo funciona

- **El archivo ES el marcador**: la carpeta donde guardes un `.nyabsidian` es la raíz del vault.
  No hacen falta `.obsidian` ni otros indicadores.
- **Config por carpeta**: el `.nyabsidian` es un archivo Lua que devuelve opciones. Lo que no
  definas lo decide la config global.
- **En vivo**: guarda cambios en un `.nyabsidian` y aplican sin reiniciar Neovim.
- **Vaults anidados**: si hay un vault dentro de otro, gana el más específico (la carpeta más
  profunda).

## Empezar

1. `:NyabsidianInit` — abre un archivo nuevo con la plantilla.
2. Guárdalo como `.nyabsidian` en la carpeta que quieras convertir en vault (`:w` te pide la ruta
   y gestiona conflictos si ya existe).
3. Listo: abre cualquier `.md` de esa carpeta y tendrás las capacidades de Obsidian.

## Configurar una carpeta

Edita su `.nyabsidian` y descomenta o añade lo que quieras:

| Clave                      | Qué hace                                                     | Ejemplo                                         |
| -------------------------- | ------------------------------------------------------------ | ----------------------------------------------- |
| `frontmatter.enabled`      | Genera `id`/`aliases`/`tags` al guardar                      | `frontmatter = { enabled = true }`              |
| `frontmatter.func`         | Construye el frontmatter a medida (función por nota)         | la función de ejemplo de la plantilla           |
| `link.style`               | Enlaces `wiki` (`[[nota]]`) o `markdown` (`[nota](nota.md)`) | `link = { style = "markdown" }`                 |
| `templates.folder`         | Carpeta de plantillas del vault                              | `templates = { folder = "Templates" }`          |
| `daily_notes.folder`       | Carpeta de las notas diarias                                 | `daily_notes = { folder = "Diario" }`           |
| `daily_notes.default_tags` | Tags que llevan las notas diarias                            | `daily_notes = { default_tags = { "diario" } }` |
| `attachments.folder`       | Carpeta para adjuntos e imágenes                             | `attachments = { folder = "Adjuntos" }`         |

## Comandos

Comandos de Nyabsidian:

| Comando                  | Qué hace                                            |
| ------------------------ | --------------------------------------------------- |
| `:NyabsidianInit`        | Abre un buffer con la plantilla de `.nyabsidian`    |
| `:NyabsidianInfo`        | Estado de la carpeta actual y sus vaults            |
| `:NyabsidianRefresh`     | Redescubre las carpetas que son vaults              |
| `:NyabsidianFrontmatter` | Regenera el frontmatter de la nota actual (forzado) |
| `:NyabsidianDebug`       | Diagnóstico del LSP                                 |

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

## Notas

- Una nota con el frontmatter malformado (corchetes `[`/`{` sin cerrar) **no se reescribe al
  guardar**: se avisa y el archivo queda intacto.
- Si una carpeta no se comporta como vault, comprueba que su `.nyabsidian` es Lua válido y mira
  `:NyabsidianInfo`.
