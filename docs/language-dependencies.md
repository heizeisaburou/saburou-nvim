# Dependencias de lenguajes en Neovim (Arch Linux)

Documento acumulativo para los LSP y formatters activados uno a uno en:

```text
~/wip/nvim-language-smoke-tests
```

La regla general es instalar SDKs y runtimes desde los repositorios oficiales de Arch. Mason
instala servidores y formatters, pero no siempre instala el toolchain base que necesitan para
ejecutarse o analizar un proyecto.

## Estado

| Lenguaje | Toolchain del sistema | LSP de Mason             | Formatter de Mason | Estado                                 |
| -------- | --------------------- | ------------------------ | ------------------ | -------------------------------------- |
| C#       | .NET SDK/runtime 10   | `csharp-language-server` | `csharpier`        | Verificado                             |
| Clojure  | Clojure CLI + Java    | `clojure-lsp`            | `zprint`           | CLI instalado; prueba manual pendiente |
| Dart     | Dart SDK              | Incluido en el SDK       | Incluido en el SDK | Verificado por el usuario                |
| Kotlin   | OpenJDK 21 LTS        | `kotlin-language-server` | `ktlint`           | Resolver configurado; prueba pendiente    |
| F#       | .NET SDK              | `fsautocomplete`         | `fantomas`         | Proyecto restaurado; prueba pendiente     |
| Haskell  | GHCup + GHC + Cabal   | `haskell-language-server`| `fourmolu`         | Toolchain instalado; prueba pendiente     |
| Java     | JDK                   | `jdtls`                  | `google-java-format`| Verificado por el usuario                |
| OCaml    | opam + OCaml 5.5      | `ocaml-lsp`              | `ocamlformat`      | opam inicializado; prueba pendiente        |
| Ruby     | Ruby + Bundler + ERB  | `ruby-lsp`               | `rubocop`          | Bundler instalado; `ruby-erb` pendiente    |
| Scala    | OpenJDK 17 + sbt       | Externo: `metals`        | Externo: `scalafmt`| Metals/sbt/JDK instalados; Scalafmt pendiente |
| Swift    | `swift-bin` (swift.org) | Externo: `sourcekit-lsp` | `swiftformat`      | Toolchain instalado; prueba pendiente          |
| Django   | `python-django`         | `django-language-server` | `djlint`           | Toolchain instalado; prueba pendiente          |

---

## C#

### Síntoma inicial

Mason fallaba al instalar `csharp-language-server` y `csharpier`:

```text
No .NET SDKs were found.
The application 'tool' does not exist.
```

### Causa

El sistema tenía `dotnet-host` 10 y únicamente el runtime 9, instalado como dependencia de
Marksman. Un runtime permite ejecutar aplicaciones compiladas, pero `dotnet tool install`
necesita el SDK completo. Mason usa ese comando para instalar `csharp-ls` y CSharpier.

Además, en Arch el runtime 9 satisfacía la dependencia virtual genérica `dotnet-runtime` del
SDK 10. Pacman instaló inicialmente el SDK sin el runtime 10 que el propio SDK necesitaba.
CSharpier requería también ASP.NET Core Runtime 10.

### Paquetes necesarios

```bash
sudo pacman -S --needed dotnet-sdk dotnet-runtime-10.0 aspnet-runtime-10.0
```

Los runtimes 9 y 10 pueden convivir. No mezclar estos paquetes con Snap, repositorios de
Microsoft ni instalaciones manuales en `/usr/share/dotnet`.

### Comprobación manual

```bash
dotnet --list-sdks
dotnet --list-runtimes
dotnet --info
```

### Estado verificado el 8 de agosto de 2026

```text
.NET SDK:       10.0.110
.NET runtimes:  Microsoft.NETCore.App 9.0.18 y 10.0.10
ASP.NET:        Microsoft.AspNetCore.App 10.0.10
csharp-ls:      0.24.0.0
CSharpier:      1.2.6

dotnet build:   0 warnings, 0 errors
csharp_ls:      attached=true
LSP root:       ~/wip/nvim-language-smoke-tests/csharp
Conform:        CSharpier aplicó el formato correctamente
```

### Activación en Neovim

```lua
-- lua/lzy/lspconfig.lua
"csharp_ls",

-- lua/lzy/conform.lua
cs = { "csharpier" },

-- lua/lzy/treesitter.lua
"c_sharp",
cs = true,
```

