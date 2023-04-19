#!/bin/bash

# ====================
#  Google (1) finder
# ====================

for drive in $(ls /mnt/ | grep "[d-z]"); do # grep drive letters after c:
	
	# find folders and sub-folders that end with a one- or two-digit number in round brackets
	find /mnt/"$drive" -type d | grep -E ".+ \([0-9]{1,2}\)$"

	# find regular files that end with a one- or two-digit number in round brackets plus a possible filename extension
	find /mnt/"$drive" -type f | grep -E ".+ \([0-9]{1,2}\)(\.[a-zA-Z0-9]+)?$"
done
