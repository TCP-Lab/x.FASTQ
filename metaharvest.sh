#!/bin/bash

# ==============================================================================
#  Harvest GEO-compatible metadata given ENA accession number
# ==============================================================================
ver="1.2.0"

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
  metaharvest [-e | --ena] [-g | --geo] [-s | --selector] ID

Positional options:
  -h | --help       Shows this message and exits.
  -v | --version    Shows this script's version and exits.
  -m | --metadata   Downloads the cross-referenced metadata from GEO and ENA
                    as one large metadata matrix.
  -x | --extra      Adds a trailing extra column (filled by 1) for subsequent custom annotations.
  ID                With -d or -m, the ENA accession number for the project to
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
    cat <(echo '"ena_sample_title","geo_series","geo_accession","ena_project","ena_sample","ena_run","read_count","library_layout"') -
}

# --- Argument parsing ---------------------------------------------------------

# Default options
ena=false
geo=false

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+"
# Project accession ID Regex Patterns
ena_rgx="^PRJ[A-Z]{2,}[0-9]+$"
geo_rgx="^GSE[0-9]+$"

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
            -x* | --extra*)
                # Test for '=' presence
                rgx="^-x=|^--extra="
                if [[ "$1" =~ $rgx ]]; then
                    regular_entry="$1"
                    regular_entry="${regular_entry#-x=}"
                    regular_entry=",\"${regular_entry#--extra=}\""
                    head_entry=",\"extra\""
                    shift
                else
                    printf "Values need to be assigned to '--extra' option "
                    printf "using the '=' operator.\n"
                    printf "Use '--help' or '-h' to see the correct syntax.\n"
                    exit 4 # Bad suffix assignment
                fi
            ;;            
            *)
                eprintf "Unrecognized option flag '$1'."
                eprintf "Use '--help' or '-h' to see possible options."
                exit 1 # Argument failure exit status: bad flag
            ;;
        esac
    else
        # The first non-FRP sequence is taken as the ID argument
        accession_id="$1"
        break
    fi
done

if [[ $ena == false && $geo == false ]]; then
    eprintf "Missing option(s) '-g' and/or '-e'."
    eprintf "At least one of the two databases GEO or ENA must be specified."
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
    eprintf "Fetching metadata of '$accession_id' from ENA database"
    
    # Since we cannot (currently) convert from GEO to ENA, we need the ENA ID.
    if [[ ! $accession_id =~ $ena_rgx ]]; then
        eprintf "Invalid project ID $accession_id."
        eprintf "Expected format: ENA accession ID."
        exit 1
    fi

    _fetch_ena_project_json "$accession_id" | _extract_ena_metadata \
        | sed "1s/$/${head_entry:-}/" | sed "2,\$s/$/${regular_entry:-}/"
    exit 0 # Success exit status

elif [[ $ena == false && $geo == true ]]; then
    eprintf "Fetching metadata of '$1' from GEO database"

    # Being able to convert from ENA to GEO, we can accommodate any ID.
    if [[ $accession_id =~ $ena_rgx ]]; then
        geo_accession_id=$(_ena2geo_id $accession_id)
        eprintf "ENA ID detected, converted to GEO alias: $accession_id --> $geo_accession_id"
    elif [[ $accession_id =~ $geo_rgx ]]; then
        geo_accession_id=$accession_id
        eprintf "GEO ID detected: $geo_accession_id"
    else
        eprintf "Invalid project ID $accession_id."
        eprintf "Unknown format."
        exit 1
    fi

    _fetch_geo_series_soft "$geo_accession_id" | _extract_geo_metadata \
        | sed "1s/$/${head_entry:-}/" | sed "2,\$s/$/${regular_entry:-}/"
    exit 0 # Success exit status

elif [[ $ena == true && $geo == true ]]; then
    eprintf "Fetching metadata from both GEO and ENA databases"

    # Since we cannot (currently) convert from GEO to ENA, we need the ENA ID.
    if [[ $accession_id =~ $ena_rgx ]]; then
        # Convert ENA ID to GEO ID
        geo_accession_id=$(_ena2geo_id $accession_id)
        eprintf "ENA-to-GEO conversion: $accession_id --> $geo_accession_id"
    else
        eprintf "Invalid project ID $accession_id."
        eprintf "Expected format: ENA accession ID."
        exit 1
    fi

    # To avoid an "argument too long" error, we need temporary files to save
    # metadata into.
    geo_meta_file="$(mktemp)"
    ena_meta_file="$(mktemp)"
    _fetch_geo_series_soft $geo_accession_id \
        | _extract_geo_metadata > "$geo_meta_file"
    _fetch_ena_project_json $accession_id \
        | _extract_ena_metadata > "$ena_meta_file"

    "${xpath}/workers/fuse_csv.R" -c "geo_accession" \
        "$geo_meta_file" "$ena_meta_file" \
        | sed "1s/$/${head_entry:-}/" | sed "2,\$s/$/${regular_entry:-}/"

    rm "$geo_meta_file"
    rm "$ena_meta_file"
    exit 0
fi
