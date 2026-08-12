# Sabunv Markdown — Obsidian y Marksman son dos diseños distintos

> Documento de arquitectura para `lua/sabunv/nvim/markdown.lua`, los parches de
> `lua/lzy/obsidian/` y `after/ftplugin/markdown.lua`.
>
> Fecha de los probes: 2026-08-12. Versiones observadas: Obsidian 1.13.6 y obsidian.nvim
> `69fe7c6bf61a5222b5061a9a9dfc5023f2ec0fdc`.

## 1. Decisión arquitectónica

Obsidian y Marksman no comparten semántica de enlaces. No habrá un «motor agnóstico» que intente
darles el mismo significado mediante flags.

Hay dos dominios independientes:

| Dominio           | Detección                                     | Gestor                                         | Contrato                                             |
| ----------------- | --------------------------------------------- | ---------------------------------------------- | ---------------------------------------------------- |
| Vault             | `.obsidian/` o `.nyabsidian`                  | obsidian.nvim / obsidian-ls + adaptador Sabunv | Semántica de la app Obsidian                         |
| Proyecto Markdown | `.marksman.toml` o `.git` sin marker de vault | Marksman + adaptador Sabunv futuro             | Semántica de Marksman/Markdown que se diseñe después |

`.nyabsidian` convierte una carpeta en vault. Por tanto, dentro de ella manda Obsidian aunque la
carpeta también sea un proyecto de software. No se intenta preservar simultáneamente una
interpretación Markdown distinta.

Las únicas piezas que pueden compartirse son utilidades mecánicas sin semántica:

- detectar y parsear el enlace bajo el cursor;
- clasificar una URI frente a un archivo local;
- convertir rutas y rangos LSP;
- aplicar un `WorkspaceEdit` de forma segura.

No se comparten entre ambos dominios:

- la resolución de targets;
- el tratamiento de duplicados;
- la representación nueva de los enlaces;
- el alcance de backlinks;
- el flujo principal de abrir o renombrar.

## 2. Estado real de cada componente

### 2.1 La app Obsidian es la referencia semántica

El comportamiento que se replica en un vault es el de la app Obsidian, especialmente con:

- `New link format = Shortest path when possible`;
- `Automatically update internal links = true`;
- wikilinks o enlaces Markdown según la configuración del vault.

Obsidian permite abrir, renombrar y mover adjuntos. Al renombrarlos o moverlos desde la propia
app, recalcula sus referencias.

### 2.2 obsidian.nvim / obsidian-ls no implementan todo eso para adjuntos

`obsidian-ls` es un servidor LSP dentro del proceso de Neovim. Se puede parchear, pero no se debe
confundir «el handler que nosotros envolvemos» con «comportamiento nativo del servidor».

En la versión observada:

- `prepareRename` devuelve el target textual bajo el cursor, también para un adjunto;
- el handler upstream de `textDocument/rename` resuelve el target mediante
  `search.resolve_note_async()`;
- por tanto, el rename upstream está orientado a notas y no contiene un flujo nativo de rename de
  adjuntos;
- `resolve_attachment_path()` no busca por el vault: concatena el target con `attachments.folder`
  (o con la carpeta de la nota si esa opción empieza por `.`);
- `attachment.format_link()` siempre genera el basename del adjunto;
- el `follow_link` upstream usa ese `resolve_attachment_path()` y puede abrir una ruta equivocada
  o inexistente cuando el target describe otra ubicación real.

Se verificó además en un Neovim limpio (`-u NONE`), sin cargar nuestra configuración. Con
`attachments.folder = "attachments"`, una nota en `notes/note.md` y tres archivos llamados `a.png`,
upstream hizo lo siguiente:

```text
![[a.png]]           -> vault/attachments/a.png
![[elsewhere/a.png]] -> vault/attachments/elsewhere/a.png  (inexistente)
[[local]]            -> vault/notes/local.md
[[duplicate]]        -> dos Locations: vault/one/duplicate.md y vault/two/duplicate.md
```

En el mismo probe, `prepareRename` sobre `![[a.png]]` devolvió el placeholder `a.png`, pero
`textDocument/rename` no llamó al callback porque intentó resolverlo como nota y no encontró
ninguna. Es decir: upstream reconoce ciertas extensiones para enviarlas a una rama especial de
apertura, pero esa rama no comparte el resolver de notas.

