

suffix <- "tsv"
out_folder <- "C:/Users/aleph/Desktop/test/PCA_Figures"
target_path <- "C:/Users/aleph/Desktop/test/"



# ============================================================================ #
#  PCA and Hierarchical Clustering - R script
# ============================================================================ #

# This is the R script that performs PCA and hierarchical clustering on samples
# when the `--tool=PCA` option is selected from the qcFASTQ Bash wrapper.
# `cc_pca.R` operates on expression matrices that have genes as rows and samples
# as columns. A row header is needed to retrieve the names of the samples and
# get possible information about the experimental design (i.e., the experimental
# group the sample belongs to). Specifically, the experimental group is
# automatically extracted whenever a string is found after the last dot in the
# name of each sample (the related countFASTQ option can be used to include this
# information in the count matrix). A column containing gene or transcript IDs
# is required (although not used for PCA, it is useful for verifying the
# validity of the target file). One or more annotation columns are allowed,
# which will be removed before clustering. All other columns must be purely
# numeric.

# This variable is not used by the R script, but provides compatibility with the
# -r (--report) option of `x.fastq.sh`.
ver="0.0.9"

# When possible, argument checks have been commented out (##) here as they were
# already performed by the 'qcfastq.sh' Bash wrapper.

## # Check if the correct number of command-line arguments is provided.
## if (length(commandArgs(trailingOnly = TRUE)) != 3) {
##   cat("Usage: Rscript cc_pca.R <suffix> <out_folder> <target_folder>\n")
##   quit(status = 1)
## }

# Extract command-line arguments.
suffix <- commandArgs(trailingOnly = TRUE)[1]
out_folder <- commandArgs(trailingOnly = TRUE)[2]
target_path <- commandArgs(trailingOnly = TRUE)[3]

## # Check if the target path exists.
## if (! dir.exists(target_path)) {
##  cat(paste("Directory", target_path, "does not exist.\n"))
##  quit(status = 4)
## }

# Functions and Packages -------------------------------------------------------

#library(PCAtools)

#' Borrowed from BioTEA and made essential.
#' Saves a graphical output to 'figure_Folder' sub-directory in both raster
#' (PNG) and vectorial (PDF) formats. Automatically makes the output folder if
#' not already there.
#'
#' @param plotfun A function that resolves to printing a plot to an open
#'   device. This takes a function and not a plot object as some plotting
#'   facilities (notably the default one) cannot print plot objects conveniently.
#' @param figure_Name name of the output file (without extension).
#' @param figure_Folder to name the saving subfolder.
#'
#' @author FeAR, Hedmad
savePlots <- function(plotfun, figure_Name, figure_Folder)
{
  
  fullName <- file.path(figure_Folder, figure_Name)
  if (!file.exists(figure_Folder)) {
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
# (Rscript cc_pca.R ... >> "$log_file" 2>&1).
cat("\nRscript is running...\n")

# List all files with '.suffix' extension in the specified directory.
file_list <- list.files(path = target_path,
                        pattern = paste0("\\.", suffix, "$"),
                        ignore.case = TRUE,
                        recursive = FALSE,
                        full.names = TRUE)
if (length(file_list) > 0) {
  cat(paste0("Found ", length(file_list), " .", suffix, " files to analyze!\n"))
} else {
  cat(paste0("Cannot find any .", suffix,
             " files in the specified target directory\n"))
  quit(status = 5)
}

# Loop through the list of files.
for (file in file_list) {
  
  # Read the file as a data frame.
  df <- read.csv(file, header = TRUE, sep = "\t")
  
  # Check the data frame.
  id_index <- grep("(gene|transcript)_id", colnames(df))
  if (length(id_index) == 0) {
    cat(paste("WARNING: Possible malformed input matrix...",
              "cannot find the gene/transcript ID column\n"))
  }
  # Subset the dataframe to keep only the numeric columns.
  numeric_df <- df[, sapply(df, is.numeric)]
  
  # Sample-wise Hierarchical Clustering ----------------------------------------
  
  # Distance Matrix: Matrix Transpose t() is used because dist() computes the
  # distances between the ROWS of a matrix.
  # Also try here 'method = "manhattan"' (it could be more robust).
  sampleDist <- dist(t(numeric_df), method = "euclidean")
  hc <- hclust(sampleDist, method = "ward.D")
  savePlots(
    \(){plot(hc)},
    figure_Name = "Dendrogram",
    figure_Folder = file.path(out_folder, basename(file)))
  
  # Sample-wise PCA ------------------------------------------------------------
  
  # Look for group suffixes (an after-dot string) in column headings.
  splitted_names <- strsplit(colnames(numeric_df), "\\.")
  group_found <- sapply(splitted_names, \(x){length(x) > 1})
  
  if (prod(group_found)) {
    # `sapply()` with `"[[",2` extracts the second element.
    design <- sapply(splitted_names, "[[", 2)
  } else {
    design <- rep(0, dim(numeric_df)[2])
  }
  cat(paste(length(unique(design)), "experimental group(s) detected\n"))
  
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
    figure_Name = "ScreePlot",
    figure_Folder = file.path(out_folder, basename(file)))
  savePlots(
    \(){print(PCAtools::biplot(pcaOut, colby = "Group"))},
    figure_Name = "BiPlot",
    figure_Folder = file.path(out_folder, basename(file)))
  #savePlots(
  #  \(){print(pairsplot(pcaOut, colby = "Group"))},
  #  figure_Name = "PairsPlot",
  #  figure_Folder = file.path(out_folder, basename(file)))
}

cat("\n\nDONE!\n")
