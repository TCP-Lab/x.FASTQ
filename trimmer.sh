#!/bin/bash

# ==============================================================================
#  The BBDuk wrapper called by trimFASTQ
# ==============================================================================

# --- Source common settings and functions -------------------------------------
# These variables are exported from the trimFASTQ wrapper:
# xpath paired_reads dual_files target_dir r1_suffix r2_suffix se_suffix counter
# bbpath nor remove_originals

#source "${xpath}"/workers/x.funx.sh

# --- Main program -------------------------------------------------------------

if $paired_reads && $dual_files; then
    # Loop over FASTQ pairs
    i=1 # Just another counter
    for r1_infile in "${target_dir}"/*"$r1_suffix"
    do
        r2_infile="$(echo "$r1_infile" | sed "s/$r1_suffix/$r2_suffix/")"

        printf "%b\n" "\n============" \
        				" Cycle ${i}/${counter}" \
        				"============" \
        				"Targeting: ${r1_infile}" \
        				"           ${r2_infile}" \
        				"\nStart trimming through BBDuk...\n"

        prefix="$(basename "$r1_infile" "$r1_suffix")"

        # Paths with spaces need to be hard-escaped at this very level to be
        # correctly parsed when passed as arguments to BBDuk!
        esc_r1_infile="${r1_infile//" "/'\ '}"
        esc_r2_infile="${r2_infile//" "/'\ '}"
        esc_target_dir="${target_dir//" "/'\ '}"

        # Run BBDuk
        # NOTE: all BBTools write status information to stderr, not stdout !!!
        # also try to add this for Illumina: ftm=5 \
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
            minlen=25
        printf "\nDONE!\n"
       
        if $remove_originals; then
            rm "$r1_infile" "$r2_infile"
        fi
        ((i++))
    done

elif ! $paired_reads; then
    # Loop over FASTQ files
    i=1 # Just another counter
    for infile in "${target_dir}"/*"$se_suffix"
    do
        printf "%b\n" "\n============" \
        				" Cycle ${i}/${counter}" \
        				"============" \
        				"Targeting: ${infile}" \
        				"\nStart trimming through BBDuk...\n"

        prefix="$(basename "$infile" "$se_suffix")"

        # Paths with spaces need to be hard-escaped at this very level to be
        # correctly parsed when passed as arguments to BBDuk!
        esc_infile="${infile//" "/'\ '}"
        esc_target_dir="${target_dir//" "/'\ '}"

        # Run BBDuk
        # NOTE: all BBTools write status information to stderr, not stdout !!!
        # also try to add this for Illumina: ftm=5 \
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
            minlen=25
        printf "\nDONE!\n"

        if $remove_originals; then
            rm "$infile"
        fi
        ((i++))
    done

elif ! $dual_files; then
    # Loop over FASTQ files
    i=1 # Just another counter
    for infile in "${target_dir}"/*"$se_suffix"
    do
        printf "%b\n" "\n============" \
        				" Cycle ${i}/${counter}" \
        				"============" \
        				"Targeting: ${infile}" \
        				"\nStart trimming through BBDuk...\n"

        prefix="$(basename "$infile" "$se_suffix")"

        # Paths with spaces need to be hard-escaped at this very level to be
        # correctly parsed when passed as arguments to BBDuk!
        esc_infile="${infile//" "/'\ '}"
        esc_target_dir="${target_dir//" "/'\ '}"

        # Run BBDuk
        # NOTE: all BBTools write status information to stderr, not stdout !!!
        # also try to add this for Illumina: ftm=5 \
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
            minlen=25
        printf "\nDONE!\n"

        if $remove_originals; then
            rm "$infile"
        fi
        ((i++))
    done
fi
