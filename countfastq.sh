#!/bin/bash

# ============================================================================ #
#  Count Matrix Assembler - Bash wrapper
# ============================================================================ #

# --- General settings and variables -------------------------------------------

set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# --- Function definition ------------------------------------------------------

# Default options
ver="1.1.0"
verbose=true
gene_names=false
metric="TPM"
level="genes"

# Source functions from x.funx.sh
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/x.funx.sh

# Print the help
function _help_countfastq {
	echo
	echo "This is a wrapper for the 'cc_assembler.R' R script that searches for"
	echo "all RSEM quantification output files in order to assemble them into"
	echo "one single count/expression matrix. It can work at both gene and"
	echo "isoform levels, optionally appending gene names and symbols. By"
	echo "design, the 'cc_assembler.R' script will search all sub-directories"
	echo "within the specified TARGET directory, assuming that each RSEM output"
	echo "file has been saved into a sample-specific sub-directory whose name"
	echo "can be used as sample name for the heading of the final expression"
	echo "table."	
	echo
	echo "Usage:"
	echo "  countfastq [-h | --help] [-v | --version]"
	echo "  countfastq -p | --progress [TARGETS]"
	echo "  countfastq [-q | --quiet] [-n | --names] [-i | --isoforms]"
	echo "             [--metric=MTYPE] TARGETS"
	echo
	echo "Positional options:"
	echo "  -h | --help      Show this help."
	echo "  -v | --version   Show script's version."
	echo "  -p | --progress  Show assembly progress by 'tailing' the latest"
	echo "                   (possibly still growing) countFASTQ log. When"
	echo "                   TARGETS is not specified, search \$PWD for logs."
	echo "  -q | --quiet     Disable verbose on-screen logging."
	echo "  -n | --names     Append gene symbols and gene names as annotations."
	echo "  -i | --isoforms  Assemble counts at the transcript level instead"
	echo "                   of gene level (default)."
	echo "  --metric=MTYPE   Metric type to be used in the expression matrix."
	echo "                   Based on RSEM output, the possible options are"
	echo "                   'expected_count', 'TPM' (default), and 'FPKM'."
	echo "  TARGETS          The path to the parent folder containing all the"
	echo "                   RSEM output files (organized into subfolders) to"
	echo "                   be used for expression matrix assembly."
}

# Show analysis progress printing the tail of the latest log
function _progress_countfastq {

	if [[ -d "$1" ]]; then
		target_dir="$1"
	else
		printf "Bad TARGETS path '$1'.\n"
		exit 2 # Argument failure exit status: bad target path
	fi

	# NOTE: In the 'find' command below, the -printf "%T@ %p\n" option prints
	#       the modification timestamp followed by the filename.
	latest_log=$(find "${target_dir}" -maxdepth 1 -type f \
		-iname "Z_Counts_*.log" -printf "%T@ %p\n" \
		| sort -n | tail -n 1 | cut -d " " -f 2)

	if [[ -n "$latest_log" ]]; then
		cat "${latest_log}"
		exit 0 # Success exit status
	else
		printf "No countFASTQ log file found in '$(realpath "$target_dir")'.\n"
		exit 3 # Argument failure exit status: missing log
	fi
}

# --- Argument parsing ---------------------------------------------------------

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+"

# Argument check: options
while [[ $# -gt 0 ]]; do
	if [[ "$1" =~ $frp ]]; then
		case "$1" in
			-h | --help)
				_help_countfastq
				exit 0 # Success exit status
			;;
			-v | --version)
				figlet count FASTQ
				printf "Ver.${ver} :: The Endothelion Project :: by FeAR\n"
				exit 0 # Success exit status
			;;
			-p | --progress)
				# Cryptic one-liner meaning "$2" or $PWD if argument 2 is unset
				_progress_countfastq "${2:-.}"
			;;
			-q | --quiet)
				verbose=false
				shift
			;;
			-n | --names)
				gene_names=true
				shift
			;;
			-i | --isoforms)
				level="isoforms"
				shift
			;;
			--metric*)
				# Test for '=' presence
				rgx="^--metric="
				if [[ "$1" =~ $rgx ]]; then
					metric="${1/--metric=/}"
					# Check if a given string is an element of an array.
					# NOTE: leading and trailing spaces around array elements
					#       are used to ensure accurate pattern matching!
					if [[ " expected_count TPM FPKM " == *" ${metric} "* ]]; then
						shift
					else
						printf "Invalid metric: '${metric}'.\n"
						printf "Please, choose among the following options:\n"
						printf "  -  expected_count\n"
						printf "  -  TPM\n"
						printf "  -  FPKM\n"
						exit 5
					fi
				else
					printf "Values need to be assigned to '--metric' option "
					printf "using the '=' operator.\n"
					printf "Use '--help' or '-h' to see the correct syntax.\n"
					exit 6 # Bad suffix assignment
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

# --- Main program -------------------------------------------------------------

target_dir="$(realpath "$target_dir")"
log_file="${target_dir}"/Z_Counts_"$(basename "$target_dir")"_$(_tstamp).log

_dual_log $verbose "$log_file" "\n\
	Expression Matrix Assembler\n
	Searching RSEM output files in ${target_dir}
	Working at ${level%s} level with ${metric} metric"

nohup Rscript "${xpath}"/cc_assembler.R \
	"$level" "$metric" "$gene_names" "$target_dir" \
	>> "$log_file" 2>&1 &
