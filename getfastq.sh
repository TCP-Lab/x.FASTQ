#!/bin/bash

# ==============================================
#  Get FastQ Files from ENA Browser
# ==============================================


while IFS= read -r line
do
	# using Bash-native string substitution to change FTP into HTTP
	# ${string/$substring/$replacement}
	# NOTE: while `$substring` and `$replacement` are literal strings
	# 		the starting `string` MUST be a reference to a variable name!
	target=${line/ftp:/http:}

	base_line="$(basename "$target")"

	# nohup (no hangups)  To keep processes running even after exiting the shell
	# per reindirizzare lo standard output e l'errore standard sul file di log
	nohup $target > ${base_line}.log 2>&1 &

	# Toggle verbose on-screen logging
	if true; then
		echo
		echo "Downloading: $(basename "$target")"
		echo "From       : $(dirname ${target/"wget -nc"/})"
	fi
	
done < "$1"