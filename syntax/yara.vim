" Vim syntax file
" Language: YARA
" Maintainer: saburou-nvim
"
" Neovim 0.12 detecta `.yar`/`.yara` como filetype `yara` y trae su
" `ftplugin/yara.vim`, pero no publica ningún `syntax/yara.vim`: sin este
" archivo las reglas se abren sin ningún resaltado. Tampoco hay parser de
" Tree-sitter catalogado en `nvim-treesitter` (ver
" docs/_ordenar/language-dependencies.md).
"
" Es un resaltado deliberadamente conservador: cubre la gramática del lenguaje,
" no el catálogo de módulos, que crece con cada versión de YARA. Cuando el
" proyecto Vim publique su propio syntax file, borrar este archivo para volver
" al del runtime.

if exists("b:current_syntax")
  finish
endif

syn case match

" Comentarios ---------------------------------------------------------------
syn keyword yaraTodo            contained TODO FIXME XXX NOTE
syn region  yaraComment         start="/\*" end="\*/" contains=yaraTodo,@Spell
syn match   yaraComment         "//.*$" contains=yaraTodo,@Spell

" Estructura de la regla ----------------------------------------------------
syn keyword yaraInclude         import include
syn keyword yaraStructure       rule skipwhite nextgroup=yaraRuleName
syn match   yaraRuleName        contained "[A-Za-z_]\w*" skipwhite nextgroup=yaraRuleTags
syn match   yaraRuleTags        contained ":[^{]*"
syn keyword yaraModifier        private global
syn match   yaraSection         "\<\%(meta\|strings\|condition\)\>\ze\s*:"

" Condición -----------------------------------------------------------------
syn keyword yaraConditional     and or not any all none of them for in at
syn keyword yaraConditional     matches icontains startswith
" `contains` no puede ir en `syn keyword`: ahí es el nombre de un argumento
" de :syntax y el parser lo rechaza con E395.
syn match   yaraConditional     "\<contains\>"
syn keyword yaraConditional     istartswith endswith iendswith defined
syn keyword yaraConstant        filesize entrypoint
syn keyword yaraBoolean         true false

" Modificadores de string ---------------------------------------------------
syn keyword yaraStringModifier  nocase wide ascii fullword xor base64 base64wide

" Identificadores de string: $cadena, #contador, @posición, !longitud --------
syn match   yaraStringId        "\$[A-Za-z0-9_]*\*\="
syn match   yaraCountId         "#[A-Za-z0-9_]\+\*\="
syn match   yaraOffsetId        "@[A-Za-z0-9_]\+\*\="
syn match   yaraLengthId        "![A-Za-z0-9_]\+\*\="

" Literales -----------------------------------------------------------------
syn match   yaraEscape          contained "\\\%(x\x\{2}\|[\\\"trn]\)"
syn region  yaraString          start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=yaraEscape

" Cadena hexadecimal: { 4D 5A ?? [0-4] ( 90 | 91 ) }
" La llave sólo abre cadena si viene de una asignación: si no, el `{` que abre
" el cuerpo de la regla se tragaría el resto del archivo.
syn region  yaraHexString       matchgroup=yaraDelimiter start="\%(=\s*\)\@<={" end="}"
      \ contains=yaraHexByte,yaraHexWildcard,yaraHexJump,yaraComment
syn match   yaraHexByte         contained "\<\x\{2}\>"
syn match   yaraHexWildcard     contained "?"
syn match   yaraHexJump         contained "\[\s*\d*\s*-\=\s*\d*\s*\]"

" Expresión regular: /patrón/is, sólo tras `=` para no comerse divisiones
syn region  yaraRegex           start="=\s*\zs/" skip="\\/" end="/[is]*"

syn match   yaraNumber          "\<0x\x\+\>"
syn match   yaraNumber          "\<0o\o\+\>"
syn match   yaraNumber          "\<\d\+\%(\.\d\+\)\=\%(KB\|MB\|GB\)\=\>"

" Enlaces -------------------------------------------------------------------
hi def link yaraTodo            Todo
hi def link yaraComment         Comment
hi def link yaraInclude         Include
hi def link yaraStructure       Structure
hi def link yaraRuleName        Function
hi def link yaraRuleTags        PreProc
hi def link yaraModifier        StorageClass
hi def link yaraSection         Label
hi def link yaraConditional     Conditional
hi def link yaraConstant        Constant
hi def link yaraBoolean         Boolean
hi def link yaraStringModifier  Type
hi def link yaraStringId        Identifier
hi def link yaraCountId         Identifier
hi def link yaraOffsetId        Identifier
hi def link yaraLengthId        Identifier
hi def link yaraEscape          SpecialChar
hi def link yaraString          String
hi def link yaraDelimiter       Delimiter
hi def link yaraHexByte         Number
hi def link yaraHexWildcard     Special
hi def link yaraHexJump         Special
hi def link yaraRegex           String
hi def link yaraNumber          Number

let b:current_syntax = "yara"
