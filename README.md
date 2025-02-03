# x.FASTQ

___x.FASTQ___ is a suite of __Bash__ wrappers for original and third-party software designed to make RNA-Seq data analysis more automated, but also accessible to _wet biologists_ without a specific bioinformatics background.

## Modules
___x.FASTQ___ provides several modules to cover the entire RNA-Seq data analysis workflow, from raw read retrieval to count matrix generation.
Each module is started with a different CLI-executable bash command:

| Module Name     | Performed Task |
| :-------------: | -------------- |
| __getFASTQ__    | downloads NGS raw data in FASTQ format from the [ENA database](https://www.ebi.ac.uk/ena/browser/home) |
| __trimFASTQ__   | performs adapter and quality trimming by running [_BBDuk_](https://jgi.doe.gov/data-and-tools/software-tools/bbtools/) |
| __anqFASTQ__    | aligns reads and quantifies transcript abundance by running [STAR](https://github.com/alexdobin/STAR) and [RSEM](https://github.com/deweylab/RSEM) |
| __qcFASTQ__     | runs quality-control tools, such as [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) and [MultiQC](https://multiqc.info/) |
| __tabFASTQ__    | merges counts from multiple samples into a single expression table |
| __metaharvest__ | fetches metadata from [GEO](https://www.ncbi.nlm.nih.gov/geo/) and/or [ENA](https://www.ebi.ac.uk/ena/browser/home) databases |
| __x.FASTQ__     | performs common tasks of general utility (disk usage monitor, dependency report...) |

## Usage
Assuming that you have identified a study of interest from GEO (e.g., `GSE138309`), have already created a project folder somewhere (`mkdir '<anyPath>'/GSE138309`), and have moved into it (`cd '<anyPath>'/GSE138309`), here are some possible sample workflows.

### Minimal Step-by-Step Workflow
As an example of a minimal workflow, we can think of the following command set to retrieve the FASTQs, align and quantify them, and generate the gene-level count matrix.
```bash
# Download FASTQs, align, quantify, and assemble a gene-level count matrix
getfastq -u GSE138309 > ./GSE138309_wgets.sh
getfastq GSE138309_wgets.sh
anqfastq .
tabfastq .
```

### Complete Step-by-Step Workflow
A more complete workflow might include the download of metadata, a read trimming step, multiple quality control steps, and the inclusion of gene annotations and experimental design information in the count matrix.
```bash
# Download FASTQs in parallel and fetch GEO-ENA cross-referenced metadata
getfastq --urls GSE138309 > ./GSE138309_wgets.sh
getfastq --multi GSE138309_wgets.sh
metaharvest --geo --ena GSE138309 > GSE138309_meta.csv

# Trim and QC
qcfastq --out=FastQC_raw .
trimfastq .
qcfastq --out=FastQC_trim .

# Align, quantify, and QC
anqfastq .
qcfastq --tool=QualiMap .
qcfastq --tool=MultiQC .

# Clean up
rm *.fastq.gz

# Assemble an isoform-level count matrix with annotation and experimental design
groups=(Ctrl Ctrl Ctrl Treat Treat Treat)
tabfastq --isoforms --names=human --design="${groups[*]}" --metric=expected_count .

# Explore samples through PCA
qcfastq --tool=PCA .
```

### Complete Workflow in Batch Mode
Due to the typical hardware requirements for read alignment and subsequent transcript abundance quantification, ___x.FASTQ___ has been designed to be installed on one (or a few) remote Linux servers and accessed by multiple client users via SSH.
Accordingly, each ___x.FASTQ___ module __runs by default in the background and persistently__ (i.e., ignoring the `HUP` hangup signal), so that the user is not forced to keep the connection active for the entire duration of the analysis, but only for job scheduling.
In this way, each ___x.FASTQ___ module can be run independently as a single analysis step.

Alternatively, multiple modules can be chained together can be chained together in a single pipeline to automate the entire analysis workflow by using the `-w | --workflow` option for foreground execution.
Here is the _batched_ version of the previous workflow
```bash
## Prototypical x.FASTQ pipeline
# Download 12 (PE) FASTQs in parallel and fetch GEO-ENA cross-referenced metadata
getfastq --urls GSE138309 > ./GSE138309_wgets.sh
getfastq -w --multi GSE138309_wgets.sh
metaharvest --geo --ena GSE138309 > GSE138309_meta.csv

# Trim and QC
qcfastq -w --out=FastQC_raw .
trimfastq -w .
qcfastq -w --out=FastQC_trim .

# Align, quantify, and QC
anqfastq -w .
qcfastq -w --tool=MultiQC .

# Clean up
rm *.fastq.gz

# Assemble an isoform-level count matrix with annotation and experimental design
groups=(Ctrl Ctrl Ctrl Treat Treat Treat)
tabfastq -w --names=human --design="${groups[*]}" --metric=expected_count .

# Explore samples through PCA
qcfastq -w --tool=PCA .
```
Just save this pipeline as a single script file (e.g., `pipeline.xfastq`) and run the entire workflow with `nohup` and in the background
```bash
nohup bash pipeline.xfastq &
```

### Complete Workflow with Moliere
Alternatively, a similar workflow can be performed in a single command using __Moliere__, a "precasted" Python script that runs, in order, `getfastq`, `qcfastq`, `trimfastq`, `qcfastq` (again), `anqfastq`, and `tabfastq`, covering the whole analysis process with sensible defaults.
```bash
nohup moliere analyse GSE138309 &
```

## Documentation
Each module (including __Moliere__) has its own `-h | --help` option, which provides detailed information on possible arguments and command syntax.

___x.FASTQ___ full documentation, including the installation procedure on the server machine, can be found in the `docs` folder instead.
