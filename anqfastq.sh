#!/bin/bash

# ==============================================================================
#  Align transcripts and quantify abundances using STAR and RSEM
# ==============================================================================
ver="1.7.2"

# NOTE: this script calls itself recursively to add a leading 'nohup' and
#       trailing '&' to $0 in order to always run in background and persistent
#       mode. This became necessary because `anqfastq.sh` is a wrapper of two
#       separate programs that need to be run sequentially (STAR -> RSEM).
#       Adding `nohup ... &` to the individual programs would have caused RSEM
#       to start immediately after STAR was launched (and long before its end).
#       While everything seems to work fine, the structure of the process is
#       quite convoluted and likely difficult to understand and maintain,
#       especially after some time since the script writing. Consider rewriting
#       the script splitting it into 2 separate files along the lines of
#       'trimmer.sh' and 'trimfastq.sh', where the former is the basic script
#       and the latter calls the former by adding the 'nohup' feature.

# --- Source common settings and functions -------------------------------------

# Source functions from x.funx.sh
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/x.funx.sh

# --- Self-calling section -----------------------------------------------------

# Default options
verbose_external=true
progress_or_kill=false

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
    nohup "$0" "selfcall" -q $@ > "nohup.out" 2>&1 &

    # Allow time for 'nohup.out' to be created and populated
    sleep 0.5
    # anqFASTQ has just called itself in '--quiet' mode. When quiet,
    # 'anqfastq.sh' sends messages to output only when called with options -h,
    # -v, -p, -k, any bad arguments, or in the case of errors/exceptions. Thus,
    # the 'nohup.out' file will be empty if and only if anqFASTQ is actually
    # going to align/quantify something. In this case we print the head of the
    # log file to show the scheduled task, otherwise we just print 'nohup.out'
    # to show the output and exit.
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
        head -n 12 "$latest_log"
        printf "Start count computation through STAR/RSEM in background...\n"
    fi
    exit 0 # Success exit status
else
    # This script has been called recursively by itself (in nohup mode)
    shift
fi

# --- Help message -------------------------------------------------------------

read -d '' _help_anqfastq << EOM || true
The anqFASTQ script (short for Align'n'Quantify FASTQs) is a wrapper for STAR
aligner and RSEM quantifier. It analyzes multiple FASTQ files in sequence, using
'nohup' to persistently schedule a series of transcript alignment and abundance
quantification operations that can be executed in the background on a remote
machine. By design, only BAM (not SAM) files are generated by STAR and removed
(by default) after each RSEM cycle.
 
Usage:
  anqfastq [-h | --help] [-v | --version]
  anqfastq -p | --progress [DATADIR]
  anqfastq -k | --kill
  anqfastq [-q | --quiet] [-s | --single-end] [-i | --interleaved]
           [-a | --keep-all] [--suffix="PATTERN"] DATADIR

Positional options:
  -h | --help         Shows this help.
  -v | --version      Shows script's version.
  -p | --progress     Shows alignment and quantification progress by printing
                      the latest cycle of the latest (still possibly growing)
                      log file. If DATADIR is not specified, it searches \$PWD
                      for anqFASTQ logs.
  -k | --kill         Kills all the 'STAR' and 'RSEM' instances currently
                      running and started by the current user (i.e., \$USER).
  -q | --quiet        Disables verbose on-screen logging.
  -s | --single-end   Single-ended (SE) reads. NOTE: non-interleaved (i.e.,
                      dual-file) PE reads is the default.
  -i | --interleaved  PE reads interleaved into a single file. Ignored when '-s'
                      option is also present.
  -a | --keep-all     Does not delete BAM files after quantification (for those
                      who have infinite storage space...).
  --suffix="PATTERN"  For dual-file PE reads, "PATTERN" should be a regex-like
                      pattern of this type
                          "leading_str(alt_1|alt_2)trailing_str",
                      specifying the two alternative suffixes used to match
                      paired FASTQs. The default pattern is "(1|2).fastq.gz".
                      For SE reads or interleaved PE reads, it can be any text
                      string, the default being ".fastq.gz". In any case, this
                      option must be the last one of the flags, placed right
                      before DATADIR.
  DATADIR             Path of a FASTQ-containing folder. The script assumes that
                      all the FASTQs are in the same directory, but it doesn't
                      inspect subfolders.
