# Neovim

Volver a [README](/README.md)  
<https://neovim.io/>

## Brief

Neovim es un editor de texto modal, continuación de Vim con foco en extensibilidad: configuración
y plugins en Lua, LSP y Tree-sitter integrados.

Esta nota cubre cómo instalar la versión exacta que necesita `saburou-nvim` (**0.12+**, sin garantía de
compatibilidad con versiones anteriores ni futuras) sin que una actualización del sistema te la
cambie sin avisar: descargas oficiales, gestor de paquetes, Snap, Flatpak y binario
autocontenido, en Windows, Linux y macOS.

## Installation

Lo más importante a tener en cuenta a la hora de instalar **Neovim para saburou-nvim** es que la
versión de Neovim debe coincidir con **la versión requerida por la configuración** ―que puedes
comprobar en [README](/README.md#installation)―.

Adicionalmente y por motivos obvios, también podría ser conveniente buscar la manera de no
permitir que _Neovim_ se actualice automáticamente.

Revisa las diferentes subsecciones para aprender a instalar _Neovim_ según tu preferencia.

### Descargas

#### Página oficial

<https://neovim.io/doc/install/>

#### Release requerida

[Release v0.12.4](https://github.com/neovim/neovim/releases/tag/v0.12.4)

### Windows

#### Using winget

Si estás en Windows, una forma sencilla de instalarlo es mediante `winget`, ya que, a diferencia de
los gestores de paquetes de las distribuciones de Linux, este sí permite especificar una versión.

```powershell
winget install Neovim.Neovim --version 0.12.4
```

### Linux

#### Using your package manager

Si tu distribución es _non-rolling_, como p.e. _Ubuntu_, puedes utilizar su gestor de paquetes para
instalar Neovim siempre que la versión disponible coincida con la versión indicada en [README](/README.md#installation).
En este caso, _normalmente_ no tendrás que preocuparte de que Neovim se actualice inesperadamente a
una versión incompatible ―que no sea rolling no necesariamente significa que no actualizan sus
paquetes.

Si tu distribución es _rolling_, como p.e. _Arch Linux_, también puedes instalar Neovim mediante su
gestor de paquetes, pero debes tener en cuenta que la versión se actualizará junto con el resto
del sistema. Puede coincidir con la versión requerida durante un tiempo, pero eventualmente una
actualización puede llevar Neovim a una versión incompatible con esta configuración.

> [!NOTE]
>
> - No suele ser aconsejable congelar paquetes individualmente en el gestor de paquetes del
>   sistema. Aunque Neovim debería ser uno de los paquetes menos problemáticos, los gestores de
>   paquetes tratan de mantener todos sus paquetes y dependencias en sintonía. Congelarlo puede
>   provocar conflictos si otro paquete depende de una versión más reciente.
> - Si tu distribución es _rolling_, está bien instalar Neovim mediante el gestor de paquetes
>   siempre y cuando aceptes que eventualmente se actualizará a una versión que podría no ser
>   compatible. Si necesitas garantizar que la configuración permanezca en una versión concreta,
>   utiliza un método de instalación que permita fijarla independientemente del resto del
>   sistema.
> - Aunque no sea recomendable, también es válido congelar `neovim` en tu gestor de paquetes
>   siempre. Si eventualmente esto rompe algo siempre puedes descongelar el paquete y buscar otro
>   método de instalación.

##### Arch Linux

```sh
sudo pacman -S --needed neovim
```

##### Fedora

```sh
sudo dnf install neovim
```

##### Debian

```sh
sudo apt install neovim
```

#### Using Snap

Snap es una opción válida para instalar Neovim si queremos mantener una versión concreta, **siempre
que la revisión correspondiente a esa versión esté disponible en el Snap Store**.

Podemos consultar las versiones y revisiones disponibles con:

```sh
snap info nvim
```

Si la versión requerida está disponible, podemos instalarla explícitamente mediante su revisión:

```sh
sudo snap install nvim --classic --revision=<revision>
```

Después podemos evitar que Snap actualice automáticamente Neovim:

```sh
sudo snap refresh --hold nvim
```

De esta forma Neovim permanecerá en la revisión instalada aunque aparezcan versiones más
recientes en el canal `stable`.

> [!NOTE]
>
> Si en algún momento queremos volver a permitir las actualizaciones:

```sh
sudo snap refresh --unhold nvim
```

> [!WARNING]
>
> La revisión es específica de Snap y no debe confundirse con la versión de Neovim. Consulta
> siempre `snap info nvim` para identificar qué revisión corresponde a la versión que necesita
> esta configuración.

#### Using Flatpak

Flatpak también es una opción válida si queremos mantener una versión concreta de Neovim, siempre
que el commit correspondiente a esa versión siga disponible en el repositorio.

El paquete de Neovim en Flathub utiliza el identificador `io.neovim.nvim`.

Podemos consultar las versiones y commits disponibles con:

```sh
flatpak remote-info --log flathub io.neovim.nvim
```

Si la versión requerida está disponible, podemos instalar Neovim desde Flathub:

```sh
flatpak install flathub io.neovim.nvim
```

Una vez instalado, podemos seleccionar el commit correspondiente a la versión requerida:

```sh
flatpak update --commit=<commit> io.neovim.nvim
```

Para evitar que Flatpak actualice la aplicación posteriormente:

```sh
flatpak mask io.neovim.nvim
```

De esta forma podemos mantener la versión seleccionada aunque aparezcan versiones más recientes
en Flathub.

Para ejecutar Neovim directamente desde Flatpak:

```sh
flatpak run io.neovim.nvim
```

Esto significa que, a diferencia de una instalación convencional, el comando `nvim` no queda
disponible directamente en la shell. Si queremos poder utilizar simplemente:

```sh
nvim
```

podemos crear un _wrapper_ que invoque la aplicación de Flatpak. Consulta
[Software Wrapper#Programa autocontenido compuesto por varios archivos](/docs/Software%20wrapper.md#programa-autocontenido-compuesto-por-varios-archivos).

> [!WARNING]
>
> La versión concreta debe seguir estando disponible en el repositorio de Flathub. Si el commit
> correspondiente ya no está disponible, no podremos utilizar este método para instalar esa
> versión desde Flathub.

#### Self-contained application

##### Complete self-contained application

- Puedes descargarlo desde [Release requerida](/docs/Neovim.md#release-requerida).
	- Linux: `nvim-linux-x86_64.tar.gz`
	- Linux (ARM): `nvim-linux-arm64.tar.gz`
	- ...
- Para hacerlo funcionar como comando, visita
  [Software Wrapper#Programa autocontenido compuesto por varios archivos](/docs/Software%20wrapper.md#programa-autocontenido-compuesto-por-varios-archivos).

##### AppImage

Puedes descargar _AppImage_ si quieres un ejecutable autocontenido compatible con cualquier Linux.

- Puedes descargarlo desde [Release requerida](/docs/Neovim.md#release-requerida).
	- Linux: `nvim-linux-x86_64.appimage`
	- Linux (ARM): `nvim-linux-arm64.appimage`
	- ...
- Para hacerlo funcionar como comando, visita [Software Wrapper#Programa autocontenido](/docs/Software%20wrapper.md#programa-autocontenido).

### macOS

[macOS support](/docs/macOS%20support.md)
