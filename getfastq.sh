#!/bin/bash

set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# ============================================================================ #
# NOTE on -e option
# -----------------
# If you use grep and do NOT consider grep finding no match as an error,
# use the following syntax
#
# grep "<expression>" || [[ $? == 1 ]]
#
# to prevent grep from causing premature termination of the script.
# This works since, according to posix manual, exit code
# 	1 means no lines selected;
# 	> 1 means an error.
#
# NOTE on -u option
# ------------------
# The existence operator ${:-} allows avoiding errors when testing variables by
# providing a default value in case the variable is not defined or empty.
#
# result=${var:-value}
#
# If `var` is unset or null, `value` is substituted (and assigned to `results`).
# Otherwise, the value of `var` is substituted and assigned.
# ============================================================================ #

# ============================================================================ #
#  Get FastQ Files from ENA database
# ============================================================================ #

# Change false to true to toggle the 'minimal implementation'
if false; then
	printf "\n===\\\ Running minimal implementation \\\===\n"
	target_dir="$(dirname "$1")"
	sed "s|ftp:|-P $target_dir http:|g" "$1" | nohup bash > "${target_dir}"/getFASTQ.log 2>&1 &
	exit 0
fi

# ============================================================================ #

# Default options
verbose=true
sequential=true

# For a friendlier use of colors in Bash...
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
end=$'\e[0m'

# Print the help
function _help_getfastq {
	echo
	echo "This script schedules a persistent (i.e., 'nohup') queue of FASTQ"
	echo "downloads from ENA database using HTTP, based on the target addresses"
	echo "provided as input. Target addresses need to be converted to HTTP"
	echo "because of the limitations on FTP by UniTo. Fortunately, this can be"
	echo "done simply replacing 'ftp' with 'http' in each address to wget,"
	echo "thanks to the great versatility of the ENA browser."
	echo
	echo "Usage:"
	echo "    $0 -h | --help"
	echo "    $0 -p | --progress [TARGETS]"
	echo "    $0 [-s | --silent] [-m | --multi] TARGETS"
	echo
	echo "Positional options:"
	echo "    -h | --help     show this help"
	echo "    -p | --progress show TARGETS downloading progress (if TARGETS is"
	echo "                    not specified, search wget processes in \$PWD)"
	echo "    -s | --silent   disable verbose on-screen logging"
	echo "    -m | --multi    multi process option. A separate download process"
	echo "                    is instantiated in background for each target"
	echo "                    FASTQ file at once, resulting in a parallel"
	echo "                    download of all the TARGETS files. Useful for"
	echo "                    broadband Internet connections, while the default"
	echo "                    behavior is sequential download of individual"
	echo "                    FASTQs."
	echo "    TARGETS         path to the text file containing the 'wgets' to"
	echo "                    schedule"
	echo
	echo "Additional Notes:"
	echo "   Use 'pgrep -l -u \"\$USER\"' to get the IDs of the active 'wget'"
	echo "   and possibly kill'em all."
}

function _progress_getfastq {

	if [[ -d "$1" ]]; then
		target_dir="$1"
	elif [[ -f "$1" ]]; then
		target_dir="$(dirname "$1")"
	else
		printf "Bad TARGETS path '$1'.\n"
		exit 1 # Argument failure exit status: bad target path
	fi

	# `compgen` is the only reliable way in Bash to test if there are files
	# matching a pattern (i.e., test whether a glob has any matches).
	if compgen -G "${target_dir}"/*.log > /dev/null; then
		printf "\n${grn}Completed:${end}\n"
		grep --no-filename "saved" "${target_dir}"/*.log || [[ $? == 1 ]]
		
		printf "\n${red}Tails:${end}\n"
		tail -n 3 "${target_dir}"/*.log
		printf "\n"
		exit $? # pipe tail's exit status
	else
		printf "No log file found in '$(realpath $target_dir)'.\n"
		exit 5 # Argument failure exit status: missing log
	fi
}

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9]+$"

# Argument check: options
while [[ $# -gt 0 ]]; do
	if [[ "$1" =~ $frp ]]; then
	    case "$1" in
	    	-h | --help)
				_help_getfastq
				exit 0 # Success exit status
			;;
		    -p | --progress)
		    	# Cryptic one-liner meaning "$2" or $PWD if 2nd argument is unset
				_progress_getfastq "${2:-.}"
			;;
	        -s | --silent)
	        	verbose=false
	        	shift
	        ;;
	        -m | --multi)
	        	sequential=false
	        	shift
	        ;;
	        * )
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
target_file=${target_file:-""}
if [[ -z "$target_file" ]]; then
	printf "Missing option or TARGETS file.\n"
	printf "Use '--help' or '-h' to see possible options.\n"
	exit 3 # Argument failure exit status: missing TARGETS
elif [[ ! -f "$target_file" ]]; then
	printf "Invalid target file '$target_file'.\n"
	exit 4 # Argument failure exit status: invalid TARGETS
fi

# Program starts here
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
# -P option is added to specify the target directory
sed "s|ftp:|-P $target_dir http:|g" "$target_file" > "${target_file}.tmp"

# In the code block below:
#
# 	`nohup` (no hangups) allows processes to keep running even upon user logout
# 		(e.g., exiting an SSH session)
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
	nohup bash "${target_file}.tmp" > "${target_dir}"/getFASTQ.log 2>&1 \
		&& rm "${target_file}.tmp" &
else
	while IFS= read -r line
	do
		fastq_name="$(basename "$line")"
		nohup $line > "${target_dir}"/"${fastq_name}".log 2>&1 &

	done < "${target_file}.tmp"

	# Remove the temporary copy of TARGETS file
	rm "${target_file}.tmp"
fi
