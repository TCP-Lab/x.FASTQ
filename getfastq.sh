#!/bin/bash

# ==============================================================================
#  Get FASTQ Files from ENA Database
# ==============================================================================
ver="1.7.0"

# --- Source common settings and functions -------------------------------------

# Source functions from x.funx.sh
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/x.funx.sh

# --- Help message -------------------------------------------------------------

read -d '' _help_getfastq << EOM || true
This script uses an alternative implementation of the 'nohup' command to
schedule a persistent download queue of FASTQ files from the ENA database via
HTTP, based on the target addresses passed as input (in the form provided by ENA
Browser when using the 'Get download script' button). Both sequential and
parallel download modes are allowed and, by default, all FASTQs are checked for
integrity after download by using MD5 hashes.

Usage:
  getfastq [-h | --help] [-v | --version]
  getfastq -p | --progress [TARGETS]
  getfastq -k | --kill
  getfastq -u | --urls PRJ_ID [> TARGETS]
  getfastq [-q | --quiet] [-m | --multi] [--no-checksum] TARGETS

Positional options:
  -h | --help      Shows this help.
  -v | --version   Shows script's version.
  -p | --progress  Shows TARGETS downloading progress by 'tail-ing' and
                   'grep-ing' ALL the getFASTQ log files (including those
                   currently growing). If TARGETS is not provided, it searches
                   \$PWD for getFASTQ logs.
  -k | --kill      Gracefully (-15) kills all the 'wget' processes currently
                   running and started by the current user.
  -u | --urls      Fetches from ENA the list of FTP download URLs for the full
                   set of Runs (i.e., FASTQ files) making up a given BioProject.
                   Note that this job is never run in the background. Also, by
                   default, the 'wget' output lines are just sent to stdout. To
                   save them locally and use them later as a TARGETS file, it is
                   then necessary to redirect the output somewhere (i.e., append
                   the statement '> TARGETS' to the command). Other possible
                   messages are sent to stderr.
  PRJ_ID           Placed right after the '-u | --urls' flag, is any valid
                   BioProject accession number as issued by the INSDC and used
                   in ENA to identify the Study whose Runs are to be retrieved
                   (e.g., "PRJNA141411"). GEO Series IDs (i.e., "GSE29580") are
                   also allowed and automatically converted to ENA/INSDC
                   BioProject IDs beforehand.
  -q | --quiet     Disables verbose on-screen logging.
  -m | --multi     Multi process option. A separate download process will be
                   instantiated in background for each target FASTQ file at
                   once, resulting in a parallel download of all the TARGETS
                   files. While the default behavior is the sequential download
                   of the individual FASTQs, using '-m' option can result in a
                   much faster global download process, especially in case of
                   broadband internet connections.
  --no-checksum    Attempts each download once and ignores the checksum.
  TARGETS          Path to the text file (as provided by ENA Browser) containing
                   the 'wgets' to be scheduled. Placed right after '-p' option,
                   it is the (file or folder) path where to look for getFASTQ
                   progress logs.

