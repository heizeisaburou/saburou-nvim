# Cargo + Rust

Volver a [README](/README.md) https://doc.rust-lang.org/cargo/getting-started/installation.html

## Brief

Necesario para compilar y/o ―binstall― instalar `tree-sitter-cli`. También necesario para programar
en _Rust_.

## Installation

### Windows

En Windows puedes encontrar el instalador en
https://doc.rust-lang.org/cargo/getting-started/installation.html, o descargarlo directamente
desde [rustup-init.exe](https://win.rustup.rs/).

Cargo puede parecer una dependencia complicada por dos motivos:

1. El _toolchain_ MSVC de Rust necesita algunas herramientas de compilación de Windows:

	- **MSVC C++ build tools** (`MSVC v143 - VS 2022 C++ x64/x86 build tools`)
	- **Windows SDK** (Windows 11 SDK)

2. El instalador ofrece como opción sencilla **Quick install via the Visual Studio Community
   installer**, lo que puede dar la impresión de que es necesario instalar Visual Studio
   completo.

En realidad, podemos elegir entre dos opciones:

### Visual Studio Community

Es la opción más sencilla si queremos disponer además de un entorno completo de desarrollo C/C++.

Durante la instalación selecciona la carga de trabajo:

- **Desktop development with C++**
- **MSVC v143 - VS 2022 C++ x64/x86 build tools**
- **Windows SDK**

### Visual Studio Build Tools

Es la opción más ligera si no queremos instalar el IDE de Visual Studio.

Podemos instalarla mediante:

```powershell
winget install Microsoft.VisualStudio.2022.BuildTools
```

Después hay que añadir la carga de trabajo **Desktop development with C++**, que incluye las
herramientas de MSVC y el Windows SDK.

Podemos hacerlo desde **Visual Studio Installer**:

1. Abre **Visual Studio Installer**.
2. En **Build Tools 2022**, pulsa **Modify**.
3. Selecciona **Desktop development with C++**.
4. Pulsa **Modify**.

También podemos hacerlo desde PowerShell:

```powershell
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe" `
	modify `
	--installPath "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools" `
	--add Microsoft.VisualStudio.Workload.VCTools `
	--includeRecommended `
	--passive `
	--norestart
```

Ambas opciones son válidas para Rust y para esta configuración de **Neovim**. La diferencia es
principalmente de comodidad: **Visual Studio Community ofrece un entorno más completo**, mientras
que **Build Tools** permite instalar únicamente las herramientas necesarias.

Una vez instaladas las herramientas, podemos continuar con la instalación estándar de Rust.

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

> [!NOTE]
>
> Si ya tienes instalado Rust pero posteriormente descubres que necesitas las herramientas de
> MSVC, puedes volver a [Compilador de C#MSVC](#compilador-de-cmsvc) para instalarlas sin
> necesidad de reinstalar Rust.

### Cargar el entorno de MSVC manualmente

> [!NOTE] Sección adicional
>
> Esto es información gratuita que no tiene que ver con la guía. _saburou-nvim_ no necesita
> cargar el entorno MSVC pero si tu quisieras utilizar `cl.exe` directamente desde una terminal
> puedes cargar el entorno de desarrollo de MSVC:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\Launch-VsDevShell.ps1"
```

Después `cl.exe` estará disponible en esa sesión de PowerShell.

## cargo-binstall

`cargo-binstall` es una herramienta adicional para Cargo que permite instalar binarios
precompilados de paquetes de Rust cuando están disponibles.

No forma parte de la instalación de Rust y Cargo, por lo que debe instalarse por separado.

Si instalas `cargo-binstall` y existe un binario precompilado de `tree-sitter-cli` para tu
plataforma, puedes instalarlo sin necesidad de disponer de _Node.js_ para compilarlo.

### Installation of cargo-binstall

https://github.com/cargo-bins/cargo-binstall

Al igual que `cargo`, `cargo-binstall` puede instalarse mediante un binario precompilado. Esto evita
tener que compilarlo desde el código fuente.

#### Linux / macOS

```sh
curl -L --proto '=https' --tlsv1.2 -sSf \
  https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh \
  | bash
```

#### Windows

```powershell
Set-ExecutionPolicy Unrestricted -Scope Process
iex (iwr "https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.ps1").Content
```

Una vez instalado, podemos comprobar que `cargo-binstall` está disponible mediante:

```sh
cargo binstall -V
```

> [!NOTE]
>
> Es necesario reiniciar la terminal para que binstall pase a estar disponible tras la
> instalación.
