#!/bin/bash

# ==============================================================================
#  Persistently Trim FastQ Files using BBDuk
# ==============================================================================
ver="1.4.0"

# --- Source common settings and functions -------------------------------------

# Source functions from x.funx.sh
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/x.funx.sh

# --- Help message -------------------------------------------------------------

read -d '' _help_trimfastq << EOM || true
This is a wrapper of 'trimmer.sh' script, designed to schedules a persistent (by
'nohup') queue of FASTQ adapter-trimming processes. Syntax and options are the
same for both 'trimfastq.sh' and 'trimmer.sh' (which is in turn a wrapper of
BBDuk trimmer) the only difference being that 'trimfastq' is designed to always
run persistently, in background, and more quietly than 'trimmer.sh'. In any
case, trimFASTQ can even be made completely silent by using the '-q' flag.

Here it follows the 'trimmer.sh --help':
EOM

# --- Argument parsing ---------------------------------------------------------

# Default options
verbose=true
progress=false

# Argument check: override -h, -v, -q, and -p option settings
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        printf "%s\n" "$_help_trimfastq"
        source "${xpath}"/trimmer.sh --help
        exit 0 # Success exit status
    elif [[ "$arg" == "-v" || "$arg" == "--version" ]]; then
        figlet trim FASTQ
        printf "Ver.${ver} :: ___________________________ :: by FeAR\n"
        exit 0 # Success exit status
    elif [[ "$arg" == "-q" || "$arg" == "--quiet" ]]; then
        verbose=false
    elif [[ "$arg" == "-p" || "$arg" == "--progress" ]]; then
        progress=true
    fi
done

# --- Main program -------------------------------------------------------------

running_proc=$(pgrep -l -u "$USER" "bbduk" | wc -l || [[ $? == 1 ]])
if [[ $running_proc -gt 0 ]] && (! $progress) && $verbose; then

    echo "WARNING: Some instances of BBDuk are already running in the background!"
    echo "Are you sure you want to continue? (y/n)"

    # Prompt the user for input
    read -r response
    if [[ "$response" != "y" && "$response" != "Y" ]]; then
        echo "ABORTING..."
        exit 0
    fi
fi

# Get the last argument (i.e., either DATADIR or -p)
target_dir="${!#}"

# Hand down all the arguments
# NOTE: ${@:1:$#-1} array slicing is to represent all the arguments except the
#       last one, which needs special attention to handle possible spaces in
#       DATADIR path.
if ${verbose} && (! ${progress}); then
    echo -e -n\
        "\nRunning: nohup bash trimmer.sh -q ${@:1:$#-1} \"${target_dir}\" &"
fi

# MAIN STATEMENT
nohup bash "${xpath}"/trimmer.sh -q ${@:1:$#-1} "${target_dir}" \
    > "nohup.out" 2>&1 &

# Allow time for 'nohup.out' to be created
sleep 0.5
# When in '--quiet' mode, 'trimmer.sh' sends messages to the standard output
# (i.e., display on screen) only in the case of bad arguments, exceptions, or to
# show progress when run with the '-p' option. For this reason, only when
# 'nohup.out' file is empty 'trimmer.sh' is actually going to trim something...
if [[ -s "nohup.out" ]]; then
    echo
    cat "nohup.out" # Retrieve error messages...
    rm "nohup.out"  # ...and then clean
    exit 13
fi

rm "nohup.out"

# Print the head of the log file just created, as a preview of the scheduled job
if ${verbose} && (! ${progress}); then

    # Allow time for the new log to be created and found
    sleep 0.5
    # NOTE: In the 'find' command below, the -printf "%T@ %p\n" option prints
    #       the modification timestamp followed by the filename.
    #       The '-f 2-' option in 'cut' is used to take all the fields after
    #       the first one (i.e., the timestamp) to avoid cropping possible
    #       filenames or paths with spaces.
    latest_log="$(find "${target_dir}" -maxdepth 1 -type f \
        -iname "Z_Trimmer_*.log" -printf "%T@ %p\n" | \
        sort -n | tail -n 1 | cut -d " " -f 2-)"

    printf "\n\nHead of ${latest_log}\n"
    head -n 9 "$latest_log"
    printf "Start trimming through BBDuk in background...\n"
fi