Additional Notes:
  . Target addresses need to be converted to HTTP because of the limitations on
    FTP imposed by UniTo. Luckily, this can be done simply by replacing 'ftp'
    with 'http' in each URL to wget, thanks to the great versatility of the ENA
    Browser.
  . Use
      watch getfastq -p
      watch -cn 0.5 'getfastq -p [TARGETS]'
    to follow the growth of a log file in real time.
  . While the 'getfastq -k' option tries to gracefully kill ALL the currently
    active 'wget' processes started by \$USER, you may wish to selectively kill
    just some of them (possibly forcefully) after you retrieved their IDs
    through 'pgrep -l -u "\$USER"'.
  . To download an entire BioProject (aka Study or Series) you need a two-step
    procedure. E.g.:
      getfastq --urls PRJNA141411 > PRJNA141411_wgets.sh
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
    
    # An array for all the log files inside target_dir
    declare -a logs=()
    readarray -t logs < <(find "$target_dir" -maxdepth 1 \
        -type f -iname "Z_getFASTQ_*.log")
    if [[ "${#logs[@]}" -eq 0 ]]; then
        printf "No getFASTQ log file found in '${target_dir}'.\n"
        exit 2 # Argument failure exit status: missing log
    fi

    # Parse logs and heuristically capture download status
    declare -a completed=()
    declare -a failed=()
    declare -a incoming=()
    for log in "${logs[@]}"; do
        # Note the order of the following capturing blocks. It matters.
        test_failed=$(grep -E \
            ".+Terminated| unable to |Not Found.|Unable to " \
            "$log" || [[ $? == 1 ]])
        if [[ -n $test_failed ]]; then
            failed+=("$(echo "$test_failed" | rev | cut -d$'\r' -f 1 | rev)")
            continue
        fi
        test_incoming=$(tail -n 1 "$log" | grep -E "%\[=*>? *\] " \
            || [[ $? == 1 ]])
        if [[ -n $test_incoming ]]; then
            incoming+=("$(echo "$test_incoming" | rev | cut -d$'\r' -f 2 | rev)")
            continue
        fi
        test_completed=$(grep -E \
            " saved \[| already there;" \
            "$log" | tail -n 1 || [[ $? == 1 ]])
        if [[ -n $test_completed ]]; then
            completed+=("$test_completed")
        fi
    done

    # Report findings
    printf "\n${grn}Completed:${end}\n"
    if [[ ${#completed[@]} -eq 0 ]]; then
        printf "  - No completed items!\n"
    else
        for item in "${completed[@]}"; do
            echo "  - ${item}"
        done
    fi
    printf "\n${red}Failed:${end}\n"
    if [ ${#failed[@]} -eq 0 ]; then
        printf "  - No failed items!\n"
    else
        for item in "${failed[@]}"; do
            echo "  - ${item}"
        done
    fi
    printf "\n${yel}Incoming:${end}\n"
    if [ ${#incoming[@]} -eq 0 ]; then
        printf "  - No incoming items!\n"
    else
        for item in "${incoming[@]}"; do
            echo "  - ${item}"
        done
    fi
    exit 0 # Success exit status
}

# --- Argument parsing ---------------------------------------------------------

# Default options
verbose=true
download_mode=sequential
integrity=true

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
                _print_ver "get FASTQ" "${ver}" "Hedmad & FeAR"
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
                    # BioProject Accession ID Regex Patterns
                    ena_rgx="^PRJ(E|D|N)[A-Z][0-9]+$"
                    geo_rgx="^GSE[0-9]+$"
                    # If GEO ID, then convert to ENA/INSDC
                    if [[ $2 =~ $geo_rgx ]]; then
                        ena_accession_id=$(_geo2ena_id ${2})
                        if [[ $ena_accession_id == NA ]]; then
                            printf "Cannot convert GEO Series ID to ENA alias..."
                            exit 3 # ID conversion failure
                        fi
                        printf "GEO Series ID detected and converted to the ENA/INSDC BioProject ID: " >&2
                        printf "$2 --> ${ena_accession_id}\n" >&2
                    elif [[ $2 =~ $ena_rgx ]]; then
                        ena_accession_id=$2
                        printf "ENA/INSDC BioProject ID detected: ${ena_accession_id}\n" >&2
                    else
                        printf "Invalid BioProject ID ${2}.\n"
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
                download_mode=parallel
                shift
            ;;
            --no-checksum)
                integrity=false
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
        shift
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

# Verbose on-screen logging
if $verbose; then
    printf "getFASTQ :: NGS Read Retriever :: ver.${ver}\n\n"
    echo "========================"
    if [[ $download_mode == sequential ]]; then
        echo "| Sequential Job Queue |"
    else
        echo "|  Parallel Job Queue  |"
    fi
    echo "========================"

    counter=1
    while IFS= read -r line
    do
        # Bash-native string substitution syntax to change FTP into HTTP
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
target_dir="$(dirname "$target_file")"
sed "s|ftp:|--progress=bar:force -P ${target_dir//" "/"\\\ "} http:|g" \
    "$target_file" > "$target_file_tmp"

# Reimplementation of nohup (in background) that also applies to functions.
function _NUhup { (trap '' HUP; "$@" &) }

# This function is triggered by '_process_series' and takes a single wget-FASTQ
# target, along with its expected MD5 hash as fetched from ENA, in order to
# (i) perform the actual download of the FASTQ file, (ii) check its integrity by
# MD5 checksum, (iii) retry the download three times if checksum fails.
function _process_sample {

    local eval_str="$1"
    local target="$(basename "$eval_str")"
    local checksum="$2"
    local attempt=1

    if [[ $integrity == true ]]; then
        while true; do
            printf "Spawning download worker for $target "
            printf "with checksum $checksum (attempt ${attempt})\n"
            bash -c "$eval_str"
            
            local local_hash=$(cat "$target" | md5sum | cut -d' ' -f1)
            printf "Computed hash: $local_hash - "
            if [[ $checksum == $local_hash ]]; then
                printf "Success!\n"
                return
            else
                printf "FAILURE! Deleting corrupt file...\n"
                rm $target
                if [[ $attempt -lt 3 ]]; then
                    printf "File was corrupted in transit. Trying again.\n\n"
                    attempt=$((attempt+1))
                else
                    printf "Unable to download $target - corrupted checksum\n"
                    return
                fi
            fi
        done
    else
        printf "Spawning download worker for ${target}\n"
        bash -c "$eval_str"
    fi
}

# This function takes a file with a list of wget-FASTQ targets and, for each one
# of them, (i) makes a log file, (ii) retrieves from ENA the expected MD5 hash,
# (iii) prepares sample download by calling '_process_sample' function with the
# correct nohup setting, depending on the selected download mode.
function _process_series {

    local target_file_tmp="$1"
    local download_mode=$2

    while IFS= read -r line
    do
        # Set the log files (with the names of the samples)
        local sample_id="$(basename "$line" | sed -E "s/(\.fastq|\.gz)//g")"
        local log_file="${target_dir}/Z_getFASTQ_${sample_id}_$(_tstamp).log"
        _dual_log false "$log_file" "-- $(_tstamp) --" \
            "getFASTQ :: NGS Read Retriever :: ver.${ver}\n"
        
        # Remove possible PE read suffix and retrieve the real MD5 from ENA
        local ena_id=$(echo $sample_id | cut -d'_' -f1)
        local checksums=$(_fetch_ena_sample_hash $ena_id)
        if [[ $sample_id =~ ^.*_R?2$ ]]; then
            local checksum=$(echo $checksums | cut -d';' -f2)
        else
            local checksum=$(echo $checksums | cut -d';' -f1)
        fi

        # MAIN STATEMENT - "parallel" mode
        if [[ $download_mode == sequential ]]; then
            _process_sample "$line" "$checksum" >> "$log_file" 2>&1
        elif [[ $download_mode == parallel ]]; then
            _NUhup _process_sample "$line" "$checksum" >> "$log_file" 2>&1
        fi
    done < "$target_file_tmp"
}

# MAIN STATEMENT - "sequential" mode
if [[ $download_mode == sequential ]]; then
    _NUhup _process_series "$target_file_tmp" $download_mode
elif [[ $download_mode == parallel ]]; then
    _process_series "$target_file_tmp" $download_mode
fi
