#!/bin/bash

# ==============================================================================
#  Count Matrix Assembler - Bash wrapper
# ==============================================================================

# --- General settings and variables -------------------------------------------

set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# --- Function definition ------------------------------------------------------

# Default options
ver="1.4.3"
verbose=true
gene_names=false
level="genes"
design="NA"
metric="TPM"
raw=false

# Source functions from x.funx.sh
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/x.funx.sh

# Help message
_help_countfastq=""
read -d '' _help_countfastq << EOM || true
This is a wrapper for the 'assembler.R' worker script that searches for all the
RSEM quantification output files within a given folder in order to assemble them
into one single read count matrix (aka expression matrix). It can work at both
gene and isoform levels, optionally appending gene names and symbols. By design,
'assembler.R' searches all sub-directories within the specified DATADIR folder,
assuming that each RSEM output file has been saved into a sample-specific
sub-directory, whose name will be used as a sample ID in the heading of the
final expression table. If provided, it can also inject an experimental design
into column names by adding a dotted suffix to each sample name.
	
Usage:
  countfastq [-h | --help] [-v | --version]
  countfastq -p | --progress [DATADIR]
  countfastq [-q | --quiet] [-n | --names] [-i | --isoforms] [--design=ARRAY]
             [--metric=MTYPE] [-r | --raw] DATADIR

Positional options:
  -h | --help      Shows this help.
  -v | --version   Shows script's version.
  -p | --progress  Shows assembly progress by 'tailing' the latest (possibly
                   still growing) countFASTQ log file. When DATADIR is unset, it
                   searches \$PWD for logs.
  -q | --quiet     Disables verbose on-screen logging.
  -n | --names     Appends gene symbols and names as annotations.
  -i | --isoforms  Assembles counts at the transcript level instead of gene (the
                   default level).
  -r | --raw       Not to include the name of the metric in the column names.
  --design="SUFFX" Injects an experimental design into the heading of the final
                   expression matrix by adding a suffix to each sample name.
                   Suffixes must be as many in number as samples, and they
                   should be given as an array of spaced elements enclosed or
                   not within round or square brackets. In any case, the set of
                   suffixes needs always to be quoted. Elements in the array are
                   meant to label the samples according to the experimental
                   group they belong to; for this reason they should be ordered
                   according to the reading sequence of the sample files (i.e.,
                   alphabetical order on their full path).
  --metric=MTYPE   Metric type to be used in the expression matrix. Based on
                   RSEM output, the possible options are 'expected_count', 'TPM'
                   (default), and 'FPKM'.
  DATADIR          The path to the parent folder containing all the RSEM output
                   files (organized into subfolders) to be used for expression
                   matrix assembly.

Additional Notes:
  Examples of valid input for the '--design' parameter are:
    --design="(ctrl ctrl drug1 drug2 drug1 drug2)"
    --design="[0 0 1 1 0 0 1]"
    --design="[[ x y z ))"
    --design="a a bb bb bb ccc"
  Even previously defined Bash arrays can be used as '--design' arguments, but
  they have to be expanded to a 'single word' using '*' in place of '@' (and
  never forgetting the double-quotes!!):
    --design="\${foo[*]}"
  However, keep in mind that this works only if the first value of \$IFS is a
  space. Thus, a two-step approach may be safer:
    bar="\${foo[@]}"
    --design="\$bar"
  For large sample sizes, you can also take advantage of the brace expansion in
  this way:
    --design=\$(echo {1..15}.ctrl {1..13}.drug)
EOM

# Show analysis progress printing the tail of the latest log
function _progress_countfastq {

	target_dir="$(realpath "$1")"
	if [[ ! -d "$target_dir" ]]; then
		printf "Bad DATADIR path '$target_dir'.\n"
		exit 1 # Argument failure exit status: bad target path
	fi

	# NOTE: In the 'find' command below, the -printf "%T@ %p\n" option prints
	#       the modification timestamp followed by the filename.
	#       The '-f 2-' option in 'cut' is used to take all the fields except
	#       the first one (i.e., the timestamp) to properly handle filenames
	#       or paths with spaces.
	latest_log="$(find "$target_dir" -maxdepth 1 -type f \
		-iname "Z_Counts_*.log" -printf "%T@ %p\n" \
		| sort -n | tail -n 1 | cut -d " " -f 2-)"

	if [[ -n "$latest_log" ]]; then
		cat "$latest_log"
		exit 0 # Success exit status
	else
		printf "No countFASTQ log file found in '$target_dir'.\n"
		exit 2 # Argument failure exit status: missing log
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
				printf "%s\n" "$_help_countfastq"
				exit 0 # Success exit status
			;;
			-v | --version)
				figlet count FASTQ
				printf "Ver.$ver :: The Endothelion Project :: by FeAR\n"
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
			-r | --raw)
				raw=true
				shift
			;;
			--design*)
				# Test for '=' presence
				rgx="^--design="
				if [[ "$1" =~ $rgx ]]; then
					design="${1/--design=/}"
					shift
				else
					printf "Values need to be assigned to '--design' option "
					printf "using the '=' operator.\n"
					printf "Use '--help' or '-h' to see the correct syntax.\n"
					exit 4 # Bad suffix assignment
				fi
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
						printf "Invalid metric: '$metric'.\n"
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
				exit 7 # Argument failure exit status: bad flag
			;;
		esac
	else
		# The first non-FRP sequence is assumed as the DATADIR argument
		target_dir="$(realpath "$1")"
		break
	fi
done

# Argument check: DATADIR directory
if [[ -z "${target_dir:-""}" ]]; then
	printf "Missing option or DATADIR argument.\n"
	printf "Use '--help' or '-h' to see the expected syntax.\n"
	exit 8 # Argument failure exit status: missing DATADIR
elif [[ ! -d "$target_dir" ]]; then
	printf "Invalid target directory '$target_dir'.\n"
	exit 9 # Argument failure exit status: invalid DATADIR
fi

# --- Main program -------------------------------------------------------------

# When creating the log file, 'basename "$target_dir"' assumes that DATADIR
# was properly named with the current Experiment_ID
log_file="${target_dir}/Z_Counts_$(basename "$target_dir")_$(_tstamp).log"

_dual_log $verbose "$log_file" "\n\
	Expression Matrix Assembler\n
	Searching RSEM output files in $target_dir
	Working at ${level%s} level with $metric metric"

nohup Rscript "${xpath}"/workers/assembler.R \
	"$gene_names" "$level" "$design" "$metric" "$raw" "$target_dir" \
	>> "$log_file" 2>&1 &
