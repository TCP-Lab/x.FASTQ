#!/bin/bash

# ========================================================================== #
#  Harvest GEO-compatible metadata given ENA accession number                #
# ========================================================================== #

# Originally written by hedmad following the footprint of x.fastq.sh

set -e
set -u
set -o pipefail

# Default version
ver="0.1.0"

# Source functions from x.funx.sh
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/x.funx.sh

_helpmsg_metaharves=""

read -d '' _helpmsg_metaharvest << EOM || true
Utility script to fetch metadata from both GEO and ENA referring to a given
project.

The issue this script tries to solve is that the metadata from GEO has the
"useful" indications, such as sample name, sample type (e.g. case or control),
etc... which ENA does not (always) have.

This script downloads the ENA metadata and cross references it with GEO
metadata to obtain a large metadata matrix for better usage later.

Different from other x.FASTQ scripts, this one does not run the job in the
background. It also emits found files to stdout.

Usage:
    metaharvest [-h | --help] [-v | --version]
    metaharvest -d | --download ENA
    metaharvest -m | --metadata ENA

Options:
    -h | --help         Show this message and exit.
    -v | --version      Show this script's version and exit.
    -d | --download     Fetch the FTP links to download the FASTQ files of an
                        ENA accession.
    -m | --metadata     Download the cross-referenced metadata from GEO and ENA
                        as one large metadata matrix.
    ENA                 With -d or -m, the ENA accession number for the project
                        to download, e.g. "PRJNA141411"

EOM

eprintf() { printf "%s\n" "$*" >&2; }

# Fetch the JSON file with the metadata of some ENA project
#
# Usage:
#   _fetch_ena_project_json ENA_ID
function _fetch_ena_project_json {
    _vars="study_accession,sample_accession,study_alias,fastq_ftp,sample_alias,sample_alias"
    _endpoint="https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${1}&result=read_run&fields=${_vars}&format=json&limit=0"

    wget -qnv -O - ${_endpoint}
}

# Extract from an ENA JSON a list of download URLs.
#
# Emits parsed lines to stdout.
#
# Usage:
#   cat JSON_TO_PARSE | _extract_download_urls
function _extract_download_urls {
    cat - | jq -r '.[] | .fastq_ftp' | sed 's/^/wget -nc ftp:\/\//'
}

# Fetch the series file of a GEO project
#
# Usage:
#   _fetch_series_file GEO_ID
function _fetch_series_file {
    _mask=$(echo "$1" | sed 's/...$/nnn/')
    _url="https://ftp.ncbi.nlm.nih.gov/geo/series/${_mask}/${1}/soft/${1}_family.soft.gz"

    wget -qnv -O - ${_url} | gunzip
}

# Parse a series file to a matrix of variables
#
# Usage:
#   echo $MINIML | _series_to_csv > output.csv
function _series_to_csv {
    cat - | Rscript --vanilla ${xpath}/parse_series.R
}

function _extract_geo_ena_sample_ids {
    jq -r '["sample_accession", "run_accession", "sample_alias"] as $cols | map(. as $row | $cols | map($row[.])) as $rows | $rows[] | @csv' | \
        cat <(echo "sample_accession,run_accession,geo_accession") - 
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
            -d | --download)
                shift 1
                eprintf "Downloading URLs for FASTQ data of '$1'"
                _fetch_ena_project_json $1 | _extract_download_urls > /dev/stdout
                exit 0
            ;;
            -m | --metadata)
                shift 1
                eprintf "Fetching metadata of '$1'"
                project_json=$(_fetch_ena_project_json $1)
                geo_project_id=$(echo "${project_json}" | jq -r '.[0] | .study_alias')
                eprintf "Fetching GEO metadata of '${geo_project_id}'"
                geo_metadata=$(_fetch_series_file "${geo_project_id}" | _series_to_csv)
                keys=$(echo ${project_json} | _extract_geo_ena_sample_ids)
                ${xpath}/fuse_csv.R -c "geo_accession" -r "${geo_metadata}" -r "${keys}"
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
