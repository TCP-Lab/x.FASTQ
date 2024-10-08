#!/usr/bin/env -S Rscript --vanilla

# ==============================================================================
#  PCA and Hierarchical Clustering - R script
# ==============================================================================

# This is the R script that performs PCA and hierarchical clustering on samples
# when the `--tool=PCA` option is selected from the qcFASTQ Bash wrapper.
# `pca_hc.R` operates on expression matrices that have genes as rows and samples
# as columns. A row header is needed to retrieve sample names and possible
# information about the experimental design (i.e., the experimental group to
# which the sample belong). In particular, the experimental group is extracted
# automatically whenever a string is found after the last dot in the name of
# each sample (see also the related countFASTQ option that allows including such
# information in the count matrix headings). If no columns containing gene or
# transcript IDs is found, a warning triggered (although not used for PCA, ID
# column is useful for checking the validity of the target file). One or more
# annotation columns are allowed, which will be removed before clustering. All
# the other columns are supposed to be purely numeric.

# This variable is not used by the R script, but provides compatibility with the
# -r (--report) option of `x.fastq.sh`.
#ver="1.1.0" # currently unversioned

# When possible, argument checks have been commented out (##) here as they were
# already performed in the 'qcfastq.sh' Bash wrapper.

## # Check if the correct number of command-line arguments is provided.
## if (length(commandArgs(trailingOnly = TRUE)) != 3) {
##   cat("Usage: Rscript pca_hc.R <suffix> <out_folder> <target_path>\n")
##   quit(status = 1)
## }

# Extract command-line arguments (automatically doubles escaping backslashes).
suffix <- commandArgs(trailingOnly = TRUE)[1]
out_folder <- commandArgs(trailingOnly = TRUE)[2]
target_path <- commandArgs(trailingOnly = TRUE)[3]

## # Check if the out_folder already exists and stop here if it does.
## if (dir.exists(out_folder)) {
##  cat("Directory", out_folder, "already exists. Aborting...\n")
##  quit(status = 2)
## }

## # Check if the target path exists.
## if (! dir.exists(target_path)) {
##  cat("Directory", target_path, "does not exist.\n")
##  quit(status = 3)
## }

# Functions and Packages -------------------------------------------------------

#library(PCAtools)

#' Borrowed from BioTEA/r4tcpl and made essential.
#' Saves a graphical output to 'figure_Folder' sub-directory in both raster
#' (PNG) and vectorial (PDF) formats. Automatically makes the output folder if
#' not already there.
#'
#' @param plotfun A callback function that prints a plot to an open device. This
#'   takes a function and not a plot object as some plotting facilities (notably
#'   the default one) that cannot print plot objects conveniently.
#' @param figure_Name name of the output file (without extension).
#' @param figure_Folder name of the saving subfolder.
#'
#' @author FeAR, Hedmad
savePlots <- function(plotfun, figure_Name, figure_Folder)
{
  
  fullName <- file.path(figure_Folder, figure_Name)
  if (! dir.exists(figure_Folder)) {
    dir.create(figure_Folder, recursive = TRUE)
  }
  
  # Width and height are in pixels.
  png(filename = paste0(fullName, ".png"), width = 1024, height = 576)
  plotfun()
  invisible(capture.output(dev.off())) # Suppress automatic output to console.
  
  # Width and height are in inches.
  pdf(file = paste0(fullName, ".pdf"), width = 14, height = 8)
  plotfun()
  invisible(capture.output(dev.off()))
}

# ------------------------------------------------------------------------------

# Initialize logging through qcFASTQ Bash wrapper
# (Rscript pca_hc.R ... >> "$log_file" 2>&1).
cat("\nRscript is running...\n")

# List all files with the 'suffix' extension in the specified directory.
file_list <- list.files(path = target_path,
                        pattern = paste0(suffix, "$"),
                        ignore.case = TRUE,
                        recursive = FALSE,
                        full.names = TRUE)
