#!/bin/bash

# =======================
#  Adapter Auto Trimmer
# =======================
#
# A wrapper for BBDuk trimmer to loop over a set of paired FASTQ files
#
# - Check for file pairing (paired-end reads)
# - Automatically detect contaminating adapters from FASTQ files and save stats
# - Right-trim (3') adapters (Illumina standard)
# - Loop over all the FASTQ files within the input directory
# - Save trimmed FASTQs and remove the original ones
#
# NOTE:
#	the script assumes that:
#	1.	the paired FASTQs have both the same name, only differing in the
#		suffixes defined below (R1_suffix vs R2_suffix)
# 	2.	all the FASTQs are in the same folder
#
# ISSUES:
#	1. cannot redirect bbduk.sh output to a log file...
#	2. add the option to chose the main folder $fqpath
#	3. enable the searching of FASTQs in subfolders
#

# System-related variables
bbpath="$HOME/bbmap"
fqpath="$HOME/Data/PANC1/pH/FASTQs"
R1_suffix="R1.fastq.gz"
R2_suffix="R2.fastq.gz"

# Start the script
echo "Searching FASTQs in" $fqpath

# Search and count the FASTQs in "fqpath"
R1_num=$(find $fqpath -maxdepth 1 -type f -iname "*$R1_suffix" | wc -l)
R2_num=$(find $fqpath -maxdepth 1 -type f -iname "*$R2_suffix" | wc -l)

if [[ $R1_num -eq $R2_num ]]; then
	echo "$R1_num x 2 =" $((R1_num*2)) "paired FASTQ files found."
else	
	echo "WARNING: Odd number of FASTQ files!"
	echo "         $R1_num + $R2_num =" $((R1_num+R2_num))
fi

# Loop over them
i=1 # Just a counter
for R1_infile in ${fqpath}/*$R1_suffix
do
	echo
	echo "============"
	echo " Cycle ${i}/$R1_num"
	echo "============"
	echo "Targeting:" $R1_infile

	R2_infile=$(echo $R1_infile | sed "s/$R1_suffix/$R2_suffix/")
	found_flag=$(find $fqpath -type f -wholename "$R2_infile" | wc -l)

	if [[ found_flag -eq 1 ]]; then
		echo "Paired to:" $R2_infile
		echo -e "\nStart trimming through BBDuk..."

		# Run BBDuk!
		${bbpath}/bbduk.sh \
			in1=$R1_infile \
			in2=$R2_infile \
			k=23 \
			ref=${bbpath}/resources/adapters.fa \
			stats="${fqpath}/stat_$(basename $R1_infile ${R1_suffix}).txt" \
			hdist=1 \
			tpe \
			tbo \
			out1=$(echo $R1_infile | sed "s/$R1_suffix/TRIM_$R1_suffix/") \
			out2=$(echo $R2_infile | sed "s/$R2_suffix/TRIM_$R2_suffix/") \
			ktrim=r mink=11
			#reads=100k # Add this argument when testing

		# We don't have infinite storage space...
		rm $R1_infile $R2_infile
	else
		echo "WARNING: Couldn't find the paired-ends..."
	fi

	# Increment counter
	i=$((i+1))
done
