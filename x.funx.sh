#!/bin/bash

# ==============================================================================
#  Collection of general utility variables, settings, and functions for x.FASTQ
# ==============================================================================
xfunx_ver="1.10.0"

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
#       "multi" \
#       "line" \
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

# Gets an estimate (based on the first N/4 reads) of the average length of the
# reads within the FASTQ file passed as the only input.
#
# USAGE:
#   _mean_read_length "$fastq_file"
function _mean_read_length {

    local N=400
    local n_reads=$(( N/4 ))
    local sampling="$(mktemp)"

    # Here the general idea was simply this:
    #   zcat "$fastq_file" | head -n 400 > "$sampling"
    # however this fails because 'head' exits immediately with a zero status as
    # soon as it reaches line 400. The 'zcat' command is still writing to the
    # pipe, but there is no reader (because 'head' has exited), so it is sent a
    # SIGPIPE signal from the kernel and it exits with a status of 141.
    # Thus, the solution is not use a pipe, but use a process substitution:
    head -n $N <(zcat "$(realpath "$1")") > "$sampling"

    local tot=0
    for (( i = 1; i <= n_reads; i++ )); do
        # Select just the FASTQ lines that contain the reads
        local line=$(( 4*i - 2 ))
        local r_length=$(sed -n "${line}p" "$sampling" | wc -c)
        # Here below, -1 is because of the 'new line' character introduced by sed
        tot=$(( tot + r_length - 1 ))
    done

    # Ceiling: check if there should be a fractional part
    if [[ $tot =~ 00$ ]]; then
        ceiling_val=$(( tot/n_reads ))
    else
        ceiling_val=$(( tot/n_reads + 1 ))
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
#   |       bar                 rendered into a     backbone-only element
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
    printf "$1" \
        | sed "s% %${in_1}%g" \
        | sed "s%|-%├──%g" \
        | sed "s%|_%└──%g" \
        | sed "s%|%│${in_2}%g"
    printf "${2:-}\n"
}

# 'printf' the string within a field of fixed length (tabulate-style).
# Allows controlling tab-stop positions by padding the given string with white
# spaces to reach a fixed width. Note that this function does not handle
# possible new-line characters ('\n') within the string.
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

# Helper function to set the Message Of The Day (/etc/motd) during long-lasting
# alignment and quantification tasks
#
# USAGE:
#   _set_motd MESSAGE_PATH "action" "task"
function _set_motd {

    local message="$1"
    local action="${2:-}"
    local task="${3:-}"

    if [[ -e /etc/motd ]]; then
        if [[ -w /etc/motd ]]; then

            cat "${message}" \
                | sed "s/__action__/${action}/g" \
                | sed "s/__task__/${task}/g" \
                | sed "s/__time__/$(_tstamp)/g" > /etc/motd
        else

            printf "\nWARNING: Couldn't change the Message Of The Day...\n"
            printf "Current user has no write access to '/etc/motd'.\n"
            printf "Consider 'sudo chmod 666 /etc/motd'\n"
        fi
    else
        printf "\nWARNING: Couldn't change the Message Of The Day...\n"
        printf "'/etc/motd' file not found.\n"
        printf "Consider 'sudo touch /etc/motd; sudo chmod 666 /etc/motd'\n"
    fi
}

# Helper function to print the version (and optionally the author) of a script
# as nicely as it can be.
#
# USAGE:
#   _print_ver "software_name" "version" "author"
function _print_ver {

    local sw_name="$1"
    local version="${2:-}"
    local author="${3:-}"

    if [[ -n "$author" ]]; then
        local ver_str="Ver.${version} :: by ${author}"
    else
        local ver_str="Ver.${version}"
    fi

    local banner="$(mktemp)"
    
    if which figlet > /dev/null 2>&1; then
        figlet "$sw_name" > "$banner"
        local max_width=$(cat "$banner" | wc -L)
        local space_fill=$(( max_width - ${#ver_str} ))
        printf "$(_repeat " " ${space_fill})${ver_str}\n" >> "$banner"
    else
        # Bash (not regex) wildcard [ \'] to remove possible spaces and quotes
        printf "${sw_name//[ \']/} :: ${ver_str}\n" > "$banner"
    fi
    
    cat "$banner"
}

# Fetches the series file (SOFT formatted family file) containing the metadata
# of a given GEO project and prints to stdout.
#
# USAGE:
#   _fetch_series_file GEO_ID
function _fetch_geo_series_soft {
    local mask="$(echo "$1" | sed 's/...$/nnn/')"
    local url="https://ftp.ncbi.nlm.nih.gov/geo/series/${mask}/${1}/soft/${1}_family.soft.gz"

    wget -qnv -O - ${url} | gunzip
}

# Fetches a JSON file containing metadata of a given ENA project and prints to
# stdout. You can use 'jq .' in pipe to display a formatted output.
#
# USAGE:
#   _fetch_ena_project_json ENA_ID
#   _fetch_ena_project_json ENA_ID | jq .
function _fetch_ena_project_json {
    local vars="study_accession,sample_accession,run_accession,instrument_model,library_layout,read_count,study_alias,fastq_ftp,sample_alias,sample_title,first_created"
    local endpoint="https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${1}&result=read_run&fields=${vars}&format=json&limit=0"

    wget -qnv -O - ${endpoint}
}

# Takes as input an ENA run accession ID (e.g., SRR123456) and fetches from ENA
# DB the MD5 hash of the related FASTQ file, or the two semicolon-separated
# hashes (<hash_1>;<hash_2>) in the case of dual-file PE FASTQ.
#
# USAGE:
#   _fetch_ena_sample_hash ENA_ID
function _fetch_ena_sample_hash {
    local endpoint="https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${1}&result=read_run&fields=fastq_md5&format=json&limit=0"

    wget -qnv -O - ${endpoint} | jq -r '.[0].fastq_md5'
}

# Takes an ENA JSON from stdin, extracts a list of download URLs, and emits
# parsed lines to stdout in the same "getFASTQ-ready" format provided by the
# 'Get download script' button of ENA Browser (wget -nc ftp://...).
#
# USAGE:
#   cat JSON_TO_PARSE | _extract_download_urls
#   _fetch_ena_project_json ENA_ID | _extract_download_urls
function _extract_download_urls {
    # 1st 'sed' is to manage URLs of paired-end reads
    # 2nd 'sed' is to put the 'wget' command and the FTP in front of every link 
    jq -r '.[] | .fastq_ftp' | sed 's/;/\n/' | sed 's/^/wget -nc ftp:\/\//'
}

# Converts an ENA project ID to the corresponding GEO alias.
#
# USAGE:
#   _ena2geo_id ENA_ID
function _ena2geo_id {
    local geo_id=$(_fetch_ena_project_json $1 | jq -r '.[0] | .study_alias')
    if [[ $geo_id != null ]]; then
        echo $geo_id
    else
        # When either input is a invalid ENA_ID, or input is valid but a
        # GEO alias cannot be retrieved for some reason.
        echo  NA
    fi
}

# Converts a GEO project ID to the corresponding ENA alias.
#
# USAGE:
#   _geo2ena_id GEO_ID
function _geo2ena_id {
    local ena_id=$(_fetch_geo_series_soft $1 2> /dev/null \
        | grep -oP "PRJ[A-Z]{2}\d+" | head -n 1 || [[ $? == 1 ]])
    if [[ -n $ena_id ]]; then
        echo $ena_id
    else
        # When either input is a invalid GEO_ID, or input is valid but a
        # ENA alias cannot be retrieved for some reason.
        echo  NA
    fi
}
