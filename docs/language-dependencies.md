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

## Mantenimiento

Arch es rolling release. Actualizar el sistema completo, evitando actualizaciones parciales:

```bash
sudo pacman -Syu
```

Inventario útil:

```bash
pacman -Q | grep -E '^(dotnet|aspnet|clojure|dart|jdk|jre)'
```
