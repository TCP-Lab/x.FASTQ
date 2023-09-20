#!/bin/bash

# ============================================================================ #
#  Trim FastQ Files using BBDuk
# ============================================================================ #

# --- General settings and variables -------------------------------------------

set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# --- Function definition ------------------------------------------------------

# Default options
ver="1.6.2"
verbose=true
nor=-1 # Number Of Reads (nor) == -1 --> BBDuk trims the whole FASTQ
paired_reads=true
dual_files=true
remove_originals=true
suffix_pattern="(1|2).fastq.gz"
se_suffix=".fastq.gz"

# Source functions from x.funx.sh
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/x.funx.sh

# Print the help
function _help_trimmer {
	echo
	echo "This script is a wrapper for the NGS-read trimmer BBDuk (from the"
	echo "BBTools suite) that loops over a set of FASTQ files containing either"
	echo "single-ended (SE) or paired-end (PE) reads. In particular, the script"
	echo "  . checks for file pairing in the case of non-interleaved PE reads,"
	echo "    assuming that the filenames of the paired FASTQs differ only by a"
	echo "    suffix (see the '--suffix' option below);"
	echo "  . automatically detects adapter sequences present in the reads;"
	echo "  . saves stats about adapter autodetection;"
	echo "  . right-trims (3') detected adapters (Illumina standard);"
	echo "  . saves trimmed FASTQs and (by default) removes the original ones;"
	echo "  . loops over all the FASTQ files in the target directory."
	echo 
	echo "Usage:"
	echo "  trimmer [-h | --help] [-v | --version]"
	echo "  trimmer -p | --progress [FQPATH]"
	echo "  trimmer [-t | --test] [-q | --quiet] [-s | --single-end]"
	echo "          [-i | --interleaved] [-a | --keep-all]"
	echo "          [--suffix=\"PATTERN\"] FQPATH"
	echo
	echo "Positional options:"
	echo "  -h | --help         Show this help."
	echo "  -v | --version      Show script's version."
	echo "  -p | --progress     Show trimming progress by printing the latest"
	echo "                      cycle of the latest (possibly growing) log file"
	echo "                      (this is useful only when the script is run"
	echo "                      quietly in background). If FQPATH is not"
	echo "                      specified, search \$PWD for trimming logs."
	echo "  -t | --test         Testing mode. Quit after processing 100,000"
	echo "                      reads/read-pairs."
	echo "  -q | --quiet        Disable verbose on-screen logging."
	echo "  -s | --single-end   Single-ended (SE) reads. NOTE: non-interleaved"
	echo "                      (i.e., dual-file) PE reads is the default."
	echo "  -i | --interleaved  PE reads interleaved into a single file."
	echo "                      Ignored when '-s' option is also present."
	echo "  -a | --keep-all     Do not delete original FASTQs after trimming"
	echo "                      (if you have infinite storage space...)."
	echo "  --suffix=\"PATTERN\"  For dual-file PE reads, \"PATTERN\" should be"
	echo "                      a regex-like pattern of this type"
	echo "                      \"leading_str(alt_1|alt_2)trailing_str\","
	echo "                      specifying the two alternative suffixes used to"
	echo "                      match paired FASTQs. The default pattern is"
	echo "                      \"${suffix_pattern}\"."
	echo "                      For SE reads or interleaved PE reads, it can be"
	echo "                      any text string, the default being"
	echo "                      \"${se_suffix}\"."
	echo "                      In any case, this option must be the last one"
	echo "                      of the flags, placed right before FQPATH."
	echo "  FQPATH              Path of a FASTQ-containing folder. The script"
	echo "                      assumes that all the FASTQs are in the same"
	echo "                      directory, but it doesn't inspect subfolders."
}

