#!/bin/bash

# ==============================================================================
#  x.FASTQ cover script
# ==============================================================================
ver="1.6.8"

# --- Source common settings and functions -------------------------------------

# Source functions from x.funx.sh
# NOTE: 'realpath' expands symlinks by default. Thus, $xpath is always the real
#       installation path, even when this script is called by a symlink!
xpath="$(dirname "$(realpath "$0")")"
source "${xpath}"/x.funx.sh

# --- Help message -------------------------------------------------------------

read -d '' _help_xfastq << EOM || true  
x.FASTQ cover-script to manage some features that are common to the entire suite.

Usage:
  x.fastq [-h | --help] [-v | --version] [-r | --report] [-d | --dependencies]
  x.fastq -l | --links [DATADIR]
  x.fastq -s | --space [DATADIR]

Positional options:
  -h | --help          Shows this help.
  -v | --version       Shows script's version.
  -r | --report        Shows version summary for all x.FASTQ scripts.
  -d | --dependencies  Reads the 'install.paths' file and check for third-party
                       software presence.
  -l | --links         Automatically creates multiple symlinks to the original
                       scripts to simplify their calling.
  -s | --space         Disk space usage monitor utility.
  DATADIR              With -l option, the path where the symlinks are to be
                       created. With -s option, the project folder containing
                       all raw data and analysis.
                       In both case, if omitted, it defaults to \$PWD.
EOM

# --- Argument parsing ---------------------------------------------------------

# Flag Regex Pattern (FRP)
frp="^-{1,2}[a-zA-Z0-9-]+$"

