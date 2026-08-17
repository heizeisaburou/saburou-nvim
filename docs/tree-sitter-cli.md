# tree-sitter-cli

Volver a [README](/README.md)  
<https://github.com/tree-sitter/tree-sitter/blob/master/crates/cli/README.md>

## Brief

`tree-sitter-cli` es la herramienta de línea de comandos del proyecto Tree-sitter: genera, a partir
de la gramática de un lenguaje, el código C de su parser. `nvim-treesitter` la necesita para
compilar los parsers que usa la configuración.

Esta nota cubre las dos formas de instalarlo: como binario precompilado con `cargo-binstall`, o
compilándolo con Cargo (lo que además exige tener Node.js instalado).

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