Consecuencia: el adaptador Sabunv debe completar apertura y rename de adjuntos dentro del flujo
de obsidian.nvim, pero su contrato se obtiene de Obsidian, no de la implementación incompleta del
plugin.

### 2.3 Adaptador actual

`lua/lzy/obsidian/` separa actualmente:

- `init.lua`: workspaces, conmutación LSP y ciclo de vida;
- `links.lua`: parser y dispatch compartido por `<CR>`, definición y rename;
- `headings.lua`: resolución jerárquica y refactor de headings;
- `attachments.lua`: adaptación Obsidian de apertura y rename de archivos locales.

Los enlaces `[[nota#header#subheader]]` se resuelven leyendo la nota completa. Si la nota existe
pero la jerarquía no, definición y acción inteligente diagnostican el heading roto y devuelven la
nota como fallback. El rename actúa sobre el componente exacto bajo el cursor y también puede
iniciarse desde la declaración del heading.

El último punto explica un resultado experimental antiguo atribuido erróneamente a obsidian-ls:
el `WorkspaceEdit` que renombraba una imagen y editaba referencias lo generaba nuestro wrapper, no
el handler upstream.

### 2.4 Marksman queda fuera de esta fase

Los probes anteriores de Marksman siguen siendo información útil:

- solo considera documentos Markdown, no imágenes/PDF/otros adjuntos;
- `definition` de un adjunto queda vacío aunque el archivo exista;
- no implementa `prepareRename` ni `textDocument/rename` para notas o adjuntos;
- los wikilinks y enlaces Markdown a notas tienen reglas propias de resolución y ambigüedad.

Nada de esto decide el comportamiento de un vault. El adaptador de Marksman se diseñará después y
puede romper temporalmente al separar el módulo compartido actual.

## 3. Evidencia de la app Obsidian

Se creó un vault temporal con varios `a.png`:

```text
vault/
├── one/a.png
├── two/a.png
├── left/common/a.png
└── right/common/a.png
```

Los resultados se consultaron con la CLI oficial de Obsidian y los cambios se realizaron con sus
comandos `rename` y `move`.

### 3.1 Resolución de un target explícito

Una ruta desde la raíz identifica el archivo esperado:

```markdown
![[one/a.png]]
![[left/common/a.png]]
```

El formato de Obsidian usa `/`, no un path absoluto del sistema ni un path con `/` inicial.

### 3.2 Resolución de un basename duplicado

`![[a.png]]` no es una referencia estable cuando hay varios `a.png`.

Observaciones tras recargar la caché del vault:

- desde `one/bare.md`, resolvió `one/a.png`;
- desde `two/bare.md`, resolvió `two/a.png`;
- desde `left/common/bare.md`, resolvió `left/common/a.png`;
- desde una nota sin candidato local, escogió uno de los duplicados del vault.

Esto confirma que `sourcePath` influye en el «best match», pero el empate global no debe
reimplementarse como una regla inventada. La API pública de Obsidian lo denomina precisamente
`getFirstLinkpathDest(linkpath, sourcePath)`: devuelve el mejor primer resultado, no una lista de
candidatos ni una garantía de unicidad.

Este probe de la app explica su semántica, pero la integración dentro de Neovim seguirá el
contrato observable del resolver de notas de obsidian-ls: coincidencia directa desde la nota y,
si no basta, búsqueda en el vault que puede devolver varios candidatos.

Contrato para Sabunv:

1. Un target con path se resuelve de forma exacta desde la raíz del vault.
2. Un basename único en el vault se resuelve a ese archivo.
3. Un basename duplicado devuelve los mismos candidatos que devolvería el flujo de notas de
   obsidian-ls; no se escoge uno dentro del resolver.
4. La apertura entrega esos candidatos al picker `Resolve link` que ya usa
   `:Obsidian follow_link` para notas ambiguas.
5. La apertura y el rename llaman al mismo resolver Obsidian; nunca implementan búsquedas
   distintas.

### 3.3 `Shortest path when possible` al renombrar

Caso inicial: `one/a.png` y `two/a.png`.

Al renombrar `one/a.png` a `one/b.png`, Obsidian reescribió todas las referencias que apuntaban al
primero como:

```markdown
![[b.png]]
```

