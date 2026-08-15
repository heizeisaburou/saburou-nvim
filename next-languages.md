# Próximos lenguajes

Estado de la investigación: 2026-08-14.

Este documento es una hoja de ruta. No implica que todos estos servidores deban activarse a la
vez. En especial, conviene elegir **un LSP principal** y **un formateador principal** por
filetype para evitar diagnósticos duplicados y dos herramientas peleándose por el mismo buffer.

## Estado

| Lenguaje       | Estado              | Notas                                                                |
| -------------- | ------------------- | -------------------------------------------------------------------- |
| PowerShell     | Hecho el 2026-08-15 | Probado en Linux con `pwsh` 7                                        |
| PostgreSQL/SQL | Hecho el 2026-08-15 | Los dos servidores, repartidos por raíz                              |
| Groovy         | Hecho el 2026-08-15 | Ver los avisos de su sección: el JDK y el timeout                    |
| Nix            | Hecho el 2026-08-15 | `nil` necesita `nix` del sistema para compilar, ver abajo            |
| Julia          | Hecho el 2026-08-15 | `cmd` propio; `runic` fuera del PATH, ver sección                    |
| Solidity       | Hecho el 2026-08-15 | LSP mecánico; `forge` viene con Foundry, fuera de Mason              |
| Fish           | Hecho el 2026-08-16 | LSP mecánico; `fish_indent` viene con la shell                       |
| Erlang         | Hecho el 2026-08-16 | `elp` necesita `rebar3`; `erlfmt` construido y funcionando           |
| R              | Hecho el 2026-08-16 | El más sencillo: sin condition ni dependencia de sistema             |
| Batch          | Nada que hacer      | Esperando a que el parser entre en `nvim-treesitter`                 |
| Assembly       | Configurado         | Dialectos separados: `asm` (GAS) sin formatter, `nasm` con `nasmfmt` |
| GLSL           | Configurado         | `glsl_analyzer`, no `glslls`; formato vía LSP                        |
| WebAssembly    | Configurado         | LSP mecánico; formato vía LSP; sin Treesitter todavía                |

Lo hecho trajo dos piezas que no eran de ningún lenguaje en concreto y que ya están disponibles:

- **Capa de linting** (`lua/lzy/lint.lua`, nvim-lint) para lo que ningún LSP cubre, con
  condiciones por proyecto. Nació porque `sqls` no publica diagnósticos.
- **JDK de compilación para Mason** (`lua/hzsr/mason/init.lua`): algunos paquetes se compilan al
  instalar y su herramienta de build rechaza los JDK modernos. Se fija `JAVA_HOME` antes de
  cualquier instalación.

## Qué hacer con cada lenguaje

Los lenguajes se activan **de uno en uno**, nunca varios a la vez: se termina uno, se entrega al
usuario para que lo pruebe y solo entonces se empieza el siguiente. Antes de tocar nada,
comprobar que el lenguaje ya está descrito en este documento; si no lo está, añadirlo aquí con su
stack —LSP, Treesitter, formateador y dependencias— antes de configurarlo.

No dar un lenguaje por terminado hasta completar este checklist:

- [ ] Configurar LSP, Treesitter y Conform —o documentar el fallback LSP—; tocar `opts.lua` o
	  `indent.lua` solo si hace falta.
- [ ] Verificar los mappings de Mason en `lua/hzsr/mason/nvchad/names.lua` y documentar todas las
	  dependencias en `docs/language-dependencies.md`.
- [ ] Si un paquete requiere Yay, comprobar antes si existe en Chaotic-AUR (CAUR), documentar
	  ambas vías y añadir siempre `--sudoloop` al comando de Yay.
- [ ] Crear en `/home/saburou/wip/proyectos/<lenguaje>` un proyecto mínimo pero completo, con
	  código válido y deliberadamente mal formateado. Incluir manifiestos, configuración, varios
	  filetypes o `.git` solo cuando sean necesarios para probar el lenguaje o detectar la raíz.
