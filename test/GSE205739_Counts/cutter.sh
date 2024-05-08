#!/bin/bash

# Cut a file to its first 100 lines (and overwrite the original file)
cut_to_100_lines() {
    local file="$1"
    head -n 100 "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    echo "Cut $file to its first 100 lines"
}

# Find all files in the current directory and its subdirectories
# and call the cut_to_100_lines function on each file
find . -type f | while read -r file; do
    cut_to_100_lines "$file"
done