if (length(file_list) > 0) {
  cat("Found ", length(file_list),
      " \"", suffix, "\" files to analyze!\n\n", sep = "")
} else {
  cat("Cannot find any \"",
      suffix, "\" files in the specified target directory\n", sep = "")
  quit(status = 4)
}

# Loop through the list of files.
for (file in file_list) {
  
  # Get a CountMatrix ID for naming.
  matrix_ID <- gsub(paste0("(_| |-|\\.)*", suffix, "$"), "",
                    basename(file), ignore.case = TRUE)
  # Read the file as a data frame.
  df <- read.csv(file, header = TRUE, sep = "\t")
  
  # Check the data frame.
  id_index <- grep("gene_id|transcript_id|ENSEMBL|ENSEMBLTRANS", colnames(df))
  if (all(!id_index)) {
    cat("WARNING: Possible malformed input matrix...\n",
        "Cannot find the gene/transcript ID column\n")
  }
  # Subset the dataframe to keep only the numeric columns and take the log2.
  indx <- sapply(df, is.numeric)
  numeric_df <- log2(df[,indx] + 1)
  
  # Make box-plots of count distributions
  savePlots(
    \(){boxplot(numeric_df)},
    figure_Name = paste0(matrix_ID, "_Boxplot"),
    figure_Folder = file.path(out_folder, matrix_ID))
  
  # Sample-wise Hierarchical Clustering ----------------------------------------
  
  if (ncol(numeric_df) < 3) {
    cat(basename(file),
        "\nCannot perform PCA or HC on less than three samples. Skipped!\n\n",
        sep = "")
    next
  }
  
  # Distance Matrix: Matrix Transpose t() is used because dist() computes the
  # distances between the ROWS of a matrix.
  # Also try here 'method = "manhattan"' (it could be more robust).
  sampleDist <- dist(t(numeric_df), method = "euclidean")
  hc <- hclust(sampleDist, method = "ward.D")
  savePlots(
    \(){plot(hc)},
    figure_Name = paste0(matrix_ID, "_Dendrogram"),
    figure_Folder = file.path(out_folder, matrix_ID))
  
  # Sample-wise PCA ------------------------------------------------------------
  
  # Look for group suffixes (an after-dot string) in column headings.
  splitted_names <- strsplit(colnames(numeric_df), "\\.")
  group_found <- sapply(splitted_names, \(x){length(x) > 1})
  
  if (prod(group_found)) {
    # Extract the last element from each sublist.
    design <- sapply(splitted_names, \(x){x[[length(x)]]})
  } else {
    design <- rep(0, dim(numeric_df)[2])
  }
  cat(basename(file), "\n",
      length(unique(design)), " experimental group(s) detected\n", sep ="")
  
  # Build metadata strictly enforcing that
  # rownames(metadata) == colnames(numeric_df).
  metadata <- data.frame(row.names = colnames(numeric_df))
  metadata$Group <- design
  print(metadata)
  cat("\n")
  
  # Do the PCA.
  pcaOut <- PCAtools::pca(numeric_df,
                          metadata = metadata,
                          center = TRUE,
                          scale = FALSE)
  # Plot the results.
  savePlots(
    \(){print(PCAtools::screeplot(pcaOut))},
    figure_Name = paste0(matrix_ID, "_ScreePlot"),
    figure_Folder = file.path(out_folder, matrix_ID))
  savePlots(
    \(){print(PCAtools::biplot(pcaOut, colby = "Group"))},
    figure_Name = paste0(matrix_ID, "_BiPlot"),
    figure_Folder = file.path(out_folder, matrix_ID))
  #savePlots(
  #  \(){print(pairsplot(pcaOut, colby = "Group"))},
  #  figure_Name = "PairsPlot",
  #  figure_Folder = file.path(out_folder, basename(file)))
}

cat("DONE!\n")