Instalación/actualización desde Neovim:

```vim
:MasonInstall csharp-language-server csharpier
:TSInstallAll
```

Proyecto de prueba:

```text
~/wip/nvim-language-smoke-tests/csharp/Program.cs
```

Referencias:

- https://archlinux.org/packages/extra/x86_64/dotnet-sdk/
- https://learn.microsoft.com/dotnet/core/install/linux-package-mixup
- https://github.com/razzmatazz/csharp-language-server
- https://csharpier.com/docs/Installation

---

## Clojure

### Síntoma inicial

Al abrir `deps.edn`, `clojure-lsp` mostraba:

```text
Classpath lookup failed when running `clojure -A:test:dev -Spath`.
Some features may not work properly.
```

### Causa

No era un problema de Git ni de la raíz del proyecto: `deps.edn` ya es un marcador de proyecto
válido. Mason había instalado `clojure-lsp`, pero faltaba el CLI `clojure` que el servidor
ejecuta para calcular el classpath de tools.deps.

Sin ese classpath, el LSP puede arrancar parcialmente, pero pierde información sobre
dependencias, namespaces externos y análisis del proyecto.

### Paquete necesario

```bash
sudo pacman -S --needed clojure
```

Paquete instalado:

```text
clojure 1.12.5.1654-1
```

El paquete oficial de Arch incluye:

```text
/usr/bin/clojure
/usr/bin/clj
/usr/share/clojure/libexec/clojure-tools-1.12.5.1654.jar
```

También depende de `java-environment`, por lo que Pacman exige/resuelve un JDK. No existe un
paquete oficial separado llamado `clojure-tools` en Arch.

Después de instalar, reiniciar Neovim. Si una shell ya abierta no recoge el entorno del paquete,
se puede cargar sin cerrar sesión:

```bash
source /etc/profile.d/clojure.sh
```

### Comprobación manual

```bash
clojure -Sdescribe
clojure -Spath
clojure -A:test:dev -Spath
```

El `deps.edn` mínimo de prueba no define `:test` ni `:dev`. El CLI actual puede avisar de aliases
no declarados y usar el classpath base. Si el LSP siguiera considerándolo un error, se añadirán
esos aliases al proyecto de muestra en el siguiente paso, después de observar el resultado real.

### Activación en Neovim

```lua
-- lua/lzy/lspconfig.lua
"clojure_lsp",

-- lua/lzy/conform.lua
clojure = { "zprint" },
edn = { "zprint" },

-- lua/lzy/treesitter.lua
"clojure",
clojure = true,
edn = true,

-- Alias de Treesitter para EDN
edn = "clojure",
```

Instalación desde Neovim:

```vim
:MasonInstall clojure-lsp zprint
:TSInstallAll
```

Proyecto de prueba:

```text
~/wip/nvim-language-smoke-tests/clojure/deps.edn
~/wip/nvim-language-smoke-tests/clojure/src/smoke/core.clj
```

Referencia:

- https://archlinux.org/packages/extra/any/clojure/

---

## Dart

### Proveedor del LSP y del formatter

`dartls` y `dart format` no son paquetes independientes de Mason. Ambos vienen incluidos en el
SDK oficial de Dart:

- Neovim inicia el servidor mediante `dart language-server --protocol=lsp`.
- Conform ejecuta `dart format`.

Por eso aparecen marcados como externos en la configuración y no deben añadirse a
`lua/hzsr/mason/nvchad/names.lua`.

### Paquete necesario

```bash
sudo pacman -S --needed dart
```

Paquete disponible al preparar esta sección:

```text
dart 3.12.2-1
```

Después de instalar este paquete, tanto el LSP como el formatter empezaron a funcionar
directamente, sin instalar componentes adicionales mediante Mason.

### Compatibilidad con Windows

La configuración no necesita un `cmd` personalizado como QML. Las definiciones base que ya
aportan `nvim-lspconfig` y Conform utilizan el único nombre oficial del ejecutable en todas las
plataformas:

```text
dart language-server --protocol=lsp
dart format
```

Neovim resuelve `dart` mediante `PATH`; Windows resuelve además la extensión ejecutable
correspondiente. `hzsr.sys.executable.resolve` sí es necesario para QML porque debe escoger entre
dos nombres distintos (`qmlls` y `qmlls6`), pero Dart no tiene esa variante.

