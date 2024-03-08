#!/bin/bash

# ============================================================================ #
#  x.FASTQ cover script
# ============================================================================ #

# --- General settings and variables -------------------------------------------

set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# --- Function definition ------------------------------------------------------

# Default options
ver="1.5.2"

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
	echo "  -d | --dependencies  Read the 'install.paths' file and check for"
	echo "                       third-party software presence."
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

function _banner {
read -d '' _b << EOM || true
        _____ _    ____ _____ ___  
__  __ |  ___/ \  / ___|_   _/ _ \ 
\ \/ / | |_ / _ \ \___ \ | || | | |
 >  < _|  _/ ___ \ ___) || || |_| |
/_/\_(_)_|/_/   \_\____/ |_| \__\_\
EOM    
echo ${_b}
}

# Argument check: options
while [[ $# -gt 0 ]]; do
	if [[ "$1" =~ $frp ]]; then
		case "$1" in
			-h | --help)
				_help_xfastq
				exit 0 # Success exit status
			;;
			-v | --version)
				_banner
				printf "Ver.${ver} :: The Endothelion Project :: by FeAR\n"
				exit 0 # Success exit status
			;;
			-r | --report)
				st_tot=0
				nd_tot=0
				rd_tot=0
                _banner
				# Looping through files with spaces in their names or paths is
				# not such a trivial thing...
				OIFS="$IFS"
				IFS=$'\n'
				for script in `find "${xpath}" -maxdepth 1 \
					-type f -iname "*.sh" -o -iname "*.R" | sort`  
				do
					full_ver=$(grep -oP "ver=\"(\d+\.){2}\d+\"$" "$script" \
						| grep -oP "(\d+\.){2}\d+")
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
				# Root of the visualization tree
				host="$(hostname)"
				printf "\n${host}\n |\n"
				
				# Check directory-specific software
				local_inst=($(_get_qc_tools "names") $(_get_seq_sw "names"))
				for entry in "${local_inst[@]}"; do
					# "PCA" is a valid option of qcFASTQ, but it is not a
					# stand-alone software. The presence of the related
					# "PCATools" R package will be checked later on...
					if [[ "$entry" != "PCA" ]]; then
						printf " |__${yel}${entry}${end}\n"
						printf " |   |__"
						entry_dir=$(grep -i "${host}:${entry}:" \
							"${xpath}/install.paths" | cut -d ':' -f 3)
						entry_path="${entry_dir}/$(_name2cmd ${entry})"
						if [[ -f "${entry_path}" ]]; then
							printf "${grn}Software found${end}: ${entry_path}\n"
						else
							printf "${red}Couldn't find this tool${end}\n"
						fi
						printf " |\n"
					fi
				done

				# Check globally-visible software
				global_inst=("Java" "Python" "R")
				for entry in "${global_inst[@]}"; do
					printf " |__${yel}${entry}${end}\n"
					# Draw the terminal branch when you get to the last
					# element (  ${array[-1]}  )
					if [[ "$entry" != ${global_inst[-1]} ]]; then
						bb=" |   |__"	# Regular BackBone
						af=" |\n"		# Regular AFter-branch
					else
						bb="     |__"	# Terminal BackBone
						af=""			# Terminal AFter-branch
					fi
					cmd_entry="$(_name2cmd ${entry})"
					if which "$cmd_entry" > /dev/null 2>&1; then
						entry_ver="$("$cmd_entry" --version | head -n 1 \
						  | sed -E "s/(${entry}|${cmd_entry}|ver|version)//gI" \
						  | sed -E 's/^[ \.-]*//')"
						printf "${bb}${grn}Software found${end}: "
						printf "v.${entry_ver}\n${af}"
					else
						printf "${bb}${red}Couldn't find this tool${end}\n${af}"
					fi
				done

				# Check R packages (only if Rscript is installed)
				if which Rscript > /dev/null 2>&1; then
					printf	"$(_repeat " " 5)|\n"
					R_pkgs=("BiocManager" \
							"PCAtools" \
							"org.Hs.eg.db" \
							"org.Mm.eg.db")
					indent="$(_repeat " " 5)|$(_repeat "_" 2)"
					for pkg in "${R_pkgs[@]}"; do
						pkg_dir=$(Rscript -e "system.file(package=\"${pkg}\")" \
							| sed 's/\[1\] //g' | sed 's/"//g')
						if [[ -n ${pkg_dir} ]]; then
							pkg_ver=$(Rscript -e "packageVersion(\"${pkg}\")" \
								| grep -oP "(\d+\.){2}\d+")
							printf "${indent}${yel}${pkg}${end}"
							printf "\t${grn}Package installed${end}: "
							printf "v.${pkg_ver}\n"
						else
							printf "${indent}${yel}${pkg}${end}\t"
							printf "${red}Not found${end}\n"
						fi
					done
				fi
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
					"${xpath}/install.paths" | cut -d ':' -f 3)
				if [[ -n "${genome_dir:-""}" ]]; then
					du -sh "$genome_dir"
				else
					echo "---"
				fi
				exit 0
			;;
			-m)
				_count_down 5
				# echo -e $(tail ...) is just to interpret the escape sequences
				echo -e "$(tail -n1 ~/Documents/.x.fastq-m_option)"
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
