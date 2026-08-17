# ripgrep

Volver a [README](/README.md)  
<https://github.com/BurntSushi/ripgrep>

## Brief

`ripgrep` (`rg`) es una herramienta de búsqueda de texto por línea de comandos, más rápida que
`grep` y consciente de `.gitignore` por defecto. Aquí la usan varias herramientas de la
configuración, entre ellas las búsquedas de texto de Telescope.

Esta nota solo cubre cómo instalarlo, en Windows, Linux y macOS.

## Installation

### Windows

Puedes instalarlo mediante `winget`:

```powershell
winget install BurntSushi.ripgrep.MSVC
```

Comprueba la instalación con:

```powershell
rg --version
```

### Linux

#### Arch Linux

```sh
sudo pacman -S --needed ripgrep
```

#### Fedora

```sh
sudo dnf install ripgrep
```

#### Debian

```sh
sudo apt install ripgrep
```

Comprueba la instalación con:

```sh
rg --version
```

### macOS

Puedes instalarlo mediante Homebrew:

```sh
brew install ripgrep
```

Comprueba la instalación con:

```sh
rg --version
```
