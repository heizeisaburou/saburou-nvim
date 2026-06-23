# Neovim

## TODOs

- Revisar y recuperar los scripts `safe-nvim` y `strict-nvim`; opcionalmente pensar si conviene utilizar parámetros
  aunque yo los mantendría separados y simples.

- Revisar todas las dependencias de instalación y agregarlas a su sección correcta:
  [Python](https://www.python.org/), [Node.js](https://nodejs.org/),
  [Rust](https://www.rust-lang.org/) + [Cargo](https://doc.rust-lang.org/cargo/),
  [Go](https://go.dev/) (+ las que aparezcan por el camino).

## Navegación

- [saburou-nvim](saburou-nvim.md)

## Pre-requisitos

### Pre-requisitos Windows

_(pendiente de documentar)_

### Pre-requisitos Linux

- Neovim 0.12+
- [Nerd Font](https://www.nerdfonts.com/)
  - Utiliza una fuente sin Mono al final para evitar iconos pequeños:
  - Ej: ~~JetBrains Nerd Font Mono~~ > JetBrains Nerd Font

- [Tree-sitter CLI](https://github.com/tree-sitter/tree-sitter/blob/master/crates/cli/README.md)
- [ripgrep](https://github.com/BurntSushi/ripgrep) (para Telescope, etc)

- Eliminar carpetas viejas de nvim (comandos incluidos en [Instalación](#instalación))

Dependiendo de la configuración:
- [Python](https://www.python.org/)
- [Node.js](https://nodejs.org/)
- [Rust](https://www.rust-lang.org/) + [Cargo](https://doc.rust-lang.org/cargo/)
- [Go](https://go.dev/)

## Instalación

### Instalación en Windows

```powershell
winget install Git.Git
winget install Neovim.Neovim
```

_(pendiente de completar)_

### Instalación en Linux

Si quieres instalar una versión concreta de Neovim en Linux considera:
- [Flatpak](#instalación-con-flatpak)
- [Snap](#instalación-con-snap)

Para instalación manual en cualquier sistema, o utilizar un AppImage aquí tienes el enlace a GitHub:
[Neovim stable release](https://github.com/neovim/neovim/releases/tag/stable).

Adicionalmente, la documentación oficial explica como instalarlo manualmente por ejemplo en `/opt`:
https://neovim.io/doc/install/

#### Instalación en Debian

```sh
sudo apt install neovim
```

#### Instalación en Fedora

```sh
sudo dnf install neovim
```

#### Instalación en Arch Linux

```sh
sudo pacman -S neovim
```

#### Instalación con Flatpak

- Tener en cuenta [Snap](#instalación-con-snap) (sinceramente, mucho más cómodo que Flatpak)

Tiene las siguientes ventajas o inconvenientes:
- Para actualizar tienes que utilizar `flatpak update` manualmente.
- Utiliza sus propios paths y comandos diferentes a los paths del sistema; requiere ajustes manuales.

#### Instalación con Snap

- Tener en cuenta [Flatpak](#instalación-con-flatpak)

En general Snap es mucho más sencillo de utilizar que Flatpak ya que tanto el comando como los paths de uso son los
mismos.

```sh
sudo snap install nvim --classic
snap list nvim
```

> [!WARNING]
>
> Vigila que Snap no te cree `/home/root` —ahora o tras instalar Neovim— y si lo ha hecho entonces la solución está en
> la documentación de Snap.

## Tips and tricks

### Safe and Strict Neovim

#### safe-nvim

`safe-nvim` es un lanzador pensado para editar archivos sensibles conservando la configuración habitual de Neovim, pero
evitando algunos mecanismos persistentes que pueden dejar rastro en disco.

Concretamente:
- Carga tu configuración normal.
- `-i NONE` evita leer o escribir archivos ShaDa.
- `-n` desactiva el *swap file*.

```sh
nvim -i NONE -n
```

Para instalarlo con permisos adecuados:

```sh
install -d -m 755 /usr/local/bin

cat > /tmp/safe-nvim <<'EOF'
#!/bin/sh
exec nvim -i NONE -n "$@"
EOF

install -m 755 /tmp/safe-nvim /usr/local/bin/safe-nvim
rm -f /tmp/safe-nvim
```

#### strict-nvim

`strict-nvim` es el lanzador más estricto y predecible. Útil para editar material especialmente sensible cuando no
queremos que Neovim cargue configuración de usuario, plugins ni estado persistente.

Concretamente:
- No carga archivos de configuración.
- No carga plugins.
- No lee ni escribe archivos ShaDa.
- Desactiva el *swap file*.

```sh
nvim -u NONE -i NONE -n
```

- `-u NONE` hace que Neovim no cargue archivos de configuración ni plugins.
- `-i NONE` evita leer o escribir archivos ShaDa.
- `-n` desactiva el *swap file*.

Para instalarlo con permisos adecuados:

```sh
install -d -m 755 /usr/local/bin

cat > /tmp/strict-nvim <<'EOF'
#!/bin/sh
exec nvim -u NONE -i NONE -n "$@"
EOF

install -m 755 /tmp/strict-nvim /usr/local/bin/strict-nvim
rm -f /tmp/strict-nvim
```
