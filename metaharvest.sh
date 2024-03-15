#!/bin/bash

# ==============================================================================
#  Harvest GEO-compatible metadata given ENA accession number
# ==============================================================================
ver="1.0.1"

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
  metaharvest -d | --download ENA
  metaharvest -m | --metadata ENA

Positional options:
  -h | --help       Shows this message and exit.
  -v | --version    Shows this script's version and exit.
  -d | --download   Fetches the FTP links to download the FASTQ files of an
                    entire ENA accession.
  -m | --metadata   Downloads the cross-referenced metadata from GEO and ENA
                    as one large metadata matrix.
  ENA               With -d or -m, the ENA accession number for the project to
                    download, e.g., "PRJNA141411"
EOM

# --- Function definition ------------------------------------------------------

eprintf() { printf "%s\n" "$*" >&2; }

# Fetch the JSON file with the metadata of some ENA project.
#
# Usage:
#   _fetch_ena_project_json ENA_ID
function _fetch_ena_project_json {
	_vars="study_accession,sample_accession,study_alias,fastq_ftp,sample_alias,read_count"
	_endpoint="https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${1}&result=read_run&fields=${_vars}&format=json&limit=0"

    wget -qnv -O - ${_endpoint}
}

# Extract from an ENA JSON a list of download URLs.
# Emits parsed lines to stdout.
#
# Usage:
#   cat JSON_TO_PARSE | _extract_download_urls
function _extract_download_urls {
	cat - | jq -r '.[] | .fastq_ftp' | sed 's/^/wget -nc ftp:\/\//'
}

# Fetch the series file of a GEO project (SOFT formatted family file).
#
# Usage:
#   _fetch_series_file GEO_ID
function _fetch_series_file {
	_mask=$(echo "$1" | sed 's/...$/nnn/')
	_url="https://ftp.ncbi.nlm.nih.gov/geo/series/${_mask}/${1}/soft/${1}_family.soft.gz"

	wget -qnv -O - ${_url} | gunzip
}

# Parse a series file to a matrix of variables.
#
# Usage:
#   echo $MINIML | _series_to_csv > output.csv
function _series_to_csv {
	cat - | "${xpath}/workers/parse_series.R"
}

# Takes out from an ENA-retrieved JSON the sample IDs for both ENA and GEO.
# Outputs them as a .csv file to stdout through JQ magic.
#
# Usage:
#   # You can fetch a JSON with the `_fetch_ena_project_json` function above,
#   # for example. But you don't *have* to.
#   _fetch_ena_project_json ${ACCESSION} | _extract_geo_ena_sample_ids
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
				# Also use sed to manage URLs of paired-end read. 
				_fetch_ena_project_json $1 | _extract_download_urls | \
					sed 's/;/\nwget -nc ftp:\/\//g'
				exit 0
			;;
			-m | --metadata)
				shift 1
				eprintf "Fetching metadata of '$1'"
				project_json=$(_fetch_ena_project_json $1)
				geo_project_id=$(echo "${project_json}" | jq -r '.[0] | .study_alias')

				eprintf "Fetching GEO metadata of '${geo_project_id}'"
				# To avoid an "argument too long" error, we need temporary files
				# to save the metadata into.
				geo_meta_file=$(mktemp)
				ena_keys_file=$(mktemp)
				
				_fetch_series_file "${geo_project_id}" | _series_to_csv > "${geo_meta_file}"
				echo "${project_json}" | _extract_geo_ena_sample_ids > "${ena_keys_file}"
				"${xpath}/workers/fuse_csv.R" -c "geo_accession" "${geo_meta_file}" "${ena_keys_file}"

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
