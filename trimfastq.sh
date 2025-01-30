#!/bin/bash

# ==============================================================================
#  Trim reads using BBDuk
# ==============================================================================
ver="2.0.0"

# --- Source common settings and functions -------------------------------------
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/workers/x.funx.sh
source "${xpath}"/workers/progress_funx.sh

# --- Help message -------------------------------------------------------------

read -d '' _help_trimfastq << EOM || true
trimFASTQ is a convenient wrapper of the NGS-read trimmer BBDuk (from the
BBTools suite) that
  . checks for file pairing in the case of non-interleaved paired-end (PE)
    reads (assuming that filenames of each pair only differ by a suffix);
  . automatically detects adapter sequences possibly present in the reads;
  . right-trims (3') detected adapters (Illumina standard);
  . performs quality trimming on both sides of each read (using a predefined
    quality score threshold);
  . performs length filtering by discarding all reads shorter than 25 bases; 
  . saves stats about adapter autodetection and trimmed reads;
  . saves trimmed FASTQs and (by default) removes the original ones;
  . loops over all the FASTQ files in the target directory;
  . runs the trimmer persistently and in the background, by default.

Usage:
  trimfastq [-h | --help] [-v | --version]
  trimfastq -p | --progress [DATADIR]
  trimfastq -k | --kill
  trimfastq [-t | --test] [-q | --quiet] [-w | --workflow] [-s | --single-end]
            [-i | --interleaved] [-a | --keep-all] [--suffix="PATTERN"] DATADIR

Positional options:
  -h | --help         Shows this help.
  -v | --version      Shows script's version.
  -p | --progress     Shows trimming progress by printing the latest cycle of
                      the latest (possibly growing) log file. If DATADIR is not
                      specified, it searches \$PWD for trimFASTQ logs.
  -k | --kill         Gracefully (-15) kills all the 'java' instances currently
                      running and started by the current user.
  -t | --test         Testing mode. Quits after processing 100,000
                      reads/read-pairs.
  -q | --quiet        Disables verbose on-screen logging.
  -w | --workflow     Makes processes run in the foreground for use in pipelines.
  -s | --single-end   Single-ended (SE) reads. NOTE: non-interleaved (i.e.,
                      dual-file) PE reads is the default.
  -i | --interleaved  PE reads interleaved into a single file. Ignored when '-s'
                      option is also present.
  -a | --keep-all     Does not delete original FASTQs after trimming (for people
                      who have unlimited storage space...)
  --suffix="PATTERN"  For dual-file PE reads, "PATTERN" should be a regex-like
                      pattern of this type
                          "leading_str(alt_1|alt_2)trailing_str"
                      specifying the two alternative suffixes used to match
                      paired FASTQs, the default being "(1|2).fastq.gz".
                      For SE reads or interleaved PE reads, it can be any text
                      string, the default being ".fastq.gz". In any case, this
                      option must be set after -s/-i flags.
  DATADIR             Path of a FASTQ-containing folder. The script assumes that
                      all the FASTQs are in the same directory, but it doesn't
                      inspect subfolders. Placed right after '-p' option, it is
                      the path where to look for trimming progress logs.
EOM

# --- Argument parsing and validity check --------------------------------------

# Default options
verbose=true
pipeline=false
nor=-1 # Number Of Reads (nor) == -1 --> BBDuk trims the whole FASTQ
paired_reads=true
dual_files=true
remove_originals=true
suffix_pattern="(1|2).fastq.gz"
se_suffix=".fastq.gz"

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+"
# Suffix Regex Pattern (SRP) for dual-file PE reads
srp="^.*\(.*\|.*\).*$"

# Argument check: options
while [[ $# -gt 0 ]]; do
    if [[ "$1" =~ $frp ]]; then
        case "$1" in
            -h | --help)
                printf "%s\n" "$_help_trimfastq"
                exit 0
            ;;
            -v | --version)
                _print_ver "trim FASTQ" "${ver}" "FeAR"
                exit 0
            ;;
            -p | --progress)
                # Cryptic one-liner meaning "$2" or $PWD if argument 2 is unset
                _progress_trimfastq "${2:-.}"
                exit 0
            ;;
            -k | --kill)
                _gracefully_kill "trimmer" "bbduk" "java"
                exit 0
            ;;
            -t | --test)
                nor=100k
                shift
            ;;
            -q | --quiet)
                verbose=false
                shift
            ;;
            -w | --workflow)
                pipeline=true
                shift
            ;;
            -s | --single-end)
                paired_reads=false
                shift
            ;;
            -i | --interleaved)
                dual_files=false
                shift
            ;;
            -a | --keep-all)
                remove_originals=false
                shift  
            ;;
            --suffix*)
                # Test for '=' presence
                rgx="^--suffix="
                if [[ "$1" =~ $rgx ]]; then
                    if [[ $paired_reads == true && $dual_files == true \
                        && "${1/--suffix=/}" =~ $srp ]]; then
                        suffix_pattern="${1/--suffix=/}"
                        shift
                    elif [[ ($paired_reads == false || $dual_files == false) \
                        && "${1/--suffix=/}" != "" ]]; then
                        se_suffix="${1/--suffix=/}"
                        shift
                    else
                        _print_bad_suffix
                        exit 6
                    fi
                else
                    _print_bad_assignment "--suffix"
                    exit 7
                fi
            ;;
            *)
                _print_bad_flag $1
                exit 4
            ;;
        esac
    else
        # The first non-FRP sequence is assumed as the DATADIR argument
        target_dir="$(realpath "$1")"
        shift
    fi
