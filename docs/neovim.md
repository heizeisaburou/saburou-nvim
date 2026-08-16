# Neovim

[[README]]  
<https://neovim.io/>

## Brief

La configuración usa APIs y comportamientos disponibles a partir de **Neovim 0.12+**. No se
garantiza compatibilidad con versiones anteriores ni futuras.

## Installation

Lo más importante a tener en cuenta a la hora de instalar **Neovim para saburou-nvim** es que la
versión de Neovim debe coincidir con **versión requerida por la configuración** ―que puedes
comprobar en [[README#Installation]]―.

Adicionalmente y por motivos obvios, también podría ser conveniente buscar la manera de no
permitir que _Neovim_ se actualice automáticamente.

Revisa las diferentes subsecciones para aprender a instalar _Neovim_ según tu preferencia.

### Windows

#### Using winget

Si estas en Windows una forma sencilla de instalarlo es mediante `winget`, ya que a diferencia de
los gestores de paquetes de las distribuciones de Linux este si que te permite especificar una
versión.

```powershell
winget install Neovim.Neovim --version 0.12.4
```

#todo probar a instalar sin git a ver si se queja

Necesitarás Git:

### Linux

#### Using your linux distribution package manager

Si tu distribución es _non-rolling_, como p.e. _Ubuntu_, puedes utilizar su gestor de paquetes
para instalar Neovim siempre que la versión disponible coincida con [[README#Installation]]. En
este caso, _normalmente_ no tendrás que preocuparte de que Neovim se actualice inesperadamente a
una versión incompatible.

Si tu distribución es _rolling_, como p.e. _Arch Linux_, también puedes instalar Neovim mediante
su gestor de paquetes, pero debes tener en cuenta que la versión se actualizará junto con el
resto del sistema. Puede coincidir con la versión requerida durante un tiempo, pero eventualmente
una actualización puede llevar Neovim a una versión que todavía no sea compatible con esta
configuración.

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

#### Downloading the AppImage

Puedes descargar _AppImage_ si quieres un ejecutable autocontenido compatible en cualquier Linux:

- [Release v0.12.4](https://github.com/neovim/neovim/releases/tag/v0.12.4)

Visita [Software wrapper](/docs/Software%20wrapper.md)
