#!/bin/bash

# ==============================================================================
#  Quality Control Tools for NGS Data
# ==============================================================================

# --- General settings and variables -------------------------------------------

set -e           # "exit-on-error" shell option
set -u           # "no-unset" shell option
set -o pipefail  # exit on within-pipe error

# --- Function definition ------------------------------------------------------

# Default options
ver="1.4.7"
verbose=true
tool="FastQC"

# Source functions from x.funx.sh
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/x.funx.sh

# Help message
_help_qcfastq=""
read -d '' _help_qcfastq << EOM || true
This script is meant to perform Quality Control (QC) analyses of NGS data by
wrapping some of the most popular QC software tools currently around (e.g.,
FastQC, MultiQC, QualiMap). Specifically, qcFASTQ runs them persistently (by
'nohup') and in background, possibly cycling over multiple input files.

Usage:
  qcfastq [-h | --help] [-v | --version]
  qcfastq -p | --progress [DATADIR]
  qcfastq [-q | --quiet] [--suffix=STRING] [--tool=QCTYPE] [--out=NAME] DATADIR

Positional options:
  -h | --help      Shows this help.
  -v | --version   Shows script's version.
  -p | --progress  Shows QC analysis progress by 'tailing' the latest (possibly
                   still growing) QC log. If DATADIR is not specified, it
                   searches \$PWD for QC logs.
  -q | --quiet     Disables verbose on-screen logging.
  --suffix=STRING  A string specifying the suffix (e.g., a filename extension)
                   used by qcFASTQ for selecting the files to analyze. The
                   default for FastQC is ".fastq.gz", while for PCA is ".tsv".
                   This argument is ignored by the other tools.
  --tool=QCTYPE    QC software tool to be used. Currently implemented options
                   are FastQC (default), MultiQC, QualiMap, and PCA. Tools are
                   supposed to be preinstalled by the user and made globally
                   available (i.e., included in \$PATH). As an alternative, they
                   can be placed in any directory of the filesystem (even if not
                   included in \$PATH) and made visible only to qcFASTQ by
                   editing the 'install.paths' file.
  --out=NAME       The name of the output folder. The default name is
                   "QCTYPE_out". Only a folder NAME is required, not its entire
                   path; if a full path is provided, only its 'basename' will be
                   used. In any case, the script will attempt to create a new
                   folder as a sub-directory of DATADIR; if it already exists,
                   the whole process is aborted to avoid any possible
                   overwriting of previous reports.
  DATADIR          The path to the folder containing the files to be analyzed.
                   Unlike MultiQC, FastQC and PCA are designed not to search
                   sub-directories.

Additional Notes:
  Some of these tools can be applied to both raw and trimmed reads (e.g.,
  FastQC), others are useful to aggregate multiple results from previous
  analysis tools (e.g., MultiQC), others have to be used after read alignment
  (e.g., QualiMap), and, finally, some of them (such as PCA) are only suited for
  post-quantification data (i.e., for counts).
EOM

# Show analysis progress printing the tail of the latest log
function _progress_qcfastq {

	target_dir="$(realpath "$1")"
	if [[ ! -d "$target_dir" ]]; then
		printf "Bad DATADIR path '$target_dir'.\n"
		exit 2 # Argument failure exit status: bad target path
	fi

	# NOTE: In the 'find' command below, the -printf "%T@ %p\n" option prints
	#       the modification timestamp followed by the filename.
	#       The '-f 2-' option in 'cut' is used to take all the fields after
	#       the first one (i.e., the timestamp) to avoid cropping possible
	#       filenames or paths with spaces.
	latest_log="$(find "$target_dir" -maxdepth 1 -type f -iname "Z_QC_*.log" \
		-printf "%T@ %p\n" | sort -n | tail -n 1 | cut -d " " -f 2-)"

	if [[ -n "$latest_log" ]]; then
		
		tool=$(basename "$latest_log" \
			| sed "s/^Z_QC_//" | sed "s/_.*\.log$//")
		printf "\n$tool log file detected: $(basename "$latest_log")"
		printf "\nin: '$(dirname "$latest_log")'\n"

		case "$tool" in
			PCA)
				cat "$latest_log"
			;;
			FastQC)
				printf "\n${grn}Completed:${end}\n"
				grep -F "Analysis complete" "$latest_log" || [[ $? == 1 ]]
				printf "\n${yel}In progress:${end}\n"
				completed=$(tail -n 1 "$latest_log" \
					| grep -F "Analysis complete" || [[ $? == 1 ]])
				[[ -z $completed ]] && tail -n 1 "$latest_log"
			;;
			MultiQC)
				cat "$latest_log"
			;;
			QualiMap)
				echo "QualiMap selected. TO BE DONE..."
			;;
		esac
		exit 0 # Success exit status
	else
		printf "No QC log file found in '$target_dir'.\n"
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
				printf "%s\n" "$_help_qcfastq"
				exit 0 # Success exit status
			;;
			-v | --version)
				figlet qc FASTQ
				printf "Ver.$ver :: The Endothelion Project :: by FeAR\n"
				exit 0 # Success exit status
			;;
			-p | --progress)
				# Cryptic one-liner meaning "$2", or $PWD if argument 2 is unset
				_progress_qcfastq "${2:-.}"
			;;
			-q | --quiet)
				verbose=false
				shift
			;;
			--suffix*)
				# Test for '=' presence
				rgx="^--suffix="
				if [[ "$1" =~ $rgx ]]; then
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
				rgx="^--tool="
				if [[ "$1" =~ $rgx ]]; then
					tool="${1/--tool=/}"
					# Check if a given string is an element of an array.
					# NOTE: leading and trailing spaces around array elements
					#       are used to ensure accurate pattern matching!
					if [[ " $(_get_qc_tools names) " == *" ${tool} "* ]]; then
						shift
					else
						printf "Invalid QC tool name: '$tool'.\n"
						printf "Please, choose among the following options:\n"
						for i in $(_get_qc_tools names); do
							printf "  -  $i\n"
						done
						exit 5
					fi
				else
					printf "Values need to be assigned to '--tool' option "
					printf "using the '=' operator.\n"
					printf "Use '--help' or '-h' to see the correct syntax.\n"
					exit 6 # Bad tool assignment
				fi
			;;
			--out*)
				# Test for '=' presence
				rgx="^--out="
				if [[ "$1" =~ $rgx ]]; then
					out_dirname="$(basename "${1/--out=/}")"
					shift
				else
					printf "Values need to be assigned to '--out' option "
					printf "using the '=' operator.\n"
					printf "Use '--help' or '-h' to see the correct syntax.\n"
					exit 7 # Bad out_dirname assignment
				fi
			;;
			*)
				printf "Unrecognized option flag '$1'.\n"
				printf "Use '--help' or '-h' to see possible options.\n"
				exit 8 # Argument failure exit status: bad flag
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
	exit 9 # Argument failure exit status: missing DATADIR
