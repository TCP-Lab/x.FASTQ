#!/bin/bash

# ============================================================================ #
#  FASTQ Quality Control
# ============================================================================ #

# --- General settings and variables -------------------------------------------

set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# Current date and time in "yyyy.mm.dd_HH.MM.SS" format
now="$(date +"%Y.%m.%d_%H.%M.%S")"

# For a friendlier use of colors in Bash
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
end=$'\e[0m'

# --- Function definition ------------------------------------------------------

# Default options
ver="1.0.2"
verbose=true
suffix=".fastq.gz"
tool="FastQC"

# Print the help
function _help_qcfastq {
	echo
	echo "This script is meant to perform Quality Control (QC) analyses of NGS"
	echo "data by wrapping some of the most popular QC software tools currently"
	echo "around (e.g, FastQC, MultiQC, QualiMap). Specifically, 'qcfastq' runs"
	echo "them persistently (by 'nohup') and in background, possibly cycling"
	echo "over multiple input files."
	echo
	echo "Usage:"
	echo "  qcfastq [-h | --help] [-v | --version]"
	echo "  qcfastq -p | --progress [TARGETS]"
	echo "  qcfastq [-q | --quiet] [--suffix=STRING] [--tool=QCTYPE]"
	echo "          [--out=NAME] TARGETS"
	echo
	echo "Positional options:"
	echo "  -h | --help      Show this help."
	echo "  -v | --version   Show script's version."
	echo "  -p | --progress  Show QC analysis progress by 'tailing' the latest"
	echo "                   (possibly still growing) QC log. If TARGETS is not"
	echo "                   specified, search \$PWD for QC logs."
	echo "  -q | --quiet     Disable verbose on-screen logging."
	echo "  --suffix=STRING  A string specifying the suffix (e.g., a filename"
	echo "                   extension) used to identify the files to be"
	echo "                   analyzed. The default is \"${suffix}\"."
	echo "  --tool=QCTYPE    QC software tool to be used. Currently implemented"
	echo "                   options are PCA, FastQC, MultiQC, and QualiMap."
	echo "  --out=NAME       The name of the output folder. Only a folder NAME"
	echo "                   is required, not its entire path; if a full path"
	echo "                   is provided, only its 'basename' will be used. In"
	echo "                   any case, a folder will be created (if it still"
	echo "                   doesn't exist) as a sub-directory within the"
	echo "                   TARGETS folder."
	echo "  TARGETS          The path to the folder containing the files to"
	echo "                   be analyzed."
	echo
	echo "Additional Notes:"
	echo "  Some of these tools can be applied to both raw and trimmed reads"
	echo "  (e.g., FastQC), others are useful to aggregate multiple results"
	echo "  from previous analysis tools (e.g., MultiQC), others have to be"
	echo "  used after read alignment has been performed (e.g., QualiMap),"
	echo "  and, finally, some of them (such as PCA) are only suited for"
	echo "  post-quantification data (i.e., for counts)."
}

# Show analysis progress printing the tail of the latest log
function _progress_qcfastq {

	if [[ -d "$1" ]]; then
		target_dir="$1"
	else
		printf "Bad TARGETS path '$1'.\n"
		exit 2 # Argument failure exit status: bad target path
	fi

	# NOTE: In the 'find' command below, the -printf "%T@ %p\n" option prints
	#       the modification timestamp followed by the filename.
	latest_log=$(find "${target_dir}" -maxdepth 1 -type f -iname "QC_*.log" \
		-printf "%T@ %p\n" | sort -n | tail -n 1 | cut -d " " -f 2)

	if [[ -n "$latest_log" ]]; then
		
		echo -e "\n${latest_log}"

		printf "\n${grn}Completed:${end}\n"
		grep --no-filename "Analysis complete" "${latest_log}" || [[ $? == 1 ]]
		
		printf "\n${yel}Tails:${end}\n"
		tail -n 1 "${latest_log}"
		exit 0 # Success exit status
	else
		printf "No QC log file found in '$(realpath "$target_dir")'.\n"
		exit 3 # Argument failure exit status: missing log
	fi
}

# On-screen and to-file logging function
#
# USAGE: _dual_log $verbose log_file "message"
#
# Always redirect "message" to log_file; also redirect it to standard output
# (i.e., print on screen) if $verbose == true.
# NOTE:	the 'sed' part allows tabulations to be ignored while still allowing
#       the code (i.e., multi-line messages) to be indented.
function _dual_log {
	if $1; then echo -e "$3" | sed "s/\t//g"; fi
	echo -e "$3" | sed "s/\t//g" >> "$2"
}

# --- Argument parsing ---------------------------------------------------------

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+"

