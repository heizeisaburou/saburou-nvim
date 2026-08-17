# Cargo + Rust

Volver a [README.md](/README.md)
<https://doc.rust-lang.org/cargo/getting-started/installation.html>

## Brief

Cargo es el gestor de paquetes y compilación de Rust; instalarlo instala también el propio
toolchain de Rust. Es necesario para compilar [tree-sitter-cli](/docs/tree-sitter-cli.md), o, en caso de instalar
[cargo-binstall](#cargo-binstall) para instalar el binario compilado directamente.

## Installation

### Windows

En _Windows_ instalar _Cargo+Rust_ es más complejo que en _Linux / macOS_ debido a sus dependencias:

- [Visual Studio Build Tools](/docs/Compilador%20de%20C.md#visual-studio-build-tools)
	- MSVC C++ build tools
	- Windows SDK

Empecemos por la descarga:

- Página: <https://doc.rust-lang.org/cargo/getting-started/installation.html>
- Énlace directo: [rustup-init.exe](https://win.rustup.rs/).

Una vez tengas el ejecutable puedes elegir como instalar las dependencias:

- [Visual Studio Installer method](#visual-studio-installer-method) → Camino simple, resuelve todas las dependencias de una.
- [Manual dependencies method](#manual-dependencies-method) → Camino intermedio; no es tan difícil.

#### Installation methods

##### Visual Studio Installer method

Inicia `rustup-init.exe` y selecciona la primera opción:

```text
1) Quick install via the Visual Studio Community installer
   (free for individuals, academic uses, and open source).
```

Se abrirá el instalador; es una instalación pesada pero sencilla, solamente sigue los pasos.

Una vez instalado elige:

```text
1) Proceed with standard installation (default - just press enter)
```

Reinicia la terminal para que `cargo` esté disponible en el `PATH`. Si quieres instalar
[cargo-binstall](/docs/Cargo+Rust.md#cargo-binstall) es un buen momento para hacerlo.

##### Manual dependencies method

Antes de iniciar `rustup-init.exe` instala las [Visual Studio Build Tools](/docs/Cargo+Rust.md#visual-studio-build-tools).

Inicia `rustup-init.exe` y selecciona la segunda opción:

```text
2) Manually install the prerequisites
   (for enterprise and advanced users).
```

Una vez instalado elige:

```text
1) Proceed with standard installation (default - just press enter)
```

Reinicia la terminal para que `cargo` esté disponible en el `PATH`. Si quieres instalar
[cargo-binstall](/docs/Cargo+Rust.md#cargo-binstall) es un buen momento para hacerlo.

## cargo-binstall

`cargo-binstall` es una herramienta adicional para Cargo que permite instalar binarios
precompilados de paquetes de Rust cuando están disponibles.

Si instalas `cargo-binstall` [tree-sitter-cli](/docs/tree-sitter-cli.md) dispone de binarios precompilados para todas las
plataformas, por lo que podrás instalarlo sin necesidad de instalar [Node.js](/docs/Node.js.md).

> [!NOTE]
>
> [Node.js](/docs/Node.js.md) sigue siendo una dependencia imprescindible de la configuración ya que no solamente
> es necesaria para poder compilar [tree-sitter-cli](/docs/tree-sitter-cli.md).

### Installation of cargo-binstall

<https://github.com/cargo-bins/cargo-binstall>

Al igual que `cargo`, `cargo-binstall` puede instalarse mediante un binario precompilado. Esto evita
tener que compilarlo desde el código fuente.

#### Windows

```powershell
Set-ExecutionPolicy Unrestricted -Scope Process
iex (iwr "https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.ps1").Content
```

> [!tip]
>
> No es necesario reiniciar la terminal.

#### Linux / macOS

```sh
curl -L --proto '=https' --tlsv1.2 -sSf \
  https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh \
  | bash
```

> [!tip]
>
> No es necesario reiniciar la terminal.

#### Comprobar la instalación de cargo-binstall

> [!NOTE]
>
> Es necesario reiniciar la terminal para que binstall pase a estar disponible tras la
> instalación.

```sh
cargo binstall -V
```