- [ ] Pedir al usuario que ejecute `:MasonInstallAll`; no lanzar instalaciones de Mason en su
	  lugar. Si faltan paquetes del sistema, indicar cuáles y esperar a que autorice instalarlos
	  con `pkexec`. Avisar antes al usuario, el usuario quizás está fumando y el pkexec se puede
	  quedar 5 minutos colgado mientras el usuario no está. Una vez autorizado el paquete exacto,
	  ejecutar `pkexec pacman` con `--noconfirm` desde el primer intento para evitar repetir el
	  comando por falta de entrada interactiva.
- [ ] Después de la instalación, comprobar detección de filetype, Treesitter, conexión y
	  funciones básicas del LSP, diagnósticos y formato usando el proyecto de prueba. Esto
	  también se delega al usuario.

## Lenguajes hechos: primera y segunda tanda

`pwsh`/`powershell.exe`/`cmd.exe` no son variantes del mismo lenguaje: `pwsh` y `powershell.exe`
hablan PowerShell (`.ps1`/`.psm1`/`.psd1` → filetype `ps1`); `cmd.exe` interpreta batch
(`.bat`/`.cmd` → filetype `dosbatch`), un lenguaje aparte. `.psd1` no lo detecta Neovim de serie;
lo mapea `lua/user/opts.lua`.

Resumen de las nueve implementadas, detalle completo en `docs/language-dependencies.md` (sección
"Notas por lenguaje") y en el código de cada capa:

| Lenguaje     | LSP decidido                  | Treesitter   | Conform                | Nota                                              |
| ------------ | ----------------------------- | ------------ | ---------------------- | ------------------------------------------------- |
| PowerShell   | `powershell_es`               | `powershell` | vía LSP                | `bundle_path` propio: el paquete no deja binario  |
| PostgreSQL   | `postgres_lsp`                | `sql`        | `pg_format`            | Se autolimita a proyectos con root PostgreSQL     |
| SQL genérico | `sqls`                        | `sql`        | `sqlfluff`/`pg_format` | `root_dir` cede ante `postgres_lsp`               |
| Fish         | `fish_lsp`                    | `fish`       | `fish_indent`          | LSP mecánico; formatter viene con la shell        |
| Nix          | `nil_ls` (no `nixd`)          | `nix`        | `nixfmt`               | `nil` necesita `nix` del sistema para compilarse  |
| Solidity     | `solidity_ls_nomicfoundation` | `solidity`   | `forge_fmt`            | LSP mecánico; `forge` lo trae Foundry             |
| Erlang       | `elp`                         | `erlang`     | `erlfmt`               | `elp` necesita `rebar3`; `erlfmt` se compila      |
| Groovy       | `groovyls`                    | `groovy`     | `npm-groovy-lint`      | JDK 21/17 fijado antes de compilar con Gradle     |
| R            | `air`                         | `r`          | `air`                  | El más sencillo: sin `cmd` ni `condition` propios |
| Julia        | `julials`                     | `julia`      | `runic`                | `cmd` propio; `runic` vive en `~/.julia/bin`      |

Batch (`.bat`/`.cmd`) sigue sin ninguna integración: no hay LSP maduro que merezca añadirse, no
hay formatter consolidado en Conform, y `tree-sitter-batch` (`wharflab/tree-sitter-batch`)
todavía no está catalogado en `nvim-treesitter`. No añadir `cmd`/`bat`/`dosbatch` a `M.languages`
mientras eso siga así.

Los formatters que no vienen de Mason (`forge_fmt`, `erlfmt`, `runic`, `fish_indent`) entran por
la pieza compartida de binarios ausentes que se describe más abajo.

## Prioridad 2: tercera tanda

### Resumen recomendado

| Lenguaje    | LSP decidido          | Treesitter    | Conform               | Instalación principal |
| ----------- | --------------------- | ------------- | --------------------- | --------------------- |
| Assembly    | `asm_lsp`             | `asm`, `nasm` | `nasmfmt` (solo NASM) | Mason (Cargo) + Go    |
| GLSL        | `glsl_analyzer`       | `glsl`        | vía LSP               | Mason                 |
| WebAssembly | `wasm_language_tools` | pendiente     | vía LSP               | Mason                 |

Los tres LSP son mecánicos: `cmd`/`root_markers` por defecto ya sirven. Assembly es el único que
necesitó `M.config`, y no por el servidor sino para añadirle el filetype `nasm`. Detalle completo
en `docs/language-dependencies.md`.