# Argument check: options
while [[ $# -gt 0 ]]; do
    if [[ "$1" =~ $frp ]]; then
        case "$1" in
            -h | --help)
                printf "%s\n" "$_help_xfastq"
                exit 0 # Success exit status
            ;;
            -v | --version)
                figlet x.FASTQ
                printf "Ver.${ver} :: The Endothelion Project :: by FeAR\n"
                exit 0 # Success exit status
            ;;
            -r | --report)
                st_tot=0    # 1st version number
                nd_tot=0    # 2nd version number
                rd_tot=0    # 3rd version number
                tab=18      # Tabulature value
                figlet x.FASTQ
                # Looping through files with spaces in their names or paths is
                # not such a trivial thing...
                OIFS="$IFS"
                IFS=$'\n'
                for script in $(find "${xpath}" -maxdepth 2 \
                    -type f -iname "*.sh" -o -iname "*.R" | sort)
                do
                    full_ver=$(grep -ioP "ver=\"(\d+\.){2}\d+\"$" "$script" \
                        | sed "s/[ver=\"]//gI" || [[ $? == 1 ]])
                    if [[ -z "$full_ver" ]]; then
                        continue # Just ignore possible unversioned scripts
                    fi
                    st_num=$(echo $full_ver | cut -d'.' -f1)
                    nd_num=$(echo $full_ver | cut -d'.' -f2)
                    rd_num=$(echo $full_ver | cut -d'.' -f3)
                    st_tot=$(( st_tot + st_num ))
                    nd_tot=$(( nd_tot + nd_num ))
                    rd_tot=$(( rd_tot + rd_num ))
                    _printt $tab "$(basename "$script")"
                    printf ":: v.${full_ver}\n"
                done
                IFS="$OIFS"
                _repeat " " $tab; _repeat "-" 13; printf "\n"
                _printt $tab "Version Sum"
                printf ":: x.${st_tot}.${nd_tot}.${rd_tot}\n"
                exit 0 # Success exit status
            ;;
            -d | --dependencies)
                # Root of the visualization tree
                host="$(hostname)"
                printf "\n${host}\n"
                _arm "|"

                # Check directory-specific software
                local_inst=($(_get_qc_tools "names") $(_get_seq_sw "names"))
                for entry in "${local_inst[@]}"; do
                    # "PCA" is a valid option of qcFASTQ, but it is not a
                    # stand-alone software. The presence of the related
                    # "PCATools" R package will be checked later on...
                    if [[ "$entry" != "PCA" ]]; then
                        _arm "|-" "${yel}${entry}${end}"
                        entry_dir="$(grep -i "${host}:${entry}:" \
                            "${xpath}/install.paths" | cut -d ':' -f 3 \
                            || [[ $? == 1 ]])"
                        entry_path="${entry_dir}/$(_name2cmd ${entry})"
                        if [[ -f "${entry_path}" ]]; then
                            _arm "||_" "${grn}Software found${end}"
                            _arm "| |-" "${entry_path}"
                            _arm "| |_" "v.$(_get_ver "${entry_path}")"
                        else
                            _arm "||_" \
                                "${red}Couldn't find this tool${end}"
                        fi
                        _arm "|"
                    fi
                done

                # Check globally-visible software
                global_inst=("Java" "Python" "R")
                for entry in "${global_inst[@]}"; do
                    
                    # Be aware of the last element (one-liner if-else)
                    final=$([[ "$entry" == "${global_inst[-1]}" ]] \
                        && echo true || echo false)
                    # Draw the terminal branch when you get to the last element
                    $final \
                        && _arm "|_" "${yel}${entry}${end}" \
                        || _arm "|-" "${yel}${entry}${end}"

                    cmd_entry="$(_name2cmd ${entry})"
                    if which "$cmd_entry" > /dev/null 2>&1; then
                        $final && { \
                            _arm " |-" "${grn}Software found${end}"; \
                            _arm " ||-" "(system-wide)"; \
                            _arm " ||_" "v.$(_get_ver "${cmd_entry}")"; \
                        } || { \
                            _arm "||_" "${grn}Software found${end}"; \
                            _arm "| |-" "(system-wide)"; \
                            _arm "| |_" "v.$(_get_ver "${cmd_entry}")"; \
                        }
                    else
                        $final \
                            && _arm " |_" "${red}Couldn't find this tool${end}" \
                            || _arm "||_" "${red}Couldn't find this tool${end}"
                    fi
                    $final || _arm "|"
                done

                # Check R packages (only if Rscript is installed)
                if which Rscript > /dev/null 2>&1; then
                    _arm " |"
                    tab=16  # Tabulature value
                    R_pkgs=("BiocManager" \
                            "PCAtools" \
                            "org.Hs.eg.db" \
                            "org.Mm.eg.db" \
                            "gtools" \
                            "stringi")
                    
                    for pkg in "${R_pkgs[@]}"; do

                        pkg_dir=$(Rscript -e "system.file(package=\"${pkg}\")" \
                            | sed 's/\[1\] //g' | sed 's/"//g')
                        final=$([[ "$pkg" == "${R_pkgs[-1]}" ]] \
                            && echo true || echo false)

                        if [[ -n ${pkg_dir} ]]; then
                            pkg_ver=$(Rscript -e "packageVersion(\"${pkg}\")" \
                                | grep -oP "(\d+\.){2}\d+" || [[ $? == 1 ]])
                            $final \
                                && _arm " |_" "${yel}$(_printt $tab ${pkg})${end}${grn}Package installed${end}: v.${pkg_ver}" \
                                || _arm " |-" "${yel}$(_printt $tab ${pkg})${end}${grn}Package installed${end}: v.${pkg_ver}"
                        else
                            $final \
                                && _arm " |_" "${yel}$(_printt $tab ${pkg})${end}${red}Not found${end}" \
                                || _arm " |-" "${yel}$(_printt $tab ${pkg})${end}${red}Not found${end}"
                        fi
                    done
                fi
                exit 0 # Success exit status
            ;;
            -l | --links)
                OIFS="$IFS"
                IFS=$'\n'
                for script in $(find "${xpath}" -maxdepth 1 -type f \
                    -iname "*.sh" -a -not -iname "x.funx.sh")
                do
                    script_name=$(basename "${script}")
                    # Default to $PWD in the case of missing DATADIR
                    link_path="${2:-.}"/${script_name%.sh}
                    if [[ -e "$link_path" ]]; then
                        rm "$link_path"
                    fi
                    ln -s "$script" "$link_path"
                done
                IFS="$OIFS"
                exit 0 # Success exit status
            ;;
            -s | --space)
                target_dir="$(realpath "${2:-.}")"
                printf "\n${grn}Disk usage report for the "
                printf "$(basename "${target_dir}") x.FASTQ project${end}\n\n"
                printf "${yel}System stats:${end}\n"
                df -Th "$target_dir"
                printf "\n${yel}Project stats:${end}\n"
                _printt 15 "Data"
                du -sh "$target_dir"
                _printt 15 "Genome"
                host="$(hostname)"
                genome_dir="$(grep -i "${host}:Genome:" \
                    "${xpath}/install.paths" | cut -d ':' -f 3 \
                    || [[ $? == 1 ]])"
                if [[ -n "${genome_dir:-""}" ]]; then
                    du -sh "$genome_dir"
                else
                    echo "---"
                fi
                exit 0
            ;;
            -m)
                _count_down 5
                # echo -e $(tail ...) is just to interpret the escape sequences
                echo -e "$(tail -n1 ~/Documents/.x.fastq-m_option)"
                sleep 5
                clear
                exit 0 # Success exit status
            ;;
            *)
                printf "Unrecognized option flag '$1'.\n"
                printf "Use '--help' or '-h' to see possible options.\n"
                exit 1 # Argument failure exit status: bad flag
            ;;
        esac
    else
        printf "Bad argument '$1'.\n"
        printf "Use '--help' or '-h' to see possible options.\n"
        exit 2 # Argument failure exit status: bad argument
    fi
done

printf "Missing option.\n"
printf "Use '--help' or '-h' to see the expected syntax.\n"
exit 3 # Argument failure exit status: missing option
