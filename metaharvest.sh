#!/bin/bash

# ==============================================================================
#  Harvest GEO-compatible metadata given ENA accession number
# ==============================================================================
ver="1.1.0"

# --- Source common settings and functions -------------------------------------

# Source functions from x.funx.sh
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/x.funx.sh

# --- Help message -------------------------------------------------------------

read -d '' _help_metaharvest << EOM || true
Utility script to fetch metadata from both GEO and ENA referring to a given
project.

The issue this script tries to solve is that metadata from GEO have the "useful"
indications, such as sample name, sample type (e.g., case or control), etc...
which ENA's do not (always) have. This script downloads the ENA metadata and
cross references it with GEO metadata to obtain a large metadata matrix for
better usage later.

Different from other x.FASTQ scripts, this one does not run the job in the
background. It also emits found files to stdout, while other messages are sent
to stderr.

Usage:
  metaharvest [-h | --help] [-v | --version]
  metaharvest [-e | --ena] [-g | --geo] ID

  metaharvest -m | --metadata ENA

Positional options:
  -h | --help       Shows this message and exits.
  -v | --version    Shows this script's version and exits.
  -m | --metadata   Downloads the cross-referenced metadata from GEO and ENA
                    as one large metadata matrix.
  ENA               With -d or -m, the ENA accession number for the project to
                    download, e.g., "PRJNA141411"
EOM

# --- Function definition ------------------------------------------------------

eprintf() { printf "%s\n" "$*" >&2; }

# Parses a GEO-retrieved series file (SOFT formatted family file) to a matrix of
# variables and outputs metadata as a .csv file to stdout.
# You can fetch a SOFT file from GEO using the '_fetch_geo_series_soft' function
# as defined in 'x.funx.sh', for example. But you don't *have* to.
#
# USAGE:
#   _fetch_geo_series_soft GEO_ID | _extract_geo_metadata
#   cat SOFT_FILE | _extract_geo_metadata
function _extract_geo_metadata {
    "${xpath}/workers/parse_series.R"
}

# Takes out some metadata from an ENA-retrieved JSON. Outputs them as a .csv
# file to stdout through JQ magic.
# You can fetch a JSON from ENA using the '_fetch_ena_project_json' function as
# defined in 'x.funx.sh', for example. But you don't *have* to.
#
# USAGE:
#   _fetch_ena_project_json ENA_ID | _extract_ena_metadata
#   cat JSON_TO_PARSE | _extract_ena_metadata
function _extract_ena_metadata {
    jq -r '["sample_title",
            "study_alias",
            "sample_alias",
            "study_accession",
            "sample_accession",
            "run_accession",
            "read_count",
            "library_layout"]
            as $cols | map(. as $row | $cols | map($row[.]))
            as $rows | $rows[] | @csv' | \
    cat <(echo "sample_title,geo_series,geo_sample,ena_project,ena_sample,ena_run,read_count,library_layout") -
}

# --- Argument parsing ---------------------------------------------------------

# Default options
ena=false
geo=false

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+$"

# Argument check: options
while [[ $# -gt 0 ]]; do
    if [[ "$1" =~ $frp ]]; then
        case "$1" in
            -h | --help)
                printf "%s\n" "$_help_metaharvest"
                exit 0 # Success exit status
            ;;
            -v | --version)
                _print_ver "metaharvest" "${ver}" "Hedmad & FeAR"
                exit 0 # Success exit status
            ;;
            -e | --ena)
                ena=true
                shift
            ;;
            -g | --geo)
                geo=true
                shift
            ;;
            *)
                eprintf "Unrecognized option flag '$1'."
                eprintf "Use '--help' or '-h' to see possible options."
                exit 1 # Argument failure exit status: bad flag
            ;;
        esac
    else
        accession_id="$1"
        break
    fi
done

if [[ $ena == false && $geo == false ]]; then
    eprintf "Missing option(s) '-g' and/or '-e'."
    eprintf "At least one of the two databases GEO and ENA must be specified."
    eprintf "Use '--help' or '-h' to see the expected syntax."
    exit 2 # Argument failure exit status: missing option
fi
if [[ -z "${accession_id:-}" ]]; then
    eprintf "Missing study accession ID."
    eprintf "Use '--help' or '-h' to see the expected syntax."
    exit 2 # Argument failure exit status: missing option
fi

# --- Main program -------------------------------------------------------------

if [[ $ena == true && $geo == false ]]; then
    
    eprintf "Fetching metadata of '$1' from ENA database"
    _fetch_ena_project_json "$1" | _extract_ena_metadata
    exit 0 # Success exit status

elif [[ $ena == false && $geo == true ]]; then

    eprintf "Fetching metadata of '$1' from GEO database"
    _fetch_geo_series_soft "$1" | _extract_geo_metadata
    exit 0 # Success exit status

elif [[ $ena == true && $geo == true ]]; then
    echo "ENA & GEO"


fi


