#!/bin/bash

# ==============================================================================
#  Trim FastQ Files using BBDuk
# ==============================================================================
ver="1.8.0"

# --- Source common settings and functions -------------------------------------

# Source functions from x.funx.sh
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/x.funx.sh

# --- Help message -------------------------------------------------------------

read -d '' _help_trimmer << EOM || true
This script is a wrapper for the NGS-read trimmer BBDuk (from the BBTools suite)
that loops over a set of FASTQ files containing either single-ended (SE) or
paired-end (PE) reads. In particular, the script
  . checks for file pairing in the case of non-interleaved PE reads, assuming
    that the filenames of the paired FASTQs differ only by a suffix (see the
    '--suffix' option below);
  . automatically detects adapter sequences present in the reads;
  . right-trims (3') detected adapters (Illumina standard);
  . performs quality trimming on both sides of each read (using a predefined
    quality score threshold);
  . performs length filtering by discarding all reads shorter than 25 bases; 
  . saves stats about adapter autodetection and trimmed reads;
  . saves trimmed FASTQs and (by default) removes the original ones;
  . loops over all the FASTQ files in the target directory.

Usage:
  trimmer [-h | --help] [-v | --version]
  trimmer -p | --progress [DATADIR]
  trimmer [-t | --test] [-q | --quiet] [-s | --single-end] [-i | --interleaved]
          [-a | --keep-all] [--suffix="PATTERN"] DATADIR

Positional options:
  -h | --help         Shows this help.
  -v | --version      Shows script's version.
  -p | --progress     Shows trimming progress by printing the latest cycle of
                      the latest (possibly growing) log file (this is useful
                      only when the script is run quietly in background). If
                      DATADIR is not provided, it searches \$PWD for trimming
                      logs.
  -t | --test         Testing mode. Quits after processing 100,000
                      reads/read-pairs.
  -q | --quiet        Disables verbose on-screen logging.
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
                      the path where to look for trimming progress logs. In any
                      case, this argument has to be the last one when trimmer.sh
                      is run by the trimFASTQ wrapper.
EOM

# --- Function definition ------------------------------------------------------

# Show trimming progress printing the tail of the latest log
# (useful in case of background run)
function _progress_trimmer {

    if [[ -d "$1" ]]; then
        local target_dir="$(realpath "$1")"
    else
        printf "Bad DATADIR '$1'.\n"
        exit 1 # Argument failure exit status: bad target path
    fi

    # NOTE: In the 'find' command below, the -printf "%T@ %p\n" option prints
    #       the modification timestamp followed by the filename.
    #       The '-f 2-' option in 'cut' is used to take all the fields after
    #       the first one (i.e., the timestamp) to avoid cropping possible
    #       filenames or paths with spaces.
    local latest_log="$(find "${target_dir}" -maxdepth 1 -type f \
        -iname "Z_Trimmer_*.log" -printf "%T@ %p\n" \
        | sort -n | tail -n 1 | cut -d " " -f 2-)"

    if [[ -n "$latest_log" ]]; then
        
        echo -e "\n${latest_log}\n"

        # Print only the last cycle in the log file by finding the penultimate
        # occurrence of the pattern "============"
        local line=$(grep -n "============" "$latest_log" \
            | cut -d ":" -f 1 | tail -n 2 | head -n 1 || [[ $? == 1 ]])
        
        tail -n +${line} "$latest_log"      
        exit 0 # Success exit status
    else
        printf "No Trimmer log file found in '${target_dir}'.\n"
        exit 2 # Argument failure exit status: missing log
    fi
}

# --- Argument parsing ---------------------------------------------------------

# Default options
verbose=true
nor=-1 # Number Of Reads (nor) == -1 --> BBDuk trims the whole FASTQ
paired_reads=true
dual_files=true
remove_originals=true
suffix_pattern="(1|2).fastq.gz"
se_suffix=".fastq.gz"

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+"
# Value Regex Pattern (VRP)
vrp="^.*\(.*\|.*\).*$"

# Argument check: options
while [[ $# -gt 0 ]]; do
    if [[ "$1" =~ $frp ]]; then
        case "$1" in
            -h | --help)
                printf "%s\n" "$_help_trimmer"
                exit 0 # Success exit status
            ;;
            -v | --version)
                _print_ver "trimmer" "${ver}" "FeAR"
                exit 0 # Success exit status
            ;;
            -p | --progress)
                # Cryptic one-liner meaning "$2" or $PWD if argument 2 is unset
                _progress_trimmer "${2:-.}"
            ;;
            -t | --test)
                nor=100k
                shift
            ;;
            -q | --quiet)
                verbose=false
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
                        && "${1/--suffix=/}" =~ $vrp ]]; then
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
if [[ -z "${target_dir:-""}" ]]; then
    printf "Missing option or DATADIR argument.\n"
    printf "Use '--help' or '-h' to see the expected syntax.\n"
    exit 6 # Argument failure exit status: missing DATADIR