`b.png` era globalmente único, por lo que no necesitó carpeta.

Al renombrarlo de nuevo a `one/a.png`, creando otra vez el duplicado, Obsidian reescribió esas
referencias como:

```markdown
![[one/a.png]]
```

y mantuvo las del otro archivo como:

```markdown
![[two/a.png]]
```

Conclusión: «shortest» no significa preservar la forma anterior ni usar siempre basename. Es el
path más corto que conserva de manera estable la identidad del archivo. En estos casos, al haber
duplicados, Obsidian usó el path completo desde la raíz del vault; no se observó una reducción a
un sufijo común como `common/a.png` cuando ese sufijo seguía siendo ambiguo.

### 3.4 Mover mediante un path completo

El comando de Obsidian:

```text
move path=one/a.png to=archive/deep/a.png
```

movió el archivo y reescribió sus referencias como:

```markdown
![[archive/deep/a.png]]
```

porque continuaban existiendo otros `a.png`. Esto confirma las dos entradas que debe aceptar
nuestro prompt:

- `nuevo.png`: rename dentro de la carpeta actual;
- `carpeta/subcarpeta/nuevo.png`: path desde la raíz del vault; rename + move.

Si el nombre final vuelve a ser único, `shortest` puede reducir las referencias otra vez al
basename.

### 3.5 Conservación del estilo del enlace

Al renombrar `one/a.png` a `one/unique image.png`, Obsidian produjo:

```markdown
![[unique image.png]]
![one](unique%20image.png)
![one](unique%20image.png "title")
```

Por tanto:

- wiki/embed permanece wiki/embed;
- Markdown permanece Markdown;
- el alt text y el título Markdown permanecen intactos;
- los targets Markdown codifican caracteres como el espacio;
- la decisión basename/path sigue siendo `shortest` en ambos estilos.

## 4. Contrato cerrado para adjuntos de Obsidian

### 4.1 Alcance

Se considera adjunto cualquier archivo local enlazado que no pertenezca al flujo de notas de
Obsidian. No se usa una lista cerrada de extensiones: los plugins pueden introducir tipos nuevos.
Las URIs externas conservan su flujo propio.

Los paths fuera del vault se admiten cuando el enlace los expresa de forma explícita. La sintaxis
exacta que cuenta como explícita y el alcance de rename/move fuera del vault se fijarán como una
decisión separada.

### 4.2 Resolver Obsidian

Debe ser una función propia del dominio Obsidian, conceptualmente:

```lua
resolve_obsidian_attachment(target, {
  bufnr = bufnr,
  root = vault_root,
}) -> resolved | ambiguous | missing
```

Propiedades obligatorias:

- normaliza URL encoding y separadores;
- elimina fragmentos de embed que no forman parte del filename;
- con el default `shortest`, un path con carpetas es vault-relative y se comprueba exactamente;
- un target que exprese una ruta relativa se evalúa desde la nota origen; `relative` y `absolute`
  siguen la configuración activa del workspace;
- un basename busca archivos locales de ese nombre en todo el vault con la misma semántica de
  identidad que una nota Obsidian;
- usa la nota origen como contexto igual que `resolve_note_async()`;
- representa la ambigüedad explícitamente, no como `nil` ni como el primer resultado de
  `vim.fs.find()`;
- no conoce `.marksman.toml`, `.git` ni reglas Markdown fuera del vault.

La apertura (`gx`, smart action, `Obsidian follow_link`, definición) y el rename consumen este mismo
resultado.

### 4.3 Rename y move

Entrada:

- target del enlace bajo el cursor;
- nombre nuevo o path nuevo desde la raíz del vault.

Validaciones:

- no vacío, `.` ni `..` como destino final;
- solo `/` como separador;
- un destino dentro del vault se calcula desde su root; un destino externo requiere una forma
  explícita todavía pendiente de concretar;
- se conserva la extensión si el usuario la omite;
- el destino no existe;
- origen y destino son distintos;
- el origen es resoluble sin elección arbitraria.

Aplicación:

1. Resolver exactamente el archivo origen.
2. Calcular el destino desde el root del vault.
3. Crear los directorios padre necesarios solo como parte del move solicitado.
4. Buscar únicamente referencias que Obsidian atribuya al archivo origen.
5. Para cada nota, calcular el target nuevo según `link.format` del workspace; para el default
   `shortest`, basename si es único y path vault-relative si necesita desambiguación.
