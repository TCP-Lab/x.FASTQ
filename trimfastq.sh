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
  trimfastq [-t | --test] [-q | --quiet] [-w | --workflow] [-s | --single-end]
          [-i | --interleaved] [-a | --keep-all] [--suffix="PATTERN"] DATADIR

Positional options:
  -h | --help         Shows this help.
  -v | --version      Shows script's version.
  -p | --progress     Shows trimming progress by printing the latest cycle of
                      the latest (possibly growing) log file. If DATADIR is not
                      specified, it searches \$PWD for trimFASTQ logs.
  -t | --test         Testing mode. Quits after processing 100,000
                      reads/read-pairs.
  -q | --quiet        Disables verbose on-screen logging.
  -w | --workflow     Makes processes run in the foreground for use in pipelines.
  -s | --single-end   Single-ended (SE) reads. NOTE: non-interleaved (i.e.,
                      dual-file) PE reads is the default.
  -i | --interleaved  PE reads interleaved into a single file. Ignored when '-s'
                      option is also present.
  -a | --keep-all     Does not delete original FASTQs after trimming (when you
                      have infinite storage space...).
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
                exit 0 # Success exit status
            ;;
            -v | --version)
                _print_ver "trim FASTQ" "${ver}" "FeAR"
                exit 0 # Success exit status
            ;;
            -p | --progress)
                # Cryptic one-liner meaning "$2" or $PWD if argument 2 is unset
                _progress_trimfastq "${2:-.}"
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
                        printf "Bad suffix pattern.\n"
                        printf "Values assigned to '--suffix' must have the "
                        printf "following structure:\n\n"
                        printf " - Non interleaved paired-end reads:\n"
                        printf "   \"leading_str(alt_1|alt_2)trailing_str\"\n\n"
                        printf " - Single-ended/interleaved paired-end reads:\n"
                        printf "   \"any_nonEmpty_str\"\n"
                        exit 3 # Bad suffix pattern format
                    fi
                else
                    printf "Values need to be assigned to '--suffix' option "
                    printf "using the '=' operator.\n"
                    printf "Use '--help' or '-h' to see the correct syntax.\n"
                    exit 4 # Bad suffix assignment
                fi
            ;;
            *)
                printf "Unrecognized option flag '$1'.\n"
                printf "Use '--help' or '-h' to see possible options.\n"
                exit 5 # Argument failure exit status: bad flag
            ;;
        esac
    else
        # The first non-FRP sequence is assumed as the DATADIR argument
        target_dir="$(realpath "$1")"
        shift
    fi
done

# Argument check: DATADIR target directory
if [[ -z "${target_dir:-}" ]]; then
    printf "Missing option or DATADIR argument.\n"
    printf "Use '--help' or '-h' to see the expected syntax.\n"
    exit 6 # Argument failure exit status: missing DATADIR
elif [[ ! -d "$target_dir" ]]; then
    printf "Invalid target directory '${target_dir}'.\n"
    exit 7 # Argument failure exit status: invalid DATADIR
fi

# Retrieve BBDuk local folder from the 'install.paths' file
bbpath="$(grep -i "$(hostname):BBDuk:" "${xpath}/config/install.paths" | \
    cut -d ':' -f 3 || [[ $? == 1 ]])"

if [[ ! -f "${bbpath}/bbduk.sh" ]]; then
    printf "Couldn't find 'bbduk.sh'...\n"
    printf "Please, check the 'install.paths' file.\n"
    exit 8 # Argument failure exit status: missing BBDuk
fi

# --- Main program -------------------------------------------------------------

# Set the log file
# When creating the log file, 'basename "$target_dir"' assumes that DATADIR
# was properly named with the current BioProject/Study ID.
log_file="${target_dir}/Z_trimFASTQ_$(basename "$target_dir")_$(_tstamp).log"
_dual_log false "$log_file" "-- $(_tstamp) --"
_dual_log $verbose "$log_file" \
    "trimFASTQ :: x.FASTQ Wrapper for BBDuk :: ver.${ver}\n" \
    "BBDuk found in '${bbpath}'" \
    "Searching '${target_dir}' for FASTQs to trim..."

