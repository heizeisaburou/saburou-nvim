# tree-sitter-cli

Volver a [README](/README.md)  
<https://github.com/tree-sitter/tree-sitter/blob/master/crates/cli/README.md>

## Brief

Necesario para que `nvim-treesitter` compile los parsers.

## Installation

> [!HINT]
>
> Esta sección es independiente del sistema y de la terminal. Allí donde veas un bloque de código
> `sh` puedes entender también `powershell`.

Si has instalado [cargo-binstall](/docs/Cargo+Rust.md#cargo-binstall), puedes instalar el binario precompilado:

```sh
cargo binstall tree-sitter-cli
```

Si no lo has instalado, puedes compilarlo mediante [Cargo](/docs/Cargo+Rust.md), pero necesitarás instalar primero
[Node.js](/docs/Node.js.md), ya que _Node.js_ es necesario durante la compilación:

```sh
cargo install tree-sitter-cli --locked
```

> [!NOTE]
>
> La opción `--locked` obliga a Cargo a utilizar las versiones de las dependencias especificadas
> en `Cargo.lock`. Si no puede hacerlo, la instalación falla en lugar de resolver versiones
> diferentes.
