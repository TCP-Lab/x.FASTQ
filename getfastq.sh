#!/bin/bash
#set -e # "exit-on-error" shell option
#set -u # "nounset" shell option

# ==============================================
#  Get FastQ Files from ENA database
# ==============================================

# NOTE:
#	- The script assumes all the target addresses are in the input file
# 	- because of limitations on FTP, target address are converted to HTTP,
# 		taking advantage of the intrinsic versatility of ENA browser
#	- use, e.g., `tail -n 3 *.log` to see their progress
#	- use, e.g., `pgrep -l -u fear` to get the IDs of the active wget processes
#

# Default options
verbose=true
sequential=true

# Print the help
function _help_getfastq {
	echo
	echo "This script schedules a persistent queue of FASTQ downloads from ENA"
	echo "database using HTTP, based on the target addresses provided by the"
	echo "input file."
	echo
	echo "Usage: $0 -h | --help"
	echo "       $0 -p | --progress [TARGETS]"
	echo "       $0 [-s | --silent] [-m | --multi] TARGETS"
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
	echo "    TARGETS         path to the text file containing the wgets to"
	echo "                    schedule"
	echo
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
				if [[ -z "$2" ]]; then
					# Search for .log files in the working directory and tail
					target_dir=.
				else
					# Search for .log files in the target directory and tail
					if [[ -d "$2" ]]; then
						target_dir="$2"
					elif [[ -f "$2" ]]; then
						target_dir="$(dirname "$2")"
					else
						printf "Bad TARGETS directory '$2'.\n"
						exit 1 # Argument failure exit status
					fi
				fi
				tail -n 3 "${target_dir}"/*.log
				exit $? # pipe tail's exit status
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
if [[ -z "$1" ]]; then
	printf "Missing option or TARGETS file.\n"
	printf "Use '--help' or '-h' to see possible options.\n"
	exit 3 # Argument failure exit status: missing TARGETS
elif [[ ! -e "$target_file" ]]; then
	printf "Target file '$target_file' not found.\n"
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
# 		(e.g., during an SSH session)
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