# Select the proper library layout and prepare variables
if $paired_reads && $dual_files; then

    _dual_log $verbose "$log_file" "\nRunning in \"dual-file paired-end\" mode:"

    # Assign the suffixes to match paired FASTQs
    r_suffix="$(_explode_ORpattern "$suffix_pattern")"
    r1_suffix="$(echo "$r_suffix" | cut -d ',' -f 1)"
    r2_suffix="$(echo "$r_suffix" | cut -d ',' -f 2)"
    _dual_log $verbose "$log_file" \
        "   Suffix 1: ${r1_suffix}" \
        "   Suffix 2: ${r2_suffix}"

    if [[ $(find "$target_dir" -maxdepth 1 -type f \
    -iname "*$r1_suffix" -o -iname "*$r2_suffix" | wc -l) -eq 0 ]]; then
        _dual_log true "$log_file" \
            "\nNo FASTQ files ending with \"${r_suffix}\" in '${target_dir}'."
        exit 9 # Argument failure exit status: no FASTQ found
    fi

    # Check FASTQ pairing
    counter=0
    while IFS= read -r line
    do
        if [[ ! -e "${line}${r1_suffix}" || ! -e "${line}${r2_suffix}" ]]; then
            _dual_log true "$log_file" \
                "\nA FASTQ file is missing in the following pair:" \
                "   ${line}${r1_suffix}" \
                "   ${line}${r2_suffix}" \
                "\nAborting..."
            exit 10 # Argument failure exit status: incomplete pair
        else
            counter=$((counter+1))
        fi
    done <<< $(find "$target_dir" -maxdepth 1 -type f \
                -iname "*$r1_suffix" -o -iname "*$r2_suffix" | \
                sed -E "s/(${r1_suffix}|${r2_suffix})//" | sort -u)
    # NOTE:
    # A 'here-string' is used here because if the 'while read' loop had been
    # piped in this way
    #
    # find ... | sed ... | sort -u | while IFS= read -r line; do ... done
    #
    # the 'counter' variable would have lost its value at end of the while loop.
    # This is because pipes create SubShells, which would have made the loop
    # run on a different shell than the script. Since pipes spawn additional
    # shells, any variable you mess with in a pipe will go out of scope as soon
    # as the pipe ends!

    _dual_log $verbose "$log_file" \
        "$counter x 2 = $((counter*2)) paired FASTQ files found."

elif ! $paired_reads; then

    _dual_log $verbose "$log_file" \
        "\nRunning in \"single-ended\" mode:" \
        "   Suffix: ${se_suffix}"

    counter=$(find "$target_dir" -maxdepth 1 -type f -iname "*${se_suffix}" | wc -l)

    if (( counter > 0 )); then
        _dual_log $verbose "$log_file" \
            "$counter single-ended FASTQ files found."
    else
        _dual_log true "$log_file" \
            "\nNo FASTQ files ending with \"${se_suffix}\" in '${target_dir}'."
        exit 11 # Argument failure exit status: no FASTQ found
    fi

elif ! $dual_files; then

    _dual_log $verbose "$log_file" \
        "\nRunning in \"interleaved\" mode:" \
        "   Suffix: ${se_suffix}"

    counter=$(find "$target_dir" -maxdepth 1 -type f -iname "*${se_suffix}" | wc -l)

    if (( counter > 0 )); then
        _dual_log $verbose "$log_file" \
            "$counter interleaved paired-end FASTQ files found."
    else
        _dual_log true "$log_file" \
            "\nNo FASTQ files ending with \"${se_suffix}\" in '${target_dir}'."
        exit 12 # Argument failure exit status: no FASTQ found
    fi
fi

# Export variables needed by 'trimmer' script (running in a subshell)
export	xpath paired_reads dual_files target_dir r1_suffix r2_suffix se_suffix \
        counter bbpath nor remove_originals

# HOLD-ON STATEMENT
_hold_on "$log_file" "${xpath}/trimmer.sh"
