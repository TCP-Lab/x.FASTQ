#!/bin/bash

# ==============================================================================
#  Get FASTQ Files from the ENA Database
# ==============================================================================
ver="1.5.0"

# --- Source common settings and functions -------------------------------------

# Source functions from x.funx.sh
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/x.funx.sh

# --- Minimal implementation ---------------------------------------------------

# Change false to true to toggle the 'minimal implementation' of the script
# (for debugging purposes only...)
if false; then
    printf "\n===\\\ Running minimal implementation \\\===\n"
    target_dir="$(dirname "$(realpath "$1")")"
    sed "s|ftp:|-P ${target_dir/" "/"\\\ "} http:|g" "$(realpath "$1")" \
        | nohup bash \
        > "${target_dir}/Z_getFASTQ_$(basename "$target_dir")_$(_tstamp).log" \
        2>&1 &
    exit 0
fi

# --- Help message -------------------------------------------------------------

read -d '' _help_getfastq << EOM || true
This script uses 'nohup' to schedule a persistent queue of FASTQ downloads from
ENA database via HTTP, based on the target addresses passed as input (in the
form provided by ENA Browser when using the 'Get download script' button).
Target addresses need to be converted to HTTP because of the limitations on FTP
imposed by UniTo. Luckily, this can be done simply by replacing 'ftp' with
'http' in each URL to wget, thanks to the great versatility of the ENA Browser.

Usage:
  getfastq [-h | --help] [-v | --version]
  getfastq -p | --progress [TARGETS]
  getfastq -k | --kill
  getfastq -u | --urls PRJ_ID [> TARGETS]
  getfastq [-q | --quiet] [-m | --multi] TARGETS

Positional options:
  -h | --help      Shows this help.
  -v | --version   Shows script's version.
  -p | --progress  Shows TARGETS downloading progress by 'tail-ing' and
                   'grep-ing' ALL the getFASTQ log files (including those
                   currently growing). If TARGETS is not specified, it searches
                   \$PWD for getFASTQ logs.
  -k | --kill      Gracefully (-15) kills all the 'wget' processes currently
                   running and started by the current user.
  -u | --urls      Fetches from ENA database the list of FTP download URLs for
                   the complete set of FASTQ files making up a given ENA
                   project. Note that this job is not run in the background.
                   Also, by default, 'wget' lines are just sent to stdout. To
                   save them locally and use them later as a TARGETS file, it is
                   then necessary to redirect the output somewhere (i.e., append
                   the statement '> TARGETS' to the command). Other possible
                   messages are sent to stderr.
  PRJ_ID           ENA or GEO accession number for the project whose download
                   URLs are to be retrieved (e.g., ENA ID: "PRJNA141411", or
                   GEO ID: "GSE29580"). GEO IDs will be converted to ENA IDs
                   beforehand.
  -q | --quiet     Disables verbose on-screen logging.
  -m | --multi     Multi process option. A separate download process will be
                   instantiated in background for each target FASTQ file at
                   once, resulting in a parallel download of all the TARGETS
                   files. While the default behavior is the sequential download
                   of the individual FASTQs, using '-m' option can result in a
                   much faster global download process, especially in case of
                   broadband internet connections.
  TARGETS          Path to the text file (as provided by ENA Browser) containing
                   the 'wgets' to be scheduled.

Additional Notes:
  . While the 'getfastq -k' option tries to gracefully kill ALL the currently
    active 'wget' processes started by \$USER, you may wish to selectively kill
    just some of them (possibly forcefully) after you retrieved their IDs
    through 'pgrep -l -u "\$USER"'.
  . Just add 'time' before the two 'nohup' statements to measure the total
    execution time and compare the performance of sequential and parallel
    download modalities.
  . To download an entire study you need a two-step procedure. E.g.:
      getfastq --urls PRJNA307652 > ./PRJNA141411_wgets.sh
      getfastq PRJNA141411_wgets.sh 
EOM

# --- Function definition ------------------------------------------------------