6. Conservar wiki/Markdown, embed, label/alt, anchors, dimensiones y títulos.
7. Construir un único `WorkspaceEdit` con text edits y `RenameFile`.
8. Dejar que el cliente aplique el edit y persistir los buffers modificados siguiendo el patrón
   seguro ya usado por obsidian.nvim.

No se reemplazan cadenas por mera coincidencia textual. Antes de editar una ocurrencia, su target
se resuelve desde la nota que la contiene y debe apuntar al mismo archivo origen.

### 4.4 Ambigüedad

Un enlace ya ambiguo devuelve todos sus candidatos, igual que una definición de nota:

- abrir: usa el picker `Resolve link` existente de obsidian.nvim;
- renombrar: queda una decisión real, porque el handler upstream de notas contiene
  `TODO: pick note` y actualmente toma `notes[1]`;
- el resolver nunca escoge el primer archivo devuelto por el recorrido del filesystem.

### 4.5 Configuración del workspace

El formateo de los targets nuevos debe leer la configuración activa de obsidian.nvim:

- `link.style`: `wiki`, `markdown` o callback;
- `link.format`: `shortest`, `relative` o `absolute`;
- `link.auto_update` cuando sea relevante para respetar la intención del vault.

Este documento concentra los probes en el default `shortest`. `relative` y `absolute` deben usar las
mismas definiciones del plugin/app y requieren casos de prueba propios antes de implementar el
printer definitivo.

## 5. Separación de código necesaria

El módulo actual `lua/sabunv/nvim/markdown.lua` mezcla la política de vault y de proyecto en
`root_of()`, `resolve()`, `open()` y `rename_attachment()`. Debe partirse antes de ampliar el rename.

Una estructura posible:

```text
lua/sabunv/nvim/markdown/
├── init.lua          # parser y dispatch por contexto; sin resolución
├── link.lua          # tipos/rangos/encoding puramente mecánicos
├── obsidian.lua      # resolver, open y rename de vault
└── marksman.lua      # resolver/open/rename de proyecto; diseño posterior
```

Los nombres concretos pueden cambiar; la frontera no:

```text
entrada de vault ──────> markdown.obsidian ──────> semántica Obsidian
entrada de proyecto ───> markdown.marksman ──────> semántica Marksman
```

`lua/lzy/obsidian/init.lua` solo debe requerir adaptadores Obsidian. No debe llamar a una función cuyo
resultado dependa de detectar `.git` o `.marksman.toml`.

`after/ftplugin/markdown.lua` puede mantener `gx` como mapping común, pero primero despacha por el
contexto real del buffer:

- vault → `markdown.obsidian.open_under_cursor()`;
- no vault → `markdown.marksman.open_under_cursor()` o el fallback provisional.

Durante la separación se acepta que el flujo Marksman quede reducido al comportamiento actual o a
un fallback claramente marcado. No se añade compatibilidad accidental desde el adaptador
Obsidian.

## 6. Plan de implementación de la fase Obsidian

1. Extraer parser/utilidades mecánicas sin cambiar comportamiento.
2. Crear el resolver exclusivo de adjuntos Obsidian y pruebas de:
   - basename único;
   - basename duplicado junto a la nota;
   - basename duplicado sin ganador local;
   - path vault-relative;
   - espacios/URL encoding;
   - missing y fuera del root.
3. Hacer que todas las entradas de apertura de vault consuman ese resolver.
4. Sustituir el rename por un flujo Obsidian que acepte basename o path vault-relative.
5. Reemplazar backlinks por identidad resuelta y printer según `link.format`.
6. Probar `WorkspaceEdit` con buffers abiertos y cerrados, creación de carpetas y colisiones.
7. Solo entonces diseñar el módulo Marksman en una sección/documento independiente.

## 7. Casos de aceptación de Obsidian

- Un único `a.png`: `![[a.png]]` abre y se renombra correctamente desde cualquier nota.
- Dos `a.png`: `![[one/a.png]]` abre y renombra exclusivamente `one/a.png`.
- Dos `a.png` y target pelado: abrir presenta los candidatos con `Resolve link`, igual que para
  notas ambiguas; el comportamiento de rename está pendiente.