# Show trimming progress printing the tail of the latest log
# (useful in case of background run)
function _progress_trimmer {

	if [[ -d "$1" ]]; then
		target_dir="$1"
	else
		printf "Bad FQPATH '$1'.\n"
		exit 9 # Argument failure exit status: bad target path
	fi

	# NOTE: In the 'find' command below, the -printf "%T@ %p\n" option prints
	#       the modification timestamp followed by the filename.
	latest_log=$(find "${target_dir}" -maxdepth 1 -type f \
		-iname "Trimmer_*.log" -printf "%T@ %p\n" \
		| sort -n | tail -n 1 | cut -d " " -f 2)

	if [[ -n "$latest_log" ]]; then
		
		echo -e "\n${latest_log}\n"

		# Print only the last cycle in the log file by finding the penultimate
		# occurrence of the pattern "============"
		line=$(grep -n "============" "$latest_log" | \
			cut -d ":" -f 1 | tail -n 2 | head -n 1)
		
		tail -n +${line} "$latest_log"      
		exit 0 # Success exit status
	else
		printf "No Trimmer log file found in '$(realpath "$target_dir")'.\n"
		exit 10 # Argument failure exit status: missing log
	fi
}

# --- Argument parsing ---------------------------------------------------------

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+"
# Value Regex Pattern (VRP)
vrp="^.*\(.*\|.*\).*$"

# Argument check: options
while [[ $# -gt 0 ]]; do
	if [[ "$1" =~ $frp ]]; then
		case "$1" in
			-h | --help)
				_help_trimmer
				exit 0 # Success exit status
			;;
			-v | --version)
				figlet trimmer
				printf "Ver.${ver}\n"
				exit 0 # Success exit status
			;;
			-p | --progress)
				# Cryptic one-liner meaning "$2" or $PWD if argument 2 is unset
				_progress_trimmer "${2:-.}"
			;;
			-t | --test)
				nor=100k
				shift
			;;
			-q | --quiet)
				verbose=false
				shift
			;;
			-s | --single-end)
				paired_reads=false
				shift
			;;
			-i | --interleaved)
				dual_files=false
				shift
			;;
			-a | --keep-all)
				remove_originals=false
				shift  
			;;
			--suffix*)
				# Test for '=' presence
				rgx="^--suffix="
				if [[ "$1" =~ $rgx ]]; then

					if [[ $paired_reads == true && $dual_files == true && \
					   "${1/--suffix=/}" =~ $vrp ]]; then
						
						suffix_pattern="${1/--suffix=/}"
						shift

					elif [[ ($paired_reads == false || \
					   $dual_files == false) && "${1/--suffix=/}" != "" ]]; then

						se_suffix="${1/--suffix=/}"
						shift

					else
						printf "Bad suffix pattern.\n"
						printf "Values assigned to '--suffix' must have the "
						printf "following structure:\n\n"
						printf " - Non interleaved paired-end reads:\n"
						printf "   \"leading_str(alt_1|alt_2)trailing_str\"\n\n"
						printf " - Single-ended/interleaved paired-end reads:\n"
						printf "   \"any_nonEmpty_str\"\n"
						exit 1 # Bad suffix pattern format
					fi
				else
					printf "Values need to be assigned to '--suffix' option "
					printf "using the '=' operator.\n"
					printf "Use '--help' or '-h' to see the correct syntax.\n"
					exit 2 # Bad suffix assignment
				fi
			;;
			*)
				printf "Unrecognized option flag '$1'.\n"
				printf "Use '--help' or '-h' to see possible options.\n"
				exit 3 # Argument failure exit status: bad flag
			;;
		esac
	else
		# The first non-FRP sequence is taken as the FQPATH argument
		target_dir="$1"
		break
	fi
done

# Argument check: FQPATH target directory
if [[ -z "${target_dir:-""}" ]]; then
	printf "Missing option or FQPATH argument.\n"
	printf "Use '--help' or '-h' to see the expected syntax.\n"
	exit 4 # Argument failure exit status: missing FQPATH
elif [[ ! -d "$target_dir" ]]; then
	printf "Invalid target directory '$target_dir'.\n"
	exit 5 # Argument failure exit status: invalid FQPATH
fi

# Retrieve BBDuk local folder from the 'install_paths.txt' file
bbpath="$(grep -i "$(hostname):bbduk" "${xpath}/install_paths.txt" \
	| cut -d ':' -f 3)"

# Check if STDOUT is associated with a terminal or not to distinguish between
# direct 'trimmer.sh' runs and calls from 'trimfastq.sh', which make this script
# to run in background (&) and redirect its output to 'nohup.out', thus
# preventing user interaction...
if [[ ! -t 1 ]]; then
	# 'trimmer.sh' has been called by 'trimfastq.sh': no interaction is possible
	if [[ ! -f "${bbpath}/bbduk.sh" ]]; then
		printf "Couldn't find 'bbduk.sh'...\n"
		printf "Please, check the 'install_paths.txt' file.\n"
		exit 11
	fi