elif [[ ! -d "$target_dir" ]]; then
    printf "Invalid target directory '$target_dir'.\n"
    exit 7 # Argument failure exit status: invalid DATADIR
fi

# Retrieve BBDuk local folder from the 'install.paths' file
bbpath="$(grep -i "$(hostname):BBDuk:" "${xpath}/config/install.paths" \
    | cut -d ':' -f 3 || [[ $? == 1 ]])"

# Check if STDOUT is associated with a terminal or not to distinguish between
# direct 'trimmer.sh' runs and calls from 'trimfastq.sh', which make this script
# to run in background (&) and redirect its output to 'nohup.out', thus
# preventing user interaction...
if [[ ! -t 1 ]]; then
    # 'trimmer.sh' has been called by 'trimfastq.sh': no interaction is possible
    if [[ ! -f "${bbpath}/bbduk.sh" ]]; then
        printf "Couldn't find 'bbduk.sh'...\n"
        printf "Please, check the 'install.paths' file.\n"
        exit 8 # Argument failure exit status: missing BBDuk
    fi
else
    # 'trimmer.sh' has been called directly: interaction is possible
    if [[ -z "$bbpath" ]]; then
        printf "Couldn't find 'bbduk.sh'...\n"
        read -ep "Please, manually enter the path or 'q' to quit: " bbpath
    fi

    found_flag=false
    while ! $found_flag; do
        if [[ "$bbpath" == "q" ]]; then
            exit 9 # Argument failure exit status: missing BBDuk
        elif [[ -f "${bbpath}/bbduk.sh" ]]; then
            found_flag=true
        else
            printf "Couldn't find 'bbduk.sh' in '"${bbpath}"'\n"
            read -ep "Please, enter the right path or 'q' to quit: " bbpath
        fi
    done
fi

# --- Main program -------------------------------------------------------------

# Set the log file
# When creating the log file, 'basename "$target_dir"' assumes that DATADIR
# was properly named with the current Experiment_ID
log_file="${target_dir}"/Z_Trimmer_"$(basename "$target_dir")"_$(_tstamp).log
_dual_log false "$log_file" "-- $(_tstamp) --"
_dual_log $verbose "$log_file" \
    "Trimmer :: x.FASTQ Wrapper for BBDuk :: ver.${ver}\n" \
    "BBDuk found in \"${bbpath}\"" \
    "Searching \"${target_dir}\" for FASTQs to trim..."

