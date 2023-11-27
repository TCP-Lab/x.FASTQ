#!/bin/bash

# ============================================================================ #
#  FASTQ Quality Control
# ============================================================================ #

# --- General settings and variables -------------------------------------------

set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# --- Function definition ------------------------------------------------------

# Default options
ver="1.4.1"
verbose=true
tool="FastQC"

# Source functions from x.funx.sh
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/x.funx.sh

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
	echo "                   extension) used by qcFASTQ for selecting the files"
	echo "                   to analyze. The default for FastQC is \".fastq.gz\","
	echo "                   while for PCA is \".tsv\". This argument is ignored"
	echo "                   by the other tools."
	echo "  --tool=QCTYPE    QC software tool to be used. Currently implemented"
	echo "                   options are FastQC (default), MultiQC, QualiMap,"
	echo "                   and PCA. Tools are supposed to be preinstalled by"
	echo "                   the user and made globally available. As an"
	echo "                   alternative, they can be placed in any directory"
	echo "                   (even if not included in \$PATH) and made visible"
	echo "                   to qcfastq only by editing 'install.paths'."
	echo "  --out=NAME       The name of the output folder. The default name is"
	echo "                   \"QCTYPE_out\". Only a folder NAME is required,"
	echo "                   not its entire path; if a full path is provided,"
	echo "                   only its 'basename' will be used. In any case, the"
	echo "                   script will attempt to create a new folder as a"
	echo "                   sub-directory of the TARGETS folder; if it already"
	echo "                   exists the whole process is aborted to avoid"
	echo "                   overwriting possible previous reports."
	echo "  TARGETS          The path to the folder containing the files to"
	echo "                   be analyzed. Unlike MultiQC, FastQC and PCA are"
	echo "                   not designed to search sub-directories."
	echo
	echo "Additional Notes:"
	echo "  Some of these tools can be applied to both raw and trimmed reads"
	echo "  (e.g., FastQC), others are useful to aggregate multiple results"
	echo "  from previous analysis tools (e.g., MultiQC), others have to be"
	echo "  used after read alignment (e.g., QualiMap), and, finally, some of"
	echo "  them (such as PCA) are only suited for post-quantification data"
	echo "  (i.e., for counts)."
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
	latest_log=$(find "${target_dir}" -maxdepth 1 -type f -iname "Z_QC_*.log" \
		-printf "%T@ %p\n" | sort -n | tail -n 1 | cut -d " " -f 2)

	if [[ -n "$latest_log" ]]; then
		
		tool=$(basename "$latest_log" \
			| sed -E "s/^Z_QC_//" | sed -E "s/_.*\.log$//")
		printf "\n$tool log file detected:\n${latest_log}\n"

		case "$tool" in
			PCA)
				cat "${latest_log}"
			;;
			FastQC)
				printf "\n${grn}Completed:${end}\n"
				grep --no-filename "Analysis complete" "${latest_log}" \
					|| [[ $? == 1 ]]
				
				printf "\n${yel}Tails:${end}\n"
				tail -n 1 "${latest_log}"
			;;
			MultiQC)
				cat "${latest_log}"
			;;
			QualiMap)
				echo "QualiMap selected. TO BE DONE..."
			;;
		esac
		exit 0 # Success exit status
	else
		printf "No QC log file found in '$(realpath "$target_dir")'.\n"
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
					if [[ " $(_get_qc_tools "names") " == *" ${tool} "* ]]; then
						shift
					else
						printf "Invalid QC tool name: '${tool}'.\n"
						printf "Please, choose among the following options:\n"
						for i in $(_get_qc_tools "names"); do
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
					out_dirname="${1/--out=/}"
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
# NOTE: enclosing a command (which) within a conditional block allows excluding
#       it from the 'set -e' behavior. Otherwise, testing for "$? -ne 0" right
#       after the 'which' statement would have stopped the run (with no error
#       messages!) in the case of command failure (e.g., no tool installed).
if which "$(_name2cmd ${tool})" > /dev/null 2>&1; then
	# The command was made globally available: no leading path is needed
	tool_path=""
else
	# Search the 'install.paths' file for it.
	# NOTE: Mind the final slash! It has to be included in 'tool_path' variable
	#       so that it does not appear when the command to launch the QC tool is
	#       globally visible (tool_path="").
	tool_path="$(grep -i "$(hostname):${tool}:" \
		"${xpath}/install.paths" | cut -d ':' -f 3)"/

	if [[ ! -f "${tool_path}$(_name2cmd ${tool})" ]]; then
		printf "${tool} not found...\n"
		printf "Install ${tool} and update the 'install.paths' file,\n"
		printf "or make it globally visible creating a link to "
		printf "\'$(_name2cmd ${tool})\' in some \$PATH folder.\n"
		exit 1 # Argument failure exit status: tool not found
	fi
fi

# --- Main program -------------------------------------------------------------

target_dir="$(realpath "$target_dir")"
log_file="${target_dir}"/Z_QC_"${tool}"_"$(basename "$target_dir")"_$(_tstamp).log

# Existence operator ${:-} <=> ${user-defined_name:-default_name}
output_dir="${target_dir}/${out_dirname:-"${tool}_out"}"
mkdir "$output_dir" # Stop here if it already exists !!!

_dual_log $verbose "$log_file" "\n\
	Running ${tool} tool in background
	Calling: ${tool_path}$(_name2cmd ${tool})
	Saving output in ${output_dir}"

case "$tool" in
	PCA)
		nohup Rscript "${xpath}"/cc_pca.R \
			"${suffix:=".tsv"}" "${output_dir}" "${target_dir}" \
			>> "$log_file" 2>&1 &
	;;
	FastQC)
		suffix="${suffix:-".fastq.gz"}"
		counter=$(ls "${target_dir}"/*"${suffix}" 2>/dev/null | wc -l)
		if (( counter > 0 )); then
			
			_dual_log $verbose "$log_file" "\n\
				Found $counter FASTQ files ending with \"${suffix}\" \
				in ${target_dir}."
			
			target_files=$(find "$target_dir" -maxdepth 1 -type f \
				-iname "*$suffix")
			
			nohup ${tool_path}fastqc -o "${output_dir}" ${target_files} \
				>> "$log_file" 2>&1 &
		else
			_dual_log true "$log_file" "\n\
				There are no FASTQ files ending with \"${suffix}\" \
				in ${target_dir}.\n\
				Stop Execution."
			rmdir "$output_dir"
			exit 11 # Argument failure exit status: no FASTQ found
		fi
	;;
	MultiQC)
		nohup ${tool_path}multiqc -o "${output_dir}" "${target_dir}" \
			>> "$log_file" 2>&1 &
	;;
	QualiMap)
		echo "QualiMap selected. STILL TO BE DONE..."
	;;
esac
