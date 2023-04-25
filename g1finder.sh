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
	echo "Usage: $0 -h | --help"
	echo "       $0 -s | --seek TARGET REPORT"
	echo "       $0 -d | --destroy FNAMES"
	echo
	echo "Positional options:"
	echo "    -h | --help     show this help"
	echo "    -s | --seek     search mode (s-mode)"
	echo "    -d | --destroy  cleaning mode (d-mode)"
	echo "    TARGET          the Google Drive folder to be scanned"
	echo "    REPORT          the output directory for filename report (s-mode)"
	echo "    FNAMES          the input list of filenames to clean (d-mode)"
	echo
	echo "Examples: "$0" -s /mnt/e/UniTo\ Drive/ ~"
	echo "          "$0" -d ./OnesList.txt"
	echo
}

# Name of the filename-containing file
meta_name="OnesList.txt"

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-z]+$"

# Argument check
if [[ "$1" =~ $frp ]]; then
    case "$1" in
        -h | --help)
		_help_g1
		exit 0 # Success exit status
        ;;
        -s | --seek)
		if [[ $# -ge 3 ]]; then
			target="$2"
			report=${3%/}
			# Remove possible trailing slashes using Bash native string 
			# removal syntax: ${string%$substring}
			# The above one-liner is equivalent to:
			#    report="$3"
			#    report=${report%/}
			# NOTE: while `$substring` is a literal string, `string` must be
			#       a reference to a variable name!
		else
			printf "Missing parameter(s). Use '--help' or '-h' to see the correct s-mode syntax"
			exit 1 # Failure exit status
		fi
        ;;
	-d | --destroy)
		if [[ $# -ge 2 ]]; then
			fnames="$2"
		else
			printf "Missing parameter. Use '--help' or '-h' to see the correct d-mode syntax"
			exit 1 # Failure exit status
		fi
        ;;
        * )
		printf "\nUnrecognized flag. Use '--help' or '-h' to see the possible options\n"
		exit 1 # Failure exit status
        ;;
    esac
else
	printf "Missing Flag. Use '--help' or '-h' to see possible options"
	exit 1 # Failure exit status
fi

# The 'Target Regex Pattern' (TRP) is a white-space followed by a one-digit
# number (1 to 3) within round brackets
trp=" \([1-3]\)"

if [[ "$1" == "-s" || "$1" == "--seek" ]]; then

	# Find folders and sub-folders that end with the TRP
	find "$target" -type d | grep -E ".+$trp$" > "$report"/"$meta_name"

	# Find regular files that end with the TRP, plus a possible filename extension
	find "$target" -type f | grep -E ".+$trp(\.[a-zA-Z0-9]+)?$" >> "$report"/"$meta_name"

	echo -e "\nNumber of hits: $(wc -l "$report"/"$meta_name")"

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
