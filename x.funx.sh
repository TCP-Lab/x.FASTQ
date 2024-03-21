#!/bin/bash

# ==============================================================================
#  Collection of general utility variables, settings, and functions for x.FASTQ
# ==============================================================================
xfunx_ver="1.7.1"

# This special name is not to overwrite scripts' own 'ver' when sourced...
# ...and at the same time being compliant with the 'x.fastq -r' option!

# --- Global settings ----------------------------------------------------------

# Strict mode options
set -e           # "exit-on-error" shell option
set -u           # "no-unset" shell option
set -o pipefail  # exit on within-pipe error
set -o errtrace  # ERR trap inherited by shell functions

# For a friendlier use of colors in Bash
red=$'\e[1;31m' # Red
grn=$'\e[1;32m' # Green
yel=$'\e[1;33m' # Yellow
blu=$'\e[1;34m' # Blue
mag=$'\e[1;35m' # Magenta
cya=$'\e[1;36m' # Cyan
end=$'\e[0m'

# Set up the line tracker using the DEBUG trap.
# The command 'master_line=$LINENO' will be executed before every command in the
# script (upon x.funx.sh sourcing) to keep track of the line that is being run
# at each time (stored in the global variable 'master_line').
trap 'master_line=$LINENO' DEBUG

# Set up error handling
trap '_interceptor "$0" $master_line "${#PIPESTATUS[@]}" \
                   ${FUNCNAME:-__main__} "$BASH_SOURCE" $LINENO ' ERR
function _interceptor {
    local err_exit=$?
    local master_script="$(realpath "$1")"
    local master_line_number="$2"
    local pipe_status="$3"
    if [[ $pipe_status -eq 1 ]]; then
        local func_name="$4"
    else
        # Can't penetrate the pipes...
        local func_name="pipe in $4";
    fi
    local source_script="$(realpath "$5")"
    local line_number="$6"

    printf "\n${mag}ERROR occurred in ${cya}$(basename "${master_script}")${end}\n"
    printf " │\n"
    printf " ├── ${mag}Full path: ${cya}${master_script}${end}\n"
    printf " ├── ${mag}Occurring line: ${cya}${master_line_number}${end}\n"
    printf " ├── ${mag}Triggering function: ${cya}${func_name}${end}\n"
    printf " │    │\n"
    printf " │    ├── ${mag}Defined in: ${cya}${source_script}${end}\n"
    printf " │    └── ${mag}Error line: ${cya}${line_number}${end}\n"
    printf " │\n"
    printf " └── ${mag}Exit status: ${cya}${err_exit}${end}\n"

    exit $err_exit
}

# --- Function definition ------------------------------------------------------

# Prints current date and time in "yyyy.mm.dd_HH.MM.SS" format.
#
# USAGE:
#   _tstamp
function _tstamp {
    local now="$(date +"%Y.%m.%d_%H.%M.%S")"
    echo $now
}

# On-screen and to-file logging function.
# Always redirects the message to log_file; additionally, redirects the message
# also to standard output (i.e., print on screen) if $verbose == true. Allows
# multi-line messages and escape sequences. 
#
# USAGE:
#   _dual_log $verbose "$log_file" \
#       "multi"\
#       "line"\
#       "message."
function _dual_log {
    
    local verbose="$1"
    local log_file="$(realpath "$2")"
    shift 2
    
    if ${verbose}; then
        printf "%b\n" "$@" | tee -a "$log_file"
    else
        printf "%b\n" "$@" >> "$log_file"
    fi
}

# Makes the two alternatives explicit from an OR regex pattern.
# Expect input pattern format:
#
#   "leading_str(alt_1|alt_2)trailing_str"
#
# Returns:
#
#   "leading_stralt_1trailing_str,leading_stralt_2trailing_str"
#
# USAGE:
#   _explode_ORpattern "OR_PATTERN"
function _explode_ORpattern {

    local pattern="$1"

    # Alternative 1: remove from the beginning to (, and from | to the end
    local alt_1="$(echo "$pattern" | sed -E "s/.*\(|\|.*//g")"
    # Alternative 2: remove from the beginning to |, and from ) to the end
    local alt_2="$(echo "$pattern" | sed -E "s/.*\||\).*//g")"

    # Build the two suffixes
    local suffix_1="$(echo "$pattern" | sed -E "s/\(.*\)/${alt_1}/g")"
    local suffix_2="$(echo "$pattern" | sed -E "s/\(.*\)/${alt_2}/g")"

    # Return them through echo, separated by a comma
    echo "${suffix_1},${suffix_2}"
}

# Takes one of the two arguments "names" or "cmds" and returns an array
# containing either the names or the corresponding Bash commands of the QC tools
# currently implemented in 'qcfastq.sh'.
#
# USAGE:
#   _get_qc_tools names
#   _get_qc_tools cmds
function _get_qc_tools {
    
    # Name-command corresponding table
    local tool_name=("FastQC" "MultiQC" "QualiMap" "PCA")
    local tool_cmd=("fastqc" "multiqc" "-NA-" "Rscript")

    if [[ "$1" == "names" ]]; then
        echo "${tool_name[@]}"
    elif [[ "$1" == "cmds" ]]; then
        echo "${tool_cmd[@]}"
    else
        echo "Not a feature!"
        exit 1
    fi
}

