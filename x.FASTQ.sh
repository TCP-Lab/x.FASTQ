#!/bin/bash

# ============================================================================ #
#  x.FASTQ
# ============================================================================ #

# --- General settings and variables -------------------------------------------

set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# Current date and time in "yyyy.mm.dd_HH.MM.SS" format
now="$(date +"%Y.%m.%d_%H.%M.%S")"

# --- Function definition ------------------------------------------------------

# Default options
ver="1.1.1"

# Source functions from x.funx.sh
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/x.funx.sh

# Print the help
function _help_xfastq {
	echo
	echo "x.FASTQ cover-script to manage some features that are common to the"
	echo "entire suite."
	echo
	echo "Usage:"
	echo "  x.FASTQ [-h | --help] [-v | --version] [-vs | --versions]"
	echo "          [-pfc | --pathfile-check] [-dc | --dependencies]"
	echo "  x.FASTQ -ml | --make-links [TARGET]"
	echo
	echo "Positional options:"
	echo "  -h | --help           Show this help."
	echo "  -v | --version        Show script's version."
	echo " -vs | --versions       Show version summary for all x.FASTQ scripts."
	echo "-pfc | --pathfile-check Read the 'install_path.txt' file and check"
	echo "                        for software presence."
	echo " -ml | --make-links     Automatically create multiple symlinks to the"
	echo "                        original scripts to simplify their calling."
	echo " TARGET                 The path where the symlinks are to be created."
	echo "                        If omitted, symlinks are created in \$PWD."
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
				st_tot=0
				nd_tot=0
				rd_tot=0
				figlet x.FASTQ
				# Looping through files with spaces in their names or paths is
				# not such a trivial task...
				OIFS="$IFS"
				IFS=$'\n'
				for script in `find "${xpath}" -maxdepth 1 -type f -iname "*.sh"`  
				do
					if [[ $(basename "$script") != "x.funx.sh" ]]; then
						full_ver=$(source $script -v \
							| grep -oP "(\d{1,2}\.){2}\d{1,2}")
					else
						full_ver=$xfunx_ver # sourced from x.funx.sh
					fi
					st_num=$(echo $full_ver | cut -d'.' -f1)
					nd_num=$(echo $full_ver | cut -d'.' -f2)
					rd_num=$(echo $full_ver | cut -d'.' -f3)
					st_tot=$(( st_tot + st_num ))
					nd_tot=$(( nd_tot + nd_num ))
					rd_tot=$(( rd_tot + rd_num ))
					printf "$(basename "$script")\t:: v.${full_ver}\n"
				done
				IFS="$OIFS"
				echo -en "-----------\t-----------\nVersion Sum"
				echo -en "\t:: x.${st_tot}.${nd_tot}.${rd_tot}\n"
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
						printf "|${red}  |__Couldn't find the tool${end}\n"
						printf "|\n"
					fi
				done
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
