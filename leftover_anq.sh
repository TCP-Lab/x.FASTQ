#!/bin/bash






# --- Self-calling section -----------------------------------------------------

# Default options
verbose_external=true
progress_or_kill=false
pipeline=false
if printf "%s\n" "$@" | grep -qE '^-w$|^--workflow$'; then pipeline=true; fi

# Make sure that the script is called with `nohup`
if [[ "${1:-""}" != "selfcall" ]]; then

    # This script has *not* been called recursively by itself...
    # ...so let's do it with nohup

    # Argument check: move up -p, -k, -q detection
    for arg in "$@"; do
        if [[ "$arg" == "-q" || "$arg" == "--quiet" ]]; then
            verbose_external=false
        elif [[ "$arg" == "-p" || "$arg" == "--progress" \
             || "$arg" == "-k" || "$arg" == "--kill" ]]; then
            progress_or_kill=true
        fi
    done

    # Get the last argument (i.e., DATADIR)
    target_dir="${!#}"

    # MAIN STATEMENT
    _hold_on "nohup.out" "$0" "selfcall" -q ${@:1:$#-1} "${target_dir}"
    # NOTE: ${@:1:$#-1} array slicing is to represent all the arguments except
    #       the last one, which needs special attention to handle possible
    #       spaces in DATADIR path.

    # Allow time for 'nohup.out' to be created and populated
    sleep 0.5
    # anqFASTQ has just called itself in '--quiet' mode. When quiet, anqfastq.sh
    # is designed to send messages to stdout only when called with options -h,
    # -v, -p, -k, using a bad syntax, or in the case of errors/exceptions. Thus,
    # the 'nohup.out' file will be empty if and only if anqFASTQ is actually
    # going to align/quantify something. In this case we print the head of the
    # log file to show the scheduled task, otherwise we just print the
    # 'nohup.out' to show the alternative output and exit.
    # Throughout the entire main program section, the log function
    #       _dual_log $verbose "$log_file" "..."
    # being invoked under -q option, will send messages only to the log file,
    # whose head will be printed on screen by 'head -n 12 "$latest_log"' in the
    # case of no errors, while the code lines
    #       _dual_log true "$log_file"
    # will always send message to log AND to the redirected output, resulting in
    # a non-empty 'nohup.out' file, that will be printed just before script end.
    # Finally, 'printf' is used to send messages just to stdout (> "nohup.out")
    # and avoid the creation of a new log file (for early fatal issues).

    # Retrieve possible error (or help, version, progress) message...
    if [[ -s "nohup.out" ]]; then
        cat "nohup.out"
        rm "nohup.out"  # ...and clean
        exit 0 # Currently unable to tell whether this is successful or not...
    fi
    rm "nohup.out"

    # Print the head of the log file as a preview of the scheduled job
    if $verbose_external && (! $progress_or_kill); then

        # Allow time for the new log to be created and found
        sleep 0.5
        # NOTE: In the 'find' command below, the -printf "%T@ %p\n" option
        #       prints the modification timestamp followed by the filename.
        latest_log="$(find "${target_dir}" -maxdepth 1 -type f \
            -iname "Z_Quant_*.log" -printf "%T@ %p\n" \
            | sort -n | tail -n 1 | cut -d " " -f 2-)"

        printf "\nHead of ${latest_log}\n"
        head -n 14 "$latest_log"
        printf "Start count computation through STAR/RSEM in background...\n"
    fi
    exit 0 # Success exit status
else
    # This script has been called recursively by itself (in nohup mode)
    shift
fi











