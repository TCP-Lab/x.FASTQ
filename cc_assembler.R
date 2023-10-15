

ver="1.1.0"

# When possible, argument checks have been commented out (##) as they will be
# already performed by the 'countfastq.sh' Bash wrapper.

## # Check if the correct number of command-line arguments is provided.
## if (length(commandArgs(trailingOnly = TRUE)) != 4) {
##   cat("Usage: Rscript count_assembler.R <level> <metric> <gene_names> <target_path>\n")
##   quit(status = 1)
## }

# Extract command-line arguments.
level <- commandArgs(trailingOnly = TRUE)[1]
metric <- commandArgs(trailingOnly = TRUE)[2]
gene_names <- commandArgs(trailingOnly = TRUE)[3]
target_path <- commandArgs(trailingOnly = TRUE)[4]

## # Check level name.
## if (!(level %in% c("genes", "isoforms"))) {
##   cat(paste("Invalid working level:", level, "\n"))
##   quit(status = 2)
## }

## # Check metric name.
## if (!(metric %in% c("expected_count", "TPM", "FPKM"))) {
##   cat(paste("Invalid metric type:", metric, "\n"))
##   quit(status = 3)
## }

## # Check if the target path exists.
## if (! dir.exists(target_path)) {
##  cat(paste("Directory", directory_path, "does not exist.\n"))
##  quit(status = 4)
## }

# ------------------------------------------------------------------------------

# Initialize R logging
cat("\nRscript is running...\n")

# Get a list of all files whose name ends with "genes.results" or
# "isoforms.results" (depending on the working level) found in the target_path
# directory and all its subdirectories.
file_list <- list.files(path = target_path,
                        pattern = paste0(level, "\\.results$"),
                        recursive = TRUE,
                        full.names = TRUE)
if (length(file_list) > 0) {
  cat(paste("Found", length(file_list), "RSEM output files to merge!\n"))
} else {
  cat(paste("Cannot find any RSEM output in the specified target directory\n"))
  quit(status = 5)
}

# Initialize the count_matrix as an empty data frame with just one (empty)
# character column named "gene_id" or "transcript_id" depending on the working
# level. This will allow using 'merge' to append columns in the for loop.
if (level == "genes") {
  RSEM_key <- "gene_id"
  OrgDb_key <- "ENSEMBL"
  count_matrix <- data.frame(gene_id = character(0))
} else if (level == "isoforms") {
  RSEM_key <- "transcript_id"
  OrgDb_key <- "ENSEMBLTRANS"
  count_matrix <- data.frame(transcript_id = character(0))
}

# Also, initialize a vector of integers to store the size of columns.
entries <- vector(mode = "integer")

# Loop through the list of files and read them as data frames.
for (file in file_list) {
  
  # Read the file as a data frame.
  df <- read.csv(file, header = TRUE, sep = "\t")
  
  # Check if the mandatory columns exist in the data frame.
  good_format <- all(c(RSEM_key, metric) %in% colnames(df))
  if (! good_format) {
    cat(paste("ERROR: Malformed RSEM output...",
              "cannot find some of the columns required\n"))
    quit(status = 6)
  }
  
  # Extract the metric of interest along with entry IDs, and merge them into the
  # count_matrix. Perform an outer join by 'RSEM_key' (gene_id/transcript_id).
  # Also rename sample column heading using subfolder name as sample name.
  count_column <- df[,c(RSEM_key, metric)]
  colnames(count_column)[2] <- paste(basename(dirname(file)), metric, sep = "_")
  
  # Check genome/transcriptome size.
  entries[length(entries)+1] <- dim(count_column)[1]
  
  # The outer join (all = T) returns all rows from both the tables, joining the
  # records that have matching (~ union).
  count_matrix <- merge(count_matrix, count_column,
                        by.x = RSEM_key, by.y = RSEM_key, all = TRUE)
}

# Make 'entries' a named vector.
names(entries) <- colnames(count_matrix)[-1]

# Test if all matrices had the same number of rows (entries), then print a
# genome/transcriptome size report.
if (sum(diff(entries)) > 0) {
  cat(paste0("WARNING: Some columns have been merged with a different number",
             "of rows (", level, ").\n"))
}
print(entries)

# Add annotations ("true" instead of TRUE because it comes from Bash)
if (gene_names == "true") {
  library(AnnotationDbi)
  # See columns(org.Hs.eg.db) or keytypes(org.Hs.eg.db) for a complete list of all possible annotations
  org <- "human"
  if (org == "human") {
    library(org.Hs.eg.db)
    annots <- select(org.Hs.eg.db,
                     keys = count_matrix[,RSEM_key],
                     columns = c("SYMBOL", "GENENAME", "GENETYPE"),
                     keytype = OrgDb_key)
  } else if (org == "mouse") {
    library(org.Mm.eg.db)
    annots <- select(org.Mm.eg.db,
                     keys = count_matrix[,RSEM_key],
                     columns = c("SYMBOL", "GENENAME", "GENETYPE"),
                     keytype = OrgDb_key)
  }
  count_matrix <- merge(count_matrix, annots,
                        by.x = RSEM_key, by.y = OrgDb_key, all = TRUE)
  cat("Swappare le colonne per mettere l'annotazione a sinistra della matrice")
}

# Save count_matrix to disk (inside 'target_path' folder).
output <- paste0(target_path, "/Count_Matrix_", level, "_", metric, ".tsv")
cat("Saving Counts to:", output, sep = " ")
write.table(count_matrix,
            file = output,
            quote = FALSE,
            sep = "\t",
            dec = ".",
            row.names = FALSE,
            col.names = TRUE)

cat("\nDONE!\n")
