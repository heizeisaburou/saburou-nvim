" Vim syntax file
" Language: PlantUML
" Maintainer: saburou-nvim
"
" Neovim no detecta `.puml` ni publica ningún `syntax/plantuml.vim`: sin este
" archivo —y sin el mapeo de extensiones en lua/user/opts.lua— un diagrama se
" abre sin filetype y sin ningún resaltado. nvim-treesitter tampoco cataloga
" ningún parser de PlantUML; las gramáticas que existen son de terceros y
" ninguna está integrada.
"
" Como en syntax/jql.vim, es un resaltado gramatical y no un catálogo: cubre
" la estructura común a todos los diagramas (etiquetas @start/@end,
" preprocesador, comentarios, flechas, notas, estereotipos, colores) y las
" palabras clave de declaración, sin intentar validar cada tipo de diagrama.
" La validación la hace plantuml_lsp con `plantuml -syntax`.

if exists("b:current_syntax")
  finish
endif

" PlantUML acepta muchas palabras clave en cualquier caja, pero en la práctica
" se escriben en minúsculas, y con `syn case ignore` una clase llamada `File`,
" `Node` o `State` se resaltaría como palabra clave.
syn case match

" Comentarios ----------------------------------------------------------------
" `'` solo es comentario como primer carácter de la línea: en mitad de un
" texto es un apóstrofo. El de bloque sí puede abrirse en cualquier sitio.
syn keyword plantumlTodo        contained TODO FIXME XXX NOTE
syn match   plantumlComment     "^\s*'.*$" contains=plantumlTodo,@Spell
syn region  plantumlComment     start="/'" end="'/" contains=plantumlTodo,@Spell

" Delimitadores del diagrama --------------------------------------------------
" @startuml, @enduml, @startmindmap, @startgantt, @startjson...
syn match   plantumlTag         "^\s*@\%(start\|end\)\a\+\>"

" Preprocesador --------------------------------------------------------------
syn match   plantumlPreProc     "^\s*!\a\w*\>"
syn match   plantumlInclude     "^\s*!\%(include\w*\|import\|theme\)\>"
      \ nextgroup=plantumlIncludePath skipwhite
syn match   plantumlIncludePath contained "\S.*$"
syn match   plantumlVariable    "\$\w\+"
" Funciones integradas: %date(), %filename(), %strlen(...)
syn match   plantumlBuiltin     "%\w\+\ze("

" Palabras clave -------------------------------------------------------------
" Declaraciones de elementos, de todos los tipos de diagrama.
syn keyword plantumlDecl        actor participant boundary control entity database
syn keyword plantumlDecl        collections queue usecase class abstract interface
syn keyword plantumlDecl        enum annotation protocol struct exception metaclass
syn keyword plantumlDecl        stereotype object map json component node package
syn keyword plantumlDecl        namespace folder frame cloud rectangle artifact card
syn keyword plantumlDecl        file stack storage agent person hexagon label circle
syn keyword plantumlDecl        diamond state port portin portout process action
syn keyword plantumlDecl        archimate together

" Bloques y control de flujo (secuencia y actividad).
syn keyword plantumlStatement   alt else opt loop par par2 break critical group end
syn keyword plantumlStatement   activate deactivate destroy create return box
syn keyword plantumlStatement   autonumber autoactivate newpage ref
syn keyword plantumlStatement   if then elseif endif while endwhile repeat again
syn keyword plantumlStatement   fork endfork merge split start stop kill detach
syn keyword plantumlStatement   partition switch case endswitch backward
syn keyword plantumlStatement   endnote legend endlegend
syn keyword plantumlStatement   header endheader footer endfooter title caption
syn keyword plantumlStatement   mainframe

" Ajustes del documento.
syn keyword plantumlSetting     skinparam skin scale hide show remove restore
syn keyword plantumlSetting     allowmixing allow_mixing
" `left to right direction`: `left` y `right` ya son keywords de modificador, y
" un match que empezara en `left` perdería contra ellos.
syn keyword plantumlSetting     direction

" Modificadores de relación y posición.
syn keyword plantumlModifier    as of on over left right top bottom up down
syn keyword plantumlModifier    extends implements
" Modificadores de miembro: {static}, {abstract}, {field}, {method}...
syn match   plantumlModifier    "{\%(static\|abstract\|classifier\|field\|method\)}"

" Nombre del parámetro de `skinparam`, que es texto libre. Con lookbehind y no
" con `\zs`: un keyword gana a cualquier match que empiece en su misma
" columna, y `skinparam` lo es.
syn match   plantumlSkinparam   "\%(\<skinparam\s\+\)\@<=\w\+"

