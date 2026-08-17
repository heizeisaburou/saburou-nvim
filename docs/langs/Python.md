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

- [conform.lua](/lua/lzy/conform.lua) ― descomenta `python = { "ruff_format" }`
- [treesitter.lua](/lua/lzy/treesitter.lua) ― descomenta `python`
- [lspconfig.lua](/lua/lzy/lspconfig.lua) ― descomenta `python` y `ruff`.
