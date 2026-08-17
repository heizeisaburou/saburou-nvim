# Python

Volver a [README](/README.md)  
<https://www.python.org/>

## Brief

Python es el lenguaje de programación de propósito general. Aquí hace falta para ejecutar
herramientas y servidores LSP que están escritos en Python y que se instalan mediante Mason.

Esta nota solo cubre cómo instalarlo, en Windows y Linux.

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
