# Compilador de C

Volver a [README](/README.md)

## Brief

Un compilador de C traduce código C a código máquina. Aquí hace falta uno para compilar binarios
nativos: los parsers de Tree-sitter, herramientas de Mason que no traen binario precompilado,
etc. Además, el _toolchain_ que Rust instala por defecto en Windows compila y enlaza mediante MSVC,
así que [Cargo+Rust](/docs/Cargo+Rust.md) depende de esta nota.

Esta nota cubre las opciones disponibles en Windows (MSVC, clang, gcc vía MinGW) y en Linux (gcc,
clang), y cuál de ellas usa realmente esta configuración en cada sistema.

## Installation

### Windows

Puedes utilizar cualquiera de los siguientes compiladores o _toolchains_, dependiendo de lo que
requiera el programa:

- [MSVC](#msvc) — el que usan el _toolchain_ MSVC de [Rust](/docs/Cargo+Rust.md) y `tree-sitter build`, además de los programas
  que piden `cl.exe`.
- [clang](#clang)
- [gcc](#gcc)
- [MinGW](#mingw)

#### Qué compilador necesita esta configuración

En Windows, los parsers de Tree-sitter no los compila Neovim: `nvim-treesitter` ejecuta
`tree-sitter build` ([tree-sitter-cli](/docs/tree-sitter-cli.md)), y ese comando **localiza el compilador de MSVC a través de
la instalación de Visual Studio, no del `PATH`**. Por eso `:TSInstallAll` funciona desde una PowerShell
normal, sin cargar el entorno de MSVC y sin que `cl.exe` esté en el `PATH`; lo único que hace falta
es tener las herramientas instaladas.

Y como el _toolchain_ de [Rust](/docs/Cargo+Rust.md) que instalas para disponer de `tree-sitter-cli` ya exige esas mismas
herramientas, en Windows no hay realmente un paso extra: al terminar [Cargo+Rust](/docs/Cargo+Rust.md) ya tienes el
compilador de C que necesitan los parsers.

`clang`, `gcc` o MinGW siguen siendo útiles para el resto: paquetes de Mason que se compilan al
instalarse, y programas que esperan un _toolchain_ GNU.

En [Linux](#linux) es más simple: `tree-sitter build` usa el `cc` del `PATH`, así que basta con tener instalado
`gcc` o `clang`.

> [!NOTE] Si en Windows no quieres MSVC
>
> `tree-sitter build` respeta la variable de entorno `CC`: si la defines apuntando a otro
> compilador —por ejemplo el `gcc` de [MinGW](#mingw)—, la usará en lugar de buscar MSVC. No es
> el camino que cubre esta guía y no lo he comprobado, pero existe.

#### MSVC

MSVC es el compilador de C/C++ de Microsoft y forma parte de las **Visual Studio Build Tools**.

Lo necesitas en tres casos, y los tres se resuelven con la misma instalación:

- Vas a instalar Rust con su _toolchain_ por defecto en Windows (`x86_64-pc-windows-msvc`), que
  compila y enlaza con MSVC; ver [Cargo+Rust#requisito-previo](/docs/Cargo+Rust.md#requisito-previo-herramientas-de-msvc).
- Vas a compilar los parsers de Tree-sitter, porque `tree-sitter build` usa MSVC en Windows.
- Un programa requiere específicamente `cl.exe`.

En ambos casos los componentes que hacen falta son los mismos:

- **MSVC v143 - VS 2022 C++ x64/x86 build tools**
- **Windows 11 SDK**

Los dos se obtienen seleccionando la carga de trabajo **Desktop development with C++**, y hay dos
formas de instalarla: con el IDE ([Visual Studio Community](#visual-studio-community)) o sin él
([Visual Studio Build Tools](#visual-studio-build-tools)).

Ambas opciones son igualmente válidas para Rust y para esta configuración de **Neovim**. La
diferencia es principalmente de comodidad: **Visual Studio Community ofrece un entorno de
desarrollo completo**, mientras que **Build Tools** instala únicamente las herramientas necesarias.

##### Visual Studio Community

> NOTA: Si vienes desde otra nota, empieza a leer desde
> [Windows](/docs/Compilador%20de%20C.md#windows).

Es la opción más sencilla, y **no es una mala opción** si vas a desarrollar habitualmente en C/C++ o
quieres disponer de un entorno de desarrollo completo para Windows.

Durante la instalación, selecciona la carga de trabajo:

- **Desktop development with C++**

Esto instalará, entre otras herramientas, **MSVC v143 - VS 2022 C++ x64/x86 build tools** y el
**Windows 11 SDK**.

##### Visual Studio Build Tools

> NOTA: Si vienes desde otra nota, empieza a leer desde
> [Windows](/docs/Compilador%20de%20C.md#windows).

Es la opción más ligera si no quieres instalar el IDE. Puedes instalarla mediante `winget`:

```powershell
winget install Microsoft.VisualStudio.2022.BuildTools
```

Esto instala el instalador y las herramientas comunes, pero **todavía no el compilador**: después hay
que añadir la carga de trabajo **Desktop development with C++**, que es la que incluye las
herramientas de MSVC y el Windows SDK.

Puedes añadirla desde **Visual Studio Installer**:

1. Abre **Visual Studio Installer**.
2. En **Build Tools 2022**, pulsa **Modify**.
3. Selecciona **Desktop development with C++**.
4. Pulsa **Modify**.

También puedes añadirla desde PowerShell:

```powershell
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe" `
	modify `
	--installPath "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools" `
	--add Microsoft.VisualStudio.Workload.VCTools `
	--includeRecommended `
	--passive `
	--norestart
```

##### Cargar el entorno de MSVC manualmente

> [!NOTE] Sección adicional
>
> Esto es información gratuita que no tiene que ver con la guía. Nada de lo que usa esta
> configuración necesita que cargues el entorno de MSVC: ni Rust ni `tree-sitter build`, que
> localizan las herramientas por su cuenta. Pero si quisieras utilizar `cl.exe` directamente
> desde una terminal normal puedes cargarlo tú mismo:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\Launch-VsDevShell.ps1"
```

Después `cl.exe` estará disponible en esa sesión de PowerShell.

La ruta corresponde a **Build Tools**; si instalaste **Visual Studio Community**, el script está en el
directorio de esa edición (`...\Microsoft Visual Studio\2022\Community\Common7\Tools\`).

###### Comprobar la instalación de MSVC

Abre **Developer PowerShell for VS 2022** o **x64 Native Tools Command Prompt for VS 2022** y comprueba
`cl.exe`:

```powershell
cl
```

> [!NOTE] Por qué hace falta una terminal de desarrollo para comprobarlo
>
> `cl.exe` no está disponible en una PowerShell o CMD normal mediante `PATH`. Las herramientas de
> MSVC necesitan además variables como `INCLUDE` y `LIB`, por lo que Visual Studio proporciona
> terminales de desarrollo que cargan automáticamente este entorno.
>
> Eso es un requisito para invocar `cl.exe` a mano, **no para esta configuración**: tanto el
> _toolchain_ de Rust como `tree-sitter build` localizan MSVC a través de la instalación de
> Visual Studio y se configuran ese entorno ellos mismos. Que `cl` no funcione en tu PowerShell
> habitual no significa que las herramientas estén mal instaladas.

> [!NOTE]
>
> Instalar LLVM mediante `winget install LLVM.LLVM` no instala `cl.exe`. LLVM proporciona
> `clang.exe` y `clang-cl.exe`, que son herramientas diferentes de MSVC.

##### Si posteriormente necesitas el IDE de Visual Studio

Si inicialmente instalaste únicamente **Visual Studio Build Tools** y posteriormente necesitas el IDE
de Visual Studio, no es necesario reinstalar las herramientas: puedes instalar **Visual Studio
Community** después y conservar la instalación existente de las Build Tools.

> [!NOTE]
>
> Si llegaste a esta sección desde [Cargo+Rust](/docs/Cargo+Rust.md) porque el instalador de Rust
> te pide las herramientas de MSVC, ya puedes volver a
> [Cargo+Rust#instalar-rust-con-rustup-init](/docs/Cargo+Rust.md#instalar-rust-con-rustup-init)
> para continuar con la instalación de Rust.

#### clang

`clang` es un compilador de C/C++ basado en LLVM.

Puedes instalarlo mediante `winget`:

```powershell
winget install LLVM.LLVM
```

Comprueba la instalación con:

```powershell
clang --version
```

#### gcc

`gcc` es el compilador de C del proyecto GNU.

En Windows, `gcc` normalmente se utiliza a través de un _toolchain_ como [MinGW-w64](#mingw).

#### MinGW

MinGW-w64 proporciona un _toolchain_ basado en GNU para compilar programas nativos para Windows.
Incluye `gcc`, el linker y otras herramientas necesarias para la compilación.

Puedes instalarlo mediante `winget`:

```powershell
winget install BrechtSanders.WinLibs.POSIX.UCRT
```

Comprueba la instalación con:

```powershell
gcc --version
```

> [!NOTE]
>
> `clang`, `gcc` y `MinGW` no son exactamente alternativas equivalentes. `clang` y `gcc` son
> compiladores, mientras que MinGW-w64 es un _toolchain_ que incluye `gcc` y las herramientas
> necesarias para utilizarlo en Windows.

> [!NOTE]
>
> MinGW-w64 también es lo que necesita el _toolchain_ alternativo de Rust
> `x86_64-pc-windows-gnu`, que enlaza con GNU en lugar de con MSVC. Esta guía asume el
> _toolchain_ MSVC, que es el que instala rustup por defecto; ver
> [Cargo+Rust](/docs/Cargo+Rust.md#windows).

### Linux

En Linux puedes instalar directamente `gcc` o `clang` mediante el gestor de paquetes de tu
distribución.

#### gcc

Instala el paquete `gcc` mediante el gestor de paquetes de tu distribución.

Comprueba la instalación con:

```sh
gcc --version
```

#### clang

Instala el paquete `clang` mediante el gestor de paquetes de tu distribución.

Comprueba la instalación con:

```sh
clang --version
```

> [!NOTE]
>
> En Linux no necesitas MinGW para compilar programas nativos para Linux. MinGW-w64 está
> orientado principalmente a generar programas para Windows.
>
> Tampoco necesitas nada de MSVC: es exclusivo de Windows, y en Linux el _toolchain_ de Rust
> enlaza con las herramientas de GNU/LLVM que ya trae el sistema.