En Windows basta con que el SDK de Dart —o el SDK incluido con Flutter— esté en `PATH`. No se debe
añadir `dartls` ni `dart_format` a `names.lua`, porque no son paquetes independientes de Mason.

### Activación en Neovim

```lua
-- lua/lzy/lspconfig.lua
"dartls",

-- lua/lzy/conform.lua
dart = { "dart_format" },

-- lua/lzy/treesitter.lua
"dart",
dart = true,
```

Después de instalar el SDK, reiniciar Neovim. No hay que ejecutar `:MasonInstall` para el LSP ni
para el formatter de Dart. El parser sí se instala con:

```vim
:TSInstallAll
```

Proyecto de prueba:

```text
~/wip/nvim-language-smoke-tests/dart
```

Referencia:

- https://archlinux.org/packages/extra/x86_64/dart/

---

## Kotlin

### Síntoma inicial

`kotlin-language-server` terminaba durante el arranque con:

```text
java.lang.IllegalArgumentException: 26.0.1
at com.intellij.util.lang.JavaVersion.parse(...)
```

Las líneas sobre `sun.misc.Unsafe` son advertencias, no la causa del cierre. La entrada de
Marksman que aparece cerca también es informativa: Neovim la registra como error porque Marksman
escribe su mensaje de inicio en `stderr`.

### Causa

Mason instaló `kotlin-language-server` 1.3.13, que incluye Kotlin Compiler 2.1.0. El servidor se
estaba ejecutando con OpenJDK 26.0.1 y su parser interno no reconoce todavía esa versión de Java.
No falta Kotlin ni otro paquete de Mason: el LSP necesita arrancar con un JDK compatible.

Después de resolver Java apareció un segundo error al abrir un `.kts` suelto:

```text
Expected BEGIN_OBJECT but was BEGIN_ARRAY at path $
at org.javacs.kt.ConfigurationKt.getStoragePath(...)
```

La configuración base de `nvim-lspconfig` intenta usar como `storagePath` la raíz de un proyecto
Gradle o Maven. Si el script no pertenece a uno, el valor es `nil`, `init_options` queda como una
tabla Lua vacía y Neovim la serializa como el array JSON `[]`. El servidor espera un objeto JSON.

La factory define siempre una ruta de caché portable y existente:

```lua
local storage_path = vim.fs.joinpath(vim.fn.stdpath "cache", "kotlin-language-server")
vim.fn.mkdir(storage_path, "p")

return {
  init_options = { storagePath = storage_path },
}
```

`stdpath("cache")` selecciona la ubicación correcta en Linux, macOS y Windows. Para guardar la
caché en otro sitio basta con sustituir `storage_path`; debe apuntar a un directorio existente o
crearse antes de iniciar el servidor.

### Paquete instalado

```bash
sudo pacman -S --needed jdk21-openjdk
```

Estado después de la instalación:

```text
jdk21-openjdk 21.0.11.u10-1
jdk-openjdk   26.0.1.u8-1

java-21-openjdk
java-26-openjdk (default)
```

Java 21 y Java 26 están instalados en paralelo. Pacman conservó Java 26 como predeterminado y la
configuración de Neovim asigna Java 21 únicamente al proceso de `kotlin-language-server`; no cambia
el runtime de otras aplicaciones.

### Resolución portable del JDK

`lua/hzsr/sys/java.lua` descubre instalaciones de Java, ejecuta `java -version` para validar su
versión real y, cuando se exige un JDK, comprueba también que exista `javac`. Kotlin acepta Java 21
o 17 en ese orden de preferencia.

La búsqueda respeta este orden:

1. `KOTLIN_LSP_JAVA_HOME`, `JAVA_HOME` y `JDK_HOME`.
2. Rutas exactas añadidas mediante `extra_homes`.
3. El `java` disponible en `PATH`.
4. Ubicaciones habituales de Linux, macOS y Windows, además de SDKMAN, asdf y mise.

El resultado se aplica mediante `cmd_env` al launcher de Mason, que respeta `JAVA_HOME` tanto en
Unix como en Windows:

```lua
kotlin_language_server = function()
  local java_home = hzsr.sys.java.resolve_home {
    env = { "KOTLIN_LSP_JAVA_HOME", "JAVA_HOME", "JDK_HOME" },
    versions = { 21, 17 },
    require_jdk = true,
  }

  local config = {
    init_options = {
      storagePath = vim.fs.joinpath(vim.fn.stdpath "cache", "kotlin-language-server"),
    },
  }

  if java_home then
    config.cmd_env = { JAVA_HOME = java_home }
  end

  return config
end
```