### Assembly

`asm_lsp` (Mason: `asm-lsp`) cubre NASM/GAS/ensamblador de Go con el mismo binario. Mason lo
compila con Cargo; a diferencia de `nil` (Nix), no hay indicio en su repositorio de que necesite
ningún ensamblador del sistema para compilarse —la tabla de opcodes viene embebida como datos, no
generada llamando a un ensamblador externo—, pero no se ha verificado con una compilación real.

El formateo tuvo vuelta, y la solución no estaba en Conform sino en el filetype. `asm` no es un
lenguaje: es dos, con extensiones que se solapan. `asmfmt` (el único candidato de Mason) es del
**ensamblador de Go**, sintaxis Plan 9, y usa la misma extensión `.s` que GAS; `nasmfmt` solo
entiende NASM; para GAS/AT&T no existe formateador en ningún sitio. Aplicar cualquiera de ellos
al filetype `asm` compartido destrozaría los archivos de los otros dialectos.

Neovim ya resuelve esto y no lo estábamos usando: `vim.filetype.detect.asm()` lee las 5 primeras
líneas buscando una directiva `asmsyntax=<dialecto>` y **usa ese valor como filetype**.
Verificado:

```
; asmsyntax=nasm  →  filetype nasm
(sin directiva)   →  filetype asm     (GAS/AT&T, el default)
```

Con eso el filetype compartido desaparece y cada dialecto puede tener su herramienta:

| Filetype | Dialecto   | Parser | Formateador                    |
| -------- | ---------- | ------ | ------------------------------ |
| `asm`    | GAS/AT&T   | `asm`  | ninguno: no existe             |
| `nasm`   | NASM/Intel | `nasm` | `nasmfmt` (externo, ver abajo) |

```lua
-- lspconfig.lua: M.servers
"asm_lsp",

-- lspconfig.lua: M.config -- nvim-lspconfig solo declara asm/vmasm, pero
-- asm-lsp entiende NASM también
asm_lsp = { filetypes = { "asm", "vmasm", "nasm" } },

-- treesitter.lua
"asm", "nasm",             -- M.languages
asm = true, nasm = true,   -- M.enabled_highlights

-- conform.lua: SOLO nasm, nunca asm
nasm = { "nasmfmt" },
```

`nasmfmt` (`yamnikov-oleg/nasmfmt`) no está en Mason ni tiene builtin en Conform: se instala con
`go install github.com/yamnikov-oleg/nasmfmt@latest` y entra por la pieza compartida de binarios
externos. Reescribe in situ (`stdin = false`), y comprobado que no toca la directiva `asmsyntax`
de la primera línea, así que formatear no rompe la detección de dialecto.

El mapping `asm_lsp = "asm-lsp"` ya existía en `names.lua`; `nasmfmt` no lleva mapping porque
Mason no lo ofrece.

### GLSL

Decidido: `glsl_analyzer`, no `glslls`. Mismo criterio que decidió `nil_ls` sobre `nixd`:
`glslls` (`svenstaro/glsl-language-server`) solo se instala compilando a mano o vía AUR en esta
config, mientras que `glsl_analyzer` es un release Rust prebuilt de Mason. En una config pública,
quien clona y ejecuta `:MasonInstallAll` se queda sin nada con la primera opción.

```lua
-- lspconfig.lua: M.servers
"glsl_analyzer",

-- treesitter.lua
"glsl",       -- M.languages
glsl = true,  -- M.enabled_highlights
```

`glsl_analyzer` anuncia los filetypes `glsl`, `vert`, `tesc`, `tese`, `frag`, `geom` y `comp`,
pero Neovim ya normaliza todas esas extensiones al filetype único `glsl` (verificado con archivos
reales), así que no hace falta ningún alias. Sin entrada en Conform: `glsl_analyzer` expone su
propio `textDocument/formatting` y el atajo de formato de esta config ya cae al LSP cuando
Conform no cubre el filetype. Los mappings `glsl_analyzer = "glsl_analyzer"` y `glslls =
"glslls"` ya existían en `names.lua`.

### WebAssembly