done

# Argument check: DATADIR directory
_check_target "directory" "${target_dir:-}"

# Fetch BBDuk local folder from 'config/install.paths'
bbpath="$(_read_config "BBDuk")"
if [[ ! -f "${bbpath}/bbduk.sh" ]]; then
    eprintf "Couldn't find 'bbduk.sh'...\n" \
        "Please, check the 'install.paths' file.\n"
    exit 11
fi

# --- Main program -------------------------------------------------------------

# Check if stdout (file descriptor 1) is connected to a terminal (TTY) or not.
# Whenever trimFASTQ output is globally redirected (e.g., `trimfastq . > file`,
# or because it is part of a larger pipeline run in nohup mode) [[ -t 1 ]] is
# false, meaning that no interaction with the user is possible.
if [[ -t 1 ]]; then
    # trimFASTQ has been called directly: interaction is possible
    running_proc=$(pgrep -l "bbduk" | wc -l || [[ $? == 1 ]])
    if [[ $running_proc -gt 0 ]]; then
        printf "%b" "\nWARNING\n" \
            "Some instances of BBDuk are already running in the background!\n" \
            "Are you sure you want to continue? (y/n) "
        # Prompt the user for input
        read -r response
        printf "\n"
        if [[ "$response" != "y" && "$response" != "Y" ]]; then
            printf "ABORTING...\n"
            exit 0
        fi
    fi
fi

# Set the log file
# When creating the log file, 'basename "$target_dir"' assumes that DATADIR
# was properly named with the current BioProject/Study ID.
log_file="${target_dir}/Z_trimFASTQ_$(basename "$target_dir")_$(_tstamp).log"
_dual_log false "$log_file" "-- $(_tstamp) --\n"
_dual_log $verbose "$log_file" \
    "trimFASTQ :: x.FASTQ Wrapper for BBDuk :: ver.${ver}\n\n" \
    "BBDuk found in '${bbpath}'\n" \
    "Searching '${target_dir}' for FASTQs to trim...\n\n"

# Select the proper library layout and prepare variables
if $paired_reads && $dual_files; then

    _dual_log $verbose "$log_file" "Running in \"dual-file paired-end\" mode:\n"
    
    # Assign paired suffixes
    r_suffix="$(_explode_ORpattern "$suffix_pattern")"
    r1_suffix="$(echo "$r_suffix" | cut -d ',' -f 1)"
    r2_suffix="$(echo "$r_suffix" | cut -d ',' -f 2)"
    _dual_log $verbose "$log_file" \
        "   Suffix 1: ${r1_suffix}\n" \
        "   Suffix 2: ${r2_suffix}\n"

    _check_fastq_pairing $verbose "$log_file" \
                         "$r1_suffix" "$r2_suffix" "$target_dir"

elif ! $paired_reads; then

    _dual_log $verbose "$log_file" \
        "Running in \"single-ended\" mode:\n" \
        "   Suffix: ${se_suffix}\n"    
    _check_fastq_unpaired $verbose "$log_file" "$se_suffix" "$target_dir"

elif ! $dual_files; then

    _dual_log $verbose "$log_file" \
        "Running in \"interleaved\" mode:\n" \
        "   Suffix: ${se_suffix}\n"
    _check_fastq_unpaired $verbose "$log_file" "$se_suffix" "$target_dir"
fi

# Export variables needed by 'trimmer' script (running in a subshell)
export	xpath paired_reads dual_files target_dir r1_suffix r2_suffix se_suffix \
        counter bbpath nor remove_originals

# HOLD-ON STATEMENT
_hold_on "$log_file" "${xpath}/trimmer.sh"
