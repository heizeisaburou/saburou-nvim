# Guía rápida

> [!NOTE]
>
> **Versión actual: `v0.1.0-alpha.1` — requiere Neovim 0.12+.**

Esta guía recoge las decisiones básicas de uso de esta configuración. Está incompleta y puede cambiar con el tiempo.

El objetivo es que sirva tanto a usuarios nuevos como a usuarios con experiencia en Neovim. Si algo no queda claro,
falta información o crees que se puede explicar mejor, cualquier sugerencia es bienvenida.

> [!TIP]
>
> El feedback es lo más importante para mejorar tanto la configuración como la documentación. Puedes enviar sugerencias,
> comentarios o preguntas a través de [mi perfil de GitHub](https://github.com/heizeisaburou) o abrir un issue en el
> repositorio de esta configuración.

## Índice

- [Requisitos](#requisitos)
- [Resumen rápido](#resumen-rápido)
- [Instalación aislada de Neovim](#instalación-aislada-de-neovim)
  - [Linux](#linux)
  - [macOS](#macos)
  - [Windows](#windows)
  - [Usar varias configuraciones con `NVIM_APPNAME`](#usar-varias-configuraciones-con-nvim_appname)
  - [Alias recomendados](#alias-recomendados)
- [Nuevos usuarios](#nuevos-usuarios)
- [Instalación de plugins y herramientas](#instalación-de-plugins-y-herramientas)
- [Tema](#tema)
- [IA](#ia)
- [Markdown](#markdown)
- [Undo / Redo](#undo--redo)
- [Clipboard](#clipboard)
- [Licencia](#licencia)

## Requisitos

- **Neovim 0.12 o superior.** La configuración usa APIs y comportamientos disponibles a partir de Neovim 0.12 y no se
  garantiza compatibilidad con versiones anteriores. Comprueba tu versión con `nvim --version`.
- `git`, `curl` y un compilador de C (`gcc`/`clang`) en el `PATH` para que `lazy.nvim`, `mason.nvim` y `nvim-treesitter`
  puedan instalar lo que necesitan.
- Una _Nerd Font_ configurada en la terminal para los iconos.

## Resumen rápido

Si solo quieres lo esencial:

1. Asegúrate de tener Neovim 0.12+ instalado con un binario fijo (por ejemplo `nvim12`, ver
   [Instalación aislada](#instalación-aislada-de-neovim)).
2. Clona el repositorio en `~/.config/nvim12`:

   ```bash
   git clone https://github.com/heizeisaburou/saburou-nvim ~/.config/nvim12
   ```

3. Lanza Neovim con la configuración aislada:

   ```bash
   NVIM_APPNAME=nvim12 nvim12
   ```

4. Cuando termine la instalación automática de plugins, dentro de Neovim ejecuta:

   ```vim
   :Lazy sync
   :MasonInstallAll
   :TSInstallAll
   ```

El resto de la guía explica cada paso con detalle.

## Instalación aislada de Neovim

Esta configuración está pensada para usarse con una versión concreta de Neovim. Es recomendable instalar el binario con
un nombre fijo, por ejemplo:

```bash
/usr/local/bin/nvim12
```

Esto evita que una actualización del sistema cambie la versión de Neovim sin avisar y rompa la configuración, algún
plugin o algún comportamiento interno.

La idea es sencilla:

- `nvim` puede seguir siendo el Neovim normal del sistema.
- `nvim12` apunta a la versión concreta que quieres usar con esta configuración.
- `NVIM_APPNAME=nvim12` hace que Neovim use una configuración separada.

### Linux

En Linux puedes descargar o compilar la versión de Neovim que quieras y colocar el binario en `/usr/local/bin`.

Por ejemplo:

```bash
sudo cp nvim /usr/local/bin/nvim12
sudo chmod +x /usr/local/bin/nvim12
```

Después comprueba que funciona:

```bash
nvim12 --version
```

Si usas un AppImage, también puedes guardarlo con nombre fijo:

```bash
sudo cp nvim.appimage /usr/local/bin/nvim12
sudo chmod +x /usr/local/bin/nvim12
```

### macOS

En macOS puedes hacer lo mismo usando un nombre fijo para el binario.

Por ejemplo, si tienes un binario de Neovim concreto:

```bash
sudo cp nvim /usr/local/bin/nvim12
sudo chmod +x /usr/local/bin/nvim12
```

En Apple Silicon, si prefieres usar `/opt/homebrew/bin`, también puedes dejarlo ahí:

```bash
cp nvim /opt/homebrew/bin/nvim12
chmod +x /opt/homebrew/bin/nvim12
```

Comprueba la versión:

```bash
nvim12 --version
```

### Windows

En Windows puedes guardar una versión concreta de Neovim en una carpeta fija, por ejemplo:

```text
C:\Tools\nvim12\
```

Dentro debería estar el ejecutable:

```text
C:\Tools\nvim12\bin\nvim.exe
```

Después puedes añadir esta carpeta al `PATH`:

```text
C:\Tools\nvim12\bin
```

Si quieres tener un comando separado llamado `nvim12`, puedes crear un archivo `nvim12.cmd` en una carpeta que esté en
el `PATH`:

```cmd
@echo off
C:\Tools\nvim12\bin\nvim.exe %*
```

Así podrás abrir esa versión concreta con:

```cmd
nvim12
```

### Usar varias configuraciones con `NVIM_APPNAME`

Neovim permite usar varias configuraciones distintas mediante la variable de entorno `NVIM_APPNAME`.

Por defecto, Neovim usa:

```text
~/.config/nvim
```

Pero si ejecutas:

```bash
NVIM_APPNAME=nvim12 nvim12
```

Neovim usará:

```text
~/.config/nvim12
```

Esto permite tener varias configuraciones separadas sin que se mezclen plugins, cachés o archivos de estado.

Por ejemplo:

```bash
NVIM_APPNAME=nvim12 nvim12
```

usará una configuración en:

```text
~/.config/nvim12
```

Y otra configuración distinta podría usar:

```bash
NVIM_APPNAME=nvim-test nvim
```

con archivos en:

```text
~/.config/nvim-test
```

Esto es especialmente útil para probar configuraciones nuevas sin romper tu Neovim principal.

### Alias recomendados

Para no tener que escribir siempre `NVIM_APPNAME=...`, puedes crear un alias.

#### Bash

Edita tu archivo:

```bash
~/.bashrc
```

Y añade:

```bash
alias nvim12='NVIM_APPNAME=nvim12 /usr/local/bin/nvim12'
```

Después recarga la shell:

```bash
source ~/.bashrc
```

Ahora puedes abrir la configuración con:

```bash
nvim12
```

#### Zsh

Edita tu archivo:

```bash
~/.zshrc
```

Y añade:

```bash
alias nvim12='NVIM_APPNAME=nvim12 /usr/local/bin/nvim12'
```

Después recarga la shell:

```bash
source ~/.zshrc
```

Ahora puedes usar:

```bash
nvim12
```

#### Alias usando el Neovim normal del sistema

Si no quieres fijar un binario concreto y solo quieres separar la configuración, puedes hacer:

```bash
alias nvim12='NVIM_APPNAME=nvim12 nvim'
```

Esto usa el `nvim` que tengas instalado normalmente, pero carga la configuración desde:

```text
~/.config/nvim12
```

#### Alias usando binario fijo y configuración fija

La opción más segura es combinar ambas cosas:

```bash
alias nvim12='NVIM_APPNAME=nvim12 /usr/local/bin/nvim12'
```

Así controlas tanto:

- la versión exacta de Neovim;
- la configuración exacta que se va a cargar.

Esta es la opción recomendada para evitar que una actualización del sistema o una configuración distinta rompa el
entorno.

## Nuevos usuarios

Si eres nuevo en Neovim, esta configuración puede resultar un poco abrumadora al principio. Es normal.

Te recomendamos ir poco a poco: explora las secciones de la configuración, revisa la documentación de los plugins
incluidos y prueba las funcionalidades según las vayas necesitando. No hace falta entenderlo todo desde el primer día.

## Instalación de plugins y herramientas

> [!WARNING]
>
> En esta versión inicial se integran muchos plugins y herramientas externas para ofrecer una experiencia completa desde
> el principio. Esto puede hacer que la instalación inicial tarde un poco más, pero permite tener casi todo listo desde
> el primer día.

La primera vez que abras Neovim, `lazy.nvim` instalará automáticamente todos los plugins configurados.

Si necesitas forzar la instalación o sincronizar de nuevo los plugins, puedes ejecutar:

```vim
:Lazy sync
```

Cuando los plugins ya estén instalados, instala las herramientas externas configuradas para LSP, formatters y linters
con:

```vim
:MasonInstallAll
```

Por último, instala los parsers de Treesitter configurados con:

```vim
:TSInstallAll
```

En resumen, después de abrir Neovim por primera vez, puedes ejecutar:

```vim
:Lazy sync
:MasonInstallAll
:TSInstallAll
```

## Tema

El tema principal elegido es Moonfly, con varias personalizaciones encima.

Además, la configuración incluye una alternancia entre versión con fondo y sin fondo. Por ahora este es el único tema
mantenido oficialmente.

Para ofrecer múltiples temas de forma limpia, lo ideal sería implementar un sistema de temas y permitir que la comunidad
contribuya con variantes. Hasta entonces, esta configuración se centrará en mantener bien pulido el tema actual.

## IA

La configuración integra herramientas como _Claude_, _Codex_ y _Copilot_ para ofrecer una experiencia de IA más
completa.

Con el tiempo se podrán añadir más herramientas y funcionalidades, pero algunas de ellas tienen coste o requieren
configuración externa. Por eso, la integración irá creciendo poco a poco.

Las contribuciones en esta parte también son bienvenidas.

## Markdown

Se incluye un renderizador de Markdown que se activa automáticamente.

Puedes alternar el renderizado con:

```vim
<leader>mr
```

## Undo / Redo

Deshacer se mantiene como en Vim normal:

```vim
u
```

Rehacer sigue disponible con:

```vim
<C-r>
```

Además, también se ha añadido:

```vim
U
```

## Clipboard

La configuración evita, por ahora, redefinir operadores básicos como `d`, `c`, `x` o `s` para proteger el comportamiento
normal del clipboard y de los registros de Vim.

Es preferible usar los registros de Vim de forma explícita cuando quieras controlar exactamente qué se copia, qué se
borra y qué va al clipboard del sistema.

> [!TIP]
>
> Si quieres sincronizar siempre el clipboard de Neovim con el clipboard del sistema, puedes descomentar esto en
> `../lua/user/cfg.lua`:
>
> ```lua
> -- sabunv.util.clipboard.sync(true)
> ```
>
> O configurarlo directamente en `../lua/user/opts.lua`:
>
> ```lua
> vim.o.clipboard = "unnamedplus"
> ```

### Registros útiles

- `"_` descarta texto y no toca registros útiles.
- `"` es el registro principal de Neovim.
- `"0` contiene el último yank real.
- `"+` usa el clipboard del sistema.
- `"a` a `"z` son registros con nombre para guardar texto manualmente.

### Borrar sin actualizar el clipboard

```vim
"_dd
```

### Recuperar el último yank real

```vim
"0p
```

Desde insert mode:

```vim
<C-r>0
```

### Pegar desde el clipboard del sistema

```vim
"+p
```

### Copiar un registro al clipboard del sistema

Registro principal:

```vim
let @+ = @"
```

Último yank real:

```vim
let @+ = @0
```

Registro con nombre:

```vim
let @+ = @a
```

### Guardar texto en un registro con nombre

Guarda una selección en el registro `a`:

```vim
"ay
```

Recupérala después:

```vim
"ap
```

## Licencia

Este repositorio contiene código bajo varias licencias:

- La mayor parte del código original se publica bajo los términos de la [Apache License 2.0](../LICENSE)
  ([texto oficial](https://www.apache.org/licenses/LICENSE-2.0)).
- El directorio [`lua/hzsr/mason/nvchad/`](../lua/hzsr/mason/nvchad/) contiene código derivado de NvChad/ui y está
  licenciado bajo [GPL-3.0-only](../lua/hzsr/mason/nvchad/LICENSE). Consulta también
  [`lua/hzsr/mason/nvchad/NOTICE.md`](../lua/hzsr/mason/nvchad/NOTICE.md) para más detalles.