else
	# 'trimmer.sh' has been called directly: interaction is possible
	if [[ -z "$bbpath" ]]; then
		printf "Couldn't find 'bbduk.sh'...\n"
		read -ep "Please, manually enter the path or 'q' to quit: " bbpath
	fi

	found_flag=false
	while ! $found_flag; do
		if [[ "$bbpath" == "q" ]]; then
			exit 12 # Argument failure exit status: missing BBDuk
		elif [[ -f "${bbpath}/bbduk.sh" ]]; then
			found_flag=true
		else
			printf "Couldn't find 'bbduk.sh' in '"${bbpath}"'\n"
			read -ep "Please, enter the right path or 'q' to quit: " bbpath
		fi
	done
fi

# --- Main program -------------------------------------------------------------

target_dir="$(realpath "$target_dir")"
log_file="${target_dir}"/Trimmer_"$(basename "$target_dir")"_$(_tstamp).log

_dual_log $verbose "$log_file" "\n\
	BBDuk found in \"${bbpath}\" !!\n
	Searching ${target_dir} for FASTQs to trim..."

if $paired_reads && $dual_files; then

	_dual_log $verbose "$log_file" \
		"\nRunning in \"dual-file paired-end\" mode:"

	# Assign the suffixes to match paired FASTQs
	r_suffix="$(_explode_ORpattern "$suffix_pattern")"
	r1_suffix="$(echo "$r_suffix" | cut -d ',' -f 1)"
	r2_suffix="$(echo "$r_suffix" | cut -d ',' -f 2)"
	_dual_log $verbose "$log_file" "\
		   Suffix 1: ${r1_suffix}\n\
		   Suffix 2: ${r2_suffix}"

	# Check FASTQ pairing
	counter=0
	while IFS= read -r line
	do
		if [[ ! -e "${line}${r1_suffix}" || ! -e "${line}${r2_suffix}" ]]; then
			_dual_log true "$log_file" "\n\
				A FASTQ file is missing in the following pair:\n\
				   ${line}${r1_suffix}\n\
				   ${line}${r2_suffix}\n\n\
				Aborting..."
			exit 6 # Argument failure exit status: incomplete pair
		else
			counter=$((counter+1))
		fi
	done <<< $(find "$target_dir" -maxdepth 1 -type f \
				-iname "*$r1_suffix" -o -iname "*$r2_suffix" \
				| sed -E "s/(${r1_suffix}|${r2_suffix})//" | sort -u)
	# NOTE:
	# A 'here-string' is used here because if the 'while read' loop had been
	# piped in this way
	#
	# find ... | sed ... | sort -u | while IFS= read -r line; do ... done
	#
	# the 'counter' variable would have lost its value at end of the while loop.
	# This is because pipes create SubShells, which would have made the loop
	# run on a different shell than the script. Since pipes spawn additional
	# shells, any variable you mess with in a pipe will go out of scope as soon
	# as the pipe ends!

	_dual_log $verbose "$log_file" \
		"$counter x 2 = $((counter*2)) paired FASTQ files found."

	# Loop over them
	i=1 # Just another counter
	for r1_infile in "${target_dir}"/*"$r1_suffix"
	do
		r2_infile=$(echo "$r1_infile" | sed "s/$r1_suffix/$r2_suffix/")

		_dual_log $verbose "$log_file" "\n\
			============\n\
			 Cycle ${i}/${counter}\n\
			============\n\
			Targeting: ${r1_infile}\n\
			           ${r2_infile}\n\
			\nStart trimming through BBDuk..."

		prefix="$(basename "$r1_infile" "$r1_suffix")"

		# Run BBDuk!
		# also try to add this for Illumina: ftm=5 \
		echo >> "$log_file"
		${bbpath}/bbduk.sh \
			reads="$nor" \
			in1="$r1_infile" \
			in2="$r2_infile" \
			ref="${bbpath}/resources/adapters.fa" \
			stats="${target_dir}/${prefix}_STATS.tsv" \
			ktrim=r \
			k=23 \
			mink=11 \
			hdist=1 \
			tpe \
			tbo \
			out1=$(echo $r1_infile | sed "s/$r1_suffix/_TRIM_$r1_suffix/") \
			out2=$(echo $r2_infile | sed "s/$r2_suffix/_TRIM_$r2_suffix/") \
			qtrim=rl \
			trimq=10 \
			minlen=25 \
			>> "${log_file}" 2>&1
		# NOTE: By default, all BBTools write status information to stderr,
		#       not stdout !!!
		echo >> "$log_file"

		_dual_log $verbose "$log_file" "DONE!"

		if $remove_originals; then
			rm "$r1_infile" "$r2_infile"
		fi

		# Increment the i counter
		((i++))
	done

elif ! $paired_reads; then

	_dual_log $verbose "$log_file" "\n\
		Running in \"single-ended\" mode:\n\
		   Suffix: ${se_suffix}"

	counter=$(ls "${target_dir}"/*"$se_suffix" | wc -l)

	if (( counter > 0 )); then
		_dual_log $verbose "$log_file" "\n\
			$counter single-ended FASTQ files found."
	else
		_dual_log true "$log_file" \
			"\nThere are no FASTQ files ending with \"${se_suffix}\" \
			in ${target_dir}."
		exit 7 # Argument failure exit status: no FASTQ found
	fi

	# Loop over them
	i=1 # Just another counter
	for infile in "${target_dir}"/*"$se_suffix"
	do
		_dual_log $verbose "$log_file" "\n\
			============\n\
			 Cycle ${i}/${counter}\n\
			============\n\
			Targeting: ${infile}\n\
			\nStart trimming through BBDuk..."

		prefix="$(basename "$infile" "$se_suffix")"

		# Run BBDuk!
		# also try to add this for Illumina: ftm=5 \
		echo >> "$log_file"
		${bbpath}/bbduk.sh \
			reads="$nor" \
			in="$infile" \
			ref="${bbpath}/resources/adapters.fa" \
			stats="${target_dir}/${prefix}_STATS.tsv" \
			ktrim=r \
			k=23 \
			mink=11 \
			hdist=1 \
			interleaved=f \
			out=$(echo $infile | sed "s/$se_suffix/_TRIM$se_suffix/") \
			qtrim=rl \
			trimq=10 \
			minlen=25 \
			>> "${log_file}" 2>&1
		echo >> "$log_file"

		_dual_log $verbose "$log_file" "DONE!"

		if $remove_originals; then
			rm "$infile"
		fi

		# Increment the i counter
		((i++))
	done

elif ! $dual_files; then

	_dual_log $verbose "$log_file" "\n\
		Running in \"interleaved\" mode:\n\
		   Suffix: ${se_suffix}"

	counter=$(ls "${target_dir}"/*"$se_suffix" | wc -l)

	if (( counter > 0 )); then
		_dual_log $verbose "$log_file" "\n\
			$counter interleaved paired-end FASTQ files found."
	else
		_dual_log true "$log_file" \
			"\nThere are no FASTQ files ending with \"${se_suffix}\" \
			in ${target_dir}."
		exit 8 # Argument failure exit status: no FASTQ found
	fi

	# Loop over them
	i=1 # Just another counter
	for infile in "${target_dir}"/*"$se_suffix"
	do
		_dual_log $verbose "$log_file" "\n\
			============\n\
			 Cycle ${i}/${counter}\n\
			============\n\
			Targeting: ${infile}\n\
			\nStart trimming through BBDuk..."

		prefix="$(basename "$infile" "$se_suffix")"

		# Run BBDuk!
		# also try to add this for Illumina: ftm=5 \
		echo >> "$log_file"
		${bbpath}/bbduk.sh \
			reads="$nor" \
			in="$infile" \
			ref="${bbpath}/resources/adapters.fa" \
			stats="${target_dir}/${prefix}_STATS.tsv" \
			ktrim=r \
			k=23 \
			mink=11 \
			hdist=1 \
			interleaved=t \
			tpe \
			tbo \
			out=$(echo $infile | sed "s/$se_suffix/_TRIM$se_suffix/") \
			qtrim=rl \
			trimq=10 \
			minlen=25 \
			>> "${log_file}" 2>&1
		echo >> "$log_file"

		_dual_log $verbose "$log_file" "DONE!"

		if $remove_originals; then
			rm "$infile"
		fi

		# Increment the i counter
		((i++))
	done
fi
