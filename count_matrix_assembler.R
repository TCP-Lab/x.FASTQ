

# All argument checks have been commented out (##) as they are performed by the
# Bash wrapper

## # Check if the correct number of command-line arguments is provided
## if (length(commandArgs(trailingOnly = TRUE)) != 2) {
##   cat("Usage: Rscript count_matrix_assembler.R <metric> <target_path>\n")
##   quit(status = 1)
## }

# Extract command-line arguments
metric <- commandArgs(trailingOnly = TRUE)[1]
target_path <- commandArgs(trailingOnly = TRUE)[2]

## # Check metric name
## if (!(metric %in% c("expected_count", "TPM", "FPKM"))) {
##   cat(paste("Invalid Metric:", metric, "\n"))
##   quit(status = 2)
## }


#############################################
target_path <- "C:/Users/aleph/Desktop/Test"
metric <- "TPM"
#############################################


# Get a list of all files whose name ends with "genes.results", found in the
# target_path directory and its subdirectories
file_list <- list.files(path = target_path,
                        pattern = "genes\\.results$",
                        recursive = TRUE,
                        full.names = TRUE)
if (length(file_list) > 0) {
  cat(paste("Found", length(file_list), "RSEM output files to merge!\n"))
} else {
  cat(paste("Cannot find any RSEM output in the specified target directory\n"))
  quit(status = 3)
}

# Initialize the count_matrix as an empty data frame with just one (empty)
# character column named "gene_id". In addition, initialize a vector of integers
count_matrix <- data.frame(gene_id = character(0))
genes <- vector(mode = "integer")

# Loop through the list of files and read them as data frames
for (file in file_list) {
  
  # Read the file as a data frame
  df <- read.csv(file, header = TRUE, sep = "\t")
  
  # Check if the needed columns exist in the data frame
  good_format <- all(c("gene_id",
                       "expected_count",
                       "TPM",
                       "FPKM") %in% colnames(df))
  if (! good_format) {
    cat(paste("ERROR: Malformed RSEM output... cannot find some columns\n"))
    quit(status = 4)
  }
  
  # Extract the metric of interest along with gene IDs, and merge them into the
  # count_matrix (outer join by gene_id)
  count_column <- df[,c("gene_id", metric)]
  colnames(count_column)[2] <- paste(basename(dirname(file)), metric, sep = "_")
  
  # Check genome size
  genes[length(genes)+1] <- dim(count_column)[1]
  
  # The outer join (all = T) returns all rows from both the tables, joining the
  # records that have matching (~ union)
  count_matrix <- merge(count_matrix, count_column,
                        by.x = "gene_id", by.y = "gene_id", all = TRUE)
}

# Make 'genes' a named vector
names(genes) <- colnames(count_matrix)[-1]

count_matrix
genes

# Test if all matrices had the same number of rows (genes), then print a genome
# size report
if (sum(diff(genes)) > 0) {
  cat(paste("WARNING: Some columns have been merged with a different number",
            "of rows (genes).\n"))
}
print(genes)



