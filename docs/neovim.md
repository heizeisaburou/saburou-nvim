# Neovim

[[README]]  
<https://neovim.io/>

## Installation

Revisa las diferentes subsecciones para aprender a instalar Neovim para tu sistema. Lo más
importante es que la versión de Neovim que instales coincida con [[README#Installation]] y además
no permitir que se actualice actualice libremente.

### Linux distribution package manager

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

### Windows
