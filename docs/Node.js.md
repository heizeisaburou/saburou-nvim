# Node.js

Volver a [README.md](/README.md)  
<https://nodejs.org/>

## Brief

Node.js es el entorno de ejecución de JavaScript fuera del navegador, con `npm` como gestor de
paquetes. Aquí hace falta para compilar `tree-sitter-cli` y para varias herramientas de
JavaScript/TypeScript que usa la configuración: servidores LSP, herramientas instaladas mediante
Mason y `copilot.lua`.

Esta nota solo cubre cómo instalarlo, en Windows, Linux y macOS.

## Installation

### Windows

Puedes instalar Node.js mediante `winget`:

```powershell
winget install OpenJS.NodeJS
```

Comprueba la instalación con:

```powershell
node --version
npm --version
```

### Linux

#### Arch Linux

```sh
sudo pacman -S --needed nodejs npm
```

Comprueba la instalación con:

```sh
node --version
npm --version
```

#### Fedora

```sh
sudo dnf install nodejs npm
```

Comprueba la instalación con:

```sh
node --version
npm --version
```

#### Debian

```sh
sudo apt install nodejs npm
```

Comprueba la instalación con:

```sh
node --version
npm --version
```

> [!NOTE]
>
> Si la versión de Node.js proporcionada por tu distribución es demasiado antigua para alguna de
> las herramientas utilizadas por la configuración, puede ser preferible utilizar un gestor de
> versiones de Node.js como `nvm` en lugar del paquete de la distribución.

### macOS

Puedes instalar Node.js mediante [Homebrew](https://brew.sh/):

```sh
brew install node
```

Comprueba la instalación con:

```sh
node --version
npm --version
```

> [!warning]
>
> Reinicia la terminal al terminar incluso si node y npm funcionan.