if $paired_reads && $dual_files; then

    _dual_log $verbose "$log_file" "\nRunning in \"dual-file paired-end\" mode:"

    # Assign the suffixes to match paired FASTQs
    r_suffix="$(_explode_ORpattern "$suffix_pattern")"
    r1_suffix="$(echo "$r_suffix" | cut -d ',' -f 1)"
    r2_suffix="$(echo "$r_suffix" | cut -d ',' -f 2)"
    _dual_log $verbose "$log_file" \
        "   Suffix 1: ${r1_suffix}" \
        "   Suffix 2: ${r2_suffix}"

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
                -iname "*$r1_suffix" -o -iname "*$r2_suffix" \
                | sed -E "s/(${r1_suffix}|${r2_suffix})//" | sort -u)
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

    # Loop over them
    i=1 # Just another counter
    for r1_infile in "${target_dir}"/*"$r1_suffix"
    do
        r2_infile="$(echo "$r1_infile" | sed "s/$r1_suffix/$r2_suffix/")"

        _dual_log $verbose "$log_file" \
            "\n============" \
            " Cycle ${i}/${counter}" \
            "============" \
            "Targeting: ${r1_infile}" \
            "           ${r2_infile}" \
            "\nStart trimming through BBDuk..."

        prefix="$(basename "$r1_infile" "$r1_suffix")"

        # Paths with spaces need to be hard-escaped at this very level to be
        # correctly parsed when passed as arguments to BBDuk!
        esc_r1_infile="${r1_infile//" "/'\ '}"
        esc_r2_infile="${r2_infile//" "/'\ '}"
        esc_target_dir="${target_dir//" "/'\ '}"

        # MAIN STATEMENT (Run BBDuk)
        # also try to add this for Illumina: ftm=5 \
        echo >> "$log_file"
        ${bbpath}/bbduk.sh \
            reads=$nor \
            in1=$esc_r1_infile \
            in2=$esc_r2_infile \
            ref=${bbpath}/resources/adapters.fa \
            stats=${esc_target_dir}/Trim_stats/${prefix}_STATS.tsv \
            ktrim=r \
            k=23 \
            mink=11 \
            hdist=1 \
            tpe \
            tbo \
            out1=$(echo $esc_r1_infile | sed -E "s/_?$r1_suffix/_TRIM_$r1_suffix/") \
            out2=$(echo $esc_r2_infile | sed -E "s/_?$r2_suffix/_TRIM_$r2_suffix/") \
            qtrim=rl \
            trimq=10 \
            minlen=25 \
            >> "${log_file}" 2>&1
        # NOTE: By default, all BBTools write status information to stderr,
        #       not stdout !!!
        echo >> "$log_file"

        _dual_log $verbose "$log_file" "DONE!"

        if $remove_originals; then
            rm "$r1_infile" "$r2_infile"
        fi

        # Increment the i counter
        ((i++))
    done

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
            "\nNo FASTQ files ending with \"${se_suffix}\" in ${target_dir}."
        exit 11 # Argument failure exit status: no FASTQ found
    fi

    # Loop over them
    i=1 # Just another counter
    for infile in "${target_dir}"/*"$se_suffix"
    do
        _dual_log $verbose "$log_file" \
            "\n============" \
            " Cycle ${i}/${counter}" \
            "============" \
            "Targeting: ${infile}" \
            "\nStart trimming through BBDuk..."

        prefix="$(basename "$infile" "$se_suffix")"

        # Paths with spaces need to be hard-escaped at this very level to be
        # correctly parsed when passed as arguments to BBDuk!
        esc_infile="${infile//" "/'\ '}"
        esc_target_dir="${target_dir//" "/'\ '}"

        # MAIN STATEMENT (Run BBDuk)
        # also try to add this for Illumina: ftm=5 \
        echo >> "$log_file"
        "${bbpath}"/bbduk.sh \
            reads=$nor \
            in=$esc_infile \
            ref=${bbpath}/resources/adapters.fa \
            stats=${esc_target_dir}/Trim_stats/${prefix}_STATS.tsv \
            ktrim=r \
            k=23 \
            mink=11 \
            hdist=1 \
            interleaved=f \
            out=$(echo $esc_infile | sed -E "s/_?$se_suffix/_TRIM$se_suffix/") \
            qtrim=rl \
            trimq=10 \
            minlen=25 \
            >> "${log_file}" 2>&1
        echo >> "$log_file"

        _dual_log $verbose "$log_file" "DONE!"

        if $remove_originals; then
            rm "$infile"
        fi

        # Increment the i counter
        ((i++))
    done

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
            "\nNo FASTQ files ending with \"${se_suffix}\" in ${target_dir}."
        exit 12 # Argument failure exit status: no FASTQ found
    fi

    # Loop over them
    i=1 # Just another counter
    for infile in "${target_dir}"/*"$se_suffix"
    do
        _dual_log $verbose "$log_file" \
            "\n============" \
            " Cycle ${i}/${counter}" \
            "============" \
            "Targeting: ${infile}" \
            "\nStart trimming through BBDuk..."

        prefix="$(basename "$infile" "$se_suffix")"

        # Paths with spaces need to be hard-escaped at this very level to be
        # correctly parsed when passed as arguments to BBDuk!
        esc_infile="${infile//" "/'\ '}"
        esc_target_dir="${target_dir//" "/'\ '}"

        # MAIN STATEMENT (Run BBDuk)
        # also try to add this for Illumina: ftm=5 \
        echo >> "$log_file"
        ${bbpath}/bbduk.sh \
            reads=$nor \
            in=$esc_infile \
            ref=${bbpath}/resources/adapters.fa \
            stats=${esc_target_dir}/Trim_stats/${prefix}_STATS.tsv \
            ktrim=r \
            k=23 \
            mink=11 \
            hdist=1 \
            interleaved=t \
            tpe \
            tbo \
            out=$(echo $esc_infile | sed -E "s/_?$se_suffix/_TRIM$se_suffix/") \
            qtrim=rl \
            trimq=10 \
            minlen=25 \
            >> "${log_file}" 2>&1
        echo >> "$log_file"

        _dual_log $verbose "$log_file" "DONE!"

        if $remove_originals; then
            rm "$infile"
        fi

        # Increment the i counter
        ((i++))
    done
fi
