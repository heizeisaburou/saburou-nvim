" Vim syntax file
" Language: D2 (d2lang.com)
" Maintainer: saburou-nvim
"
" Neovim no detecta `.d2` ni publica ningún `syntax/d2.vim`, y nvim-treesitter
" no cataloga ningún parser de D2: sin este archivo —y sin el mapeo de
" extensión en lua/user/opts.lua— un diagrama se abre sin ningún resaltado.
" Tampoco hay language server; el formateo (`d2 fmt`) lo hace Conform.
"
" Las palabras reservadas, las formas y la sintaxis de flechas y de bloques
" salen del propio parser de D2 (d2ast/keywords.go y d2parser/parse.go).

if exists("b:current_syntax")
  finish
endif

" D2 distingue mayúsculas en las claves; solo los literales (`true`, `null`...)
" se aceptan en cualquier caja, y esos llevan `\c` en su patrón.
syn case match

" Palabras reservadas --------------------------------------------------------
" Solo en posición de clave: detrás de un inicio de línea, espacio, `.`, `{`,
" `;` o `(`, y delante de `.`, `:` o `{`. Así `label` se resalta en
" `a.label: x` y en `style.fill: red`, pero no dentro del texto de una etiqueta.
let s:reserved = [
      \ 'source-arrowhead', 'target-arrowhead', 'horizontal-gap', 'vertical-gap',
      \ 'grid-columns', 'grid-rows', 'grid-gap', 'constraint', 'direction',
      \ 'tooltip', 'classes', 'class', 'label', 'shape', 'icon', 'link', 'near',
      \ 'width', 'height', 'top', 'left', 'vars', 'style',
      \ 'text-transform', 'double-border', 'border-radius', 'stroke-width',
      \ 'stroke-dash', 'fill-pattern', 'font-color', 'font-size', 'underline',
      \ 'animated', 'multiple', 'opacity', 'italic', 'filled', 'shadow',
      \ 'stroke', 'bold', 'font', 'fill', '3d']
exe 'syn match d2Reserved "\%(^\|[[:space:].{;(]\)\@<=\%('
      \ . join(s:reserved, '\|') . '\)\ze\s*[.:{]"'
unlet s:reserved

" `layers`, `scenarios` y `steps` crean tableros nuevos, no son propiedades.
syn match   d2Board             "\%(^\|[[:space:].{;]\)\@<=\%(layers\|scenarios\|steps\)\ze\s*[.:{]"

" Valores --------------------------------------------------------------------
syn match   d2Shape             "\%(\<shape\s*:\s*\)\@<=\%(rectangle\|square\|page\|parallelogram\|document\|cylinder\|queue\|package\|step\|callout\|stored_data\|person\|diamond\|oval\|circle\|hexagon\|cloud\|text\|code\|class\|sql_table\|image\|sequence_diagram\|hierarchy\)\>"
" Puntas de flecha: `source-arrowhead.shape` y `target-arrowhead.shape`. Las
" largas primero: `cf-one` también encaja al principio de `cf-one-required`.
syn match   d2Shape             "\%(\<shape\s*:\s*\)\@<=\%(cf-one-required\|cf-many-required\|cf-one\|cf-many\|triangle\|arrow\|box\|cross\)\>"
syn match   d2Constant          "\%(\<direction\s*:\s*\)\@<=\%(up\|down\|left\|right\)\>"
" Posiciones de `near`, `label.near`, `icon.near` y `tooltip.near`.
syn match   d2Constant          "\<\%(\%(outside\|border\)-\)\=\%(top\|center\|bottom\|left\|right\)-\%(top\|center\|bottom\|left\|right\)\>"
syn match   d2Boolean           "\c\<\%(true\|false\)\>"
syn match   d2Constant          "\c\<\%(null\|suspend\|unsuspend\)\>"
syn match   d2Number            "\<\d\+\%(\.\d\+\)\=\>"