elif [[ ! -d "$target_dir" ]]; then
	printf "Invalid target directory '$target_dir'.\n"
	exit 10 # Argument failure exit status: invalid DATADIR
fi

# Argument check: QCTYPE tool
# NOTE: enclosing a command (which) within a conditional block allows excluding
#       it from the 'set -e' behavior. Otherwise, testing for "$? -ne 0" right
#       after the 'which' statement would have stopped the run (with no error
#       messages!) in the case of command failure (e.g., no tool installed).
if which "$(_name2cmd $tool)" > /dev/null 2>&1; then
	# The command was made globally available: no leading path is needed
	tool_path=""
else
	# Search the 'install.paths' file for it.
	# NOTE: Mind the final slash! It has to be included in 'tool_path' variable
	#       so that it does not appear when calling a globally visible QC tool
	#       (tool_path="").
	tool_path="$(grep -i "$(hostname):${tool}:" \
		"${xpath}/install.paths" | cut -d ':' -f 3 || [[ $? == 1 ]])"/

	if [[ ! -f "${tool_path}$(_name2cmd $tool)" ]]; then
		printf "$tool not found...\n"
		printf "Install $tool and update the 'install.paths' file,\n"
		printf "or make it globally visible by creating a link to "
		printf "\'$(_name2cmd $tool)\' in some \$PATH folder.\n"
		exit 11 # Argument failure exit status: tool not found
	fi
fi

# --- Main program -------------------------------------------------------------

# When creating the log file, 'basename "$target_dir"' assumes that DATADIR
# was properly named with the current Experiment_ID
log_file="${target_dir}/Z_QC_${tool}_$(basename "$target_dir")_$(_tstamp).log"

output_dir="${target_dir}/${out_dirname:-"${tool}_out"}"
mkdir "$output_dir" # Stop here if it already exists !!! (exit status 1)

_dual_log $verbose "$log_file" "\n\
	Running $tool tool in background
	Calling: ${tool_path}$(_name2cmd $tool)
	Saving output in $output_dir"

case "$tool" in
	PCA)
		nohup Rscript "${xpath}"/cc_pca.R \
			"${suffix:-".tsv"}" "$output_dir" "$target_dir" \
			>> "$log_file" 2>&1 &
	;;
	FastQC)
		suffix="${suffix:-".fastq.gz"}"
		counter=$(find "$target_dir" -type f -name "*$suffix" | wc -l)
		if (( counter > 0 )); then
			
			_dual_log $verbose "$log_file" "\n\
				Found $counter FASTQ files ending with \"${suffix}\" \
				in $target_dir."
			
			# FastQC recognizes multiple files with the use of wildcards
			nohup ${tool_path}fastqc -o "$output_dir" \
				"$target_dir"/*"$suffix" >> "$log_file" 2>&1 &
		else
			_dual_log true "$log_file" "\n\
				There are no FASTQ files ending with \"${suffix}\" \
				in $target_dir.\n\
				Stop Execution."
			rmdir "$output_dir"
			exit 12 # Argument failure exit status: no FASTQ found
		fi
	;;
	MultiQC)
		nohup ${tool_path}multiqc -o "$output_dir" "$target_dir" \
			>> "$log_file" 2>&1 &
	;;
	QualiMap)
		echo "QualiMap selected. STILL TO BE DONE..."
	;;
esac
