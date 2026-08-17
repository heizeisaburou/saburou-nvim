# Compilador de C

Volver a [README](/README.md)

### Windows

Solo necesitas un compilador, y como [Visual Studio Build Tools](/docs/Compilador%20de%20C.md#visual-studio-build-tools) lo has tenido que instalar para
poder instalar [Cargo+Rust](/docs/Cargo+Rust.md) no necesitas otro compilador. Aún así voy a explicar como instalar
otros compiladores y _toolchains_ por si necesitaras más.

Para que funcione la configuración en Windows solo necesitas ―y necesitas este― `MSCV`.

- El comando `TSInstallAll` utiliza `cl.exe` en Windows.
- Normlamente instalarás el paquete completo [Visual Sudio Build Tools](/docs/Compilador%20de%20C.md#visual-sudio-build-tools), ya que el paquete
  completo es una dependencia de [Cargo+Rust](/docs/Cargo+Rust.md).

#### Visual Sudio Build Tools

> [!note]
>
> - insalado en el paso [Visual Studio Installer method](/docs/Cargo+Rust.md#visual-studio-installer-method) de Cargo+Rust.

- Incluye:
	- MSVC C++ build tools
	- Windows SDK

Instalación:

```powershell
winget install Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
```

> [!warning]
>
> Si ya está instalado entonces no se instalará nada. Si tras no dejarte instalar porque ya está
> instalado ejecutas `rustup-init` ves un mensaje en rojo que dice
> `Install the C++ build tools before proceeding.` entonces puedes agregar `--force` delante del
> `--override` para que se instale lo que falta tras una instalación parcial.
>
> ```powershell
> winget install Microsoft.VisualStudio.2022.BuildTools --force --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
> ```

> [!tip]
>
> Si quieres cargarlo en tu `pwsh` ―no es necesario para `saburou-nvim`― puedes utilizar:
>
> ```powershell
> Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
> & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\Launch-VsDevShell.ps1"
> ```

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
> `clang`, `gcc` y `MinGW` no son exactamente alternativas equivalentes. `clang` y `gcc` son compiladores,
> mientras que MinGW-w64 es un _toolchain_ que incluye `gcc` y las herramientas necesarias para
> utilizarlo en Windows.

> [!NOTE]
>
> MinGW-w64 también es lo que necesita el _toolchain_ alternativo de Rust `x86_64-pc-windows-gnu`,
> que enlaza con GNU en lugar de con MSVC. Esta guía asume el _toolchain_ MSVC, que es el que
> instala rustup por defecto; ver [Cargo+Rust](/docs/Cargo+Rust.md#windows-1).

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
> Tampoco necesitas nada de MSVC: es exclusivo de Windows, y en Linux el _toolchain_ de Rust enlaza
> con las herramientas de GNU/LLVM que ya trae el sistema.
