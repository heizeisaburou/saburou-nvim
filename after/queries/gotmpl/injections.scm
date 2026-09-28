;; extends

; La gramática de `gotmpl` sólo parsea lo que va entre `{{` y `}}`; todo lo demás
; cae en nodos `(text)` opacos, así que sin estas inyecciones el marcado y el
; frontmatter de la plantilla se quedan sin resaltar. Las queries que trae
; nvim-treesitter sólo inyectan en el argumento de `html`/`js`/`printf`, nunca en
; el cuerpo.
;
; El predicado y las directivas `hzsr-gotmpl-*` los registra
; `lua/hzsr/ts/gotmpl.lua` desde `lzy.treesitter.setup`; ahí está el detalle de
; por qué el recorte no se puede hacer con `#offset!`.
;
; Las acciones conservan su resaltado en ambos casos: el `highlights.scm` de
; `gotmpl` fija `priority 110`, por encima del 100 de las inyecciones.

; HTML en el cuerpo.
;
; `injection.combined` es imprescindible: los `(text)` llegan troceados por cada
; acción (y hay unos cuantos anidados dentro de `range_action`, `if_action`…).
; Combinados forman un único documento, de modo que las etiquetas partidas por
; una acción (`<a href="{{ .URL }}">` pasa a ser `<a href="">`) siguen abriendo y
; cerrando en el mismo árbol. Sin combinar, cada trozo se parsearía por separado
; y el HTML quedaría roto en cada `{{`.
;
; `#hzsr-gotmpl-body!` deja fuera el frontmatter, que es YAML y no marcado. Va en
; este mismo patrón —y no en uno aparte— porque `injection.combined` sólo une las
; matches de un patrón: separarlos dejaría la cabecera y el cuerpo en dos árboles.
((text) @injection.content
  (#hzsr-gotmpl-body! @injection.content)
  (#set! injection.language "html")
  (#set! injection.combined))

; YAML en el frontmatter.
;
; El predicado limita la match al nodo que abre el búfer con un bloque `---`
; cerrado; la directiva lo recorta a ese bloque.
((text) @injection.content
  (#hzsr-gotmpl-frontmatter? @injection.content)
  (#hzsr-gotmpl-frontmatter! @injection.content)
  (#set! injection.language "yaml"))
