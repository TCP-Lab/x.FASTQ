#!/bin/bash

# ============================================================================ #
#  x.FASTQ
# ============================================================================ #

# --- General settings and variables -------------------------------------------

set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# Current date and time in "yyyy.mm.dd_HH.MM.SS" format
now="$(date +"%Y.%m.%d_%H.%M.%S")"

# For a friendlier use of colors in Bash
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
end=$'\e[0m'

# --- Function definition ------------------------------------------------------

# Default options
ver="0.1.0"
xpath="$(dirname "$(realpath "$0")")" # realpath expands symlinks by default... so this is always the real installation path, even when x.FASTQ is called by a symlink

# Print the help
function _help_xfastq {
	echo
	echo "This script is meant to be blah blah blah..."
	echo
	echo "Usage:"
	echo "  x.FASTQ [-h | --help] [-v | --version] [-vs | --versions]"
	echo "          [-pfc | --pathfile-check] [-dc | --dependencies]"
	echo "  x.FASTQ -ml | --make-links [TARGET]"
	echo
	echo "Positional options:"
	echo "  -h | --help         Show this help."
	echo "  -v | --version      Show script's version."
	echo
	echo "Additional Notes:"
	echo "    You can use this or that to do something..."
	echo
	echo "installation path: $xpath"
}

# --- Argument parsing ---------------------------------------------------------

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+$"

# Argument check: options
while [[ $# -gt 0 ]]; do
	if [[ "$1" =~ $frp ]]; then
		case "$1" in
			-h | --help)
				_help_xfastq
				exit 0 # Success exit status
			;;
			-v | --version)
				figlet x.FASTQ
				printf "Ver.${ver} :: The Endothelion Project :: by FeAR\n"
				exit 0 # Success exit status
			;;
			-vs | --versions)
				figlet x.FASTQ
				# Handling spaces in paths and filenames within a for loop may
				# not be trivial...
				OIFS="$IFS"
				IFS=$'\n'
				for script in `find "${xpath}" -maxdepth 1 -type f -iname "*.sh"`  
				do
					printf "$(basename "$script")\t:: v."
					printf "$("$script" -v | grep -oE "[0-9]\.[0-9]\.[0-9]")"
					printf "\n"
				done
				IFS="$OIFS"
				exit 0 # Success exit status
			;;
			-pfc | --pathfile-check)

				host="$(hostname)"
				printf "\n${host}\n|\n"

				OIFS="$IFS"
				IFS=$'\n'
				for entry in `grep -i "$(hostname)" "${xpath}"/install_paths.txt`  
				do
					printf "|__${entry/${host}:/}\n"
					entry_path=$(echo "${entry}" | cut -d ':' -f 3)
					if [[ -e "${entry_path}" ]]; then
						printf "|${grn}  |__Software found${end}\n"
						printf "|\n"
					else
						printf "|${red}  |__Couldn'f find software${end}\n"
						printf "|\n"
					fi
				done
				#grep -i "$(hostname)" "${xpath}"/install_paths.txt
				#grep -i "$(hostname)" "${xpath}"/install_paths.txt | cut -d ':' -f 3
				exit 0
			;;
			-ml | --make-links)
				OIFS="$IFS"
				IFS=$'\n'
				for script in `find "${xpath}" -maxdepth 1 -type f -iname "*.sh"`  
				do
					script_name=$(basename "${script}")
					# Default to $PWD in the case of missing TARGET
					link_path="${2:-.}"/${script_name%.sh}
					if [[ -e "$link_path" ]]; then
						rm "$link_path"
					fi
					ln -s "$script" "$link_path"
				done
				IFS="$OIFS"
				exit 0 # Success exit status
			;;
			*)
				printf "Unrecognized option flag '$1'.\n"
				printf "Use '--help' or '-h' to see possible options.\n"
				exit 1 # Argument failure exit status: bad flag
			;;
		esac
	else
		printf "Unrecognized option '$1'.\n"
	fi
done

# --- Main program -------------------------------------------------------------


