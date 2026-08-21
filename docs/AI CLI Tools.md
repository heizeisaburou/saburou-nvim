# AI CLI Tools

Volver a [README.md](/README.md)

## Brief

Herramientas de línea de comandos para trabajar con distintos asistentes de inteligencia
artificial:

- `opencode`
- `claude`
- `codex`

Esta nota cubre cómo instalar las tres (en Windows y Linux, todas vía `npm`) y las teclas para
togglear cada una —además de Copilot, que no es una CLI pero se integra junto a ellas— dentro de
Neovim.

## Installation

> [!note] Dependencias
>
> [Node.js](/docs/Node.js.md)

### Linux / macOS

En Linux, las tres herramientas se instalan mediante `npm`:

```sh
sudo npm install -g opencode-ai
sudo npm install -g @anthropic-ai/claude-code
sudo npm install -g @openai/codex
```

Comprueba la instalación con:

```sh
opencode --version
claude --version
codex --version
```

### Windows

En Windows también pueden instalarse mediante `npm`:

```powershell
Set-ExecutionPolicy Unrestricted -Scope Process
npm install -g opencode-ai
npm install -g @anthropic-ai/claude-code
npm install -g @openai/codex
```

Comprueba la instalación con:

```powershell
opencode --version
claude --version
codex --version
```

## Keybindings

Cada herramienta se togglea (abre/cierra) con una combinación con `Alt`, definida a mano en
`lua/lzy/`:

| Tecla             | Qué hace                               | Modos   | Archivo                |
| ----------------- | -------------------------------------- | ------- | ---------------------- |
| `<A-[>`           | Claude Code: toggle                    | n, i, t | `lua/lzy/claude.lua`   |
| `<A-]>`           | Codex: toggle                          | n, i, t | `lua/lzy/codex.lua`    |
| `<A-o>`           | Opencode: toggle                       | n, i    | `lua/lzy/opencode.lua` |
| `<A-p>`           | Copilot: toggle                        | n       | `lua/lzy/copilot.lua`  |
| `<A-n>` / `<A-N>` | Copilot: sugerencia siguiente/anterior | i       | `lua/lzy/copilot.lua`  |

Copilot también se togglea con `<leader>gt`; `<A-p>` es sólo un atajo más rápido.

Probadas en **kitty** (config por defecto) y **PowerShell** (Windows): ninguna de las cinco combinaciones
está tomada por el terminal ahí, así que llegan intactas a Neovim.

### Si alguna no abre

Seguramente tu terminal tiene esa tecla ocupada para otra cosa. Cámbiala en la config de tu
terminal, o directamente en el archivo indicado en la tabla (busca ahí la tecla y sustitúyela por
otra libre).

## Troubleshooting

### Command not found after installing a package

Si después de instalar una CLI con `npm` aparece:

```text
zsh: command not found: opencode
```

comprueba que el directorio de ejecutables globales de npm esté en el `PATH`:

```sh
npm config get prefix
echo $PATH
```

Si usas Node.js instalado mediante Homebrew, puedes añadirlo a `zsh` con:

```sh
echo 'export PATH="$(npm config get prefix)/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Después comprueba:

```sh
opencode --version
claude --version
codex --version
```

Si `npm install -g` muestra `added ... packages`, la instalación se ha realizado correctamente; un
`command not found` posterior normalmente indica un problema con el `PATH`.

Si una combinación de teclas no funciona dentro de Neovim, comprueba que tu terminal no esté
capturándola y, si es necesario, cámbiala en la configuración del terminal o en el archivo
indicado en **Keybindings**.
