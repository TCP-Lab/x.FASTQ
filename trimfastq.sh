#!/bin/bash

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
# 	1 means no lines selected;
# 	> 1 means an error.
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

# ============================================================================ #
#  Persistently Trim FastQ Files using BBDuk
# ============================================================================ #

# Current date and time
now="$(date +"%Y.%m.%d_%H.%M.%S")"

# Default options
ver="0.9"

# Print the help
function _help_trimfastq {
    echo
    echo "This script schedules a persistent (i.e., 'nohup') queue of FASTQ"
    echo "adapter-trimming by wrapping the 'trimmer.sh' script, which is in"
    echo "turn a wrapper of BBDuk trimmer (from the BBTools suite). Syntax and"
    echo "options are the same for both 'trimfastq.sh' and 'trimmer.sh', the"
    echo "only difference being the persistence feature of the the former."
    echo
    printf "Here it follows the 'trimmer.sh --help'."
    bash ./trimmer.sh --help
}

# Argument check: override -h and -v options
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        _help_trimfastq
        exit 0 # Success exit status
    elif [[ "$arg" == "-v" || "$arg" == "--version" ]]; then
        figlet trim FASTQ
        printf "Ver.${ver} :: The Endothelion Project :: by FeAR\n"
        exit 0 # Success exit status
    fi
done

# Hand down all the other arguments
echo "trimmer.sh $@"
bash ./trimmer.sh $@

nohup bash ./trimmer.sh -q $@