EOM

# --- Function definition ------------------------------------------------------

# Show alignment and quantification progress printing the tail of the latest log
function _progress_anqfastq {

    if [[ -d "$1" ]]; then
        target_dir="$(realpath "$1")"
    else
        printf "Bad DATADIR '$1'.\n"
        exit 1 # Argument failure exit status: bad target path
    fi

    # NOTE: In the 'find' command below, the -printf "%T@ %p\n" option prints
    #       the modification timestamp followed by the filename.
    #       The '-f 2-' option in 'cut' is used to take all the fields after
    #       the first one (i.e., the timestamp) to avoid cropping possible
    #       filenames or paths with spaces.
    latest_log="$(find "${target_dir}" -maxdepth 1 -type f \
        -iname "Z_Quant_*.log" -printf "%T@ %p\n" \
        | sort -n | tail -n 1 | cut -d " " -f 2-)"

    if [[ -n "$latest_log" ]]; then
        
        echo -e "\n${latest_log}\n"

        # Print only the last cycle in the log file by finding the penultimate
        # occurrence of the pattern "============"
        line=$(grep -n "============" "$latest_log" | \
            cut -d ":" -f 1 | tail -n 2 | head -n 1 || [[ $? == 1 ]])
        
        # The 'uniq' removes the highly repeated 'ROUND = xxx' lines generated
        # by 'rsem', keeping only the last ROUND.
        # This has the unfortunate side effect of removing ALL duplicated lines
        # that are adjacent and that start with the same 8 characters...
        tail -n +${line} "$latest_log" | tac - | uniq -w 8 | tac
        exit 0 # Success exit status
    else
        printf "No anqFASTQ log file found in '${target_dir}'.\n"
        exit 2 # Argument failure exit status: missing log
    fi
}

# --- Argument parsing ---------------------------------------------------------

# Default options
verbose=true
paired_reads=true
dual_files=true
remove_bam=true
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
                printf "%s\n" "$_help_anqfastq"
                exit 0 # Success exit status
            ;;
            -v | --version)
                figlet a\'n\'q FASTQ
                printf "Ver.${ver} :: The Endothelion Project :: by FeAR\n"
                exit 0 # Success exit status
            ;;
            -p | --progress)
                # Cryptic one-liner meaning "$2" or $PWD if argument 2 is unset
                _progress_anqfastq "${2:-.}"
            ;;
            -k | --kill)
                k_flag="k_flag"
                while [[ -n "$k_flag" ]]; do
                    k_flag="$(pkill -eu $USER "STAR" || [[ $? == 1 ]])"
                    if [[ -n "$k_flag" ]]; then echo "$k_flag"; fi
                done
                k_flag="k_flag"
                while [[ -n "$k_flag" ]]; do
                    k_flag="$(pkill -eu $USER "rsem-" \
                        || [[ $? == 1 ]])"
                    if [[ -n "$k_flag" ]]; then echo "$k_flag"; fi
                done
                    _set_motd "${xpath}/config/motd_idle" \
                        "gracefully killed" "read alignment"
                exit 0
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
                remove_bam=false
                shift  
            ;;
            --suffix*)
                # Test for '=' presence
                rgx="^--suffix="
                if [[ "$1" =~ $rgx ]]; then
                    if [[ $paired_reads == true && $dual_files == true && \
                       "${1/--suffix=/}" =~ $vrp ]]; then
                        suffix_pattern="${1/--suffix=/}"
                        shift
                    elif [[ ($paired_reads == false || \
                       $dual_files == false) && "${1/--suffix=/}" != "" ]]; then
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
        # The first non-FRP sequence is taken as the DATADIR argument
        target_dir="$(realpath "$1")"
        break
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

# Retrieve STAR and RSEM local paths from the 'install.paths' file
starpath="$(grep -i "$(hostname):STAR:" \
    "${xpath}/install.paths" | cut -d ':' -f 3 || [[ $? == 1 ]])"