" Flechas --------------------------------------------------------------------
" El cuerpo es una tira de `-`, `.` o `=` que admite estilo entre corchetes
" (`-[#red,dashed]->`) y dirección en medio (`-up->`, `-l->`). Las cabezas son
" `<`, `<|`, `*`, `o`, `#`, `x`, `+`, `^`, `}`... según el diagrama.
"
" Tres patrones para no confundir un `-` suelto de visibilidad (`- name`) con
" una flecha: con cabeza a la izquierda, con cabeza a la derecha, o sin cabezas
" pero con al menos dos trazos (`--`, `..`).
let s:body = '[-.=]\+\%(\[[^\]]*\]\)\=\%(\%(up\|down\|left\|right\|[udlr]\)[-.=]\+\)\=[-.=]*'
let s:head = '\%(<|\|<<\|<\|[*#}+^]\|\<[ox]\)'
let s:tail = '\%(|>\|>>\|>\|[*#{+^]\|\\\\\|//\)\%([ox]\>\)\=\|[ox]\>'
exe 'syn match plantumlArrow "' . s:head . s:body . '\%(' . s:tail . '\)\="'
exe 'syn match plantumlArrow "' . s:body . '\%(' . s:tail . '\)"'
syn match   plantumlArrow       "[-.=]\{2,}"
unlet s:body s:head s:tail

" Separadores de secuencia: `== Fase ==`, `... 10 min ...`, `|||`, `||45||`.
" Van después de las flechas: si dos items empiezan en la misma columna gana el
" definido más tarde, y `==` también encaja como flecha.
syn match   plantumlSeparator   "^\s*==.*==\s*$"
syn match   plantumlSeparator   "^\s*\.\.\..*$"
syn match   plantumlSeparator   "^\s*||\d*||\=|\=\s*$"

" Notas ----------------------------------------------------------------------
" La nota multilínea abre con `note ...` sin `:` y cierra con `end note`. La de
" una línea (`note left: texto`) no entra aquí: solo resalta la palabra clave.
" `note` no puede ser keyword: un keyword gana a cualquier región que empiece en
" su columna, y la nota multilínea no llegaría a abrirse. Por eso la de una
" línea tiene su propio match, y la región va después para ganarle.
syn match   plantumlStatement   "^\s*\zs[hr]\=note\>"
" El resto de la cabecera (`right of Animal #pink`) no es texto de la nota, y
" plantumlNoteHead lo saca del resaltado de cadena.
syn region  plantumlNote        matchgroup=plantumlStatement
      \ start="^\s*[hr]\=note\>\ze[^:]*$" end="^\s*end\s*[hr]\=note\>"
      \ contains=plantumlNoteHead,plantumlComment,@Spell
syn match   plantumlNoteHead    contained "\%(^\s*[hr]\=note\)\@<=.*$"
      \ contains=plantumlModifier,plantumlColor,plantumlStereotype

" Literales ------------------------------------------------------------------
syn region  plantumlString      start=+"+ skip=+\\"+ end=+"+ oneline
" Estereotipo: <<entity>>, <<interface>>, <<(C,#ff0000) Control>>
syn match   plantumlStereotype  "<<[^<>]\{-1,}>>"
" Color: #lightblue, #AABBCC. Al principio de línea `#` es visibilidad
" protegida (`# name : string`), no un color.
syn match   plantumlColor       "\%(^\s*\)\@<!#\%(\x\{3,8}\>\|\a\w*\)"
syn match   plantumlNumber      "\<\d\+\%(\.\d\+\)\=\>"
" Visibilidad al principio de un miembro: + público, - privado, # protegido,
" ~ de paquete.
syn match   plantumlVisibility  "^\s*\zs[-+#~]\ze\s*[[:alnum:]_{]"

" Enlaces --------------------------------------------------------------------
hi def link plantumlTodo        Todo
hi def link plantumlComment     Comment
hi def link plantumlTag         Special
hi def link plantumlPreProc     PreProc
hi def link plantumlInclude     Include
hi def link plantumlIncludePath String
hi def link plantumlVariable    Identifier
hi def link plantumlBuiltin     Function
hi def link plantumlDecl        Type
hi def link plantumlStatement   Statement
hi def link plantumlSetting     PreProc
hi def link plantumlModifier    Keyword
hi def link plantumlSkinparam   Identifier
hi def link plantumlArrow       Operator
hi def link plantumlSeparator   Delimiter
hi def link plantumlNote        String
hi def link plantumlString      String
hi def link plantumlStereotype  Label
hi def link plantumlColor       Constant
hi def link plantumlNumber      Number
hi def link plantumlVisibility  Operator

let b:current_syntax = "plantuml"
