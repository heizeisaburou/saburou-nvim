---
id: nyabsidian
aliases: []
tags: []
---
# Nyabsidian — carpetas como vaults de Obsidian

> [!NOTE]
>
> Nyabsidian convierte **cualquier carpeta** en un vault de Obsidian: por el simple hecho de
> existir un archivo `.nyabsidian` en ella, esa carpeta gana capacidades de markdown adicionales
> (enlaces wiki, frontmatter, plantillas, notas diarias, adjuntos…), las mismas que ofrece
> obsidian.nvim pero por carpeta y con configuración propia de cada carpeta.

## Cómo funciona

- **El marcador es el archivo**: donde guardes un `.nyabsidian` es la raíz del vault. No se
  necesitan `.obsidian` ni ningún otro indicador.
- **Config por carpeta**: el `.nyabsidian` es un archivo Lua que devuelve un fragmento de
  opciones. Lo que no definas lo decide la config global (defaults).
- **En vivo**: se relee al entrar en cada nota, sin reiniciar Neovim. Guardar cambios en un
  `.nyabsidian` refresca los workspaces automáticamente.
- **Vaults anidados**: si hay un vault dentro de otro, gana el más específico (la carpeta más
  profunda).

## Empezar

1. `:NyabsidianInit` — abre un buffer con la plantilla.
2. Guárdalo como `.nyabsidian` (con `:w` pides ruta y gestionas conflictos).
3. Listo: esa carpeta ya es un vault.

## Qué activa un `.nyabsidian`

- **Frontmatter automático**: metatags `id`, `aliases`, `tags` (y el resto de metadatos que ya
  tenga la nota) generados al guardar. Se puede activar por vault, por nota (función) o dejar
  desactivado. Si el body del frontmatter está malformado (flow `[`/`{` sin cerrar), no se toca
  la nota: aviso en lugar de reescribir basura.
- **Enlaces wiki y navegación**: `[[enlace]]` con salto, completado y renombrado, incluido el
  archivo de ayuda del plugin (wiki embebida).
- **Plantillas**: carpeta de plantillas, fecha/hora y sustituciones por vault.
- **Notas diarias**: carpeta y tags por defecto por vault.
- **Adjuntos**: carpeta de archivos por vault.
- **Funciones por vault**: `note_id_func`, `note_path_func`, `callbacks`, y el `func` del
  frontmatter — todo lo que en otros sitios es "global" aquí puede ser por carpeta.
- **Multi-vault**: carpetas distintas con reglas distintas, todo en una misma sesión.

## Comandos

| Comando                  | Qué hace                                                  |
| ------------------------ | --------------------------------------------------------- |
| `:NyabsidianInit`        | Buffer con la plantilla de `.nyabsidian`                  |
| `:NyabsidianRefresh`     | Redescubre workspaces (marcadores, buffers abiertos, cwd) |
| `:NyabsidianInfo`        | Workspaces activos, config de cada uno y estado           |
| `:NyabsidianDebug`       | Información del LSP de obsidian                           |
| `:NyabsidianFrontmatter` | Regenera el frontmatter de la nota actual (forzado)       |

## Qué probar (checklist)

1. `:NyabsidianInit` en una carpeta nueva, guardar como `.nyabsidian` con la plantilla tal cual.
   `:NyabsidianInfo` debe listar esa carpeta como workspace.
2. Descomentar `frontmatter = { enabled = true }` y guardar. Abrir una nota nueva → al guardar se
   genera el frontmatter (`id`, `aliases`, `tags`). `:NyabsidianFrontmatter` lo fuerza.
3. Descomentar el `frontmatter.func` de ejemplo (la función completa) → se aplica por vault.
4. Romper a propósito el `.nyabsidian` (sintaxis inválida) → warning claro y la carpeta sigue
   funcionando con defaults; el resto de vaults intactos.
5. Editar el `.nyabsidian` de un vault y volver a entrar en una nota → los cambios aplican sin
   reiniciar (live reload).
6. Crear un vault dentro de otro (carpeta con su propio `.nyabsidian`) → cada nota usa la config
   de su carpeta más específica.
7. Nota con `aliases: [` sin cerrar en el frontmatter → `:NyabsidianFrontmatter` avisa y no toca
   el archivo.

> [!TIP]
>
> Si algo falla, `:NyabsidianInfo` y `:NyabsidianDebug` son el punto de partida para mirar qué
> config quedó activa en cada carpeta.