starindex_path="$(grep -i "$(hostname):S_index:" \
    "${xpath}/install.paths" | cut -d ':' -f 3 || [[ $? == 1 ]])"
rsempath="$(grep -i "$(hostname):RSEM:" \
    "${xpath}/install.paths" | cut -d ':' -f 3 || [[ $? == 1 ]])"
rsemref_path="$(grep -i "$(hostname):R_ref:" \
    "${xpath}/install.paths" | cut -d ':' -f 3 || [[ $? == 1 ]])"

# Check if stuff exists
if [[ -z "${starpath}" || ! -e "${starpath}/STAR" ]]; then
    printf "Couldn't find 'STAR' executable...\n"
    printf "Please, check the 'install.paths' file.\n"
    exit 8
fi
if [[ -z "${starindex_path}" || ! -e "${starindex_path}/SA" ]]; then
    printf "Couldn't find a valid 'STAR' index...\n"
    printf "Please, build one using 'STAR ... --runMode genomeGenerate ...'\n"
    printf "and check the 'install.paths' file.\n"
    exit 9
fi
if [[ -z "${rsempath}" || ! -e "${rsempath}/rsem-calculate-expression" ]]; then
    printf "Couldn't find 'rsem-calculate-expression' executable...\n"
    printf "Please, check the 'install.paths' file.\n"
    exit 10
fi
if [[ -z "${rsemref_path}" || -z "$(find "$(dirname "${rsemref_path}")" \
    -maxdepth 1 -type f -iname "$(basename "${rsemref_path}*")" \
    2> /dev/null)" ]]; then
    printf "Couldn't find a valid 'RSEM' reference...\n"
    printf "Please, build one using 'rsem-prepare-reference'\n"
    printf "and check the 'install.paths' file.\n"
    exit 11
fi

# --- Main program -------------------------------------------------------------

running_proc=$(pgrep -l "STAR|rsem-" | wc -l || [[ $? == 1 ]])
if [[ $running_proc -gt 0 ]]; then
    printf "\nSome instances of either STAR or RSEM are already running "
    printf "in the background!"
    printf "\nPlease kill them or wait for them to finish before running this "
    printf "script again...\n"
    exit 12 # Failure exit status: STAR/RSEM already running
fi

log_file="${target_dir}"/Z_Quant_"$(basename "$target_dir")"_$(_tstamp).log

# Set the warning login message
_set_motd "${xpath}/config/motd_warn" >> "$log_file"

_dual_log $verbose "$log_file"\
    "\nSTAR found in \"${starpath}\""\
    "STAR index found in \"${starindex_path}\""\
    "RSEM found in \"${rsempath}\""\
    "RSEM reference found in \"$(dirname "${rsemref_path}")\"\n"\
    "Searching '$target_dir' for FASTQs to align..."

