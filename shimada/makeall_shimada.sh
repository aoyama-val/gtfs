#!/bin/sh

TILE_DIR="./shimada"

ruby tile_png_pot.rb --debug 256 6 shimada_bus_map.png

find "$TILE_DIR" -regex '.*/[0-9]+_[0-9]+.png$' | xargs optipng
