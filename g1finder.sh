#!/bin/bash

# ======================================
#  Seek and Destroy Google Drive's (1)s 
# ======================================

# Flag regex pattern (FRP)
frp="^-{1,2}[a-z]+$"

if [[ "$1" == "-h" || "$1" == "--help" ]]; then

	# Make this a function...
	printf "\nSeek and destroy annoying Google Drive's (1)s in filenames\n"
	printf "\n"
	printf "Usage: "$0" -s TARGET_DIR OUT_DIR\n"
	printf "       "$0" -d TARGET_DIR IN_FILE\n"
	printf "\n"
	printf "Positional options:\n"
	printf "\t-s (--seek)\tsearch mode\n"
	printf "\t-d (--destroy)\tcleaning mode\n"
	printf "\tTARGET_DIR\tthe Google Drive folder to be scanned or fixed\n"
	printf "\tOUT_DIR\t\toutput directory for search mode report\n"
	printf "\tIN_FILE\t\tpath of the input list of filenames to clean\n"
	printf "\n"
	printf "Examples: "$0" -s /mnt/e/UniTo\ Drive/ ~\n"
	printf "          "$0" -d /mnt/e/UniTo\ Drive/ ./gd1list.txt\n"
	printf "\n"

	exit 0 # Success exit status

elif [[ $# -ge 3 && "$1" =~ $frp ]]; then

	target="$2"
	report="$3"
else

	printf "Wrong syntax. Use --help (-h) option to see mandatory parameters"
	exit 1 # Failure exit status
fi

# The 'base regex pattern' (BRP) is a white-space followed by a one-digit number
# within round brackets
brp=" \([1-3]\)"

if [[ "$1" == "-s" || "$1" == "--seek" ]]; then

	# Find folders and sub-folders that end with the BRP
	find "$target" -type d | grep -E ".+$brp$" > "$report"/gd1list.txt

	# Find regular files that end with the BRP, plus a possible filename extension
	find "$target" -type f | grep -E ".+$brp(\.[a-zA-Z0-9]+)?$" >> "$report"/gd1list.txt

	echo "Number of hits: $(wc -l "$report"/gd1list.txt)"

elif [[ "$1" == "-d" || "$1" == "--destroy" ]]; then

	printf "Still to be implemented..."	
else

	printf "Invalid flag $1"
fi