# Argument check: options
while [[ $# -gt 0 ]]; do
	if [[ "$1" =~ $frp ]]; then
		case "$1" in
			-h | --help)
				_help_qcfastq
				exit 0 # Success exit status
			;;
			-v | --version)
				figlet qc FASTQ
				printf "Ver.${ver} :: The Endothelion Project :: by FeAR\n"
				exit 0 # Success exit status
			;;
			-p | --progress)
				# Cryptic one-liner meaning "$2" or $PWD if argument 2 is unset
				_progress_qcfastq "${2:-.}"
			;;
			-q | --quiet)
				verbose=false
				shift
			;;
			--suffix*)
				# Test for '=' presence
				if [[ "$1" =~ ^--suffix=  ]]; then
					suffix="${1/--suffix=/}"
					shift
				else
					printf "Values need to be assigned to '--suffix' option "
					printf "using the '=' operator.\n"
					printf "Use '--help' or '-h' to see the correct syntax.\n"
					exit 4 # Bad suffix assignment
				fi
			;;
			--tool*)
				# Test for '=' presence
				if [[ "$1" =~ ^--tool=  ]]; then
					
					tool="${1/--tool=/}"
					
					if [[ "$tool" == "PCA" || \
					      "$tool" == "FastQC" || \
					      "$tool" == "MultiQC" || \
					      "$tool" == "QualiMap" ]]; then
						shift
					else
						printf "Invalid QC tool name: '${tool}'.\n"
						printf "Please, choose among the following options:\n"
						printf "  -  PCA\n"
						printf "  -  FastQC\n"
						printf "  -  MultiQC\n"
						printf "  -  QualiMap\n"
						exit 5
					fi
				else
					printf "Values need to be assigned to '--tool' option "
					printf "using the '=' operator.\n"
					printf "Use '--help' or '-h' to see the correct syntax.\n"
					exit 6 # Bad suffix assignment
				fi
			;;
			--out*)
				# Test for '=' presence
				if [[ "$1" =~ ^--out=  ]]; then
					out_dirname="${1/--out=/}"
					shift
				else
					printf "Values need to be assigned to '--out' option "
					printf "using the '=' operator.\n"
					printf "Use '--help' or '-h' to see the correct syntax.\n"
					exit 7 # Bad suffix assignment
				fi
			;;
			*)
				printf "Unrecognized option flag '$1'.\n"
				printf "Use '--help' or '-h' to see possible options.\n"
				exit 8 # Argument failure exit status: bad flag
			;;
		esac
	else
		# The first non-FRP sequence is taken as the TARGETS argument
		target_dir="$1"
		break
	fi
done

# Argument check: TARGETS directory
if [[ -z "${target_dir:-""}" ]]; then
	printf "Missing option or TARGETS argument.\n"
	printf "Use '--help' or '-h' to see the expected syntax.\n"
	exit 9 # Argument failure exit status: missing TARGETS
elif [[ ! -d "$target_dir" ]]; then
	printf "Invalid target directory '$target_dir'.\n"
	exit 10 # Argument failure exit status: invalid TARGETS
fi

# Argument check: QCTYPE tool
case "$tool" in
	PCA)
		echo "PCA selected. TO BE DONE..."
	;;
	FastQC)
		if ! which fastqc > /dev/null 2>&1; then
			printf "FastQC not found...\n"
			printf "Install FastQC and put 'fastqc' file in some \$PATH folder.\n"
			exit 1 # Argument failure exit status: FastQC not found
		fi
	;;
	MultiQC)
		echo "MultiQC selected. TO BE DONE..."
	;;
	QualiMap)
		echo "QualiMap selected. TO BE DONE..."
	;;
esac

# --- Main program -------------------------------------------------------------

target_dir="$(realpath "$target_dir")"
log_file="${target_dir}"/QC_"${tool}"_"$(basename "$target_dir")"_"${now}".log

counter=$(ls "${target_dir}"/*"$suffix" 2>/dev/null | wc -l)

if (( counter > 0 )); then
	_dual_log $verbose "$log_file" "\n\
		Found $counter FASTQ files ending with \"${suffix}\" in ${target_dir}."
else
	_dual_log true "$log_file" "\n\
		There are no FASTQ files ending with \"${suffix}\" in ${target_dir}."
	exit 11 # Argument failure exit status: no FASTQ found
fi

# Existence operator ${:-} <=> ${user-defined_name:-default_name}
output_dir="${target_dir}/${out_dirname:-"${tool}_out"}"
mkdir "$output_dir"

target_files=$(find "$target_dir" -maxdepth 1 -type f -iname *"$suffix")

_dual_log $verbose "$log_file" "\n\
	Running ${tool} tool in background and saving output in ${output_dir}...\n"

case "$tool" in
	PCA)
		echo "PCA selected. TO BE DONE..."
	;;
	FastQC)
		nohup fastqc -o "${output_dir}" ${target_files} >> "$log_file" 2>&1 &
	;;
	MultiQC)
		echo "MultiQC selected. TO BE DONE..."
	;;
	QualiMap)
		echo "QualiMap selected. TO BE DONE..."
	;;
esac
