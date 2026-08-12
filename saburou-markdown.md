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
- `links.lua`: dispatch común de `<CR>`, `gd`, `prepareRename` y rename;
- `headings.lua`: resolución jerárquica y refactor de headings;
- `attachments.lua`: índice, resolvedor, apertura y refactor de cualquier archivo local del vault.

Los enlaces `[[nota#header#subheader]]` se resuelven leyendo la nota completa. Si la nota existe
pero la jerarquía no, definición y acción inteligente diagnostican el heading roto y devuelven la
nota como fallback. El rename actúa sobre el componente exacto bajo el cursor y también puede
iniciarse desde la declaración del heading.

El último punto explica un resultado experimental antiguo atribuido erróneamente a obsidian-ls:
el `WorkspaceEdit` que renombraba una imagen y editaba referencias lo generaba nuestro wrapper, no
el handler upstream.

El adaptador de adjuntos ya no requiere `sabunv.nvim.markdown`: el mapping común de `gx` despacha
primero al dominio Obsidian y solo usa ese módulo antiguo como fallback fuera de un vault.

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

Además del probe, se inspeccionó la implementación de Obsidian 1.13.6 instalada. Su
`getFirstLinkpathDest()` llama a `getLinkpathDest()` y toma el primer resultado. Este último:

1. indexa por basename sin distinguir mayúsculas/minúsculas;
2. devuelve primero un path exacto relativo al vault o a la nota;
3. acepta también sufijos de path;
4. separa los candidatos que están bajo la carpeta de la nota de los demás;
5. ordena cada grupo por longitud del path y conserva el orden de indexación en empates.

Por tanto, la fidelidad a la app sí define un ganador. Un duplicado no se entrega al selector de
obsidian-ls: se abre el mismo «best match» que elegiría `getFirstLinkpathDest()`.

Contrato para Sabunv:

1. Un target con path se resuelve de forma exacta desde la raíz del vault.
2. Un basename único en el vault se resuelve a ese archivo.
3. Un basename duplicado conserva los candidatos ordenados para diagnóstico, pero resuelve al
   primero con el orden real de la app.
4. La apertura sigue directamente ese ganador; no hereda el picker de notas de obsidian-ls.
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

Los paths fuera del vault se admiten cuando el enlace los expresa de forma explícita: URI
`file://`, path absoluto del sistema o ruta `./` / `../` desde la nota. También pueden ser origen o
destino de rename; las referencias que se actualizan siguen estando dentro del vault.

### 4.2 Resolver Obsidian

Debe ser una función propia del dominio Obsidian, conceptualmente:

```lua
resolve_obsidian_attachment(target, {
  bufnr = bufnr,
  root = vault_root,
}) -> resolved | missing
```

Propiedades obligatorias:

- normaliza URL encoding y separadores;
- elimina fragmentos de embed que no forman parte del filename;
- un path con carpetas prueba primero el path vault-relative exacto y después los sufijos
  compatibles de la app, independientemente de la política usada al reescribir enlaces;
- un target `./` / `../` se evalúa desde la nota origen; un path sin ese prefijo se interpreta con
  la semántica vault-relative o de sufijo de Obsidian;
- un basename busca archivos locales de ese nombre en todo el vault con la semántica de
  `MetadataCache.getLinkpathDest()` / `getFirstLinkpathDest()`;
- compara sin distinguir mayúsculas, admite sufijos de path y usa la nota origen como contexto;
- prioriza candidatos bajo la carpeta origen y luego el path más corto, conservando además la
  lista ordenada para diagnóstico;
- no cruza el límite de un vault anidado;
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
- un destino dentro del vault se calcula desde su root; un destino externo requiere `file://`, un
  path absoluto o una ruta `./` / `../` desde la nota;
- se conserva la extensión si el usuario la omite;
- el destino no existe;
- origen y destino son distintos;
- el origen es resoluble sin elección arbitraria.

Aplicación:

1. Resolver exactamente el archivo origen.
2. Calcular el destino desde el root del vault.
3. Crear los directorios padre necesarios solo como parte del move solicitado.
4. Buscar únicamente referencias que Obsidian atribuya al archivo origen.
5. Para cada nota, calcular el target nuevo según la política propia de Nyabsidian. El default
   `preserve` conserva la clase original de cada referencia; `simplify` delega en `link.format`.
6. Conservar wiki/Markdown, embed, label/alt, anchors, dimensiones y títulos.
7. Construir un único `WorkspaceEdit` con text edits y `RenameFile`.
8. Dejar que el cliente aplique el edit y persistir los buffers modificados siguiendo el patrón
   seguro ya usado por obsidian.nvim.

No se reemplazan cadenas por mera coincidencia textual. Antes de editar una ocurrencia, su target
se resuelve desde la nota que la contiene y debe apuntar al mismo archivo origen.

### 4.4 Duplicados

Los duplicados no se ordenan con una regla inventada ni con el primer resultado bruto del
filesystem. El resolver reproduce el ranking de la app y devuelve el ganador junto con los
candidatos ordenados. Apertura, `prepareRename` y rename reutilizan esa misma identidad; no pueden
escoger archivos distintos durante una operación.

### 4.5 Políticas de representación

Son opciones propias de Nyabsidian, separadas de la configuración nativa de obsidian.nvim:

