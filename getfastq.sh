#!/bin/bash

# ============================================================================ #
#  Get FastQ Files from ENA Database
# ============================================================================ #

# --- General settings and variables -------------------------------------------

#set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# Current date and time
now="$(date +"%Y.%m.%d_%H.%M.%S")"

# For a friendlier use of colors in Bash
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
end=$'\e[0m'

# --- Minimal implementation ---------------------------------------------------

# Change false to true to toggle the 'minimal implementation' of the script
if false; then
	printf "\n===\\\ Running minimal implementation \\\===\n"
	target_dir="$(dirname "$1")"
	sed "s|ftp:|-P ${target_dir/" "/"\\\ "} http:|g" "$1" | nohup bash \
		> "${target_dir}/getFASTQ_$(basename "$target_dir")_${now}.log" 2>&1 &
fi

# --- Function definition ------------------------------------------------------

# Default options
ver="1.2.2"
verbose=true
sequential=true

# Print the help
function _help_getfastq {
	echo
	echo "This script uses 'nohup' to schedule a persistent queue of FASTQ"
	echo "downloads from ENA database via HTTP, based on the target addresses"
	echo "passed as input (in the form provided by ENA Browser when using the"
	echo "'Get download script' option). Target addresses need to be converted"
	echo "to HTTP because of the limitations on FTP imposed by UniTo. Luckily,"
	echo "this can be done simply by replacing 'ftp' with 'http' in each URL"
	echo "to wget, thanks to the great versatility of the ENA Browser."
	echo
	echo "Usage:"
	echo "  getfastq [-h | --help] [-v | --version]"
	echo "  getfastq -p | --progress [TARGETS]"
	echo "  getfastq -k | --kill"
	echo "  getfastq [-q | --quiet] [-m | --multi] TARGETS"
	echo
	echo "Positional options:"
	echo "  -h | --help      Show this help."
	echo "  -v | --version   Show script's version."
	echo "  -p | --progress  Show TARGETS downloading progress by 'tail-ing'"
	echo "                   and 'grep-ing' ALL the getFASTQ log files"
	echo "                   (including those currently growing). If TARGETS is"
	echo "                   not specified, search \$PWD for getFASTQ logs."
	echo "  -k | --kill      Kill all the 'wget' processes currently running"
	echo "                   and started by the current user (i.e., \$USER)."
	echo "  -q | --quiet     Disable verbose on-screen logging."
	echo "  -m | --multi     Multi process option. A separate download process"
	echo "                   will be instantiated in background for each target"
	echo "                   FASTQ file at once, resulting in a parallel"
	echo "                   download of all the TARGETS files. While the"
	echo "                   default behavior is the sequential download of the"
	echo "                   individual FASTQs, using '-m' option can result in"
	echo "                   a much faster global download process, especially"
	echo "                   in case of broadband Internet connections."
	echo "  TARGETS          Path to the text file (as provided by ENA Browser)"
	echo "                   containing the 'wgets' to be scheduled."
	echo
	echo "Additional Notes:"
	echo "  . You can use 'pgrep -l -u \"\$USER\"' to get the IDs of the active"
	echo "    'wget' processes, and selectively kill some of them. To kill'em"
	echo "    all, use the 'getfastq -k' option."
	echo "  . Just add 'time' before the two 'nohup' statements to measure the"
	echo "    total execution time and compare the performance of sequential"
	echo "    and parallel download modalities."
}

# Show download progress
function _progress_getfastq {

	if [[ -d "$1" ]]; then
		target_dir="$1"
	elif [[ -f "$1" ]]; then
		target_dir="$(dirname "$1")"
	else
		printf "Bad TARGETS path '$1'.\n"
		exit 1 # Argument failure exit status: bad target path
	fi

	log_file=$(find "${target_dir}" -maxdepth 1 -type f -iname "getFASTQ_*.log")
	
	if [[ -n "$log_file" ]]; then
		printf "\n${grn}Completed:${end}\n"
		grep --no-filename "saved" "${target_dir}"/getFASTQ_*.log \
			|| [[ $? == 1 ]]

		printf "\n${yel}Tails:${end}\n"
		tail -n 3 "${target_dir}"/getFASTQ_*.log
		printf "\n"
		exit 0 # Success exit status
	else
		printf "No getFASTQ log file found in '$(realpath $target_dir)'.\n"
		exit 5 # Argument failure exit status: missing log
	fi
}