`wasm_language_tools` (Mason: `wasm-language-tools`, release Rust prebuilt) para el formato de
texto WebAssembly (`.wat`/`.wast`, filetype `wat`, verificado con archivos reales). Es LSP y
formatter a la vez —el propio proyecto se describe como "out-of-the-box formatter"—, así que
tampoco necesita entrada en Conform: cae al LSP igual que GLSL.

```lua
-- lspconfig.lua: M.servers
"wasm_language_tools",

-- names.lua: mapping que faltaba
wasm_language_tools = "wasm-language-tools",
```

Sin Tree-sitter: no existe ningún parser de WebAssembly en el catálogo local de `nvim-treesitter`
(comprobado; ni `wat` ni `wasm` aparecen). Mismo caso que Batch: queda pendiente de que aparezca
un parser catalogado, sin entrada en `M.languages` mientras tanto.

## Política de herramientas que Mason no instala

Esta config es pública y hay gente usándola, así que el criterio no es "qué tengo yo instalado"
sino "qué le pasa a quien la clona". `:MasonInstallAll` instala todo lo que salga de la lista de
servidores y de Conform, pero **lo que no tiene mapping en Mason se salta en silencio**
(`lua/hzsr/mason/nvchad/init.lua`). Eso afecta a `erlfmt`, `runic`, `forge_fmt` y `nasmfmt`, y
afectaría a `nixd` si alguna vez volviera a la propuesta.

Decidido: esas herramientas **sí entran** en la config, pero con `condition` sobre el ejecutable,
de modo que no se intente formatear con un binario que no existe. **El fallo no puede ser
silencioso**: si un filetype tiene formateador configurado y su binario falta, hay que decirlo
—una vez por herramienta y sesión, no en cada guardado— indicando qué falta y cómo se instala.

Los binarios que sí vienen de Mason (`pg_format`, `nixfmt`, `air`, `npm-groovy-lint`) no
necesitan nada de esto: si falta alguno, es que `:MasonInstallAll` no se ha ejecutado.

### La pieza compartida: `hzsr.sys.executable.external`

Escrita, y los cinco casos la usan. Vive en `lua/hzsr/sys/executable.lua` porque resolver
ejecutables no es asunto de Conform; el adaptador que la convierte en `command`/`condition` sí
está en `lua/lzy/conform.lua`, en la función local `external`.

```lua
runic = external {
  bin = "runic",
  paths = { "~/.julia/bin" },
  why = "el formato de Julia no se ejecuta",
  how = [[Instálalo con `julia -e 'using Pkg; Pkg.Apps.add("Runic")'`.]],
},
```

Hace tres cosas que los condicionales sueltos hacían mal o no hacían:

- **Memoiza la resolución** una vez por sesión, no una por formateo.
- **Busca fuera del `PATH`**, con los directorios de `paths`. Esto no era un lujo: `forge` solo
  está en el `PATH` porque el instalador de Foundry lo añade desde el rc de la shell, así que
  Neovim abierto desde un lanzador de escritorio no lo encontraba aunque estuviera instalado.
  Ahora se resuelve por ruta.
- **Avisa una sola vez** (`vim.notify_once`), con el mismo formato para todos:
  `<label> no está instalado: <why>. <how>`.

Los cinco consumidores actuales:

| Herramienta   | Lenguaje | Fuera del `PATH` en              |
| ------------- | -------- | -------------------------------- |
| `runic`       | Julia    | `~/.julia/bin`                   |
| `erlfmt`      | Erlang   | `~/.local/share/erlfmt/...`      |
| `forge_fmt`   | Solidity | `~/.config/.foundry/bin`         |
| `nasmfmt`     | NASM     | `~/go/bin`                       |
| `fish_indent` | Fish     | —, viene del paquete del sistema |

### Nota para quien siga con esto