```lua
nyabsidian = {
  attachment_paths = {
    vault = "preserve",    -- "preserve" | "simplify"
    external = "preserve", -- "preserve" | "absolute"
  },
}
```

Ambas usan `preserve` por defecto. Para destinos internos conserva la clase de cada referencia
(`file://`, absoluto, relativo a la nota, relativo al vault o basename); solo amplía un basename
si mantenerlo perdería identidad. Para destinos externos conserva URI, absoluto o relativo. La
opción `vault = "simplify"` canonicaliza con el `link.format` activo de obsidian.nvim, mientras
`external = "absolute"` convierte targets externos en paths absolutos.

Estas políticas modifican la representación, no la identidad ni el estilo sintáctico: wiki sigue
wiki y Markdown sigue Markdown.

## 5. Separación de código

`lua/sabunv/nvim/markdown.lua` conserva provisionalmente la política antigua para el fallback de
Markdown/Marksman. El dominio de vault ya no entra en esas funciones: vive en
`lua/lzy/obsidian/attachments.lua` y se despacha antes desde el mapping común.

La estructura efectiva de la fase Obsidian es:

```text
lua/lzy/obsidian/
├── init.lua          # workspaces, configuración y ciclo de vida
├── links.lua         # dispatch LSP y acción inteligente
├── headings.lua      # identidad y refactor de headings
└── attachments.lua   # identidad, apertura y refactor de archivos

lua/sabunv/nvim/markdown.lua  # fallback antiguo fuera de vaults
```

Los nombres concretos pueden cambiar; la frontera no:

```text
entrada de vault ──────> lzy.obsidian.attachments ──> semántica Obsidian
entrada de proyecto ───> sabunv.nvim.markdown ─────> fallback / futura semántica Marksman
```

`lua/lzy/obsidian/init.lua` solo debe requerir adaptadores Obsidian. No debe llamar a una función cuyo
resultado dependa de detectar `.git` o `.marksman.toml`.

`after/ftplugin/markdown.lua` puede mantener `gx` como mapping común, pero primero despacha por el
contexto real del buffer:

- vault → `lzy.obsidian.attachments.open_under_cursor()`;
- no vault → `markdown.marksman.open_under_cursor()` o el fallback provisional.

Durante la separación se acepta que el flujo Marksman quede reducido al comportamiento actual o a
un fallback claramente marcado. No se añade compatibilidad accidental desde el adaptador
Obsidian.

## 6. Implementación verificada de la fase Obsidian

Se implementó y probó:

1. Un parser con rangos exactos para wiki, Markdown y Canvas.
2. El resolver exclusivo de adjuntos Obsidian con casos de:
   - basename único;
   - basename duplicado junto a la nota;
   - basename duplicado con ganador por carpeta origen y por longitud;
   - path vault-relative;
   - espacios/URL encoding;
   - missing y fuera del root.
3. Todas las entradas de apertura de vault (`gx`, `<CR>`, definición y `follow_link`) consumiendo
   ese resolver.
4. Rename/move por basename o path vault-relative, con paths externos explícitos.
5. Referencias actualizadas por identidad con `preserve` por defecto y canonicalización opcional.
6. Un único `WorkspaceEdit`, creación de carpetas, colisiones y conservación de sintaxis.

Marksman queda como la siguiente fase independiente.

## 7. Casos de aceptación de Obsidian

- Un único `a.png`: `![[a.png]]` abre y se renombra correctamente desde cualquier nota.
- Dos `a.png`: `![[one/a.png]]` abre y renombra exclusivamente `one/a.png`.
- Dos `a.png` y target pelado: abrir y rename usan el mismo best match que la app Obsidian.
- Renombrar `one/a.png` a `b` crea `one/b.png`; las referencias que ya eran basename quedan cortas
  si siguen siendo inequívocas y las explícitas conservan su clase.
- Renombrar a `archive/b` crea/mueve a `archive/b.png` y actualiza cada referencia sin convertir
  arbitrariamente absolutos en relativos ni relativos en absolutos.
- Crear una colisión `b.png` amplía los basenames afectados al path vault-relative necesario.
- Wiki y Markdown conservan su sintaxis, labels/alt, títulos, dimensiones, encoding y, por
  defecto, la clase de path original.
- `gx`, `<CR>`, `:Obsidian follow_link`, definición y rename identifican siempre el mismo
  archivo.
- Ninguna operación de vault consulta o hereda la política de Marksman.
- Ningún basename pelado ni path vault-relative escapa accidentalmente del vault.
- Un path `file://`, absoluto o `./` / `../` puede apuntar fuera únicamente porque lo expresa de
  forma explícita.

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
- En vaults anidados manda siempre el marker `.nyabsidian` o `.obsidian/` más cercano a la nota.
  Si ambos están en la misma carpeta, identifican el mismo root y no compiten entre sí.
- Un basename duplicado se ordena como `getLinkpathDest()`: carpeta de la nota, longitud de path y
  orden de indexación; `getFirstLinkpathDest()` define el ganador para abrir y renombrar.
- Los paths externos explícitos son `file://`, absolutos del sistema o `./` / `../`; se permiten
  como origen y destino, mientras el scan de referencias permanece limitado al vault.
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
