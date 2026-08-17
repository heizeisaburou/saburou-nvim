# Python

Volver a [README](/README.md)  
<https://www.python.org/>

## Brief

Necesario para ejecutar herramientas y servidores LSP desarrollados en Python.

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
