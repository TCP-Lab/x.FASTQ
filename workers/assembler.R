#!/usr/bin/env -S Rscript --vanilla

# ==============================================================================
#  Count Matrix Assembler - R script
# ==============================================================================

# This R script is meant to be wrapped by the `countfastq.sh` Bash script from
# the x.FASTQ suite. It searches for RSEM quantification output files in order
# to assemble them into one single count/expression matrix. It can work at both
# gene and isoform levels, optionally appending gene names and symbols. By
# design, it searches all sub-directories within the specified "target_path"
# directory, assuming that each RSEM output file has been saved into a
# sample-specific sub-directory, whose name will be used as a sample ID in the
# heading of the final expression table. If provided, it can also inject an
# experimental design into column names by adding a dotted suffix to each sample
# name.

# This variable is not used by the R script, but provides compatibility with the
# -r (--report) option of `x.fastq.sh`.
#ver="1.6.0" # currently unversioned

# When possible, argument checks have been commented out (##) here as they were
# already performed in the 'countfastq.sh' Bash wrapper.

## # Check if the correct number of command-line arguments is provided.
## if (length(commandArgs(trailingOnly = TRUE)) != 7) {
##   cat("Usage: Rscript assembler.R <gene_names> <org> <level> \\\n",
##       "                           <design_str> <metric> <raw_flag> \\\n",
##       "                           <target_path>\n",
##       sep = "")
##   quit(status = 1)
## }

# Extract command-line arguments (automatically doubles escaping backslashes).
gene_names <- commandArgs(trailingOnly = TRUE)[1]
org <- tolower(commandArgs(trailingOnly = TRUE)[2])
level <- commandArgs(trailingOnly = TRUE)[3]
design_str <- commandArgs(trailingOnly = TRUE)[4]
metric <- commandArgs(trailingOnly = TRUE)[5]
raw_flag <- commandArgs(trailingOnly = TRUE)[6]
target_path <- commandArgs(trailingOnly = TRUE)[7]

## # Check the 'gene_names' logical flag
## if (! gene_names %in% c("true", "false")) {
##   cat(" Invalid \'gene_names\' parameter \'", gene_names, "\'.\n",
##       " It must be one of the two Bash logical values true or false.\n",
##       sep = "")
##   quit(status = 2)
## }

## # Check the 'gene_names' logical flag
## if (! org %in% c("human", "mouse")) {
##   cat(" Currently unsupported model organism \'", org, "\'.\n",
##       " Please, choose one of the following:\n",
##       "  - human\n",
##       "  - mouse\n",
##       sep = "")
##  quit(status = 3)
## }

## # Check level name.
## if (! level %in% c("genes", "isoforms")) {
##   cat("Invalid working level:", level, "\n")
##   quit(status = 4)
## }

## # Check metric name.
## if (! metric %in% c("expected_count", "TPM", "FPKM")) {
##   cat("Invalid metric type:", metric, "\n")
##   quit(status = 5)
## }

## # Check the 'raw_flag' logical flag
## if (! raw_flag %in% c("true", "false")) {
##   cat(" Invalid \'raw_flag\' parameter \'", raw_flag, "\'.\n",
##       " It must be one of the two Bash logical values true or false.\n",
##       sep = "")
##   quit(status = 6)
## }

## # Check if the target path exists.
## if (! dir.exists(target_path)) {
##  cat("Directory", target_path, "does not exist.\n")
##  quit(status = 7)
## }

# ------------------------------------------------------------------------------

# Initialize logging through countFASTQ Bash wrapper
# (nohup Rscript "${xpath}"/workers/assembler.R ... >> "$log_file" 2>&1).
cat("\nRscript is running...\n")

# Get a list of all the files whose name ends with "genes.results" or
# "isoforms.results" (depending on the working level) found in the target_path
# directory and all its subdirectories.
file_list <- list.files(path = target_path,
                        pattern = paste0(level, "\\.results$"),
                        recursive = TRUE,
                        full.names = TRUE)
if (length(file_list) > 1) {
  cat("Found", length(file_list), "RSEM output files to merge!\n")
} else if (length(file_list) == 1) {
  cat("Find only one RSEM output file... cannot assemble count matrix.\n")
  quit(status = 7)
} else if (length(file_list) == 0) {
  cat("Cannot find any RSEM output in the specified target directory.\n")
  quit(status = 7)
}

# Initialize the count_matrix as an empty data.frame with just one (empty)
# character column named "gene_id" or "transcript_id", depending on the working
# level. This will allow using 'merge' to append columns later.
if (level == "genes") {
  RSEM_key <- "gene_id"
  OrgDb_key <- "ENSEMBL"
  count_matrix <- data.frame(gene_id = character(0))
} else if (level == "isoforms") {
  RSEM_key <- "transcript_id"
  OrgDb_key <- "ENSEMBLTRANS"
  count_matrix <- data.frame(transcript_id = character(0))
}

# Also, initialize a vector of integers to store the size of columns
# (i.e., number of genes/isoforms).
entries <- vector(mode = "integer")

