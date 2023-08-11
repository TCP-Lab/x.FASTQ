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

# Default options
ver="0.0.9"
paired_reads=true
dual_files=true
suffix_pattern="(1|2).fastq.gz"

# For a friendlier use of colors in Bash...
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
end=$'\e[0m'

# Print the help
function _help_trimfastq {
	echo
	echo "This script schedules a persistent (i.e., 'nohup') adapter-trimming"
	echo "of NGS reads."
	echo 
	echo "Usage:"
	echo "    trimfastq [-h | --help] [-v | --version]"
	echo "    trimfastq [-s | --single-end] [-i | --interleaved]"
	echo "              [--suffix=PATTERN] FQPATH"
	echo
	echo "Positional options:"
	echo "    -h | --help           show this help"
	echo "    -v | --version        show script's version"
	echo "    -s | --single-end     for single-ended reads"
	echo "    -i | --interleaved    for paired reads interleaved into a single"
	echo "                          file. This option is ignored when option -s"
	echo "                          is also present."
	echo "    --suffix=\"PATTERN\"  a regex matching the suffix of the files containing read pairs"
	echo "    FQPATH                path to the FASTQ-containing folder"
}

# Make the two alternatives explicit from an OR regex pattern
function _explode_ORpattern {
	
	# Input pattern must have the form: "leading(alt_1|alt_2)trailing"
	pattern="$1"

	# Alternative 1: remove from the beginning to (, and from | to the end
	alt_1="$(echo "$pattern" | sed -r "s/.*\(|\|.*//g")"
	# Alternative 2: remove from the beginning to |, and from ) to the end
	alt_2="$(echo "$pattern" | sed -r "s/.*\||\).*//g")"

	suffix_1="$(echo "$pattern" | sed -r "s/\(.*\)/${alt_1}/g")"
	suffix_2="$(echo "$pattern" | sed -r "s/\(.*\)/${alt_2}/g")"

	echo "${suffix_1},${suffix_2}"
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
				printf "//-- trimfastq --// script ver.${ver}\n"
				exit 0 # Success exit status
			;;
	        -s | --single-end)
	        	paired_reads=false
	        	echo "Single-ended reads."
	        	shift
	        ;;
	        -i | --interleaved)
	        	dual_files=false
	        	echo "Interleaved paired reads."
	        	shift
	        ;;
			--suffix*)
				# Test for '=' presence
				if [[ "$1" =~ ^--suffix=  ]]; then
					# Test for "leading(alt_1|alt_2)trailing" structure
					if [[ "${1/--suffix=/}" =~ $vrp  ]]; then
						suffix_pattern="${1/--suffix=/}"
						echo wow
						shift
					else
						printf "Bad suffix pattern format. Value to be assigned to '--suffix' must have the following structure:\n"
						printf "leading(alt_1|alt_2)trailing\n"
						printf "Use '--help' or '-h' to see possible options.\n"
						exit 1 # Bad suffix pattern format
					fi
				else
					printf "Some value needs to be assigned to '--suffix' option using =.\n"
					printf "Use '--help' or '-h' to see possible options.\n"
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
		# The first non-FRP sequence is taken as the TARGETS argument
		target_dir="$1"
		break
	fi
done

# Argument check: target file
if [[ -z "${target_dir:-""}" ]]; then
	printf "Missing option or FQPATH file.\n"
	printf "Use '--help' or '-h' to see the expected syntax.\n"
	exit 3 # Argument failure exit status: missing FQPATH
elif [[ ! -d "$target_dir" ]]; then
	printf "Invalid target directory '$target_dir'.\n"
	exit 4 # Argument failure exit status: invalid FQPATH
fi





# Program starts here
target_dir="$(realpath "$target_dir")"
echo "Searching FASTQs in $target_dir"


# Assign the suffixes for paired read files
r_suffix="$(_explode_ORpattern "$suffix_pattern")"
r1_suffix="$(echo "$r_suffix" | cut -d ',' -f 1)"
r2_suffix="$(echo "$r_suffix" | cut -d ',' -f 2)"
echo "Reads 1: $r1_suffix"
echo "Reads 2: $r2_suffix"

# Search and count the FASTQs in "target_dir"
r1_num=$(find "$target_dir" -maxdepth 1 -type f -iname "*$r1_suffix" | wc -l)
r2_num=$(find "$target_dir" -maxdepth 1 -type f -iname "*$r1_suffix" | wc -l)

if [[ $r1_num -eq $r2_num ]]; then
	echo "$r1_num x 2 = $((r1_num*2)) paired FASTQ files found."
else	
	echo "WARNING: Odd number of FASTQ files!"
	echo "         $r1_num + $r2_num = $((r1_num+r2_num))"
fi

# Loop over them
i=1 # Just a counter
for r1_infile in ${target_dir}/*$r1_suffix
do
	echo
	echo "============"
	echo " Cycle ${i}/${r1_num}"
	echo "============"
	echo "Targeting: $r1_infile"

	r2_infile=$(echo "$r1_infile" | sed "s/$r1_suffix/$r2_suffix/")
	found_flag=$(find "$target_dir" -type f -wholename "$r2_infile" | wc -l)

	if [[ found_flag -eq 1 ]]; then
		echo "Paired to:" $r2_infile
		echo -e "\nStart trimming through BBDuk..."

		# Run BBDuk!
		#${bbpath}/bbduk.sh \
		#	in1=$R1_infile \
		#	in2=$R2_infile \
		#	k=23 \
		#	ref=${bbpath}/resources/adapters.fa \
		#	stats="${fqpath}/stat_$(basename $R1_infile ${R1_suffix}).txt" \
		#	hdist=1 \
		#	tpe \
		#	tbo \
		#	out1=$(echo $R1_infile | sed "s/$R1_suffix/TRIM_$R1_suffix/") \
		#	out2=$(echo $R2_infile | sed "s/$R2_suffix/TRIM_$R2_suffix/") \
		#	ktrim=r mink=11
		#	#reads=100k # Add this argument when testing

		# We don't have infinite storage space...
		#rm $R1_infile $R2_infile
	else
		echo "WARNING: Couldn't find the paired-ends..."
	fi

	# Increment counter
	((i++))
done

echo "The End"
exit 55