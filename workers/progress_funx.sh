#!/bin/bash

# ==============================================================================
#  Collection of functions to show the progress of each x.FASTQ module
# ==============================================================================

# --- getFASTQ -----------------------------------------------------------------
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
    if [[ ${#logs[@]} -eq 0 ]]; then
        printf "No getFASTQ log file found in '${target_dir}'.\n"
        exit 2 # Argument failure exit status: missing log
    fi

    # Parse logs and heuristically capture download status
    declare -a completed=()
    declare -a failed=()
    declare -a incoming=()
    for log in "${logs[@]}"; do
        # Mind the order of the following capturing blocks... it matters!
        local test_failed=$(grep -E \
            ".+Terminated| unable to |Not Found.|Unable to " \
            "$log" || [[ $? == 1 ]])
        if [[ -n $test_failed ]]; then
            failed+=("$(echo "$test_failed" | rev | cut -d$'\r' -f 1 | rev)")
            continue
        fi
        local test_incoming=$(tail -n 1 "$log" | grep -E "%\[=*>? *\] " \
            || [[ $? == 1 ]])
        if [[ -n $test_incoming ]]; then
            incoming+=("$(echo "$test_incoming" | rev | cut -d$'\r' -f 1 | rev)")
            continue
        fi
        local test_completed=$(grep -E \
            " saved \[| already there;" \
            "$log" | tail -n 1 || [[ $? == 1 ]])
        if [[ -n $test_completed ]]; then
            completed+=("$test_completed")
            continue
        fi
        printf "WARNING: Cannot classify '${log}'\n"
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
    if [[ ${#failed[@]} -eq 0 ]]; then
        printf "  - No failed items!\n"
    else
        for item in "${failed[@]}"; do
            echo "  - ${item}"
        done
    fi
    printf "\n${yel}Incoming:${end}\n"
    if [[ ${#incoming[@]} -eq 0 ]]; then
        printf "  - No incoming items!\n"
    else
        for item in "${incoming[@]}"; do
            echo "  - ${item}"
        done
    fi
    exit 0 # Success exit status
}

# --- qcFASTQ ------------------------------------------------------------------
function _progress_qcfastq {

    local target_dir="$(realpath "$1")"
    if [[ ! -d "$target_dir" ]]; then
        printf "Bad DATADIR path '${target_dir}'.\n"
        exit 1 # Argument failure exit status: bad target path
    fi

    # NOTE: In the 'find' command below, the -printf "%T@ %p\n" option prints
    #       the modification timestamp followed by the filename.
    #       The '-f 2-' option in 'cut' is used to take all the fields after
    #       the first one (i.e., the timestamp) to avoid cropping possible
    #       filenames or paths with spaces.
    local latest_log="$(find "$target_dir" -maxdepth 1 -type f \
        -iname "Z_QC_*.log" -printf "%T@ %p\n" | \
        sort -n | tail -n 1 | cut -d " " -f 2-)"

    if [[ -n "$latest_log" ]]; then
        
        local tool=$(basename "$latest_log" \
            | sed "s/^Z_QC_//" | sed "s/_.*\.log$//")
        printf "\n$tool log file detected: $(basename "$latest_log")\n"
        printf "in: '$(dirname "$latest_log")'\n\n"

        case "$tool" in
            PCA)
                cat "$latest_log"
            ;;
            FastQC)
                printf "${grn}Completed:${end}\n"
                grep -F "Analysis complete" "$latest_log" || [[ $? == 1 ]]
                printf "\n${red}Failed:${end}\n"
                grep -iE "Failed|Stop" "$latest_log" || [[ $? == 1 ]]
                printf "\n${yel}In progress:${end}\n"
                local completed=$(tail -n 1 "$latest_log" | \
                    grep -iE "Analysis complete|Failed|java|Stop" \
                    || [[ $? == 1 ]])
                [[ -z $completed ]] && tail -n 1 "$latest_log"
            ;;
            MultiQC)
                cat "$latest_log"
            ;;
            QualiMap)
                echo "QualiMap selected. STILL TO ADD THIS OPTION..."
            ;;
        esac
        exit 0 # Success exit status
    else
        printf "No QC log file found in '$target_dir'.\n"
        exit 2 # Argument failure exit status: missing log
    fi
}

# --- trimFASTQ ----------------------------------------------------------------
function _progress_trimfastq {

    local target_dir="$(realpath "$1")"
    if [[ ! -d "$target_dir" ]]; then
        printf "Bad DATADIR path '${target_dir}'.\n"
        exit 1 # Argument failure exit status: bad target path
    fi

    # NOTE: In the 'find' command below, the -printf "%T@ %p\n" option prints
    #       the modification timestamp followed by the filename.
    #       The '-f 2-' option in 'cut' is used to take all the fields after
    #       the first one (i.e., the timestamp) to avoid cropping possible
    #       filenames or paths with spaces.
    local latest_log="$(find "$target_dir" -maxdepth 1 -type f \
        -iname "Z_trimFASTQ_*.log" -printf "%T@ %p\n" | \
        sort -n | tail -n 1 | cut -d " " -f 2-)"

    if [[ -n "$latest_log" ]]; then
        
        echo -e "\n${latest_log}\n"

        # Print only the last cycle in the log file by finding the penultimate
        # occurrence of the pattern "============"
        local line=$(grep -n "============" "$latest_log" | \
            cut -d ":" -f 1 | tail -n 2 | head -n 1 || [[ $? == 1 ]])
        
        tail -n +${line} "$latest_log"      
        exit 0 # Success exit status
    else
        printf "No Trimmer log file found in '${target_dir}'.\n"
        exit 2 # Argument failure exit status: missing log
    fi
}

# --- anqFASTQ -----------------------------------------------------------------
function _progress_anqfastq {

    local target_dir="$(realpath "$1")"
    if [[ ! -d "$target_dir" ]]; then
        printf "Bad DATADIR path '${target_dir}'.\n"
        exit 1 # Argument failure exit status: bad target path
    fi

    # NOTE: In the 'find' command below, the -printf "%T@ %p\n" option prints
    #       the modification timestamp followed by the filename.
    #       The '-f 2-' option in 'cut' is used to take all the fields after
    #       the first one (i.e., the timestamp) to avoid cropping possible
    #       filenames or paths with spaces.
    local latest_log="$(find "$target_dir" -maxdepth 1 -type f \
        -iname "Z_anqFASTQ_*.log" -printf "%T@ %p\n" | \
        sort -n | tail -n 1 | cut -d " " -f 2-)"

    if [[ -n "$latest_log" ]]; then
        
        echo -e "\n${latest_log}\n"

        # Print only the last cycle in the log file by finding the penultimate
        # occurrence of the pattern "============"
        local line=$(grep -n "============" "$latest_log" | \
            cut -d ":" -f 1 | tail -n 2 | head -n 1 || [[ $? == 1 ]])
        
        # The 're_uniq.py' python script removes the highly repeated lines
        # generated by RSEM, keeping only the last ones.        
        local rep_rgx1='^Parsed [0-9]* entries$'
        local rep_rgx2='^FIN [0-9]*$'
        local rep_rgx3='^DAT [0-9]* reads left$'
        local rep_rgx4='^[0-9]* READS PROCESSED$'
        local rep_rgx5='^ROUND = [0-9]*, SUM = [0-9.]*, bChange = [0-9.]*, totNum = [0-9]*$'
        local rep_rgx="${rep_rgx1}|${rep_rgx2}|${rep_rgx3}|${rep_rgx4}|${rep_rgx5}"
        tail -n +${line} "$latest_log" | \
            tac | "${xpath}/workers/re_uniq.py" "$rep_rgx" | tac
        exit 0 # Success exit status
    else
        printf "No anqFASTQ log file found in '${target_dir}'.\n"
        exit 2 # Argument failure exit status: missing log
    fi
}

# --- countFASTQ ---------------------------------------------------------------
function _progress_countfastq {

    local target_dir="$(realpath "$1")"
    if [[ ! -d "$target_dir" ]]; then
        printf "Bad DATADIR path '$target_dir'.\n"
        exit 1 # Argument failure exit status: bad target path
    fi

    # NOTE: In the 'find' command below, the -printf "%T@ %p\n" option prints
    #       the modification timestamp followed by the filename.
    #       The '-f 2-' option in 'cut' is used to take all the fields except
    #       the first one (i.e., the timestamp) to properly handle filenames
    #       or paths with spaces.
    local latest_log="$(find "$target_dir" -maxdepth 1 -type f \
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