# Loop through the list of files.
for (file in file_list) {
  
  # Read the file as a data frame.
  df <- read.csv(file, header = TRUE, sep = "\t")
  
  # Check if the mandatory columns exist in the data frame.
  good_format <- all(c(RSEM_key, metric) %in% colnames(df))
  if (! good_format) {
    cat("ERROR: Malformed RSEM output...\n",
        "Cannot find some of the columns required.\n")
    quit(status = 8)
  }
  
  # Extract the metric of interest along with entry IDs, and merge them into
  # count_matrix. Perform an outer join by 'RSEM_key' (gene_id/transcript_id).
  # Also rename sample column heading using subfolder name (and metric, unless
  # raw_flag == "true") as sample name ("true" is used instead of TRUE because
  # that comes from Bash).
  count_column <- df[,c(RSEM_key, metric)]
  colnames(count_column)[2] <- if (raw_flag == "true") {
      basename(dirname(file))
    } else {
      paste(basename(dirname(file)), metric, sep = "_")
    }
  
  # Check genome/transcriptome size.
  entries[length(entries)+1] <- dim(count_column)[1]
  
  # The full outer join (all = T) returns all rows from both the tables, joining
  # the records that have matching (~ union).
  count_matrix <- merge(count_matrix, count_column,
                        by.x = RSEM_key, by.y = RSEM_key, all = TRUE)
}

# Make 'entries' a named vector.
names(entries) <- colnames(count_matrix)[-1]

# Test if all matrices had the same number of rows (entries).
if (sum(diff(entries)) > 0) {
  cat("WARNING: Some columns have been merged with a different number of rows",
      " (", level, ").\n", sep = "")
}

# Add design ("NA" is used instead of NA because this comes from Bash).
if (design_str != "NA") {
  
  # Log the experimental design as retrieved from Bash.
  cat("Experimental design found:\n    ", design_str, "\n")
  
  # First remove parentheses, then remove both leading and trailing spaces, then
  # split the string by space. " +" is a regex that allows 'strsplit' to handle
  # possible multiple spaces in the string.
  rmv <- function(x,rgx){gsub(rgx, "", x)}
  design_str |> rmv("\\[|\\(|\\)|\\]") |> rmv("^( +)") |> rmv("( +)$") |>
    strsplit(" +") |> unlist() -> design
  
  # Append design to sample names in 'count_matrix' heading.
  if (length(design) == length(file_list)) {
    cat("Design size matches sample size.\n")
    colnames(count_matrix)[-1] <- paste(colnames(count_matrix)[-1],
                                        design, sep = ".")
    entries <- cbind(entries, design)
  } else {
    cat("Design length does not fit the number of samples.\n",
        "Experimental design has been discarded...\n", sep = "")
  }
}

# Print a size/design report.
cat("\n")
print(as.data.frame(entries))
cat("\n")

# Add annotations ("true" is used instead of TRUE because that comes from Bash).
if (gene_names == "true") {
  
  cat("Appending annotations...")
  #library(AnnotationDbi)
  # See columns(org.Hs.eg.db) or keytypes(org.Hs.eg.db) for a complete list of
  # all possible annotations.
  
  # Choose model organism DB.
  if (org == "human") {
    #library(org.Hs.eg.db)
    org_db <- org.Hs.eg.db::org.Hs.eg.db
  } else if (org == "mouse") {
    #library(org.Mm.eg.db)
    org_db <- org.Mm.eg.db::org.Mm.eg.db
  }
  annots <- AnnotationDbi::select(org_db,
                                  keys = count_matrix[,RSEM_key],
                                  columns = c("SYMBOL", "GENENAME", "GENETYPE"),
                                  keytype = OrgDb_key)
  # Warning: 'select()' returned 1:many mapping between keys and columns
  # ========>
  # Collapse the duplicated entries in the ID column and concatenate the
  # (unique) values in the remaining columns using a comma as a separator.
  # This step prevents rows from being added to 'count_matrix' in the following
  # join step, which would introduce duplicate counts altering the normalization
  # of each column (i.e., TPMs would no longer sum to 1e6).
  if (anyDuplicated(annots[,OrgDb_key])) {
    cat("    Multiple annotation entries corresponding to a single\n   ",
        OrgDb_key, "ID will be collapsed by a comma separator.\n")
    annots <- aggregate(. ~ get(OrgDb_key),
                        data = annots,
                        FUN = \(x)paste(unique(x), collapse = ","),
                        na.action = NULL)[,-1]
  }
  # Left (outer) join (all.x = TRUE) returns all rows from count_matrix, joining
  # the records that have matching. Rows in count_matrix that have no matching
  # rows in annots matrix will be filled with NAs.
  count_matrix <- merge(annots, count_matrix,
                        by.x = OrgDb_key, by.y = RSEM_key, all.y = TRUE)
  cat("\n")
}

# Save 'count_matrix' to disk (inside the 'target_path' folder).
output <- file.path(target_path,
                    paste0(basename(target_path), "_CountMatrix_",
                           level, "_", metric, ".tsv"))
cat("Saving Counts to:", output, sep = " ")
write.table(count_matrix,
            file = output,
            quote = FALSE,
            sep = "\t",
            dec = ".",
            row.names = FALSE,
            col.names = TRUE)

cat("\n\nDONE!\n")
