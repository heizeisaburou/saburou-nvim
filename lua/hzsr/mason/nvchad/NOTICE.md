# NvChad-derived Mason adapter

This `nvchad` directory contains code derived from NvChad/ui.

Source files:

- https://github.com/NvChad/ui/blob/v3.0/lua/nvchad/mason/init.lua
- https://github.com/NvChad/ui/blob/v3.0/lua/nvchad/mason/names.lua

License: GPL-3.0-only

Please read the accompanying `LICENSE` file and the SPDX headers in each source file.

NvChad copyright, license, and source notices must be preserved.

Within this `nvchad` directory only, attribution to Saburou is not required for reuse of my modifications.

# Modifications

## Pre-release

- Moved into a local `nvchad` adapter directory.
- Adapted require paths from `nvchad.mason.*` to the local adapter namespace.
- Used through a wrapper from the parent Mason module.
- Added `elixirls`, `expert`, `qmlls`