Las entradas de `M.config` pueden ser tablas normales o factories. Las factories se evalúan cada
vez que se activa o reinicia un servidor, por lo que instalar otro JDK y ejecutar
`:LspRestart kotlin_language_server` vuelve a realizar la detección.

### Personalizar una instalación no detectada

La opción más sencilla y portable es definir una ruta explícita antes de iniciar Neovim:

```bash
# Linux/macOS
export KOTLIN_LSP_JAVA_HOME="$HOME/ruta/al/jdk-21"
```

```powershell
# Windows PowerShell
$env:KOTLIN_LSP_JAVA_HOME = "C:\Program Files\Java\jdk-21"
```

También se pueden añadir rutas exactas o directorios que contengan varios JDK desde
`lua/lzy/lspconfig.lua`:

```lua
local java_home = hzsr.sys.java.resolve_home {
  versions = { 21, 17 },
  require_jdk = true,
  extra_homes = { "/ruta/exacta/jdk-21" },
  extra_roots = { "/directorio/con/varios-jdk" },
}
```

Si una versión futura de `kotlin-language-server` admite otros Java, se puede cambiar
`versions = { 21, 17 }`. El orden establece la preferencia y las versiones que no aparezcan en la
lista se rechazan. Si no se encuentra ninguna compatible, Neovim muestra un aviso y deja arrancar
el servidor con su entorno normal para que el error siga siendo visible en `lsp.log`.

Inspección manual desde Neovim:

```vim
:lua print(vim.inspect(hzsr.sys.java.find { require_jdk = true }))
```

Proyecto de prueba:

```text
~/wip/nvim-language-smoke-tests/kotlin
```

---

## F#

### LSP adjunto sin diagnósticos

FSAutocomplete 0.83.0 aparecía adjunto al buffer y Fantomas formateaba, pero el LSP no ofrecía
diagnósticos, hover ni análisis. `lsp.log` mostraba la causa real:

```text
Typecheck failed for Program.fs with Check aborted
Unable to find the file 'System.Runtime.dll'
```

No faltaba otro paquete global. El proyecto todavía no se había restaurado y no existía
`obj/project.assets.json`, por lo que FSharp.Compiler.Service no podía construir las referencias
del framework.

### Preparar un proyecto F#

Desde la carpeta que contiene el `.fsproj`:

```bash
dotnet restore
```

Después hay que reiniciar `fsautocomplete` o Neovim. El LSP necesita el `.fsproj` porque en F# el
orden y la lista de archivos compilados forman parte del proyecto:

```xml
<ItemGroup>
  <Compile Include="Program.fs" />
</ItemGroup>
```

Proyecto de prueba:

```text
~/wip/nvim-language-smoke-tests/fsharp/Smoke.fsproj
~/wip/nvim-language-smoke-tests/fsharp/Program.fs
```

`Program.fs` contiene records, funciones y pipelines para probar hover, `gd` y completado. Al
final incluye una asignación de tipo incorrecto comentada; al descomentarla debe aparecer un
diagnóstico.

El parser de Treesitter y su resaltado usan el filetype `fsharp`. Son independientes de
FSAutocomplete y Fantomas.

---

## Haskell

### Fallo inicial de Mason

Mason intentaba instalar HLS mediante GHCup:

```text
ghcup --url-source=... install hls 2.13.0.0 -i .../mason/packages/haskell-language-server
ghcup no está instalado
```

GHCup no está en los repositorios oficiales configurados de Pacman. En AUR existe
`ghcup-hs-bin`, pero en esta instalación se utilizó el bootstrap oficial autorizado por el
usuario.

### Instalación oficial en Unix

