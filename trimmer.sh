#!/bin/bash

# ==============================================================================
#  Trim reads using BBDuk
# ==============================================================================

# Source functions from x.funx.sh
source "${xpath}"/x.funx.sh

# All these variables are exported from the anqfastq wrapper:
#
# xpath paired_reads dual_files target_dir r1_suffix r2_suffix se_suffix counter
# bbpath nor remove_originals verbose log_file

# --- Main program -------------------------------------------------------------

if $paired_reads && $dual_files; then

    # Loop over them
    i=1 # Just another counter
    for r1_infile in "${target_dir}"/*"$r1_suffix"
    do
        r2_infile="$(echo "$r1_infile" | sed "s/$r1_suffix/$r2_suffix/")"

        printf "%b\n" "\n============" \
        				" Cycle ${i}/${counter}" \
        				"============" \
        				"Targeting: ${r1_infile}" \
        				"           ${r2_infile}" \
        				"\nStart trimming through BBDuk..."

        prefix="$(basename "$r1_infile" "$r1_suffix")"

        # Paths with spaces need to be hard-escaped at this very level to be
        # correctly parsed when passed as arguments to BBDuk!
        esc_r1_infile="${r1_infile//" "/'\ '}"
        esc_r2_infile="${r2_infile//" "/'\ '}"
        esc_target_dir="${target_dir//" "/'\ '}"

        # MAIN STATEMENT (Run BBDuk)
        # also try to add this for Illumina: ftm=5 \
        echo >> "$log_file"
        ${bbpath}/bbduk.sh \
            reads=$nor \
            in1=$esc_r1_infile \
            in2=$esc_r2_infile \
            ref=${bbpath}/resources/adapters.fa \
            stats=${esc_target_dir}/Trim_stats/${prefix}_STATS.tsv \
            ktrim=r \
            k=23 \
            mink=11 \
            hdist=1 \
            tpe \
            tbo \
            out1=$(echo $esc_r1_infile | sed -E "s/_?$r1_suffix/_TRIM_$r1_suffix/") \
            out2=$(echo $esc_r2_infile | sed -E "s/_?$r2_suffix/_TRIM_$r2_suffix/") \
            qtrim=rl \
            trimq=10 \
            minlen=25 \
            >> "${log_file}" 2>&1
        # NOTE: By default, all BBTools write status information to stderr,
        #       not stdout !!!
        echo >> "$log_file"

        printf "DONE!"

        if $remove_originals; then
            rm "$r1_infile" "$r2_infile"
        fi

        # Increment the i counter
        ((i++))
    done

elif ! $paired_reads; then
	
	# Loop over them
    i=1 # Just another counter
    for infile in "${target_dir}"/*"$se_suffix"
    do
        printf "%b\n" "\n============" \
        				" Cycle ${i}/${counter}" \
        				"============" \
        				"Targeting: ${infile}" \
        				"\nStart trimming through BBDuk..."

        prefix="$(basename "$infile" "$se_suffix")"

        # Paths with spaces need to be hard-escaped at this very level to be
        # correctly parsed when passed as arguments to BBDuk!
        esc_infile="${infile//" "/'\ '}"
        esc_target_dir="${target_dir//" "/'\ '}"

        # MAIN STATEMENT (Run BBDuk)
        # also try to add this for Illumina: ftm=5 \
        echo >> "$log_file"
        "${bbpath}"/bbduk.sh \
            reads=$nor \
            in=$esc_infile \
            ref=${bbpath}/resources/adapters.fa \
            stats=${esc_target_dir}/Trim_stats/${prefix}_STATS.tsv \
            ktrim=r \
            k=23 \
            mink=11 \
            hdist=1 \
            interleaved=f \
            out=$(echo $esc_infile | sed -E "s/_?$se_suffix/_TRIM$se_suffix/") \
            qtrim=rl \
            trimq=10 \
            minlen=25 \
            >> "${log_file}" 2>&1
        echo >> "$log_file"

        printf "DONE!"

        if $remove_originals; then
            rm "$infile"
        fi

        # Increment the i counter
        ((i++))
    done

elif ! $dual_files; then

    # Loop over them
    i=1 # Just another counter
    for infile in "${target_dir}"/*"$se_suffix"
    do
        printf "%b\n" "\n============" \
        				" Cycle ${i}/${counter}" \
        				"============" \
        				"Targeting: ${infile}" \
        				"\nStart trimming through BBDuk..."

        prefix="$(basename "$infile" "$se_suffix")"

        # Paths with spaces need to be hard-escaped at this very level to be
        # correctly parsed when passed as arguments to BBDuk!
        esc_infile="${infile//" "/'\ '}"
        esc_target_dir="${target_dir//" "/'\ '}"

        # MAIN STATEMENT (Run BBDuk)
        # also try to add this for Illumina: ftm=5 \
        echo >> "$log_file"
        ${bbpath}/bbduk.sh \
            reads=$nor \
            in=$esc_infile \
            ref=${bbpath}/resources/adapters.fa \
            stats=${esc_target_dir}/Trim_stats/${prefix}_STATS.tsv \
            ktrim=r \
            k=23 \
            mink=11 \
            hdist=1 \
            interleaved=t \
            tpe \
            tbo \
            out=$(echo $esc_infile | sed -E "s/_?$se_suffix/_TRIM$se_suffix/") \
            qtrim=rl \
            trimq=10 \
            minlen=25 \
            >> "${log_file}" 2>&1
        echo >> "$log_file"

        printf "DONE!"

        if $remove_originals; then
            rm "$infile"
        fi

        # Increment the i counter
        ((i++))
    done
fi