# Show download progress
function _progress_getfastq {

    if [[ -d "$1" ]]; then
        local target_dir="$(realpath "$1")"
    elif [[ -f "$1" ]]; then
        local target_dir="$(dirname "$(realpath "$1")")"
    else
        printf "Bad TARGETS path '$1'.\n"
        exit 1 # Argument failure exit status: bad target path
    fi

    local log_file="$(find "${target_dir}" \
        -maxdepth 1 -type f -iname "Z_getFASTQ_*.log")"

    if [[ -n "$log_file" ]]; then

        # NOTE: the -- is used here to indicate the end of 'bash' command
        #       options and the beginning of Bash script arguments.
        # NOTE: possible non-matching greps inside 'find ... -exec bash' won't
        #       break the script, even when 'set -e' is active.
        printf "\n${grn}Completed:${end}\n"
        find "${target_dir}" -maxdepth 1 -type f -iname "Z_getFASTQ_*.log" \
            -exec bash -c '
                grep -E " saved \[| already there;" "$1"
            ' -- {} \;

        printf "\n${red}Failed:${end}\n"
        find "${target_dir}" -maxdepth 1 -type f -iname "Z_getFASTQ_*.log" \
            -exec bash -c '
                grep -E ".+Terminated| unable to |Not Found." "$1"
            ' -- {} \;

        printf "\n${yel}Incoming:${end}\n"
        find "${target_dir}" -maxdepth 1 -type f -iname "Z_getFASTQ_*.log" \
            -exec bash -c '
                dead_track=$(tail -n 3 "$1" | grep -E \
                    " saved \[| already there;|Terminated|unable to|Not Found")
                [[ -z $dead_track ]] && tail -n 1 "$1" && echo
            ' -- {} \;
        exit 0 # Success exit status
    else
        printf "No getFASTQ log file found in '${target_dir}'.\n"
        exit 2 # Argument failure exit status: missing log
    fi
}

# --- Argument parsing ---------------------------------------------------------

# Default options
verbose=true
sequential=true

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+$"

# Argument check: options
while [[ $# -gt 0 ]]; do
    if [[ "$1" =~ $frp ]]; then
        case "$1" in
            -h | --help)
                printf "%s\n" "$_help_getfastq"
                exit 0 # Success exit status
            ;;
            -v | --version)
                _print_ver "get FASTQ" "${ver}" "FeAR"
                exit 0 # Success exit status
            ;;
            -p | --progress)
                # Cryptic one-liner meaning "$2" or $PWD if argument 2 is unset
                _progress_getfastq "${2:-.}"
            ;;
            -k | --kill)
                k_flag="k_flag"
                while [[ -n "$k_flag" ]]; do
                    k_flag="$(pkill -15 -eu "$USER" "wget" || [[ $? == 1 ]])"
                    if [[ -n "$k_flag" ]]; then echo "${k_flag} gracefully"; fi
                done
                exit 0
            ;;
            -u | --urls)
                if [[ -n "${2:-}" ]]; then
                    # Project Accession ID Regex Patterns
                    ena_rgx="^PRJ[A-Z]{2}[0-9]+$"
                    geo_rgx="^GSE[0-9]+$"
                    # If GEO ID, then convert to ENA
                    if [[ $2 =~ $geo_rgx ]]; then
                        ena_accession_id=$(_geo2ena_id ${2})
                        if [[ $ena_accession_id == NA ]]; then
                            printf "Cannot convert GEO project ID to ENA alias..."
                            exit 3 # ID conversion failure
                        fi
                        printf "GEO ID detected, converted to ENA alias: " >&2
                        printf "$2 --> ${ena_accession_id}\n" >&2
                    elif [[ $2 =~ $ena_rgx ]]; then
                        ena_accession_id=$2
                        printf "ENA ID detected: ${ena_accession_id}\n" >&2
                    else
                        printf "Invalid project ID ${2}.\n"
                        printf "Unknown format.\n"
                        exit 4
                    fi
                    # Get download URLs from ENA 
                    _fetch_ena_project_json "$ena_accession_id" \
                        | _extract_download_urls
                    exit 0
                else
                    printf "Missing value for PRJ_ID.\n"
                    printf "Use '--help' or '-h' to see the expected syntax.\n"
                    exit 5 # Argument failure exit status: missing PRJ_ID
                fi
            ;;
            -q | --quiet)
                verbose=false
                shift
            ;;
            -m | --multi)
                sequential=false
                shift
            ;;
            *)
                printf "Unrecognized option flag '$1'.\n"
                printf "Use '--help' or '-h' to see possible options.\n"
                exit 6 # Argument failure exit status: bad flag
            ;;
        esac
    else
        # The first non-FRP sequence is taken as the TARGETS argument
        target_file="$(realpath "$1")"
        break
    fi