# --- Argument parsing ---------------------------------------------------------

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+$"

# Argument check: options
while [[ $# -gt 0 ]]; do
	if [[ "$1" =~ $frp ]]; then
		case "$1" in
			-h | --help)
				_help_getfastq
				exit 0 # Success exit status
			;;
			-v | --version)
				figlet get FASTQ
				printf "Ver.${ver} :: The Endothelion Project :: by FeAR\n"
				exit 0 # Success exit status
			;;
			-p | --progress)
				# Cryptic one-liner meaning "$2" or $PWD if argument 2 is unset
				_progress_getfastq "${2:-.}"
			;;
			-k | --kill)
				while [[ $? -eq 0 ]]; do
					pkill -eu $USER wget
				done
				exit 0
				# 'set -e' option would have prevented reaching this success
				# exit status. That is why the option has been disabled.
			;;
			-q | --quiet)
				verbose=false
				shift
			;;
			-m | --multi)
				sequential=false
				shift
			;;
			*)
				printf "Unrecognized option flag '$1'.\n"
				printf "Use '--help' or '-h' to see possible options.\n"
				exit 2 # Argument failure exit status: bad flag
			;;
		esac
	else
		# The first non-FRP sequence is taken as the TARGETS argument
		target_file="$1"
		break
	fi
done

# Argument check: target file
if [[ -z "${target_file:-""}" ]]; then
	printf "Missing option or TARGETS file.\n"
	printf "Use '--help' or '-h' to see the expected syntax.\n"
	exit 3 # Argument failure exit status: missing TARGETS
elif [[ ! -f "$target_file" ]]; then
	printf "Invalid target file '$target_file'.\n"
	exit 4 # Argument failure exit status: invalid TARGETS
fi

# --- Main program -------------------------------------------------------------

target_dir="$(dirname "$(realpath "$target_file")")"

# Verbose on-screen logging
if $verbose; then
	echo
	echo "========================"
	if $sequential; then
		echo "| Sequential Job Queue |"
	else
		echo "|  Parallel Job Queue  |"
	fi
	echo "========================"

	counter=1
	while IFS= read -r line
	do
		# Using Bash-native string substitution syntax to change FTP into HTTP
		# ${string/$substring/$replacement}
		# NOTE: while `$substring` and `$replacement` are literal strings
		# 		the starting `string` MUST be a reference to a variable name!
		fastq_name="$(basename "$line")"
		fastq_address="$(dirname ${line/wget* ftp:/http:})"

		echo
		echo "[${counter}]"
		echo "Downloading: $fastq_name"
		echo "From       : $fastq_address"

		((counter++))

	done < "$target_file"
fi

# Make a temporary copy of TARGETS file, where FTP is replaced by HTTP and the
# wget's -P option is added to specify the target directory.
# In addition, possible spaces in paths are also escaped to avoid issues in the
# next part.
sed "s|ftp:|-P ${target_dir/" "/"\\\ "} http:|g" "$target_file" \
	> "${target_file}.tmp"

# In the code block below:
#
# 	`nohup` (no hangups) allows processes to keep running even upon user logout
# 		(e.g., when exiting an SSH session)
# 	`>` allows output to be redirected somewhere other than the default
# 		./nohup.out file
# 	`2>&1` is to redirect both standard output and standard error to the
# 		getFASTQ log file
# 	`&&` is to execute the next command only after the first one is terminated
# 		with exit status == 0 
# 	`&` at the end of the line, is, as usual, to run the command in the
# 		background and get the shell prompt active again
#
if $sequential; then
	nohup bash "${target_file}.tmp" \
		> "${target_dir}/getFASTQ_$(basename "$target_dir")_${now}.log" 2>&1 \
		&& rm "${target_file}.tmp" &
else
	while IFS= read -r line
	do
		fast_name="$(echo "$(basename "$line")" | sed -E "s/(\.fastq|\.gz)//g")"
		nohup bash -c "$line" \
			> "${target_dir}/getFASTQ_${fast_name}_${now}.log" 2>&1 &

	done < "${target_file}.tmp"

	# Remove the temporary copy of TARGETS file
	rm "${target_file}.tmp"
fi
