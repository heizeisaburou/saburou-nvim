#!/usr/bin/env sh
# Sync: origen → destino (defaults: ~/.config/hzsr12 → ~/.config/nvim).
# Uso: ./sync.sh [origen] [destino]
SRC="${1:-$HOME/.config/hzsr12}"
DST="${2:-$HOME/.config/nvim}"
exec nvim --headless -u NONE -c "lua dofile('$HOME/.config/hzsr12/lua/hzsr/sync.lua').deploy('$SRC', '$DST')" -c "qa!"