done

# Argument check: target file
if [[ -z "${target_file:-""}" ]]; then
    printf "Missing option or TARGETS file.\n"
    printf "Use '--help' or '-h' to see the expected syntax.\n"
    exit 7 # Argument failure exit status: missing TARGETS
elif [[ ! -f "$target_file" ]]; then
    printf "Invalid target file '${target_file}'.\n"
    exit 8 # Argument failure exit status: invalid TARGETS
fi

# --- Main program -------------------------------------------------------------

target_dir="$(dirname "$target_file")"

# Verbose on-screen logging
if $verbose; then
    printf "getFASTQ :: NGS Read Retriever :: ver.${ver}\n\n"
    echo "========================"
    if $sequential; then
        echo "| Sequential Job Queue |"
    else
        echo "|  Parallel Job Queue  |"
    fi
    echo "========================"

    counter=1
    while IFS= read -r line
    do
        # Using Bash-native string substitution syntax to change FTP into HTTP
        # ${string/$substring/$replacement}
        # NOTE: while `$substring` and `$replacement` are literal strings
        #       the starting `string` MUST be a reference to a variable name!
        fastq_name="$(basename "$line")"
        fastq_address="$(dirname ${line/wget* ftp:/http:})"

        echo
        echo "[${counter}]"
        echo "Downloading: $fastq_name"
        echo "From       : $fastq_address"

        ((counter++))
    done < "$target_file"
fi

# Make a temporary copy of TARGETS file, where:
# - FTP is replaced by HTTP;
# - wget's -P option is added to specify the target directory;
# - the progress bar is forced even if the output is not a TTY (see 'man wget');
# - possible spaces in paths are escaped to avoid issues in the next part.
target_file_tmp="$(mktemp)"
sed "s|ftp:|--progress=bar:force:noscroll -P ${target_dir/" "/"\\\ "} http:|g" \
    "$target_file" > "$target_file_tmp"

# In the code block below:
#
#   `nohup` (no hangups) allows processes to keep running even upon user logout
#       (e.g., when exiting an SSH session)
#   `>>` allows output to be redirected (and appended) somewhere other than the
#       default ./nohup.out file
#   `2>&1` is to redirect both standard output and standard error to the
#       getFASTQ log file
#   `&` at the end of the line, is, as usual, to run the command in the
#       background and get the shell prompt active again
#
if $sequential; then

    # Set the log file (with the name of the series)
    log_file="${target_dir}/Z_getFASTQ_$(basename "$target_dir")_$(_tstamp).log"
    _dual_log false "$log_file" "-- $(_tstamp) --" \
        "getFASTQ :: NGS Read Retriever :: ver.${ver}\n"

    # MAIN STATEMENT
    nohup bash "$target_file_tmp" >> "$log_file" 2>&1 &

else
    while IFS= read -r line
    do
        fast_name="$(basename "$line" | sed -E "s/(\.fastq|\.gz)//g")"

        # Set the log files (with the names of the samples)
        fast_name="$(basename "$line" | sed -E "s/(\.fastq|\.gz)//g")"
        log_file="${target_dir}/Z_getFASTQ_${fast_name}_$(_tstamp).log"
        _dual_log false "$log_file" "-- $(_tstamp) --" \
            "getFASTQ :: NGS Read Retriever :: ver.${ver}\n"
        
        ena_id=$(echo $fast_name | cut -d'_' -f1)
        checksums=$(_fetch_ena_sample_hash $ena_id)
        if [[ $fast_name == *"_2."* ]]; then
            checksum=$(echo $checksums | cut -d';' -f2)
        else
            checksum=$(echo $checksums | cut -d';' -f1)
        fi

        # MAIN STATEMENT
        nohup bash ${xpath}/getcheck.sh "$line" "culo" "$(basename "$line")" >> "$log_file" 2>&1 &
        # Originally, this was 'nohup bash -c "$line"', but it didn't print
        # the 'Terminated' string in the log file when killed by the -k option
        # (thus affecting in turn '_progress_getfastq'). So I used a
        # 'here string' to make the process equivalent to the sequential branch.
    done < "$target_file_tmp"
fi
