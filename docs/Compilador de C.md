# Compilador de C

Volver a [README](/README.md)

## Brief

Un compilador de C traduce código C a código máquina. Aquí hace falta uno para compilar binarios
nativos: parsers de Tree-sitter, herramientas de Mason que no traen binario precompilado, etc.

Esta nota cubre las opciones disponibles en Windows (MSVC, clang, gcc vía MinGW) y en Linux (gcc,
clang).

## Windows

Puedes utilizar cualquiera de los siguientes compiladores o _toolchains_, dependiendo de lo que
requiera el programa:

- [MSVC](#msvc)
- [clang](#clang)
- [gcc](#gcc)
- [MinGW](#mingw)

### MSVC

MSVC es el compilador de C/C++ de Microsoft y forma parte de las **Visual Studio Build Tools**.

Es necesario para programas que requieran específicamente `cl.exe`, y también es el compilador
utilizado por el _toolchain_ MSVC de Rust.

Existen dos formas principales de instalar las herramientas necesarias.

#### Visual Studio Community

La opción más sencilla es instalar **Visual Studio Community**, que incluye el IDE además de las
herramientas de compilación.

Durante la instalación, selecciona la carga de trabajo:

- **Desktop development with C++**

Esto instalará, entre otras herramientas:

- **MSVC v143 - VS 2022 C++ x64/x86 build tools**
- **Windows SDK**

Aunque para compilar no sea necesario el IDE, **instalar Visual Studio Community no es una mala
opción** si vamos a desarrollar habitualmente en C/C++ o queremos disponer de un entorno de
desarrollo completo para Windows.

#### Visual Studio Build Tools

Si no necesitamos el IDE, podemos instalar únicamente las herramientas de compilación:

```powershell
winget install Microsoft.VisualStudio.2022.BuildTools
```

Durante la instalación, selecciona:

- **Desktop development with C++**
- **MSVC v143 - VS 2022 C++ x64/x86 build tools**
- **Windows 11 SDK**

Esta opción proporciona las herramientas necesarias para compilar sin instalar Visual Studio
Community completo.

Una vez instaladas, puedes comprobar `cl.exe` desde **Developer PowerShell for VS 2022** o **x64
Native Tools Command Prompt for VS 2022**:

```powershell
cl
```

> [!NOTE]
>
> `cl.exe` no tiene por qué estar disponible en una PowerShell o CMD normal mediante `PATH`. Las
> herramientas de MSVC necesitan configurar también variables como `INCLUDE` y `LIB`, por lo que
> Visual Studio proporciona terminales de desarrollo que cargan automáticamente este entorno.

> [!NOTE]
>
> Instalar LLVM mediante `winget install LLVM.LLVM` no instala `cl.exe`. LLVM proporciona
> `clang.exe` y `clang-cl.exe`, que son herramientas diferentes de MSVC.

#### Si posteriormente necesitas Visual Studio

Si inicialmente instalaste únicamente **Visual Studio Build Tools** y posteriormente necesitas el
IDE de Visual Studio, no es necesario reinstalar las herramientas.

Puedes instalar **Visual Studio Community** posteriormente y conservar la instalación existente
de las Build Tools.

Del mismo modo, si llegaste a esta sección desde la documentación de **Cargo + Rust** porque Rust
te solicita las herramientas de MSVC, puedes volver a [Cargo + Rust](../cargo-rust/README.md) para continuar con la
instalación de Rust.

### clang

`clang` es un compilador de C/C++ basado en LLVM.

Puedes instalarlo mediante `winget`:

```powershell
winget install LLVM.LLVM
```

Comprueba la instalación con:

```powershell
clang --version
```

### gcc

`gcc` es el compilador de C del proyecto GNU.

En Windows, `gcc` normalmente se utiliza a través de un _toolchain_ como MinGW-w64.

### MinGW

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

## Linux

En Linux puedes instalar directamente `gcc` o `clang` mediante el gestor de paquetes de tu
distribución.

### gcc

Instala el paquete `gcc` mediante el gestor de paquetes de tu distribución.

Comprueba la instalación con:

```sh
gcc --version
```

### clang

Instala el paquete `clang` mediante el gestor de paquetes de tu distribución.

Comprueba la instalación con:

```sh
clang --version
```

> [!NOTE]
>
> En Linux no necesitas MinGW para compilar programas nativos para Linux. MinGW-w64 está
> orientado principalmente a generar programas para Windows.
