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
#  Trim FastQ Files using BBDuk
# ============================================================================ #

# BBDuk local folder
bbpath="$HOME/bbmap"

# Current date and time
now="$(date +"%Y.%m.%d_%H.%M.%S")"

# Default options
ver="0.0.9"
verbose=true
paired_reads=true
dual_files=true
remove_originals=true
suffix_pattern="(1|2).fastq.gz"
se_suffix=".fastq.gz"

# For a friendlier use of colors in Bash...
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
end=$'\e[0m'

# Print the help
function _help_trimfastq {
	echo
	echo "This script schedules a persistent (i.e., 'nohup') adapter-trimming"
	echo "of NGS reads. The script is a wrapper for BBDuk trimmer (from the"
	echo "BBTools suite) to loop over a set of FASTQ files containing either"
	echo "single-ended (SE) or paired-end (PE) reads. In particular, the script"
	echo "  - checks for file pairing in the case of non-interleaved PE reads,"
	echo "    assuming that the filenames of the paired FASTQs differ only by a"
	echo "    suffix (see the '--suffix' option below);"
	echo "  - automatically detects adapter sequences present in the reads;"
	echo "  - saves stats about adapter autodetection;"
	echo "  - right-trims (3') detected adapters (Illumina standard);"
	echo "  - saves trimmed FASTQs and (by default) removes the original ones;"
	echo "  - loops over all the FASTQ files in the target directory."
	echo 
	echo "Usage:"
	echo "    trimfastq [-h | --help] [-v | --version]"
	echo "    trimfastq [-q | --quiet] [-s | --single-end] [-i | --interleaved]"
	echo "              [-a | --keep-all] [--suffix=PATTERN] FQPATH"
	echo
	echo "Positional options:"
	echo "    -h | --help          show this help"
	echo "    -v | --version       show script's version"
	echo "    -q | --quiet         disable verbose on-screen logging"
	echo "    -s | --single-end    for single-ended reads. Non-interleaved"
	echo "                         (i.e., dual-file) PE reads is the default."
	echo "    -i | --interleaved   for PE reads interleaved in a single file."
	echo "                         This option is ignored when '-s' option is"
	echo "                         also present."
	echo "    -a | --keep-all      do not delete original FASTQs after trimming"
	echo "                         (if you have infinite storage space...)"
	echo "    --suffix=\"PATTERN\" for dual-file PE reads \"PATTERN\" has to be"
	echo "                         a regex-like pattern of the type"
	echo "                         \"leading_str(alt_1|alt_2)trailing_str\""
	echo "                         specifying the two alternative suffixes used"
	echo "                         to match paired FASTQs. Default pattern is"
	echo "                         \"${suffix_pattern}\""
	echo "                         For SE reads or interleaved PE reads it can"
	echo "                         be any simple string, the default being:"
	echo "                         \"${se_suffix}\""
	echo "                         In any case this option should be the last"
	echo "                         one of the flags, right before FQPATH, and"
	echo "                         it is ignored when either '-s' or -i option"
	echo "                         is also present."
	echo "    FQPATH               path to the FASTQ-containing folder (the"
	echo "                         script assumes that all the FASTQs are in"
	echo "                         the same folder, but it doesn't inspect"
	echo "                         possible subfolders)."
}

# Make the two alternatives explicit from an OR regex pattern
function _explode_ORpattern {
	
	# Input pattern must be of this type: "leading_str(alt_1|alt_2)trailing_str"
	pattern="$1"

	# Alternative 1: remove from the beginning to (, and from | to the end
	alt_1="$(echo "$pattern" | sed -r "s/.*\(|\|.*//g")"
	# Alternative 2: remove from the beginning to |, and from ) to the end
	alt_2="$(echo "$pattern" | sed -r "s/.*\||\).*//g")"

	# Build the two suffixes
	suffix_1="$(echo "$pattern" | sed -r "s/\(.*\)/${alt_1}/g")"
	suffix_2="$(echo "$pattern" | sed -r "s/\(.*\)/${alt_2}/g")"

	# Return them through echo, separated by a comma
	echo "${suffix_1},${suffix_2}"
}

