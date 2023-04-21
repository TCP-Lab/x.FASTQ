#!/bin/bash

# ======================================
#  Seek and Destroy Google Drive's (1)s 
# ======================================

function _help_g1 {
	echo
	echo "Seek and destroy the annoying '(1)s' put in filenames by Google Drive"
	echo
	echo "Usage: $0 [-h | --help] [-s | --seek] [-d | --destroy] TARGET FNAMES"
	echo
	echo "Positional options:"
	echo "    -h | --help     show this help"
	echo "    -s | --seek     search mode"
	echo "    -d | --destroy  cleaning mode"
	echo "    TARGET          the Google Drive folder to be scanned or fixed"
	echo "    FNAMES          the output directory for filename report (s-mode)"
	echo "                    or the input list of filenames to clean (d-mode)"
	echo
	echo "Examples: "$0" -s /mnt/e/UniTo\ Drive/ ~"
	echo "          "$0" -d /mnt/e/UniTo\ Drive/ ./gd1list.txt"
	echo
}

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-z]+$"

# Argument check
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
	_help_g1
	exit 0 # Success exit status
elif [[ $# -ge 3 && "$1" =~ $frp ]]; then
	target="$2"
	fnames="$3"
else
	printf "Wrong syntax. Use '--help' or '-h' option to see mandatory parameters"
	exit 1 # Failure exit status
fi

# The 'Target Regex Pattern' (TRP) is a white-space followed by a one-digit
# number (1 to 3) within round brackets
trp=" \([1-3]\)"

if [[ "$1" == "-s" || "$1" == "--seek" ]]; then

	# Find folders and sub-folders that end with the TRP
	find "$target" -type d | grep -E ".+$trp$" > "$fnames"/gd1list.txt

	# Find regular files that end with the TRP, plus a possible filename extension
	find "$target" -type f | grep -E ".+$trp(\.[a-zA-Z0-9]+)?$" >> "$fnames"/gd1list.txt

	echo -e "\nNumber of hits: $(wc -l "$fnames"/gd1list.txt)"

elif [[ "$1" == "-d" || "$1" == "--destroy" ]]; then

	printf "Still to be implemented..."
	# https://www.cyberciti.biz/faq/unix-howto-read-line-by-line-from-file/
	# https://stackoverflow.com/questions/13210880/replace-one-substring-for-another-string-in-shell-script
	
	while IFS= read -r line
	do
	  echo ${line/ ([1-3])/""}
	  #mv "$line" "${line/ ([1-3])/""}"
	done < "$fnames"/gd1list.txt

	#cat gd1list.txt | sed -r "s/$trp//g"

else

	printf "Invalid flag $1"
fi