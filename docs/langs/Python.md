# Python

Volver a [README.md](/README.md)  
<https://www.python.org/>

## Brief

Python es un lenguaje de programación de scripting y de propósito general.

Además de ser necesario instalarlo para programar en Python es una dependencia de muchos paquetes
que se instalan a traves de Mason.

## Installation

### Windows

Puedes instalar Python mediante `winget`:

```powershell
winget install Python.Python.3.14
```

Comprueba la instalación con:

```powershell
python --version
pip --version
```

> [!NOTE]
>
> Durante la instalación, `winget` se encarga de instalar Python y registrarlo para poder
> utilizarlo desde la terminal.

### Linux

Instala el paquete `python` mediante el gestor de paquetes de tu distribución.

Por ejemplo, en Arch Linux:

```sh
sudo pacman -S --needed python
```

Comprueba la instalación con:

```sh
python --version
```

## Activation

Para programar en Python primero asegurate de que esté instalado a nivel de sistema. Lo
siguiente:

- [lua/lzy/conform.lua](/lua/lzy/conform.lua) ― descomenta `python = { "ruff_format" }`
- [lua/lzy/treesitter.lua](/lua/lzy/treesitter.lua) ― descomenta `python`
- [lua/lzy/lspconfig.lua](/lua/lzy/lspconfig.lua) ― descomenta `python` y `ruff`.

### macOS

Puedes instalar Python mediante Homebrew:

```sh
brew install python
```

Comprueba la instalación con:

```sh
python3 --version
pip3 --version
```

> [!NOTE]
>
> En macOS, Homebrew instala Python con los comandos `python3` y `pip3`. No es necesario instalar
> Python mediante Xcode Command Line Tools.