Queda una sola cosa pendiente de esta iniciativa: **`docs/language-dependencies.md` necesita una
pasada completa, no solo para los lenguajes que pasaron por aquí**. Faltan lenguajes de la matriz
que ya estaban configurados en `lspconfig.lua`/`conform.lua` desde antes de "next-languages" y
que nunca se documentaron ahí (revisar toda la lista, no dar por buena una comprobación
superficial).
Y de los que sí aparecen mencionados, cualquiera con una dependencia externa real (toolchain del
sistema, binario que Mason no instala, versión de JDK/runtime específica...) necesita su propia
sección `###` explicándola, con el mismo rigor que ya tienen Groovy/Nix/Julia/PowerShell/SQL/
Solidity/Fish/Erlang. El criterio de "qué le pasa a quien clona la config sin mi toolchain" se
aplica a todo el catálogo, no solo a lo nuevo.

## Bloques consolidados

Esta sección enumeraba, antes de implementarse, los bloques `lua` a pegar en cada archivo.
Primera, segunda y tercera tanda ya están implementadas: el contenido real y actualizado vive en
`lua/lzy/lspconfig.lua`, `lua/lzy/treesitter.lua`, `lua/lzy/conform.lua` y
`lua/hzsr/mason/nvchad/names.lua`, y el detalle explicado en `docs/language-dependencies.md`. No
se mantiene una copia aquí para no tener dos fuentes de verdad divergiendo con cada cambio.

## Orden de implementación propuesto

Detalle de cada uno en su sección de arriba y en `docs/language-dependencies.md`.

1. ~~PowerShell~~. Hecho, probado en Linux con `pwsh` 7.
2. Batch: sin cambios, esperando a que madure el parser (ver su sección de arriba).
3. ~~SQL~~. Hecho, dos servidores repartidos por raíz y formateador condicional.
4. ~~Groovy~~. Hecho, con el JDK de compilación resuelto por el camino.
5. ~~Nix~~. Hecho; `nil` necesita `nix` del sistema para compilarse.
6. ~~Julia~~. Hecho; `cmd` propio (el de `nvim-lspconfig` no servía con Mason) y `runic`, que
   Julia deja fuera del `PATH`.
7. ~~Solidity~~. Hecho; LSP mecánico, `forge_fmt` con el `forge` que instala Foundry.
8. ~~Fish~~. Hecho; LSP mecánico, `fish_indent` viene con la propia shell.
9. ~~Erlang~~. Hecho; `elp` necesitó `rebar3` en runtime y `erlfmt` se construyó con
   `rebar3 as release escriptize` tras dar con el perfil correcto.
10. ~~R~~. Hecho, el más sencillo de la segunda tanda: `air` sin `cmd` ni `condition` propios.
11. Assembly. Configurado; `asm_lsp` cubre los dos dialectos, separados por filetype (`asm` para
    GAS, `nasm` vía directiva `asmsyntax`). `nasmfmt` formatea NASM; GAS se queda sin formatear
    porque no existe ninguno. Falta instalar con `:MasonInstallAll` y probar en vivo.
12. GLSL. Configurado; LSP mecánico (`glsl_analyzer`, no `glslls`), formato vía LSP. Falta
    instalar con `:MasonInstallAll` y probar en vivo.
13. WebAssembly. Configurado; LSP mecánico (`wasm_language_tools`), formato vía LSP, sin
    Treesitter porque no hay parser catalogado. Falta instalar con `:MasonInstallAll` y probar en
    vivo.
14. ~~Aviso de binario ausente~~. Hecho: `hzsr.sys.executable.external`, con los cinco casos
    (`runic`, `erlfmt`, `forge_fmt`, `fish_indent`, `nasmfmt`) migrados a él.

## Referencias principales

