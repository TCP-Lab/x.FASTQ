


suffix <- "tsv"
out_folder <- "C:/Users/FeAR/Desktop/test/PCA_Figures"
target_path <- "C:/Users/FeAR/Desktop/test/"



# ============================================================================ #
#  PCA and Hierarchical Clustering - R script
# ============================================================================ #

# This R script is meant to ...

# This variable is not used by the R script, but provides compatibility with the
# -r (--report) option of `x.fastq.sh`
ver="0.0.9"

# When possible, argument checks have been commented out (##) here as they were
# already performed by the 'countfastq.sh' Bash wrapper.

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

# ------------------------------------------------------------------------------

library(PCAtools)

#' Borrowed from BioTEA and made essential.
#' Saves a graphical output to 'figure_Folder' sub-directory. Automatically
#' makes the output folder if not there.
#'
#' @param plotfun A function that resolves to printing a plot to an open
#'   device. This takes a function and not a plot object as some plotting
#'   facilities (notably the default one) cannot print plot objects conveniently.
#' @param figure_Name name of the output file (without extension).
#' @param figure_Folder for naming the saving subfolder (defaults to `out_folder`)
#'
#' @author FeAR, Hedmad
savePlots <- function(plotfun, figure_Name, figure_Folder = out_folder)
{
  
  fullName <- file.path(figure_Folder, figure_Name)
  if (!file.exists(figure_Folder)) {
    dir.create(figure_Folder)
  }
  
  # Width and height of the graphics region are in pixels
  png(filename = paste0(fullName, ".png"), width = 1024, height = 576)
  plotfun()
  invisible(capture.output(dev.off())) # to suppress automatic output to console
  
  # Width and height of the graphics region are in inches
  pdf(file = paste0(fullName, ".pdf"), width = 14, height = 8)
  plotfun()
  invisible(capture.output(dev.off()))
}

# ------------------------------------------------------------------------------

# List all files with '.suffix' extension in the specified directory
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

# Loop through the list of files and read them as data frames.
for (file in file_list) {
  
  
  
  file <- file_list[1] ##############################################
  # Read the file as a data frame.
  df <- read.csv(file, header = TRUE, sep = "\t")
  
  # Check data frame
  id_index <- grep("(gene|transcript)_id", colnames(df))
  if (length(id_index) == 0) {
    cat(paste("WARNING: Possible malformed input matrix...",
              "cannot find the gene/transcript ID column\n"))
  }
  # Subset the dataframe to keep only the numeric columns
  numeric_df <- df[, sapply(df, is.numeric)]
  
  
  
  
  # Sample-wise Hierarchical Clustering
  # Distance Matrix: Matrix Transpose t() is used because dist() computes the
  # distances between the ROWS of a matrix.
  # also try 'method = "manhattan"' (it could be more robust)
  sampleDist <- dist(t(numeric_df), method = "euclidean")
  hc <- hclust(sampleDist, method = "ward.D")
  savePlots(
    \(){plot(hc)},
    figure_Name = "Dendrogram")

  
  
  
  
  
  # Sample-wise PCA
  
  # Strictly enforced that rownames(metadata) == colnames(numeric_df)
  metadata <- data.frame(row.names = colnames(numeric_df))
  
  # Add column 'Group' to metadata dataframe
  metadata$Group <- rep(NA, dim(metadata)[1])
  #for (i in 1:m) {
  #  metadata$Group[which(design == i)] = groups[i]
  #}
  
  # Do the PCA (centering the data before performing PCA, by default)
  pcaOut <- pca(numeric_df, metadata = metadata)
  
  # Plot results
  
  savePlots(
    \(){print(screeplot(pcaOut))},
    figure_Name = "ScreePlot")
  
  #colMAtch = myColors[1:m] # Vector for color matching
  #names(colMAtch) = groups
  
  #biplot(pcaOut, colby = "Group", colkey = colMAtch)
  savePlots(
    \(){print(biplot(pcaOut))},
    figure_Name = "BiPlot")
  
  if (dim(numeric_df)[2] > 3) {
    #pairsplot(pcaOut, colby = "Group", colkey = colMAtch)
    savePlots(
      \(){print(pairsplot(pcaOut))},
      figure_Name = "PairsPlot")
  }

}




