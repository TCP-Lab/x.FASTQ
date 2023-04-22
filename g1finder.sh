#!/bin/bash

# ======================================
#  Seek and Destroy Google Drive's (1)s 
# ======================================
#
# 1. Run OneFinder in `seek` mode on the target directory
# 2. Manually edit the filename list keeping just the files you want to clean from (1)s
# 3. Run OneFinder in `destroy` mode sourcing the edited list
#

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
	echo "          "$0" -d /mnt/e/UniTo\ Drive/ ./OnesList.txt"
	echo
}

# Name of the filename-containing file
meta_name="OnesList.txt"

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
	find "$target" -type d | grep -E ".+$trp$" > "$fnames"/"$meta_name"

	# Find regular files that end with the TRP, plus a possible filename extension
	find "$target" -type f | grep -E ".+$trp(\.[a-zA-Z0-9]+)?$" >> "$fnames"/"$meta_name"

	echo -e "\nNumber of hits: $(wc -l "$fnames"/"$meta_name")"

elif [[ "$1" == "-d" || "$1" == "--destroy" ]]; then

	# Save a temporary reverse-sorted filename list (see below the reason why)
	sort -r "$fnames" > "$(dirname "$fnames")/temp.out"

	while IFS= read -r line
	do
		# Remove TRP from filenames using Bash native string substitution:
		# ${string/$substring/$replacement}
		# NOTE: while `$substring` and `$replacement` are literal strings
		# 		the starting `string` must be a reference to a variable name!
		# Split each filename between dirname and basename to match and
		# substitute the TRP from the end of the strings.
		# This, in combination with the reverse-sorting, ensures that mv is
		# always possible, even for nested TRPs, since it starts pruning from
		# the leaves of the filesystem.
		
		base_line="$(basename "$line")"

		# Toggle verbose debugging
		if true; then
			echo
			echo "From: "$line""
			echo "To  : "$(dirname "$line")"/"${base_line/$trp/}""
		fi

		mv "$line" "$(dirname "$line")"/"${base_line/$trp/}"

	done < "$(dirname "$fnames")/temp.out"

	# Remove the temporary file
	rm "$(dirname "$fnames")/temp.out"
else

	printf "Invalid flag $1"
	exit 2 # Failure exit status
fi
