# Cargo + Rust

Volver a [README](/README.md)  
<https://doc.rust-lang.org/cargo/getting-started/installation.html>

## Brief

Cargo es el gestor de paquetes y de compilación de Rust; instalarlo instala también el propio
toolchain de Rust. Aquí hace falta para compilar —o, con [cargo-binstall](#cargo-binstall), instalar ya compilado—
[tree-sitter-cli](/docs/tree-sitter-cli.md); también es lo que necesitas si además quieres programar en Rust.

Esta nota cubre la instalación en Windows —la parte laboriosa, porque el toolchain que rustup
instala por defecto compila y enlaza con las herramientas de [MSVC](/docs/Compilador%20de%20C.md#msvc)— y, aparte, cómo instalar
`cargo-binstall`, la herramienta que permite saltarse la compilación cuando hay binario
precompilado disponible.

## Installation

### Windows

En Windows puedes encontrar el instalador en
<https://doc.rust-lang.org/cargo/getting-started/installation.html>, o descargarlo directamente
desde [rustup-init.exe](https://win.rustup.rs/).

Antes de ejecutarlo conviene saber por qué esta dependencia es más laboriosa que las demás:

1. El _toolchain_ que rustup instala por defecto en Windows (`x86_64-pc-windows-msvc`) compila y
   enlaza con [MSVC](/docs/Compilador%20de%20C.md#msvc), así que necesita antes algunas herramientas de compilación de Windows:

	- **MSVC C++ build tools** (`MSVC v143 - VS 2022 C++ x64/x86 build tools`)
	- **Windows 11 SDK**

2. El instalador ofrece como opción sencilla **Quick install via the Visual Studio Community
   installer**, lo que puede dar la impresión de que es necesario instalar Visual Studio completo.
   No lo es: basta con las Visual Studio Build Tools.

Por eso la instalación son dos pasos: primero las herramientas de MSVC, después rustup.

#### Requisito previo: herramientas de MSVC

Los pasos están en [Compilador de C#MSVC](/docs/Compilador%20de%20C.md#msvc). Resumidos, puedes elegir entre dos opciones, y ambas
son válidas para Rust:

- **[Visual Studio Community](/docs/Compilador%20de%20C.md#visual-studio-community)** — la más sencilla si quieres además un entorno completo de desarrollo
  C/C++.
- **[Visual Studio Build Tools](/docs/Compilador%20de%20C.md#visual-studio-build-tools)** — la más ligera si no quieres el IDE.

En cualquiera de los dos casos, lo que instala las herramientas es la carga de trabajo **Desktop
development with C++**.

Una vez instaladas, vuelve aquí y continúa con la instalación estándar de Rust.

Estas herramientas no son un peaje que pagues solo por Rust: en Windows son también el compilador
de C con el que `tree-sitter build` compila los parsers de Tree-sitter, así que instalarlas cubre a
la vez el requisito de [Compilador de C](/docs/Compilador%20de%20C.md#qué-compilador-necesita-esta-configuración).

> [!NOTE]
>
> Si ya tienes instalado Rust pero posteriormente descubres que necesitas las herramientas de
> MSVC, puedes instalarlas desde [Compilador de C#MSVC](/docs/Compilador%20de%20C.md#msvc) sin
> necesidad de reinstalar Rust.

> [!NOTE]
>
> Existe un _toolchain_ alternativo, `x86_64-pc-windows-gnu`, que enlaza con
> [MinGW-w64](/docs/Compilador%20de%20C.md#mingw) en lugar de con MSVC; es a lo que se refiere el
> mensaje sobre _the GNU ABI_ que muestra el instalador. Esta guía asume el _toolchain_ MSVC, que
> es el que rustup instala por defecto.

#### Instalar Rust con rustup-init

Al ejecutar `rustup-init.exe`, el instalador mostrará:

```text
If you will be targeting the GNU ABI or otherwise know what you are doing then it is fine to
continue installation without the build tools, but otherwise, install the C++ build tools before
proceeding.

Continue? (y/N)
```

- Contesta: `y`

A continuación mostrará:

```text
1. Proceed with standard installation (default - just press enter)
2. Customize installation
3. Cancel installation
```

- Pulsa `Enter` para continuar con la instalación estándar.

Finalmente **reinicia la terminal**.

#### Comprobar la instalación

```powershell
rustc --version
cargo --version
```

## cargo-binstall

`cargo-binstall` es una herramienta adicional para Cargo que permite instalar binarios
precompilados de paquetes de Rust cuando están disponibles.

No forma parte de la instalación de Rust y Cargo, por lo que debe instalarse por separado.

Si instalas `cargo-binstall` y existe un binario precompilado de [tree-sitter-cli](/docs/tree-sitter-cli.md) para tu
plataforma, puedes instalarlo sin necesidad de disponer de [Node.js](/docs/Node.js.md) para compilarlo.

### Installation of cargo-binstall

<https://github.com/cargo-bins/cargo-binstall>

Al igual que `cargo`, `cargo-binstall` puede instalarse mediante un binario precompilado. Esto evita
tener que compilarlo desde el código fuente.

#### Windows

```powershell
Set-ExecutionPolicy Unrestricted -Scope Process
iex (iwr "https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.ps1").Content
```

#### Linux / macOS

```sh
curl -L --proto '=https' --tlsv1.2 -sSf \
  https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh \
  | bash
```

#### Comprobar la instalación de cargo-binstall

> [!NOTE]
>
> Es necesario reiniciar la terminal para que binstall pase a estar disponible tras la
> instalación.

```sh
cargo binstall -V
```
