;; extends

; XML dentro de cadenas de PowerShell. El disparador es el comienzo del texto:
; el prólogo `<?xml` o un `<QueryList>` (los filtros de Get-WinEvent), que es
; como llega el XML a un script. Los delimitadores de la cadena no entran en la
; región inyectada, de ahí los `#offset!`: 2 columnas para los here-strings
; (`@"` … `"@`) y 1 para las cadenas normales.
;
; Las interpolaciones no se pierden: al no marcar `injection.include-children`,
; los nodos hijos (`$var`, `$(…)`) quedan fuera de la región y conservan el
; resaltado de PowerShell.

; here-string que empieza por <?xml
([
  (expandable_here_string_literal)
  (verbatim_here_string_characters)
] @injection.content
  (#lua-match? @injection.content "^@[\"']%s*<%?xml")
  (#offset! @injection.content 0 2 0 -2)
  (#set! injection.language "xml"))

; here-string que empieza por <QueryList>
([
  (expandable_here_string_literal)
  (verbatim_here_string_characters)
] @injection.content
  (#lua-match? @injection.content "^@[\"']%s*<QueryList")
  (#offset! @injection.content 0 2 0 -2)
  (#set! injection.language "xml"))

; cadena de una línea que empieza por <QueryList>
([
  (expandable_string_literal)
  (verbatim_string_characters)
] @injection.content
  (#lua-match? @injection.content "^[\"']%s*<QueryList")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.language "xml"))