Para Linux, macOS, FreeBSD y WSL2:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
```

El instalador trabaja dentro del directorio del usuario (`~/.ghcup`), por lo que no se ejecuta con
`sudo` ni como root. Añade esta carga del entorno al shell:

```bash
[ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env"
```

Durante esta instalación se eligieron los canales estables, se omitieron prereleases, cross y
third-party, y se dejó que Mason instalase HLS. El bootstrap sí instaló el toolchain necesario para
trabajar con proyectos Haskell:

```text
GHCup  0.2.6.2
GHC    9.10.3
Cabal  3.16.1.0
Stack  3.11.1
```

HLS no se instaló mediante el bootstrap para evitar duplicarlo fuera de Mason.

### Después de instalar

Hay que abrir una terminal nueva y reiniciar Neovim para que Mason encuentre
`~/.ghcup/bin/ghcup`. En la terminal actual se puede cargar manualmente con:

```bash
source ~/.ghcup/env
```

Después se puede repetir desde Neovim:

```vim
:MasonInstallAll
```

Mason utilizará GHCup para colocar HLS dentro de su propio directorio. Fourmolu sigue siendo el
formatter configurado mediante Conform.

Proyecto de prueba:

```text
~/wip/nvim-language-smoke-tests/haskell/lsp-smoke.cabal
~/wip/nvim-language-smoke-tests/haskell/app/Main.hs
~/wip/nvim-language-smoke-tests/haskell/literate/Literate.lhs
```

El archivo `.cabal` es el marcador de proyecto y declara `Main.hs`; debe abrirse Neovim desde esa
carpeta para que HLS y Cabal resuelvan correctamente el componente ejecutable.

El mismo `.cabal` declara un segundo ejecutable para `Literate.lhs`. Los `.lhs` usan el filetype
`lhaskell`: HLS contempla ese filetype, Conform lo asigna a Fourmolu y Treesitter reutiliza el
parser `haskell` mediante el alias `lhaskell = "haskell"`. Para probar el soporte completo hay que
activar tanto la entrada `lhaskell` de highlights como ese alias.

---

## Java

`jdtls`, `google-java-format` y el parser de Java funcionaron directamente con el JDK ya instalado,
sin dependencias ni ajustes adicionales. Estado confirmado por el usuario.

Proyecto de prueba:

```text
~/wip/nvim-language-smoke-tests/java/pom.xml
~/wip/nvim-language-smoke-tests/java/src/main/java/Main.java
```

---

## OCaml

Mason necesita `opam`, el gestor de paquetes de OCaml. Está disponible en el repositorio oficial
`extra` de Arch:

```bash
sudo pacman -S --needed opam
```

En este sistema ya estaba instalado, por lo que no se ejecutó de nuevo:

```text
opam 2.5.1-2
```

Mason falló inicialmente porque instalar el ejecutable no crea automáticamente la raíz, el
repositorio ni un switch de opam:

```text
[ERROR] Opam has not been initialised, please run `opam init`
```

La inicialización se realizó como usuario normal, reutilizando OCaml 5.5.0 del sistema y evitando
cambios en los archivos del shell:

```bash
opam init --yes --no-setup --compiler=ocaml-system
```

Estado resultante:

```text
opam root:     ~/.opam
switch activo: ocaml-system
compilador:    ocaml-system.5.5.0
```

`--no-setup` garantiza que opam no modifique `.zshrc`, `.zprofile` ni `.profile`. La orden que
muestra al terminar:

```bash
eval $(opam env --switch=ocaml-system)
```

solo actualiza variables de la terminal actual; no persiste al cerrarla. Mason ejecuta `opam`
directamente y puede utilizar el switch seleccionado, por lo que normalmente no necesita ese
`eval`. Sí puede ser necesario para ejecutar desde la terminal herramientas instaladas dentro del
switch.

### `ocamlformat-rpc` no encontrado

Después de instalar ambos paquetes, ocamllsp avisó:

```text
Unable to find 'ocamlformat-rpc' binary.
Types on hover may not be well-formatted.
```

El binario 0.29.0 sí estaba instalado tanto en el switch como dentro del paquete de Mason. El
`mason-receipt.json` de `ocamlformat` sólo enlazaba `ocamlformat` en `mason/bin` y omitía
`ocamlformat-rpc`.

Ejecutar `eval $(opam env --switch=ocaml-system)` antes de abrir Neovim también lo expondría, pero
haría depender la configuración del entorno del shell. La solución aplicada es local al servidor y
portable: la factory de `ocamllsp` añade a su `cmd_env.PATH` este directorio calculado con
`stdpath("data")`:

```text
mason/packages/ocamlformat/bin
```

Así ocamllsp encuentra el RPC en Linux, macOS o Windows sin modificar el `PATH` global, crear
symlinks manuales ni requerir integración persistente de opam con el shell.

### Dune en modo watch

Al abrir `dune-project`, ocamllsp puede mostrar:

```text
No dune instance found. Please run dune in watch mode for .../dune-project.
```

Esto es independiente de `ocamlformat-rpc`: ocamllsp ya está funcionando, pero su integración con
Dune necesita una instancia RPC activa para recibir el estado, los diagnósticos y los cambios del
proyecto.

Dune quedó instalado dentro del switch `ocaml-system`, no en el `PATH` global. Desde la raíz del
proyecto se puede iniciar sin ejecutar `eval`:

```bash
opam exec --switch=ocaml-system -- dune build --watch
```

Ese proceso debe permanecer abierto en otra terminal mientras se usa Neovim. `eval $(opam env)`
sólo permitiría escribir `dune build --watch` directamente; no iniciaría el watcher por sí mismo.
El comando equivalente con el entorno cargado es:

```bash
eval $(opam env --switch=ocaml-system)
dune build --watch
```

No se inicia Dune automáticamente desde la configuración de Neovim: el watcher pertenece al ciclo
de vida del proyecto y el usuario debe decidir cuándo arrancarlo o detenerlo.

El repositorio advirtió que opam 2.5.2 contiene correcciones de seguridad mientras Arch tenía
2.5.1-2. No se mezcla la instalación oficial de Arch con un binario manual: se actualizará mediante
una actualización completa del sistema cuando el paquete llegue al repositorio.

Proyecto de prueba:

```text
~/wip/nvim-language-smoke-tests/ocaml/dune-project
~/wip/nvim-language-smoke-tests/ocaml/bin/main.ml
```

---

## Scala

Metals (LSP) y Scalafmt (formatter) son herramientas externas: esta configuración no intenta
instalarlas mediante Mason. También hace falta un JDK compatible. Se usa Java 17 porque es la
opción conservadora recomendada para Metals; puede convivir con otro Java predeterminado.

### Arch con Chaotic-AUR

Si el repositorio de terceros Chaotic-AUR ya está configurado, Metals puede instalarse como binario
precompilado con Pacman. `sbt` y `jdk17-openjdk` proceden del repositorio oficial `extra`:

```bash
sudo pacman -S --needed metals sbt jdk17-openjdk
```

Esto se hizo en esta máquina con `sudo pacman`: quedaron instalados Metals 1.5.2, sbt 2.0.2 y
OpenJDK 17. El Java global continúa siendo OpenJDK 26. El lanzador de Metals empaquetado por
Chaotic-AUR busca `/usr/lib/jvm/java-17-openjdk` y lo utiliza sin cambiar el valor global de
`archlinux-java`.

Chaotic-AUR es sólo una comodidad, no un requisito de la configuración.

### Arch sin Chaotic-AUR

Instalar las dependencias oficiales con Pacman:

```bash
sudo pacman -S --needed sbt jdk17-openjdk
```

Después, instalar Metals desde AUR. Este paso debe ejecutarlo el usuario con su ayudante de AUR:

```bash
paru --sudoloop -S metals
```

### Scalafmt

En Arch, el paquete directo está en AUR, no en los repositorios oficiales ni en Chaotic-AUR. Para
esta configuración, la opción más sencilla es:

```bash
paru --sudoloop -S scalafmt
```

También existe `scalafmt-native-bin`, pero en el momento de escribir esta nota estaba detrás de la
versión del paquete `scalafmt`; por eso se prefiere el primero. Una vez instalado, Conform encuentra
`scalafmt` en `/usr/bin` sin configuración adicional.

Scalafmt exige que toda configuración declare una versión. Si el proyecto contiene
`.scalafmt.conf`, Conform conserva la versión indicada allí. Para archivos o proyectos sin ese
archivo, la configuración de Neovim usa `3.10.6` como fallback reproducible y añade encima las
preferencias globales de ancho e indentación. El dialecto fallback es `scala3`; para archivos
`.sbt` se usa `sbt1`. Los proyectos Scala 2 deben declarar su dialecto (`scala211`, `scala212` o
`scala213`) en `.scalafmt.conf`. Al cambiar deliberadamente esos valores hay que actualizar
`scalafmt_fallback_version` o `scalafmt_fallback_dialect` en `lua/lzy/conform.lua`.

Como Scalafmt arranca sobre la JVM, puede tardar más que el segundo de espera predeterminado de
Conform. La entrada de Scala en `formatters_by_ft` dispone de 10 segundos; este límite sólo afecta
a Scalafmt y evita que su primer arranque termine con código 143 por timeout.

La vía oficial recomendada por Scalafmt es Coursier. Puede usarse como alternativa si no se desea
el paquete AUR de Scalafmt:

```bash
paru --sudoloop -S coursier-bin
cs install scalafmt
```

El directorio de instalación que muestre Coursier debe estar en `PATH`. No conviene instalar a la
vez el mismo ejecutable con Pacman/AUR y con Coursier, porque el resultado dependería del orden del
`PATH`.

No hace falta instalar un paquete global `scala`: sbt resuelve la versión declarada por cada
proyecto. Metals puede importar builds de sbt y proporcionar diagnósticos al compilar.

Proyecto de prueba:

```text
~/wip/nvim-language-smoke-tests/scala/build.sbt
~/wip/nvim-language-smoke-tests/scala/src/main/scala/Main.scala
```

El proyecto declara Scala 3.7.1. Metals importará el build de sbt y Scalafmt se usará directamente
desde Conform.

Referencias:

- [Instalación de Scalafmt](https://scalameta.org/scalafmt/docs/installation.html)
- [Metals para Vim/Neovim](https://scalameta.org/metals/docs/editors/vim/)

---

## Ruby

Ruby LSP se instala mediante Mason, pero se ejecuta con el Ruby del sistema y necesita poder cargar
Bundler. Sin el paquete correspondiente, el servidor termina al arrancar con este error:

```text
cannot load such file -- bundler (LoadError)
```

En Arch, Ruby y Bundler están en el repositorio oficial `extra`:

```bash
sudo pacman -S --needed ruby ruby-bundler
```

En esta máquina ya estaba instalado Ruby 3.4.8 y se añadió `ruby-bundler` 4.0.3 mediante
`sudo pacman`. No hace falta instalar Bundler otra vez con `gem install`, lo que mezclaría una
gema gestionada manualmente con los paquetes del sistema.

Arch separa algunas gemas de la biblioteca estándar. RuboCop requiere ERB, por lo que también hay
que instalar su paquete oficial:

```bash
sudo pacman -S --needed ruby-erb
```

Comprobación útil:

```bash
ruby --version
bundle --version
ruby -rbundler -e 'puts Bundler::VERSION'
```

Si un proyecto contiene `Gemfile`, Ruby LSP exige también un `Gemfile.lock`. Hay que generarlo desde
la raíz del proyecto, incluso cuando todavía no se hayan añadido dependencias:

```bash
bundle install
```

Sin ese archivo, el servidor termina indicando `Project contains a Gemfile, but no Gemfile.lock`.
En el proyecto de prueba el comando no instaló gemas porque el `Gemfile` está vacío; sólo resolvió
el entorno y creó el lockfile.

Ruby LSP genera además un bundle compuesto en `.ruby-lsp` con el propio servidor, `debug` y las
dependencias del proyecto. Con el Ruby del sistema, Bundler intentaría instalar esas gemas bajo
`/usr/lib/ruby/gems` y fallaría por permisos. La configuración LSP define `BUNDLE_PATH` como:

```text
stdpath("data")/ruby-lsp/bundle
```

Así cada usuario dispone de un almacén escribible y no es necesario ejecutar Bundler como root ni
cambiar permisos dentro de `/usr/lib`. La ruta se calcula en runtime, por lo que no contiene rutas
específicas de Linux o del usuario actual.

Proyecto de prueba:

```text
~/wip/nvim-language-smoke-tests/ruby/Gemfile
~/wip/nvim-language-smoke-tests/ruby/Gemfile.lock
~/wip/nvim-language-smoke-tests/ruby/main.rb
```

---

## Swift

`sourcekit-lsp` (LSP) se distribuye dentro del toolchain de Swift: no existe un paquete
independiente `sourcekit-lsp` en Mason ni en los repositorios oficiales de Arch. Es exactamente uno
de esos servidores que se instalan a nivel de sistema. El formatter sí es de Mason (`swiftformat`).

### Instalación del toolchain

En Arch no hay un paquete oficial `swift`. Se usa el empaquetado del toolchain oficial de
swift.org:

```bash
# Con Chaotic-AUR (como Metals y Scalafmt)
sudo pacman -S --needed swift-bin

# Sin Chaotic-AUR, desde AUR
paru --needed --sudoloop swift-bin
```

En esta máquina se instaló con `sudo pacman`. `swift-bin` incluye el toolchain completo:
`/usr/bin/sourcekit-lsp` y `/usr/bin/swift`. La dependencia opcional `python39` sólo hace falta
para el REPL, no para el LSP.

Estado instalado:

```text
swift-bin 6.3.3-1
Swift 6.3.3 (swift-6.3.3-RELEASE)
Target: x86_64-unknown-linux-gnu
sourcekit-lsp: /usr/bin/sourcekit-lsp
```

### Formatter

Conform usa `swiftformat` desde Mason. No hay que confundirlo con `swift-format`, que no se incluye
en el toolchain y no está empaquetado para Pacman/AUR en este sistema.

### Comprobación manual

```bash
swift --version
sourcekit-lsp --version
```

### Activación en Neovim

```lua
-- lua/lzy/lspconfig.lua
"sourcekit",

-- lua/lzy/conform.lua
swift = { "swiftformat" },

-- lua/lzy/treesitter.lua
"swift",
swift = true,
```

En `lua/lzy/lspconfig.lua`, `sourcekit` está restringido al filetype `swift` (`filetypes = { "swift" }`)
porque el servidor también anuncia C/C++/Objective-C, que ya gestiona clangd. Así se evitan dos
clientes simultáneos.

Desde Neovim sólo hace falta instalar el formatter y el parser:

```vim
:MasonInstall swiftformat
:TSInstallAll
```

### Estado

Toolchain instalado; prueba manual pendiente en el proyecto de muestra.

Proyecto de prueba:

```text
~/wip/nvim-language-smoke-tests/swift/Package.swift
~/wip/nvim-language-smoke-tests/swift/Sources/Smoke/main.swift
```

Referencias:

- https://aur.archlinux.org/packages/swift-bin
- https://www.swift.org/

---

## Django

### LSP y formatter

`djls` (`django-language-server`) es el LSP actual para plantillas de Django (y Jinja). `djlint` es
el formatter/linter estándar de plantillas HTML (Django, Jinja, Twig, Nunjucks, Handlebars, ...).
Ambos se instalan con Mason; como son de Python, Mason los deja en su propio entorno y no hacen
falta paquetes Python del sistema para ellos.

Lo que sí hace falta es el framework: sin un proyecto Django real (`manage.py` + `settings.py`),
`djls` no puede resolver tags, filtros ni el contexto de las plantillas.

### Paquete necesario

```bash
sudo pacman -S --needed python-django
```

Paquete instalado en esta máquina:

```text
python-django 5.2.13-1
python-asgiref 3.12.1-1
python-pytz 2026.1-1
python-sqlparse 0.5.3-2
```

### Restricción de filetypes

`djls` anuncia también `html` y `python`, que ya gestionan el LSP de HTML y `basedpyright`. Para no
duplicar clientes se restringe a `htmldjango` en `lua/lzy/lspconfig.lua`:

```lua
djls = {
  filetypes = { "htmldjango" },
},
```

### Activación en Neovim

```lua
-- lua/lzy/lspconfig.lua
"djls",

-- lua/lzy/conform.lua
htmldjango = { "djlint" },

-- lua/lzy/treesitter.lua (ya estaba activo)
"htmldjango",
htmldjango = true,
```

En Conform, `djlint` recibe `--profile django`, `--indent` (ancho de la política) y
`--max-line-length`; el builtin de Conform ya aporta `--reformat -`.

Instalación desde Neovim:

```vim
:MasonInstall django-language-server djlint
:TSInstallAll
```

### Comprobación manual

```bash
python -m django --version
python manage.py check
```

### Estado

Toolchain instalado; prueba manual pendiente en el proyecto de muestra.

Proyecto de prueba:

```text
~/wip/nvim-language-smoke-tests/django/manage.py
~/wip/nvim-language-smoke-tests/django/templates/base.html
~/wip/nvim-language-smoke-tests/django/templates/index.html
```

El proyecto es un Django mínimo (manage.py, settings, urls con una TemplateView) cuyas plantillas
ejercitan `extends`, `block`, `for`, `if/else`, variables, filtros y `url`. Están mal formateadas a
propósito para probar `djlint`.

Referencia:

- https://djlint.com/
- https://github.com/joshuadavidthomas/django-language-server

---

## Mantenimiento

Arch es rolling release. Actualizar el sistema completo, evitando actualizaciones parciales:

```bash
sudo pacman -Syu
```

Inventario útil:

```bash
pacman -Q | grep -E '^(dotnet|aspnet|clojure|dart|jdk|jre|kotlin)'
```
