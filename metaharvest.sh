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

read -d '' _helpmsg_metaharvest << EOM || true
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

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+$"

# Argument check: options
while [[ $# -gt 0 ]]; do
    if [[ "$1" =~ $frp ]]; then
        case "$1" in
            -h | --help)
                eprintf "$_helpmsg_metaharvest"
                exit 0 # Success exit status
            ;;
            -v | --version)
                figlet metaharvest
                eprintf "Ver.${ver} :: The Endothelion Project :: by Hedmad"
                exit 0 # Success exit status
            ;;
            -e | --ena)
                [[ $# -lt 2 ]] && break
                shift 1
                eprintf "Fetching metadata of '$1' from ENA database"
                _fetch_ena_project_json "$1" | _extract_ena_metadata
                exit 0 # Success exit status
            ;;
            -g | --geo)
                [[ $# -lt 2 ]] && break
                shift 1
                eprintf "Fetching metadata of '$1' from GEO database"
                _fetch_geo_series_soft "$1" | _extract_geo_metadata
                exit 0 # Success exit status
            ;;
            -eg | -ge)
                [[ $# -lt 2 ]] && break
                shift 1
                eprintf "Fetching metadata of '$1'"
                project_json=$(_fetch_ena_project_json $1)
                geo_project_id=$(echo "${project_json}" \
                    | jq -r '.[0] | .study_alias')

                eprintf "Fetching GEO metadata of '${geo_project_id}'"
                # To avoid an "argument too long" error, we need temporary files
                # to save the metadata into.
                geo_meta_file=$(mktemp)
                ena_keys_file=$(mktemp)
                
                _fetch_geo_series_soft "${geo_project_id}" \
                    | _extract_geo_metadata > "${geo_meta_file}"
                echo "${project_json}" \
                    | _extract_ena_metadata > "${ena_keys_file}"
                "${xpath}/workers/fuse_csv.R" -c "geo_accession" \
                    "${geo_meta_file}" "${ena_keys_file}"

                rm "${geo_meta_file}"
                rm "${ena_keys_file}"
                exit 0
            ;;
            *)
                eprintf "Unrecognized option flag '$1'."
                eprintf "Use '--help' or '-h' to see possible options."
                exit 1 # Argument failure exit status: bad flag
            ;;
        esac
    else
        eprintf "Bad argument '$1'.\n"
        eprintf "Use '--help' or '-h' to see possible options."
        exit 1 # Argument failure exit status: bad argument
    fi
done

eprintf "Missing option."
eprintf "Use '--help' or '-h' to see the expected syntax."
exit 2 # Argument failure exit status: missing option
