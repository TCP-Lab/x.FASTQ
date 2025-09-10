#!/bin/bash

# ==============================================================================
#  Assemble the count table
# ==============================================================================
ver="2.0.0"

# --- Source common settings and functions -------------------------------------
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/workers/x.funx.sh
source "${xpath}"/workers/progress_funx.sh

# --- Help message -------------------------------------------------------------

read -d '' _help_tabfastq << EOM || true
tabFASTQ is a wrapper for the 'assembler.R' worker script that searches for all
the RSEM quantification output files within a given folder in order to assemble
them into one single matrix of counts (aka expression matrix or count table). It
can work at both gene and isoform levels, optionally including gene names and
symbols as annotation. By design, 'assembler.R' searches all the sub-directories
within the specified DATADIR folder, assuming that each RSEM output file has
been saved into a sample-specific sub-directory, whose name will be used as a
sample ID in the heading of the final expression table. If provided, it can also
inject an experimental design string into column names by adding a dotted suffix
to each sample name.

Usage:
  tabfastq [-h | --help] [-v | --version]
  tabfastq -p | --progress [DATADIR]
  tabfastq [-q | --quiet] [-w | --workflow] [-n[=ORG] | --names[=ORG]]
           [-i | --isoforms] [--design=ARRAY] [--metric=MTYPE]
           [-r | --raw] DATADIR

Positional options:
  -h | --help      Shows this help.
  -v | --version   Shows script's version.
  -p | --progress  Shows assembly progress by scraping the latest (possibly
                   still growing) tabFASTQ log file. If DATADIR is not
                   specified, it searches \$PWD for tabFASTQ logs.
  -q | --quiet     Disables verbose on-screen logging.
  -w | --workflow  Makes processes run in the foreground for use in pipelines.
  -n | --names     Appends gene symbol, gene name, and gene type annotations. 
                   NOTE: this option requires Ensembl gene/transcript IDs.
  ORG              If provided along with the previous option, can be used to
                   specify the model organism to be used for gene annotation. If
                   omitted, it defaults to 'human'.
  -i | --isoforms  Assembles counts at the transcript level instead of gene (the
                   default level).
  -r | --raw       Not to include the name of the metric in the column names.
  --design="ARRAY" Injects an experimental design into the heading of the final
                   expression matrix by adding a suffix to each sample name.
                   Suffixes must be as many in number as samples, and they
                   should be given as an array of spaced elements enclosed or
                   not within round or square brackets. In any case, the set of
                   suffixes needs always to be quoted. Elements in the array are
                   meant to label the samples according to the experimental
                   group they belong to; for this reason they should be ordered
                   according to the reading sequence of the sample files (i.e.,
                   alphabetical order on their full path).
  --metric=MTYPE   Metric type to be used in the expression matrix. Based on
                   RSEM output, the possible options are 'expected_count', 'TPM'
                   (default), and 'FPKM'.
  DATADIR          The path to the parent folder containing all the RSEM output
                   files (organized into subfolders) to be used for expression
                   matrix assembly.

Additional Notes:
  Examples of valid input for the '--design' parameter are:
    --design="(ctrl ctrl drug1 drug2 drug1 drug2)"
    --design="[0 0 1 1 0 0 1]"
    --design="[[ x y z ))"
    --design="a a bb bb bb ccc"
  Even previously defined Bash arrays can be used as '--design' arguments, but
  they have to be expanded to a 'single word' using '*' in place of '@' (and
  never forgetting the double-quotes!!):
    --design="\${foo[*]}"
  However, keep in mind that this works only if the first value of \$IFS is a
  space. Thus, a two-step approach may be safer:
    bar="\${foo[@]}"
    --design="\$bar"
  For large sample sizes, you can also take advantage of the brace expansion in
  this way:
    --design=\$(echo {1..15}.ctrl {1..13}.drug)
EOM

# --- Argument parsing and validity check --------------------------------------

# Default options
verbose=true
pipeline=false
gene_names=false
org="human"
level="genes"
design="NA"
metric="TPM"
raw=false

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+"

# Argument check: options
while [[ $# -gt 0 ]]; do
    if [[ "$1" =~ $frp ]]; then
        case "$1" in
            -h | --help)
                printf "%s\n" "$_help_tabfastq"
                exit 0
            ;;
            -v | --version)
                _print_ver "tab FASTQ" "${ver}" "FeAR"
                exit 0
            ;;
            -p | --progress)
                # Cryptic one-liner meaning "$2" or $PWD if argument 2 is unset
                _progress_tabfastq "${2:-.}"
                exit 0
            ;;
            -q | --quiet)
                verbose=false
                shift
            ;;
            -w | --workflow)
                pipeline=true
                shift
            ;;
            -n | --names)
                gene_names=true
                shift
            ;;
            -n* | --names*)
                gene_names=true
                # Test for '=' presence
                rgx="^-n=|^--names="
                if [[ "$1" =~ $rgx ]]; then
                    org="${1#-n=}" # Remove short flag
                    org="${org#--names=}" # Remove long flag
                    # Check if a given string is an element of an array.
                    # NOTE: leading and trailing spaces around array elements
                    #       are used to ensure accurate pattern matching!
                    if [[ " human mouse " == *" ${org} "* ]]; then
                        shift
                    else
                        eprintf "Currently unsupported model organism '$org'.\n" \
                            "Please, choose among the following ones:\n" \
                            "  -  human\n" \
                            "  -  mouse\n"
                        exit 6
                    fi
                else
                    _print_bad_assignment "--names"
                    exit 7
                fi
            ;;
            -i | --isoforms)
                level="isoforms"
                shift
            ;;
            -r | --raw)
                raw=true
                shift
            ;;
            --design*)
                # Test for '=' presence
                rgx="^--design="
                if [[ "$1" =~ $rgx ]]; then
                    design="${1/--design=/}"
                    shift
                else
                    _print_bad_assignment "--design"
                    exit 7
                fi
            ;;
            --metric*)
                # Test for '=' presence
                rgx="^--metric="
                if [[ "$1" =~ $rgx ]]; then
                    metric="${1/--metric=/}"
                    # Check if a given string is an element of an array.
                    # NOTE: leading and trailing spaces around array elements
                    #       are used to ensure accurate pattern matching!
                    if [[ " expected_count TPM FPKM " == *" ${metric} "* ]]; then
                        shift
                    else
                        eprintf "Invalid metric: '$metric'.\n" \
                            "Please, choose among the following options:\n" \
                            "  -  expected_count\n" \
                            "  -  TPM\n" \
                            "  -  FPKM\n"
                        exit 6
                    fi
                else
                    _print_bad_assignment "--metric"
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

# --- Main program -------------------------------------------------------------

# Set the log file
# When creating the log file, 'basename "$target_dir"' assumes that DATADIR
# was properly named with the current BioProject/Study ID.
log_file="${target_dir}/Z_tabFASTQ_$(basename "$target_dir")_$(_tstamp).log"
_dual_log false "$log_file" "-- $(_tstamp) --\n"
_dual_log $verbose "$log_file" \
    "tabFASTQ :: Expression Matrix Assembler :: ver.${ver}\n\n" \
    "Searching RSEM output files in ${target_dir}\n" \
    "Working at ${level%s} level with $metric metric.\n"
if ${gene_names}; then
    _dual_log $verbose "$log_file" \
    "Annotating for ${org}.\n"
fi

# HOLD-ON STATEMENT
_hold_on "$log_file" Rscript --vanilla "${xpath}"/workers/assembler.R \
    "$gene_names" "$org" "$level" "$design" "$metric" "$raw" "$target_dir"
