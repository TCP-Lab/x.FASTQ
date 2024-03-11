#!/bin/bash

# ==============================================================================
#  Get FASTQ Files from the ENA Database
# ==============================================================================

# --- General settings and variables -------------------------------------------

set -e           # "exit-on-error" shell option
set -u           # "no-unset" shell option
set -o pipefail  # exit on within-pipe error

# --- Minimal implementation ---------------------------------------------------

# Change false to true to toggle the 'minimal implementation' of the script
# (for debugging purposes only...)
if false; then
	printf "\n===\\\ Running minimal implementation \\\===\n"
	target_dir="$(dirname "$(realpath "$1")")"
	sed "s|ftp:|-P ${target_dir/" "/"\\\ "} http:|g" "$(realpath "$1")" \
		| nohup bash \
		> "${target_dir}/Z_getFASTQ_$(basename "$target_dir")_$(_tstamp).log" \
		2>&1 &
	exit 0
fi

# --- Function definition ------------------------------------------------------

# Default options
ver="1.3.3"
verbose=true
sequential=true

# Source functions from x.funx.sh
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/x.funx.sh

# Help message
_help_getfastq=""
read -d '' _help_getfastq << EOM || true
This script uses 'nohup' to schedule a persistent queue of FASTQ downloads from
ENA database via HTTP, based on the target addresses passed as input (in the
form provided by ENA Browser when using the 'Get download script' button).
Target addresses need to be converted to HTTP because of the limitations on FTP
imposed by UniTo. Luckily, this can be done simply by replacing 'ftp' with
'http' in each URL to wget, thanks to the great versatility of the ENA Browser.

Usage:
  getfastq [-h | --help] [-v | --version]
  getfastq -p | --progress [TARGETS]
  getfastq -k | --kill
  getfastq [-q | --quiet] [-m | --multi] TARGETS

Positional options:
  -h | --help      Shows this help.
  -v | --version   Shows script's version.
  -p | --progress  Shows TARGETS downloading progress by 'tail-ing' and
                   'grep-ing' ALL the getFASTQ log files (including those
                   currently growing). If TARGETS is not specified, it searches
                   \$PWD for getFASTQ logs.
  -k | --kill      Gracefully (-15) kills all the 'wget' processes currently
                   running and started by the current user.
  -q | --quiet     Disables verbose on-screen logging.
  -m | --multi     Multi process option. A separate download process will be
                   instantiated in background for each target FASTQ file at
                   once, resulting in a parallel download of all the TARGETS
                   files. While the default behavior is the sequential download
                   of the individual FASTQs, using '-m' option can result in a
                   much faster global download process, especially in case of
                   broadband internet connections.
  TARGETS          Path to the text file (as provided by ENA Browser) containing
                   the 'wgets' to be scheduled.

Additional Notes:
  . While the 'getfastq -k' option tries to gracefully kill ALL the currently
    active 'wget' processes started by \$USER, you may wish to selectively kill
    just some of them (possibly forcefully) after you retrieved their IDs
    through 'pgrep -l -u "\$USER"'.
  . Just add 'time' before the two 'nohup' statements to measure the total
    execution time and compare the performance of sequential and parallel
    download modalities.
  . Use the 'metaharvest' x.FASTQ utility to download an entire study. E.g.:
      metaharvest -d "PRJNA141411" > ./PRJNA141411_wgets.sh
      getfastq PRJNA141411_wgets.sh 
EOM

# Show download progress
function _progress_getfastq {

	if [[ -d "$1" ]]; then
		target_dir="$(realpath "$1")"
	elif [[ -f "$1" ]]; then
		target_dir="$(dirname "$(realpath "$1")")"
	else
		printf "Bad TARGETS path '$1'.\n"
		exit 1 # Argument failure exit status: bad target path
	fi

	log_file=$(find "${target_dir}" -maxdepth 1 -type f \
		-iname "Z_getFASTQ_*.log")

	if [[ -n "$log_file" ]]; then

		# NOTE: the -- is used here to indicate the end of 'bash' command
		#       options and the beginning of Bash script arguments.
		printf "\n${grn}Completed:${end}\n"
		find "${target_dir}" -maxdepth 1 -type f -iname "Z_getFASTQ_*.log" \
			-exec bash -c 'grep -E " saved \[| already there;" "$1"' -- {} \;

		printf "\n${red}Failed:${end}\n"
		find "${target_dir}" -maxdepth 1 -type f -iname "Z_getFASTQ_*.log" \
			-exec bash -c '
				grep -E ".+ Terminated| unable to |Not Found." "$1"
			' -- {} \;

		printf "\n${yel}Incoming:${end}\n"
		find "${target_dir}" -maxdepth 1 -type f -iname "Z_getFASTQ_*.log" \
			-exec bash -c '
				dead_track=$(tail -n 3 "$1" | grep -E \
					" saved \[| already there;|Terminated|unable to|Not Found")
				[[ -z $dead_track ]] && tail -n 1 "$1" && echo
			' -- {} \;
		exit 0 # Success exit status
	else
		printf "No getFASTQ log file found in '${target_dir}'.\n"
		exit 2 # Argument failure exit status: missing log
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
				printf "%s\n" "$_help_getfastq"
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
				k_flag="k_flag"
				while [[ -n "$k_flag" ]]; do
					k_flag="$(pkill -15 -eu "$USER" "wget" || [[ $? == 1 ]])"
					if [[ -n "$k_flag" ]]; then echo "${k_flag} gracefully"; fi
				done
				exit 0
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
				exit 3 # Argument failure exit status: bad flag
			;;
		esac
	else
		# The first non-FRP sequence is taken as the TARGETS argument
		target_file="$(realpath "$1")"
		break
	fi
done

# Argument check: target file
if [[ -z "${target_file:-""}" ]]; then
	printf "Missing option or TARGETS file.\n"
	printf "Use '--help' or '-h' to see the expected syntax.\n"
	exit 4 # Argument failure exit status: missing TARGETS
elif [[ ! -f "$target_file" ]]; then
	printf "Invalid target file '${target_file}'.\n"
	exit 5 # Argument failure exit status: invalid TARGETS
fi

# --- Main program -------------------------------------------------------------

target_dir="$(dirname "$target_file")"

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

# Make a temporary copy of TARGETS file, where:
# - FTP is replaced by HTTP;
# - wget's -P option is added to specify the target directory;
# - the progress bar is forced even if the output is not a TTY (see 'man wget');
# - possible spaces in paths are escaped to avoid issues in the next part.
sed "s|ftp:|--progress=bar:force:noscroll -P ${target_dir/" "/"\\\ "} http:|g" \
	"$target_file" > "${target_file}.tmp"

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
		> "${target_dir}/Z_getFASTQ_$(basename "$target_dir")_$(_tstamp).log" \
		2>&1 && rm "${target_file}.tmp" &
else
	while IFS= read -r line
	do
		fast_name="$(basename "$line" | sed -E "s/(\.fastq|\.gz)//g")"
		nohup bash <<< "$line" \
			> "${target_dir}/Z_getFASTQ_${fast_name}_$(_tstamp).log" 2>&1 &
		# Originally, this was 'nohup bash -c "$line"', but it didn't print
		# the 'Terminated' string in the log file when killed by the -k option
		# (thus affecting in turn '_progress_getfastq'). So I used a
		# 'here string' to make the process equivalent to the sequential branch.
	done < "${target_file}.tmp"

	# Remove the temporary copy of TARGETS file
	rm "${target_file}.tmp"
fi
