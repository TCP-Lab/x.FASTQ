#!/bin/bash

# ============================================================================ #
#  x.FASTQ cover script
# ============================================================================ #

# --- General settings and variables -------------------------------------------

set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# --- Function definition ------------------------------------------------------

# Default options
ver="1.4.3"

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
	echo "  x.fastq [-h | --help] [-v | --version] [-r | --report]"
	echo "          [-d | --dependencies]"
	echo "  x.fastq -l | --links [TARGET]"
	echo "  x.fastq -s | --space [TARGET]"
	echo
	echo "Positional options:"
	echo "  -h | --help          Show this help."
	echo "  -v | --version       Show script's version."
	echo "  -r | --report        Show version summary for all x.FASTQ scripts."
	echo "  -d | --dependencies  Read the 'install_path.txt' file and check"
	echo "                       for third-party software presence."
	echo "  -l | --links         Automatically create multiple symlinks to the"
	echo "                       original scripts to simplify their calling."
	echo "  -s | --space         Disk space usage monitor utility."
	echo "  TARGET               With -l option, the path where the symlinks"
	echo "                       are to be created. With -s option, the project"
	echo "                       folder containing all raw data and analysis."
	echo "                       In both case, if omitted, it defaults to \$PWD."
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
			-r | --report)
				st_tot=0
				nd_tot=0
				rd_tot=0
				figlet x.FASTQ
				# Looping through files with spaces in their names or paths is
				# not such a trivial thing...
				OIFS="$IFS"
				IFS=$'\n'
				for script in `find "${xpath}" -maxdepth 1 \
					-type f -iname "*.sh" -o -iname "*.R" | sort`  
				do
					full_ver=$(grep -oP "ver=\"(\d\.){2}\d\"$" "$script" \
						| grep -oP "(\d\.){2}\d")
					st_num=$(echo $full_ver | cut -d'.' -f1)
					nd_num=$(echo $full_ver | cut -d'.' -f2)
					rd_num=$(echo $full_ver | cut -d'.' -f3)
					st_tot=$(( st_tot + st_num ))
					nd_tot=$(( nd_tot + nd_num ))
					rd_tot=$(( rd_tot + rd_num ))
					printf "$(basename "$script")\t:: v.${full_ver}\n"
				done
				IFS="$OIFS"
				echo -en "---\nVersion Sum"
				echo -en "\t:: x.${st_tot}.${nd_tot}.${rd_tot}\n"
				exit 0 # Success exit status
			;;
			-d | --dependencies)
				# Check dir-specific software
				local_inst=($(_get_qc_tools "names") $(_get_seq_sw "names"))
				host="$(hostname)"
				printf "\n${host}\n |\n"
				for entry in "${local_inst[@]}"; do
					printf " |__${yel}${entry}${end}\n"
					entry_dir=$(grep -i "${host}:${entry}:" \
						"${xpath}"/install_paths.txt | cut -d ':' -f 3)
					entry_path="${entry_dir}"/"$(_name2cmd ${entry})"
					if [[ -f "${entry_path}" ]]; then
						printf " |${grn}   |__Software found${end}"
						printf ": ${entry_path}\n"
						printf " |\n"
					else
						printf " |${red}   |__Couldn't find the tool${end}\n"
						printf " |\n"
					fi
				done
				# Check globally visible software
				global_inst=("Java" "Python" "R")
				for entry in "${global_inst[@]}"; do
					printf " |__${yel}${entry}${end}\n"
					cmd_entry="$(_name2cmd ${entry})"
					if which "$cmd_entry" > /dev/null 2>&1; then
						entry_ver="$("$cmd_entry" --version | head -n 1 \
							| sed -E "s/(${entry}|${cmd_entry}|ver|version)//g" \
							| sed -E 's/^[ \.-]*//')"
						# Be aware of the last element (${array[-1]} syntax)
						if [[ "$entry" != ${global_inst[-1]} ]]; then
							printf " |${grn}   |__Software found${end}:"
							printf " v.${entry_ver}${end}\n"
							printf " |\n"
						else
							printf "  ${grn}   |__Software found${end}:"
							printf " v.${entry_ver}${end}\n"
						fi
					else
						# Be aware of the last element (${array[-1]} syntax)
						if [[ "$entry" != ${global_inst[-1]} ]]; then
							printf " |${red}   |__Couldn't find the tool${end}\n"
							printf " |\n"
						else
							printf "  ${red}   |__Couldn't find the tool${end}\n"
						fi
					fi
				done
				exit 0 # Success exit status
			;;
			-l | --links)
				OIFS="$IFS"
				IFS=$'\n'
				for script in `find "${xpath}" -maxdepth 1 -type f \
					-iname "*.sh" -a -not -iname "x.funx.sh"`
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
			-s | --space)
				target_dir=$(realpath "${2:-.}")
				printf "\n${grn}Disk usage report for the "
				printf "$(basename ${target_dir}) x.FASTQ project${end}\n\n"
				printf "${yel}System stats:${end}\n"
				df -Th "$target_dir"
				printf "\n${yel}Project stats:${end}\n"
				printf "Data\t\t"
				du -sh "$target_dir"
				printf "Genome\t\t"
				host="$(hostname)"
				genome_dir=$(grep -i "${host}:Genome:" \
					"${xpath}"/install_paths.txt | cut -d ':' -f 3)
				if [[ -n "${genome_dir:-""}" ]]; then
					du -sh "$genome_dir"
				else
					echo "---"
				fi
				exit 0
			;;
			-m)
				_count_down 5
				tail -n1 ~/Documents/.x.fastq-m_option
				sleep 5
				clear
				exit 0 # Success exit status
			;;
			*)
				printf "Unrecognized option flag '$1'.\n"
				printf "Use '--help' or '-h' to see possible options.\n"
				exit 1 # Argument failure exit status: bad flag
			;;
		esac
	else
		printf "Bad argument '$1'.\n"
		printf "Use '--help' or '-h' to see possible options.\n"
		exit 1 # Argument failure exit status: bad argument
	fi
done

printf "Missing option.\n"
printf "Use '--help' or '-h' to see the expected syntax.\n"
exit 2 # Argument failure exit status: missing option