- Renombrar `one/a.png` a `b` crea `one/b.png`; si es único, las referencias quedan cortas.
- Renombrar a `archive/b` crea/mueve a `archive/b.png` y reescribe las referencias con el target
  mínimo inequívoco.
- Crear otra colisión `b.png` hace que `shortest` añada el path vault-relative necesario.
- Wiki y Markdown conservan su sintaxis, labels/alt, títulos, dimensiones y encoding.
- `gx`, `<CR>`, `:Obsidian follow_link`, definición y rename identifican siempre el mismo
  archivo.
- Ninguna operación de vault consulta o hereda la política de Marksman.
- Ningún basename pelado ni path vault-relative escapa accidentalmente del vault.

## 8. Pendiente deliberado: Marksman

Marksman tendrá otro contrato y otras decisiones. Como mínimo habrá que decidir después:

- semántica de paths Markdown frente a wikilinks;
- si buscar adjuntos por basename fuera de la carpeta de la nota;
- cómo presentar ambigüedad;
- si Sabunv renombra notas y/o adjuntos al no existir rename LSP;
- alcance del scan de referencias y formato de salida.

Estas decisiones no bloquean ni modifican el diseño cerrado de Obsidian.

## 9. Fuentes de verdad

- App Obsidian: probes reproducibles del apartado 3 sobre un vault temporal, ejecutados con la
  CLI oficial 1.13.6.
- Documentación oficial: [Settings](https://obsidian.md/help/settings),
  [Internal links](https://obsidian.md/help/links) y
  [Obsidian CLI](https://obsidian.md/help/cli).
- obsidian.nvim instalado: `lua/obsidian/attachment.lua`, `lua/obsidian/lsp/handlers/rename.lua`,
  `prepare_rename.lua`, `_rename.lua` y `_definition.lua` del commit fijado en `lazy-lock.json`.
- API de resolución de la app: `MetadataCache.getFirstLinkpathDest(linkpath, sourcePath)`
  devuelve el mejor match para un linkpath; no expone una garantía de unicidad.

## 10. Decisiones tomadas

- Los directorios padre de un destino solicitado se crean automáticamente.
- Los adjuntos no se limitan a extensiones conocidas: puede ser cualquier archivo local enlazado
  que no siga el flujo de una nota Obsidian.
- `attachments.folder` solo decide dónde se añaden o pegan archivos nuevos; no participa en la
  resolución de un enlace existente.
- Notas y demás archivos locales comparten el resolver de identidad de la app Obsidian. El tipo
  de archivo solo decide la acción de apertura posterior.
- Los paths externos se permiten si son explícitos; queda por definir qué formas son explícitas y
  si además pueden renombrarse o moverse.
- En vaults anidados manda siempre el marker `.nyabsidian` o `.obsidian/` más cercano a la nota.
  Si ambos están en la misma carpeta, identifican el mismo root y no compiten entre sí.
- Un basename duplicado devuelve todos los candidatos y la apertura usa el picker `Resolve link`
  existente, igual que las notas de obsidian-ls.
- Solo queda pendiente el rename ambiguo: obsidian-ls tiene `TODO: pick note` y hoy toma
  `notes[1]`, una limitación que no define una política segura.
- En `[[nota#header#subheader]]`, el componente bajo el cursor decide el rename: nota, header o
  subheader. Renombrar un heading actualiza las referencias estructurales que apuntan a esa sección.
- El prompt de rename muestra el texto real de la declaración (`FatherA`, aunque el enlace diga
  `fathera`). La declaración conserva exactamente el texto nuevo y todas sus referencias usan el
  anchor canónico de Obsidian (`My Father A` → `my-father-a`). Se rechazan de forma explícita los
  nombres vacíos, con whitespace exterior, saltos de línea, `#` o sin caracteres válidos de anchor.
- Las jerarquías de headings aceptan el sufijo continuo más corto que sea inequívoco:
  `#FatherA#Child` no exige anteponer un H1 común; si `#Child` tiene varios destinos, los devuelve
  todos y se añaden ancestros solo hasta resolver la ambigüedad.
- `<CR>`, definición y rename comparten la misma resolución jerárquica. Un heading inexistente se
  diagnostica como error, pero una nota existente sigue siendo un destino válido de navegación.
