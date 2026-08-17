# Nerd Font

Volver a [README.md](/README.md)  
<https://www.nerdfonts.com/>

## Brief

Las _Nerd Fonts_ son fuentes de programación corrientes a las que se les han añadido miles de
iconos (Font Awesome, Devicons, Octicons, Material Design, etc.). Mi configuración usa esos
iconos por todas partes: explorador de archivos, statusline, diagnósticos, autocompletado, etc.
Sin una Nerd Font verás cuadrados, interrogantes o huecos en blanco en su lugar.

Quien dibuja el texto es **la terminal**, no Neovim, así que no basta con instalar la fuente: después
hay que seleccionarla en la terminal (o en tu GUI de Neovim si usas una).

Esta nota cubre cómo instalarlas, en Windows, Linux y macOS. Los ejemplos usan
`JetBrainsMono Nerd Font` porque es la que uso yo, pero vale cualquiera del [catálogo](https://www.nerdfonts.com/font-downloads); solo tienes
que cambiar el nombre de la fuente o del paquete.

## Elegir la variante

Cada fuente del catálogo se publica en varias variantes y el nombre importa:

| Variante                        | Qué hace con los iconos                                 |
| ------------------------------- | ------------------------------------------------------- |
| `JetBrainsMono Nerd Font`       | Los dibuja con su ancho natural — **es la recomendada** |
| `JetBrainsMono Nerd Font Mono`  | Los encoge todos al ancho de una celda, se ven pequeños |
| `JetBrainsMono Nerd Font Propo` | Ajusta el ancho de los iconos al espaciado proporcional |

Elige la que **no** termine en `Mono` para que los iconos no se vean todos del mismo tamaño.

Los instaladores y los paquetes suelen traer las tres variantes a la vez, así que la elección
normalmente se hace al configurar la terminal, no al instalar.

## Installation

### Windows

#### Using winget

```powershell
winget install DEVCOM.JetBrainsMonoNerdFont
```

#### Instalación manual

1. Descarga el `.zip` de la fuente en <https://www.nerdfonts.com/font-downloads>.
2. Extrae el `.zip`.
3. Selecciona los `.ttf`, botón derecho → **Instalar** (o **Instalar para todos los usuarios**, que
   requiere permisos de administrador).

En ambos casos, cierra y vuelve a abrir la terminal para que reconozca la fuente nueva.

### Linux

#### Arch Linux

```sh
sudo pacman -S --needed ttf-jetbrains-mono-nerd
```

Todas las Nerd Fonts están empaquetadas en el grupo `nerd-fonts`, así que puedes ver el catálogo
entero con:

```sh
pacman -Sg nerd-fonts
```

#### Debian

> [!WARNING]
>
> Existe el paquete `fonts-jetbrains-mono`, pero es la fuente **original sin parchear**: no trae los
> iconos y no sirve para esta configuración. Debian no empaqueta las Nerd Fonts.

Instálala a mano siguiendo [Instalación manual en Linux](#instalación-manual-en-linux).

#### Fedora

Fedora tampoco empaqueta las Nerd Fonts en sus repositorios oficiales; la excepción es
`cascadia-mono-nf-fonts`, que sí es una fuente con los símbolos de Nerd Fonts:

```sh
sudo dnf install cascadia-mono-nf-fonts
```

Para cualquier otra fuente, incluida JetBrains Mono, instálala a mano siguiendo
[Instalación manual en Linux](#instalación-manual-en-linux). Hay repositorios COPR de terceros que las empaquetan, pero no son
oficiales, suelen ir por detrás en versión y no los mantengo probados.

#### Instalación manual en Linux

Es la vía que funciona en cualquier distribución. Las fuentes se instalan copiando los `.ttf` a un
directorio de fuentes y regenerando la caché:

- `~/.local/share/fonts` — solo para tu usuario, no necesita `root`. **Es la opción recomendada.**
- `/usr/local/share/fonts` — para todos los usuarios del sistema, necesita `sudo`.

```sh
mkdir -p ~/.local/share/fonts/JetBrainsMonoNerdFont
cd ~/.local/share/fonts/JetBrainsMonoNerdFont
curl -LO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip JetBrainsMono.zip
rm JetBrainsMono.zip
fc-cache -fv
```

Para instalarla a nivel de sistema es exactamente lo mismo cambiando el directorio:

```sh
sudo mkdir -p /usr/local/share/fonts/JetBrainsMonoNerdFont
# copia ahí los .ttf y después:
sudo fc-cache -fv
```

Comprueba que el sistema la ve con:

```sh
fc-list | grep -i "jetbrainsmono nerd"
```

Si el comando no devuelve nada, la fuente no está instalada donde el sistema la busca, o falta
ejecutar `fc-cache -fv`.

### macOS

> [!note]
>
> No dispongo de un equipo macOS: revisa [macOS support](/docs/macOS%20support.md).

Puedes instalarla mediante Homebrew:

```sh
brew install --cask font-jetbrains-mono-nerd-font
```

También puedes instalarla a mano copiando los `.ttf` a `~/Library/Fonts` (solo tu usuario) o
`/Library/Fonts` (todos los usuarios), o abriéndolos con **Font Book**.

Comprueba la instalación con:

```sh
fc-list | grep -i "jetbrainsmono nerd"
```

## Configurar la terminal

Instalar la fuente no la activa; hay que seleccionarla en la terminal usando el nombre de la
variante (recuerda: la que **no** termina en `Mono`).

**Kitty** (`~/.config/kitty/kitty.conf`):

```conf
font_family JetBrainsMono Nerd Font
font_size 11
```

**WezTerm** (`~/.wezterm.lua`):

```lua
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 11
```

**Alacritty** (`~/.config/alacritty/alacritty.toml`):

```toml
[font]
size = 11

[font.normal]
family = "JetBrainsMono Nerd Font"
```

**Terminal de Windows**: _Configuración_ → tu perfil → _Aspecto_ → _Tipo de fuente_ →
`JetBrainsMono Nerd Font`.

Después reinicia la terminal y abre Neovim: si los iconos se ven, ya está.
