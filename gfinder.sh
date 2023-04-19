#!/bin/bash

# ====================
#  Google (1) finder
# ====================

# The 'base regex pattern' (BRP) is a white-space followed by a one-digit number
# within round brackets
brp=" \([1-3]\)"

# The Google Drive folder to be scanned
inpath="/mnt/e/UniTo Drive/"
outpath="$HOME"

# Find folders and sub-folders that end with the BRP
find "$inpath" -type d | grep -E ".+$brp$" > "$outpath"/g1found.txt

# Find regular files that end with the BRP, plus a possible filename extension
find "$inpath" -type f | grep -E ".+$brp(\.[a-zA-Z0-9]+)?$" >> "$outpath"/g1found.txt

echo "Number of hits: $(wc -l "$outpath"/g1found.txt)"