" Flechas --------------------------------------------------------------------
" Una tira de `-` con punta opcional en cada extremo: `<` delante, `>` o `*`
" detrás. Un `-` suelto no es flecha (`grid-rows` es una sola clave), así que
" hace falta punta o al menos dos guiones: `->`, `<-`, `<->`, `--`. El `*`
" delante no cuenta: `a *-> b` es la clave `a *`, como deja claro `d2 fmt`.
syn match   d2Arrow             "<-\+[>*]\="
syn match   d2Arrow             "-\+[>*]"
syn match   d2Arrow             "--\+"

" Referencias y especiales ---------------------------------------------------
" Primero los delimitadores: los especiales que empiezan por `[` van después
" para ganarles en la misma columna.
syn match   d2Delimiter         "[{}\[\];]"
" Variables: ${nombre}
syn match   d2Variable          "\${[^}]*}"
" Importaciones: `x: @otro.d2` y `...@otro.d2`. Solo detrás de espacio o `:`,
" para no tomar el `@` de un correo dentro de una etiqueta.
syn match   d2Import            "\%(^\|[[:space:]:]\)\@<=\%(\.\.\.\)\=@[[:alnum:]_./-]\+"
" `_` es el contenedor padre: `_.x -> y`.
syn match   d2Special           "\<_\ze\."
" Globs: `*.style.fill`, `**.shape`.
syn match   d2Special           "\*\{1,2}\ze[.:]"
" Índice de conexión: (a -> b)[0], (a -> b)[*]
syn match   d2Special           ")\zs\[\%(\d\+\|\*\)\]"
" Filtros de glob: `&shape: circle`, `!&label: x`.
syn match   d2Operator          "^\s*\zs!\=&"

" Literales ------------------------------------------------------------------
syn match   d2Escape            contained "\\."
syn region  d2String            start=+"+ skip=+\\\\\|\\"+ end=+"+ oneline contains=d2Escape,d2Variable
syn region  d2String            start=+'+ skip=+\\\\\|\\'+ end=+'+ oneline contains=d2Escape
" Bloque de texto: `|md ... |`, `||sql ... ||`, "|`go ... `|". Tras el primer
" `|` pueden ir más símbolos (`|`, `` ` ``) que forman el delimitador, y el
" cierre es ese mismo delimitador seguido de `|`. Luego va el lenguaje; sin él
" es markdown.
syn region  d2BlockString       matchgroup=d2BlockDelim
      \ start="|\z([^[:space:][:alnum:]_]*\)\%([^[:space:]]*\)" end="\z1|"
      \ contains=@Spell

" Comentarios ----------------------------------------------------------------
" Van al final porque `"""` también encaja como cadena y `#` puede ir dentro de
" otras cosas: si dos items empiezan en la misma columna gana el definido más
" tarde. `#` solo abre comentario al principio o tras un espacio; por eso los
" colores van entre comillas en D2 (`fill: "#f4a261"`).
syn keyword d2Todo              contained TODO FIXME XXX NOTE
syn match   d2Comment           "\%(^\|\s\)\zs#.*$" contains=d2Todo,@Spell
syn region  d2Comment           start=+"""+ end=+"""+ contains=d2Todo,@Spell

" Enlaces --------------------------------------------------------------------
hi def link d2Reserved          Keyword
hi def link d2Board             Statement
hi def link d2Shape             Type
hi def link d2Constant          Constant
hi def link d2Boolean           Boolean
hi def link d2Number            Number
hi def link d2Arrow             Operator
hi def link d2Variable          Identifier
hi def link d2Import            Include
hi def link d2Special           Special
hi def link d2Operator          Operator
hi def link d2Delimiter         Delimiter
hi def link d2Escape            SpecialChar
hi def link d2String            String
hi def link d2BlockDelim        Delimiter
hi def link d2BlockString       String
hi def link d2Todo              Todo
hi def link d2Comment           Comment

let b:current_syntax = "d2"