if $paired_reads && $dual_files; then

    _dual_log $verbose "$log_file" "\nRunning in \"dual-file paired-end\" mode:"

    # Assign the suffixes to match paired FASTQs
    r_suffix="$(_explode_ORpattern "$suffix_pattern")"
    r1_suffix="$(echo "$r_suffix" | cut -d ',' -f 1)"
    r2_suffix="$(echo "$r_suffix" | cut -d ',' -f 2)"
    _dual_log $verbose "$log_file"\
        "   Suffix 1: ${r1_suffix}"\
        "   Suffix 2: ${r2_suffix}"

    extension=".*\.gz$"
    if [[ ! "$r_suffix" =~ $extension ]]; then
        _dual_log true "$log_file"\
            "\nFATAL: Only .gz-compressed FASTQs are currently supported!"\
            "Adapt '--readFilesCommand' option to handle different formats."
        exit 13 # Argument failure exit status: missing DATADIR
    fi

    # Check FASTQ pairing
    counter=0
    while IFS= read -r line
    do
        if [[ ! -e "${line}${r1_suffix}" || ! -e "${line}${r2_suffix}" ]]; then
            _dual_log true "$log_file"\
                "\nA FASTQ file is missing in the following pair:"\
                "   ${line}${r1_suffix}"\
                "   ${line}${r2_suffix}"\
                "\nAborting..."
            exit 14 # Argument failure exit status: incomplete pair
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

    _dual_log $verbose "$log_file"\
        "$counter x 2 = $((counter*2)) paired FASTQ files found."

    # Loop over them
    i=1 # Just another counter
    for r1_infile in "${target_dir}"/*"$r1_suffix"
    do
        r2_infile="$(echo "$r1_infile" | sed "s/$r1_suffix/$r2_suffix/")"

        _dual_log $verbose "$log_file"\
            "\n============"\
            " Cycle ${i}/${counter}"\
            "============"\
            "Targeting: ${r1_infile}"\
            "           ${r2_infile}"

        r1_length=$(_mean_read_length "$r1_infile")
        r2_length=$(_mean_read_length "$r2_infile")
        _dual_log $verbose "$log_file" \
            "\nEstimated (ceiling) mean read length: ${r1_length} + ${r2_length} bp"
        if [[ $r1_length -lt 50 || $r2_length -lt 50 ]]; then
            min_length=$(( r1_length < r2_length ? r1_length-1 : r2_length-1 ))
            _dual_log $verbose "$log_file" \
                "WARNING: Mean read length less than 50 bp detected !!\n"\
                "If using a \"standard\" STAR index (i.e., '--sjdbOverhang 100')"\
                "consider building another one using '--sjdbOverhang ${min_length}'."
        fi

        # Change the working directory (of the sub-shell in which anqFASTQ is
        # running) and move to DATADIR (i.e., ${target_dir}).
        # Using relative paths is inelegant, but it is the only workaround I
        # found to successfully feed paths containing spaces to STAR. Even
        # hard-escaping the names of in/out directories by backslashes (i.e.,
        # "${r1_infile//" "/'\ '}") didn't work, probably due to some
        # STAR-inherent path handling features.
        cd "$target_dir"
        base_r1_infile="$(basename "$r1_infile")"
        base_r2_infile="$(basename "$r2_infile")"

        prefix="$(basename "$r1_infile" \
            | grep -oP "^[a-zA-Z]*\d+" || [[ $? == 1 ]])"
        out_dir="./Counts/${prefix}"
        mkdir -p "$out_dir"

        # Run STAR
        _dual_log $verbose "$log_file"\
            "\nStart aligning through STAR...\n"
        # also try to add this to use shared memory: --genomeLoad LoadAndKeep \
        ${starpath}/STAR \
            --runThreadN 8 \
            --runMode alignReads \
            --quantMode TranscriptomeSAM \
            --outSAMtype BAM Unsorted \
            --genomeDir "$starindex_path" \
            --readFilesIn "$base_r1_infile" "$base_r2_infile" \
            --readFilesCommand gunzip -c \
            --outFileNamePrefix "${out_dir}/STAR." \
            >> "${log_file}" 2>&1

        # Run RSEM
        _dual_log $verbose "$log_file"\
            "\nStart quantification through RSEM...\n"
        ${rsempath}/rsem-calculate-expression \
            -p 8 \
            --alignments \
            --paired-end \
            --no-bam-output \
            "${out_dir}/STAR.Aligned.toTranscriptome.out.bam" \
            "${rsemref_path}" \
            "${out_dir}/RSEM" \
            >> "${log_file}" 2>&1

        _dual_log $verbose "$log_file" "DONE!"

        # Remove BAM files generated by STAR
        if $remove_bam; then
            rm "${out_dir}"/*.bam
        fi

        # Increment the i counter
        ((i++))
    done

elif ! $paired_reads; then

    _dual_log $verbose "$log_file"\
        "\nRunning in \"single-ended\" mode:"\
        "   Suffix: ${se_suffix}"

    extension=".*\.gz$"
    if [[ ! "$se_suffix" =~ $extension ]]; then
        _dual_log true "$log_file"\
            "\nFATAL: Only .gz-compressed FASTQs are currently supported!"\
            "Adapt '--readFilesCommand' option to handle different formats."
        exit 15 # Argument failure exit status: missing DATADIR
    fi

    counter=$(find "$target_dir" -maxdepth 1 -type f -iname "*${se_suffix}" \
        | wc -l)

    if (( counter > 0 )); then
        _dual_log $verbose "$log_file"\
            "$counter single-ended FASTQ files found."
    else
        _dual_log true "$log_file"\
            "\nNo FASTQ files ending with \"${se_suffix}\" in ${target_dir}."
        exit 16 # Argument failure exit status: no FASTQ found
    fi

    # Loop over them
    i=1 # Just another counter
    for infile in "${target_dir}"/*"$se_suffix"
    do
        _dual_log $verbose "$log_file"\
            "\n============"\
            " Cycle ${i}/${counter}"\
            "============"\
            "Targeting: ${infile}"

        r_length=$(_mean_read_length "$infile")
        _dual_log $verbose "$log_file" \
            "\nEstimated (ceiling) mean read length: ${r_length} bp"
        if [[ $r_length -lt 50 ]]; then
            min_length=$(( r_length - 1 ))
            _dual_log $verbose "$log_file" \
                "WARNING: Mean read length less than 50 bp detected !!\n"\
                "If using a \"standard\" STAR index (i.e., '--sjdbOverhang 100')"\
                "consider building another one using '--sjdbOverhang ${min_length}'."
        fi

        # Change the working directory (of the sub-shell in which anqFASTQ is
        # running) and move to DATADIR (i.e., ${target_dir}).
        cd "$target_dir"
        base_infile="$(basename "$infile")"

        prefix="$(basename "$infile" \
            | grep -oP "^[a-zA-Z]*\d+" || [[ $? == 1 ]])"
        out_dir="./Counts/${prefix}"
        mkdir -p "$out_dir"

        # Run STAR
        _dual_log $verbose "$log_file"\
            "\nStart aligning through STAR...\n"
        # also try to add this to use shared memory: --genomeLoad LoadAndKeep \
        ${starpath}/STAR \
            --runThreadN 8 \
            --runMode alignReads \
            --quantMode TranscriptomeSAM \
            --outSAMtype BAM Unsorted \
            --genomeDir "$starindex_path" \
            --readFilesIn "$base_infile" \
            --readFilesCommand gunzip -c \
            --outFileNamePrefix "${out_dir}/STAR." \
            >> "${log_file}" 2>&1

        # Run RSEM
        _dual_log $verbose "$log_file"\
            "\nWARNING: no information available about fragment length!"\
            "         RSEM will run in single-end mode without considering"\
            "         fragment length distribution. See the 'README.md' file"\
            "         for a discussion about the implication of this."
        _dual_log $verbose "$log_file"\
            "\nStart quantification through RSEM...\n"
        ${rsempath}/rsem-calculate-expression \
            -p 8 \
            --alignments \
            --no-bam-output \
            "${out_dir}/STAR.Aligned.toTranscriptome.out.bam" \
            "${rsemref_path}" \
            "${out_dir}/RSEM" \
            >> "${log_file}" 2>&1

        _dual_log $verbose "$log_file" "DONE!"

        # Remove BAM files generated by STAR
        if $remove_bam; then
            rm "${out_dir}"/*.bam
        fi

        # Increment the i counter
        ((i++))
    done

elif ! $dual_files; then

    _dual_log true "$log_file"\
        "\nSTAR doesn't currently support PE interleaved FASTQ files."\
        "Check it out at https://github.com/alexdobin/STAR/issues/686"\
        "You can deinterlace them first and then run x.FASTQ in the"\
        "dual-file PE default mode. See, e.g.,"\
        "\nPosts"\
        "  https://stackoverflow.com/questions/59633038/how-to-split-paired-end-fastq-files"\
        "  https://www.biostars.org/p/141256/"\
        "\ndeinterleave_fastq.sh on GitHub Gist"\
        "  https://gist.github.com/nathanhaigh/3521724"\
        "\nseqfu deinterleave"\
        "  https://telatin.github.io/seqfu2/tools/deinterleave.html"
fi

# Set the standard login message
_set_motd "${xpath}/config/motd_idle" \
    "smoothly completed" "read alignment" >> "$log_file"
