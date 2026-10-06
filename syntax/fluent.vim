" Vim syntax file
" Language: Fluent (projectfluent.org), ficheros `.ftl`
" Maintainer: saburou-nvim
"
" Neovim detecta `.ftl` como `fluent` pero no publica ningún `syntax/fluent.vim`,
" y nvim-treesitter no cataloga ningún parser de Fluent: sin este archivo un
" fichero de traducciones se abre sin ningún resaltado. Es el respaldo del
" parser externo `fluent` (ver lua/lzy/treesitter.lua), que lo sustituye cuando
" está activo.
"
" La gramática sale de la especificación (spec/fluent.ebnf de
" projectfluent/fluent). Es un resaltado gramatical: no lista funciones ni
" categorías de plural, que dependen de cada runtime y de cada idioma.

if exists("b:current_syntax")
  finish
endif

" Los identificadores distinguen mayúsculas, y las funciones se reconocen
" precisamente por ir en mayúsculas.
syn case match

" El texto de una traducción no es ningún item de sintaxis: sin esto, al haber
" items con @Spell (los comentarios), `:set spell` dejaría de revisarlo.
syn spell toplevel

" Entradas -------------------------------------------------------------------
" Un mensaje, un término (`-nombre`) o un atributo (`.nombre`, indentado) solo
" lo son si les sigue `=`: una línea de texto que empiece igual no se resalta.
syn match   fluentMessage       "^\h[[:alnum:]_-]*\ze\s*=" nextgroup=fluentAssign skipwhite
syn match   fluentTerm          "^-\h[[:alnum:]_-]*\ze\s*=" nextgroup=fluentAssign skipwhite
syn match   fluentAttribute     "^\s\+\zs\.\h[[:alnum:]_-]*\ze\s*=" nextgroup=fluentAssign skipwhite
syn match   fluentAssign        "=" contained

" Placeables -----------------------------------------------------------------
" Todo lo que no es texto va entre llaves, y se anidan. Además de en `}`, la
" región termina donde empieza otra entrada o un comentario: un placeable sin
" cerrar no puede tragarse el resto del fichero.
syn region  fluentPlaceable     matchgroup=fluentBrace start="{" end="}"
      \ end="^\ze-\=\h[[:alnum:]_-]*\s*=" end="^\ze#"
      \ contains=fluentPlaceable,fluentVariable,fluentTermRef,fluentMessageRef,
      \fluentFunction,fluentCall,fluentString,fluentNumber,fluentArrow,fluentVariant

syn match   fluentVariable      "\$\h[[:alnum:]_-]*" contained

" Las referencias a términos y mensajes, las cadenas y los números solo se
" reconocen como expresión del placeable, justo detrás de `{`. El texto de una
" variante también está dentro de las llaves, y ahí `well-known`, `"hola"` o
" `5` son texto, no una referencia, una cadena ni un número.
syn match   fluentTermRef       "\%({\_s*\)\@<=-\h[[:alnum:]_-]*\%(\.\h[[:alnum:]_-]*\)\=" contained
syn match   fluentMessageRef    "\%({\_s*\)\@<=\h[[:alnum:]_-]*\%(\.\h[[:alnum:]_-]*\)\=\ze\_s*}" contained
syn match   fluentNumber        "\%({\_s*\)\@<=-\=\d\+\%(\.\d\+\)\=" contained
syn region  fluentString        start=+\%({\_s*\)\@<="+ skip=+\\\\\|\\"+ end=+"+ end=+$+
      \ oneline contained contains=fluentEscape

" Funciones (`NUMBER`, `DATETIME` y las que añada cada runtime: siempre en
" mayúsculas) y argumentos, también los de un término parametrizado. Dentro de
" los paréntesis las cadenas y los números sí son libres.
syn match   fluentFunction      "\<\u[A-Z0-9_-]*\ze(" contained
syn region  fluentCall          matchgroup=fluentDelimiter start="\%([[:alnum:]_-]\)\@<=(" end=")"
      \ oneline contained
      \ contains=fluentVariable,fluentNamedArg,fluentCallString,fluentCallNumber,fluentComma,fluentFunction,fluentCall
syn match   fluentNamedArg      "\h[[:alnum:]_-]*\ze\s*:" contained
syn match   fluentComma         "[,:]" contained
syn match   fluentCallNumber    "-\=\d\+\%(\.\d\+\)\=" contained
syn region  fluentCallString    start=+"+ skip=+\\\\\|\\"+ end=+"+ end=+$+
      \ oneline contained contains=fluentEscape

" Los únicos escapes que existen: `\"`, `\\`, `\uHHHH` y `\UHHHHHH`.
syn match   fluentEscape        +\\["\\]\|\\u\x\{4}\|\\U\x\{6}+ contained

" Selectores -----------------------------------------------------------------
" `{ $n ->` y, en líneas propias, las variantes `[clave]`; `*` marca la que se
" usa por defecto.
syn match   fluentArrow         "->" contained
syn match   fluentVariant       "^\s*\*\=\[\s*[^]]*\]" contained contains=fluentDefault,fluentVariantKey
syn match   fluentDefault       "\*" contained
syn match   fluentVariantKey    "[^][* \t]\+" contained

" Comentarios ----------------------------------------------------------------
" Solo de línea completa y con espacio tras la almohadilla: `#` suelto,
" `##` de grupo y `###` de fichero. Un `#` a mitad de línea es texto.
syn keyword fluentTodo          contained TODO FIXME XXX NOTE
syn match   fluentComment       "^#\%( .*\)\=$" contains=fluentTodo,@Spell
syn match   fluentGroupComment  "^##\%( .*\)\=$" contains=fluentTodo,@Spell
syn match   fluentFileComment   "^###\%( .*\)\=$" contains=fluentTodo,@Spell

" Enlaces --------------------------------------------------------------------
hi def link fluentMessage       Tag
hi def link fluentTerm          Macro
hi def link fluentAttribute     Type
hi def link fluentAssign        Operator
hi def link fluentBrace         Special
hi def link fluentVariable      Identifier
hi def link fluentTermRef       Macro
hi def link fluentMessageRef    Tag
hi def link fluentFunction      Function
hi def link fluentNamedArg      Identifier
hi def link fluentDelimiter     Delimiter
hi def link fluentComma         Delimiter
hi def link fluentNumber        Number
hi def link fluentCallNumber    Number
hi def link fluentString        String
hi def link fluentCallString    String
hi def link fluentEscape        SpecialChar
hi def link fluentArrow         Operator
hi def link fluentVariant       Delimiter
hi def link fluentDefault       Special
hi def link fluentVariantKey    Label
hi def link fluentTodo          Todo
hi def link fluentComment       Comment
hi def link fluentGroupComment  SpecialComment
hi def link fluentFileComment   SpecialComment

let b:current_syntax = "fluent"
