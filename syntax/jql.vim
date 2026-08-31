" Vim syntax file
" Language: JQL (Jira Query Language)
" Maintainer: saburou-nvim
"
" Neovim no detecta `.jql` ni publica ningún `syntax/jql.vim`: sin este archivo
" —y sin el mapeo de extensión en lua/user/opts.lua— una consulta guardada se
" abre sin filetype y sin ningún resaltado. Tampoco hay parser de Tree-sitter
" (la gramática de JQL es ANTLR, no tree-sitter) ni language server: el
" resaltado es todo lo que esta configuración puede dar.
"
" Es un resaltado gramatical, no un catálogo: un campo se reconoce por ir
" delante de un operador y una función por ir delante de `(`, en vez de
" listar los nombres de Jira, que cambian con cada instancia (campos
" personalizados) y con cada versión.

if exists("b:current_syntax")
  finish
endif

" JQL no distingue mayúsculas de minúsculas en operadores, palabras clave ni
" funciones: `project = HZSR AND status = Open` y `PROJECT = HZSR and STATUS =
" open` son la misma consulta.
syn case ignore

" JQL no tiene comentarios: cualquier texto fuera de la consulta es un error de
" sintaxis para Jira. Por eso aquí no hay ningún grupo de comentario.

" Operadores ----------------------------------------------------------------
" Todo en un `syn match` porque las alternativas se prueban de izquierda a
" derecha: así `!=` y `!~` se resuelven antes de que el `!` suelto (NOT) se
" quede con el primer carácter.
syn match   jqlOperator         "\%(!\=[=~]\|[<>]=\=\|&&\|||\|[&|!]\)"
syn keyword jqlOperator         and or not
syn keyword jqlOperator         in is was changed
" Predicados de WAS / CHANGED
syn keyword jqlPredicate        from to by before after on during

" ORDER BY ------------------------------------------------------------------
" Region hasta el final del buffer: `ORDER BY` es siempre la ultima clausula de
" una consulta, asi que quedarse con todo lo que venga detras es lo correcto.
" Hace falta para resaltar sus campos, que no van seguidos de ningun operador y
" por tanto jqlField no ve.
syn region  jqlOrderClause      matchgroup=jqlOrder start="\<order\s\+by\>" end="\%$"
      \ contains=jqlOrderDir,jqlCustomField,jqlString,jqlDelimiter,jqlOrderField
syn keyword jqlOrderDir         contained asc desc
syn match   jqlOrderField       contained "\<[a-z_][a-z0-9_.]*\>"

" Campos --------------------------------------------------------------------
" Identificador que precede a un operador. Los campos con espacios van
" entrecomillados y los recoge jqlString.
syn match   jqlField            "\<[a-z_][a-z0-9_.]*\>\ze\%(\s*\%(!\=[=~]\|[<>]\)\|\s\+\%(in\|is\|was\|not\|changed\)\>\)"
" Campo personalizado por id: cf[10001]
syn match   jqlCustomField      "\<cf\s*\[\d\+\]"

" Funciones -----------------------------------------------------------------
" currentUser(), startOfWeek(-1w), membersOf("soc")...
syn match   jqlFunction         "\<[a-z_][a-z0-9_]*\>\ze\s*("

" Literales -----------------------------------------------------------------
syn keyword jqlConstant         empty null
syn match   jqlEscape           contained "\\\%(u\x\{4}\|[\\'\"ntr]\)"
syn region  jqlString           start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=jqlEscape
syn region  jqlString           start=+'+ skip=+\\\\\|\\'+ end=+'+ contains=jqlEscape
syn match   jqlNumber           "\<\d\+\%(\.\d\+\)\=\>"
" Las fechas van despues del numero a proposito: cuando dos items empiezan en
" la misma columna gana el definido mas tarde, y si no `2026-08-01` se resalta
" como tres numeros sueltos.
" Fecha absoluta: 2026-08-28, 2026/08/28, con hora opcional
syn match   jqlDate             "\<\d\{4}[-/]\d\{2}[-/]\d\{2}\%(\s\+\d\{2}:\d\{2}\)\="
" Fecha relativa: -1w, 4h, -30d
syn match   jqlDate             "-\=\d\+[mhdw]\>"

syn match   jqlDelimiter        "[(),]"

" Enlaces -------------------------------------------------------------------
hi def link jqlOperator         Operator
hi def link jqlPredicate        Keyword
hi def link jqlOrder            Statement
hi def link jqlOrderDir         Statement
hi def link jqlOrderField       Identifier
hi def link jqlField            Identifier
hi def link jqlCustomField      Identifier
hi def link jqlFunction         Function
hi def link jqlConstant         Constant
hi def link jqlEscape           SpecialChar
hi def link jqlString           String
hi def link jqlDate             Number
hi def link jqlNumber           Number
hi def link jqlDelimiter        Delimiter

let b:current_syntax = "jql"