# Takes one of the two arguments "names" or "cmds" and returns an array
# containing either the names or the corresponding Bash commands of the RNA-Seq
# software required by x.FASTQ.
#
# USAGE:
#   _get_seq_sw names
#   _get_seq_sw cmds
function _get_seq_sw {
    
    # Name-command corresponding table
    local seq_name=("BBDuk" "STAR" "RSEM")
    local seq_cmd=("bbduk.sh" "STAR" "rsem-calculate-expression")

    if [[ "$1" == "names" ]]; then
        echo "${seq_name[@]}"
    elif [[ "$1" == "cmds" ]]; then
        echo "${seq_cmd[@]}"
    else
        echo "Not a feature!"
        exit 1
    fi
}

# Converts the name of a software to the corresponding Bash command suitable for
# execution.
#
# USAGE:
#   _name2cmd SOFTWARE_NAME
function _name2cmd {

    # Concatenate arrays
    local all_name=($(_get_qc_tools "names") $(_get_seq_sw "names") "Java" "Python" "R")
    local all_cmd=($(_get_qc_tools "cmds") $(_get_seq_sw "cmds") "java" "python" "R")

    # Looping through array indices
    local index=-1
    for i in ${!all_name[@]}; do
        if [[ "${all_name[$i]}" == "$1" ]]; then
            index=$i
            break
        fi
    done

    # Return the result
    if [[ $index -ge 0 ]]; then
        echo ${all_cmd[$index]}
    else
        echo "Element '$1' not found in the array!"
        exit 1
    fi
}

# It's the final countdown!
# Performs a countdown with a final blast proportional to the loading time
# entered by the user (as an integer).
#
# USAGE:
#   _count_down TIME
function _count_down {
    echo
    local n=$1
    for (( i = 0; i < n; i++ )); do
        printf "    "
        printf %$((i+1))s | tr " " "."
        printf $((n-i))
        printf "\r"
        sleep 1
    done
    printf "    "
    printf "B"
    printf %$((n-1))s | tr " " "o"
    printf "M! \r"
    sleep 1
}

# Gets an estimate (based on the first 100 reads) of the average length of the
# reads within the FASTQ file passed as the only input.
#
# USAGE:
#   _mean_read_length "$fastq_file"
function _mean_read_length {

    local fastq_file="$(realpath "$1")"

    local tot=0
    for (( i = 1; i <= 100; i++ )); do
        line=$(( 4*i - 2)) # Select the FASTQ lines that contains the reads
        r_length=$(zcat "$fastq_file" | head -n 400 | sed -n "${line}p" | wc -c)
        tot=$(( tot + r_length - 1 )) # -1 because of the 'new line' from sed
    done

    # Ceiling: check if there should be a fractional part
    if [[ $tot =~ 00$ ]]; then
        ceiling_val=$(( tot/100 ))
    else
        ceiling_val=$(( tot/100 + 1 ))
    fi

    echo $ceiling_val
}

# Simply repeats (prints) a character (or a string) N times.
#
# USAGE:
#   _repeat CHAR N
function _repeat {
    local character="$1"
    local count="$2"
    for (( i = 0; i < "$count"; i++ )); do
        echo -n "$character"
    done
}

# Simple Tree Assistant - Helps drawing a tree-like structure, by converting a
# a pattern of keyboard-inputable characters into a well-shaped tree element.
# Allowed input characters are     
#   |       break               rendered into a     backbone-only element
#   |-      bar hyphen          rendered into a     regular leaf element
#   |_      bar underscore      rendered into a     terminal leaf element
#   " "     space               rendered into a     coherent blank element
# In addition, it appends an optional text string at the end of the tree element
# as a leaf label. 
#
# USAGE:
#   _arm "PATTERN" "leaf-label_string"
function _arm {

    # Indentation settings
    local in_0="$(_repeat " " 1)"   # Global offset
    local in_1="$(_repeat " " 3)"   # Arm length

    # Auto space filler for the backbone-only element ('|')
    local in_2_length=$(( ${#in_1} - 1 ))
    local in_2="$(_repeat " " $in_2_length)"

    # Draw the tree!
    printf "${in_0}"
    printf "$1" | \
    sed "s% %${in_1}%g" | \
    sed "s%|-%├──%g" | \
    sed "s%|_%└──%g" | \
    sed "s%|%│${in_2}%g"
    printf "${2:-}\n"
}

# 'printf' the string within a field of fixed length (tabulate-style).
# Allows controlling tab-stop positions by padding the given string with white
# spaces to reach a fixed width.
#
# USAGE:
#   _printt N "any_string"
function _printt {
    local tab_length=$1
    local word_length=${#2}
    local fill=$(( tab_length - word_length ))

    printf "${2}$(_repeat " " ${fill})"
}

# Implements a set of heuristic rules to grab the version of a given software
# passed as the full path of its executable file (or just its command-line name
# in case of software available in $PATH).
#
# USAGE:
#   _get_ver SOFTWARE_NAME
function _get_ver {
    local ref="$1"
    local cmd="$(basename "$1")"
    local parent="$(basename "$(dirname "/$1")")"
    
    local version="$("$ref" --version 2> /dev/null | head -n 1 \
        | sed -E "s%(${cmd}|${parent}|v|ver|version|current)%%gI" \
        | sed -E 's%^[ \.\,-:]*%%')"

    [[ -z "$version" ]] && version="_NA_"
    printf "$version"
}
