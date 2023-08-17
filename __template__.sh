#!/bin/bash

# ============================================================================ #
#  Script Title
# ============================================================================ #

# --- General settings and variables -------------------------------------------

set -e # "exit-on-error" shell option
set -u # "no-unset" shell option

# ============================================================================ #
# NOTE on -e option
# -----------------
# If you use grep and do NOT consider grep finding no match as an error,
# use the following syntax
#
# grep "<expression>" || [[ $? == 1 ]]
#
# to prevent grep from causing premature termination of the script.
# This works since, according to posix manual, exit code
#   1 means no lines selected;
#   > 1 means an error.
#
# NOTE on -u option
# ------------------
# The existence operator ${:-} allows avoiding errors when testing variables by
# providing a default value in case the variable is not defined or empty.
#
# result=${var:-value}
#
# If `var` is unset or null, `value` is substituted (and assigned to `results`).
# Otherwise, the value of `var` is substituted and assigned.
# ============================================================================ #

# Current date and time in "yyyy.mm.dd_HH.MM.SS" format
now="$(date +"%Y.%m.%d_%H.%M.%S")"

# For a friendlier use of colors in Bash
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
end=$'\e[0m'

# --- Function definition ------------------------------------------------------

# Default options
ver="0.0.0"
verbose=true

# Print the help
function _help_scriptname {
	echo
	echo "This script is meant to be blah blah blah..."
	echo
	echo "Usage:"
	echo "  scriptname [-h | --help] [-v | --version] ..."
	echo "  scriptname [-q | --quiet] [--value=\"PATTERN\"] TARGETS"
	echo
	echo "Positional options:"
	echo "  -h | --help         Show this help."
	echo "  -v | --version      Show script's version."
	echo "  -q | --quiet        Disable verbose on-screen logging."
	echo "  --value=\"PATTERN\"   Argument allowing for user-defined input."
	echo "  TARGETS             E.g., the path to a file or file-containing"
	echo "                      folder to work on."
	echo "Additional Notes:"
	echo "    You can use this or that to do something..."
}

# On-screen and to-file logging function
#
# USAGE: _dual_log $verbose log_file "message"
#
# Always redirect "message" to log_file; also redirect it to standard output
# (i.e., print on screen) if $verbose == true.
# NOTE:	the 'sed' part allows tabulations to be ignored while still allowing
#       the code (i.e., multi-line messages) to be indented.
function _dual_log {
	if $1; then echo -e "$3" | sed "s/\t//g"; fi
	echo -e "$3" | sed "s/\t//g" >> "$2"
}

# --- Argument parsing ---------------------------------------------------------

# Flag Regex Pattern (FRP)
# The first one is more strict, but it doesn't work for --value=\"PATTERN\"
frp="^-{1,2}[a-zA-Z0-9-]+$"
frp="^-{1,2}[a-zA-Z0-9-]+"

# Argument check: options
while [[ $# -gt 0 ]]; do
	if [[ "$1" =~ $frp ]]; then
		case "$1" in
			-h | --help)
				_help_scriptname
				exit 0 # Success exit status
			;;
			-v | --version)
				figlet Script Title
				printf "Ver.${ver}\n"
				exit 0 # Success exit status
			;;
			-q | --quiet)
				verbose=false
				shift
			;;
			--value*)
				# Test for '=' presence
				if [[ "$1" =~ ^--value=  ]]; then
					# ...	
					value_pattern="${1/--value=/}"
					shift
					# ...
				else
					printf "Values need to be assigned to '--value' option "
					printf "using the '=' operator.\n"
					printf "Use '--help' or '-h' to see the correct syntax.\n"
					exit 1 # Bad suffix assignment
				fi
			;;
			*)
				printf "Unrecognized option flag '$1'.\n"
				printf "Use '--help' or '-h' to see possible options.\n"
				exit 1 # Argument failure exit status: bad flag
			;;
		esac
	else
		# The first non-FRP sequence is taken as the TARGETS argument
		target_dir="$1"
		break
	fi
done

# Argument check: TARGETS directory
if [[ -z "${target_dir:-""}" ]]; then
	printf "Missing option or TARGETS argument.\n"
	printf "Use '--help' or '-h' to see the expected syntax.\n"
	exit 1 # Argument failure exit status: missing TARGETS
elif [[ ! -d "$target_dir" ]]; then
	printf "Invalid target directory '$target_dir'.\n"
	exit 1 # Argument failure exit status: invalid TARGETS
fi

# --- Main program -------------------------------------------------------------

echo OK!