- [Diferencias entre PowerShell 7 y Windows PowerShell 5.1](https://learn.microsoft.com/powershell/scripting/whats-new/differences-from-windows-powershell)
- [PowerShell Editor Services](https://github.com/PowerShell/PowerShellEditorServices)
- [Parser Treesitter de batch](https://github.com/wharflab/tree-sitter-batch)
- [Postgres Language Server](https://github.com/supabase-community/postgres-language-server)
- [`sqls`](https://github.com/sqls-server/sqls) y
  [`sql-language-server`/`sqlls`](https://github.com/joe-re/sql-language-server)
- [`fish-lsp`](https://github.com/ndonfris/fish-lsp)
- [`nixd`](https://github.com/nix-community/nixd) y [`nil`](https://github.com/oxalica/nil)
- [Nomic Foundation Solidity Language Server](https://github.com/NomicFoundation/hardhat-vscode/tree/development/server)
- [Erlang Language Platform](https://github.com/WhatsApp/erlang-language-platform) y
  [`erlfmt`](https://github.com/WhatsApp/erlfmt)
- [Groovy Language Server](https://github.com/GroovyLanguageServer/groovy-language-server) y
  [`npm-groovy-lint`](https://github.com/nvuillam/npm-groovy-lint)
- [Air](https://github.com/posit-dev/air) y
  [`languageserver` para R](https://github.com/REditorSupport/languageserver)
- [`LanguageServer.jl`](https://github.com/julia-vscode/LanguageServer.jl) y
  [Runic.jl](https://github.com/fredrikekre/Runic.jl)
- [`asm-lsp`](https://github.com/bergercookie/asm-lsp)
- [`glsl_analyzer`](https://github.com/nolanderc/glsl_analyzer) y
  [`glslls`](https://github.com/svenstaro/glsl-language-server)
- [`wasm-language-tools`](https://github.com/g-plane/wasm-language-tools)

## Para 平生三郎: con qué modelo hacer cada lenguaje

> [!IMPORTANT]
>
> Sección personal de 平生三郎. La IA no entra aquí: no son instrucciones para ella, no forma
> parte del plan de implementación y no debe editarla.

Lo que decide el modelo no es el lenguaje, es el trabajo que queda pendiente en él. Pide **Opus**
cuando haya una decisión abierta entre herramientas que se excluyen, cuando el LSP necesite
código propio en `lspconfig.lua` (más que añadirlo a `M.servers`), cuando la instalación se salga de
Mason (toolchains, `pkexec`, Yay) o cuando dos herramientas puedan pelearse por el mismo buffer.
Con **Sonnet** basta cuando el stack ya está decidido y escrito aquí, todo sale de Mason o de la
propia toolchain, y el trabajo es rellenar tres tablas, montar el proyecto de prueba y seguir el
checklist.

| Lenguaje                 | Modelo  | Por qué                                                                                                                      |
| ------------------------ | ------- | ---------------------------------------------------------------------------------------------------------------------------- |
| PowerShell               | Hecho   | `powershell_es` necesita config propia: `bundle_path` a la raíz del ZIP de Mason (que no expone binario) y fallback de shell |
| Batch                    | Ninguno | No hay nada que instalar; la decisión ya está tomada: esperar al parser                                                      |
| PostgreSQL/SQL           | Hecho   | La decisión ya está tomada, pero hay que escribir el arbitraje de raíz y el formateador condicional                          |
| Nix                      | Sonnet  | `nil_ls` decidido y todo sale de Mason: es rellenar las tres tablas y probar                                                 |
| Groovy                   | Hecho   | Hay que comprobar el Java que pide `groovyls` y que `npm-groovy-lint` no duplique diagnósticos                               |
| Julia                    | Sonnet  | `julials` es mecánico y `runic` ya tiene política: entra con condition. Depende del aviso compartido                         |
| Fish                     | Sonnet  | Todo decidido: `fish_lsp` en Mason y `fish_indent` viene con el shell                                                        |
| Solidity                 | Sonnet  | Mason para el LSP y `forge_fmt` con condition; depende del aviso compartido                                                  |
| Erlang                   | Sonnet  | `elp` ya está mapeado y `erlfmt` entra con condition; depende del aviso compartido                                           |
| R                        | Sonnet  | Air es un único binario de Mason que hace LSP y formato                                                                      |
| Aviso de binario ausente | Opus    | Pieza compartida por Solidity, Erlang y Julia; se escribe una vez y antes que ellos                                          |

Dos avisos para cuando lo lance Sonnet:

- Las elecciones de herramienta ya están tomadas y escritas arriba; no hay que dejarle "elegir".
  Si se topa con una decisión que no esté en este documento, lo que debe hacer es parar y
  preguntarte, no elegir por su cuenta. Merece la pena decírselo en el propio prompt.
- Recordarle que esta config es pública: lo que rompa a quien la clone sin tu toolchain es un
  fallo, no un detalle. Ese es el criterio que decidió `nil_ls`, el formateador SQL condicional y
  el aviso de binario ausente.
