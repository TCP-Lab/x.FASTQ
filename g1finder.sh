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
	echo "       $0 -S | --Seek TARGET REPORT"
	echo "       $0 -d | --destroy FNAMES"
	echo
	echo "Positional options:"
	echo "    -h | --help     show this help"
	echo "    -s | --seek     search mode"
	echo "    -S | --Seek     enhanced search mode (with cloud connection)"
	echo "    -d | --destroy  cleaning mode"
	echo "    TARGET          the Google Drive folder to be scanned (s-mode)"
	echo "    REPORT          the output directory for filename report (s-mode)"
	echo "    FNAMES          the input list of filenames to clean (d-mode)"
	echo
	echo "Examples: "$0" -s /mnt/e/UniTo\ Drive/ ~"
	echo "          "$0" -d ./loos.txt"
	echo
}

# Name of the filename-containing file (e.g., List_Of_Ones.txt)
meta_name="loos.txt"

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-z]+$"

# Argument check
if [[ "$1" =~ $frp ]]; then
    case "$1" in
    	-h | --help)
			_help_g1
			exit 0 # Success exit status
        ;;
        -s | -S | --seek | --Seek)
			if [[ $# -ge 3 ]]; then
				target="$2"
				report="${3%/}"
				# Remove possible trailing slashes using Bash native string 
				# removal syntax: ${string%$substring}
				# The above one-liner is equivalent to:
				#    report="$3"
				#    report="${report%/}"
				# NOTE: while `$substring` is a literal string, `string` must be
				#       a reference to a variable name!
			else
				printf "Missing parameter(s).\n"
				printf "Use '--help' or '-h' to see the correct s-mode syntax.\n"
				exit 1 # Failure exit status
			fi
        ;;
        -d | --destroy)
			if [[ $# -ge 2 ]]; then
				fnames="$2"
			else
				printf "Missing parameter.\n"
				printf "Use '--help' or '-h' to see the correct d-mode syntax.\n"
				exit 1 # Failure exit status
			fi
        ;;
        * )
			printf "Unrecognized flag '$1'.\n"
			printf "Use '--help' or '-h' to see the possible options.\n"
			exit 1 # Failure exit status
        ;;
    esac
else
	printf "Missing flag.\n"
	printf "Use '--help' or '-h' to see possible options.\n"
	exit 1 # Failure exit status
fi

# The 'Target Regex Pattern' (TRP) is a white-space followed by a one-digit
# number (1 to 3) within round brackets; i.e.: (1), (2), (3)
trp=" \([1-3]\)"

# To lower case (to match both -s and -S)
flag=$(echo "$1" | tr '[:upper:]' '[:lower:]')

if [[ "$flag" == "-s" || "$flag" == "--seek" ]]; then

	# Find folders and sub-folders that end with the TRP
	find "$target" -type d | grep -E ".+$trp$" > "$report"/"$meta_name"

	# Find regular files that end with the TRP, plus a possible filename extension
	find "$target" -type f | grep -E ".+$trp(\.[a-zA-Z0-9]+)?$" >> "$report"/"$meta_name"

	echo -e "\nNumber of hits: $(wc -l "$report"/"$meta_name")"
	
	if [[ "$1" == "-s" || "$1" == "--seek" ]]; then
		
		exit 0 # Success exit status
	
	elif [[ "$1" == "-S" || "$1" == "--Seek" ]]; then

		while IFS= read -r line
		do
			
			# Get current default browser
			browser="$(echo $BROWSER)"

			# Files are organized in Google Drive by filename
			base_line="$(basename "$line")"

			# Access Google Drive Cloud by R metacoding 
			remote=$(Rscript --vanilla -e "args=commandArgs(trailingOnly=TRUE);
options(browser=args[1]); options(googledrive_quiet=TRUE);
x <- googledrive::drive_get(args[2]); cat(nrow(x))" "$browser" "$base_line" 2> /dev/null)

			if [[ "$remote" -eq 0 ]]; then
				echo "$line" >> "$report"/euristic_"$meta_name"
			fi

		done < "$report"/"$meta_name"

		echo -e "\nDetections: $(wc -l "$report"/euristic_"$meta_name")"
		exit 0 # Success exit status
	fi

elif [[ "$1" == "-d" || "$1" == "--destroy" ]]; then

	# Save a temporary reverse-sorted filename list (see below the reason why)
	temp_out="$(dirname "$fnames")/temp.out"
	sort -r "$fnames" > "$temp_out"

	while IFS= read -r line
	do
		# Remove TRP from filenames using Bash native string substitution:
		# ${string/$substring/$replacement}
		# NOTE: while `$substring` and `$replacement` are literal strings
		# 		the starting `string` must be a reference to a variable name!
		# Split each filename between dirname and basename to match and
		# substitute the TRP from the end of the strings.
		# This, in combination with the previous reverse-sorting, ensures that
		# mv is always possible, even for nested TRPs, since it starts pruning
		# from the leaves of the filesystem.
		
		dir_line="$(dirname "$line")"
		base_line="$(basename "$line")"

		# Toggle verbose debugging
		if true; then
			echo
			echo "From: "$line""
			echo "To  : "$dir_line"/"${base_line/$trp/}""
		fi
		
		# Now clean!
		mv "$line" "$dir_line"/"${base_line/$trp/}"
		
	done < "$temp_out"

	# Remove the temporary file
	rm "$temp_out"
	exit 0 # Success exit status
fi