# On-screen and to-file logging function
#
# 	USAGE:	_dual_log $verbose log_file "message"
#
# Always redirect "message" to log_file; also redirect it to standard output
# (i.e., print on screen) if $verbose == true
# NOTE:	the 'sed' part allows tabulations to be ignored while still allowing
# 		the code (i.e., multi-line messages) to be indented.
function _dual_log {
	if $1; then echo -e "$3" | sed "s/\t//g"; fi
	echo -e "$3" | sed "s/\t//g" >> "$2"
}

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+"
# Value Regex Pattern (VRP)
vrp="^.*\(.*\|.*\).*$"

# Argument check: options
while [[ $# -gt 0 ]]; do
	if [[ "$1" =~ $frp ]]; then
	    case "$1" in
	    	-h | --help)
				_help_trimfastq
				exit 0 # Success exit status
			;;
			-v | --version)
				figlet trim FASTQ
				printf "Ver.${ver} :: The Endothelion Project :: by FeAR\n"
				exit 0 # Success exit status
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
				if [[ "$1" =~ ^--suffix=  ]]; then

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
						printf "  - Non interleaved paired-end reads:\n"
						printf "    \"leading_str(alt_1|alt_2)trailing_str\"\n\n"
						printf "  - Single-ended or interleaved paired-end reads:\n"
						printf "    \"any_nonEmpty_str\"\n"
						exit 1 # Bad suffix pattern format
					fi
				else
					printf "Values need to be assigned to '--suffix' option "
					printf "using the '=' operator.\n"
					printf "Use '--help' or '-h' to see the correct syntax.\n"
					exit 2 # Bad suffix assignment
				fi
			;;
	        * )
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

# Program starts here
target_dir="$(realpath "$target_dir")"
log_file="${target_dir}"/trimFASTQ_"$(basename "$target_dir")"_"${now}".log

_dual_log $verbose "$log_file" \
	"\nSearching ${target_dir} for FASTQs to trim..."

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
				-iname *"$r1_suffix" -o -iname *"$r2_suffix" \
				| sed -r "s/(${r1_suffix}|${r2_suffix})//" | sort -u)
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

	dual_log $verbose "$log_file" \
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
		# reads=100k \ # Add this argument somewhere when testing !!
		# also try to add this for Illumina: ftm=5 \
		echo >> "$log_file"
		${bbpath}/bbduk.sh \
			reads=100k \
			in1="$r1_infile" \
			in2="$r2_infile" \
			ref="${bbpath}/resources/adapters.fa" \
			stats="${target_dir}/${prefix}STATS.tsv" \
			ktrim=r \
			k=23 \
			mink=11 \
			hdist=1 \
			tpe \
			tbo \
			out1=$(echo $r1_infile | sed "s/$r1_suffix/TRIM_$r1_suffix/") \
			out2=$(echo $r2_infile | sed "s/$r2_suffix/TRIM_$r2_suffix/") \
			>> "${log_file}" 2>&1
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
		_dual_log $verbose "$log_file" \
			"$counter single-ended FASTQ files found."
	else
		_dual_log $verbose "$log_file" \
			"\nThere are no FASTQ files ending with \"${se_suffix}\" in ${target_dir}."
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
		# reads=100k \ # Add this argument somewhere when testing !!
		# also try to add this for Illumina: ftm=5 \
		echo >> "$log_file"
		${bbpath}/bbduk.sh \
			reads=100k \
			in="$infile" \
			ref="${bbpath}/resources/adapters.fa" \
			stats="${target_dir}/${prefix}_STATS.tsv" \
			ktrim=r \
			k=23 \
			mink=11 \
			hdist=1 \
			interleaved=f \
			out=$(echo $infile | sed "s/$se_suffix/_TRIM$se_suffix/") \
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
		_dual_log $verbose "$log_file" \
			"$counter interleaved paired-end FASTQ files found."
	else
		_dual_log $verbose "$log_file" \
			"\nThere are no FASTQ files ending with \"${se_suffix}\" in ${target_dir}."
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
		# reads=100k \ # Add this argument somewhere when testing !!
		# also try to add this for Illumina: ftm=5 \
		echo >> "$log_file"
		${bbpath}/bbduk.sh \
		reads=100k \
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
