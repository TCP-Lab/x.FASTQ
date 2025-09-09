# x.FASTQ
```
$ x.fastq        _____   _      ____   _____   ___
    __  __      |  ___| / \    / ___| |_   _| / _ \
    \ \/ /      | |_   / _ \   \___ \   | |  | | | |
     >  <    _  |  _| / ___ \   ___) |  | |  | |_| |
    /_/\_\  (_) |_|  /_/   \_\ |____/   |_|   \__\_\
             Bash modules for the remote analysis of
                                        RNA-Seq data
```
___x.FASTQ___ is a suite of __Bash__ wrappers for original and third-party software designed to make RNA-Seq data analysis more accessible and automated.

## First Principles and Background
___x.FASTQ___ was originally written for the [*Endothelion*](https://github.com/TCP-Lab/Endothelion) project with the intention of _abstracting_ the standard TCP-Lab analysis pipeline for NGS transcriptional data.
The main idea was to make the whole process faster, more scalable, but also affordable for _wet biologists_ without a specific bioinformatics background, and perhaps working in different, physically distant labs.
To meet these needs, we have developed ___x.FASTQ___ with the following specific features:
* __Remote operability__: Due to the typical hardware requirements for read alignment and subsequent transcript abundance quantification, ___x.FASTQ___ has been designed to be installed on one (or a few) remote Linux servers and accessed by multiple client users via SSH.
Accordingly, each ___x.FASTQ___ module runs by default in the background and persistently (i.e., ignoring the `HUP` hangup signal), so that the user is not forced to keep the connection active for the entire duration of the analysis, but only for job scheduling.
* __Standardization__: Most ___x.FASTQ___ scripts are wrappers of lower-level applications that are commonly used as standard tools in RNA-Seq data analysis and widely appreciated for their performance (e.g., FastQC, BBDuk, STAR, RSEM).
* __Simplification__: Scripts expose a limited number of options by making extensive use of default settings (suitable for the majority of standard RNA-Seq analyses) and by taking over the management of input and output data formats and their organization.
* __Automation__: All scripts are designed to loop over sets of _target files_ properly stored in the same directory.
In addition, although designed to run independently, each module can optionally be chained to the next in a single pipeline to automate the entire analysis workflow (`-w | --workflow` option).
* __Completeness__: The tools provided by ___x.FASTQ___ allow for a complete workflow, from raw read retrieval to count matrix generation.
* __No bioinformatics skills required__: The only requirement for the user is a basic knowledge of the Unix shell and an SSH client installed on the local machine.
Each ___x.FASTQ___ module is a CLI-executable Bash command with a `--help` option that provides extensive documentation.
* __Reproducibility__: although not (yet) containerized, each ___x.FASTQ___ module is tightly versioned and designed to save detailed log files at each run.
Utilities are also available to print full version reports on ___x.FASTQ___ modules and dependencies (i.e., `x.fastq -r` and `-d` options, respectively).

## Modules
### Overview
___x.FASTQ___ currently consists of 7 modules designed to be run directly by the end user, each of which addresses a specific step of a general RNA-Seq data analysis pipeline, from raw read acquisition to expression matrix generation.
1. __getFASTQ__ allows the user to download NGS raw data in FASTQ format from the [ENA database](https://www.ebi.ac.uk/ena/browser/home) to the server machine;
1. __trimFASTQ__ uses _BBDuk_ (from the [BBTools suite](https://jgi.doe.gov/data-and-tools/software-tools/bbtools/)) to remove adapter sequences and perform quality trimming;
1. __anqFASTQ__ uses [STAR](https://github.com/alexdobin/STAR) and [RSEM](https://github.com/deweylab/RSEM) to align reads and quantify transcript abundance, respectively;
1. __qcFASTQ__ is an interface for multiple quality-control tools, including [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) and [MultiQC](https://multiqc.info/);
1. __tabFASTQ__ merges counts from multiple samples (Runs) into a single TSV expression table, choosing among multiple metrics (TPM, FPKM, RSEM expected counts) and levels (gene or isoform).
Optionally, it inserts experimental design information into the matrix header and appends annotations regarding gene symbol, gene name, and gene type (__Ensembl gene/transcript IDs are required for annotation__);
1. __metaharvest__ fetches Sample and Study metadata from [GEO](https://www.ncbi.nlm.nih.gov/geo/) and/or [ENA](https://www.ebi.ac.uk/ena/browser/home) databases, then it parses the retrieved metadata and saves a local copy of them as a CSV-formatted table;
1. __x.FASTQ__ is a *cover-script* that performs a number of common tasks of general utility, such as dependency checking, symlink creation, version monitoring, and disk usage reporting.

In addition, a Python script called __Moliere__ is included to easily run a typical RNA-Seq analysis pipeline with a single command.

___x.FASTQ___ also contains a number of auxiliary scripts (written in __Bash__, __R__, or __Python__) that are not intended to be run directly by the end user, but are called by the main modules.
Most of them are found in the `workers` subfolder.
1. `x.funx.sh` contains variables and functions that must be shared (i.e., _sourced_) by all other ___x.FASTQ___ modules;
1. `progress_funx.sh` collects all the functions for tracking the progress of the different modules (see the `-p` option below);
1. `trimmer.sh` is the actual _BBDuk_ wrapper, called by __trimFASTQ__;
1. `starsem.sh` is the actual STAR/RSEM wrapper, called by __trimFASTQ__;
1. `assembler.R` implements the matrix assembly procedure required by __tabFASTQ__;
1. `pca_hc.R` implements Principal Component Analysis and Hierarchical Clustering of samples as required by the `qcfastq --tool=PCA ...` option;
1. `fuse_csv.R` is called by `metaharvest` to merge the cross-referenced metadata downloaded from both GEO and ENA databases;
1. `parse_series.R` is called by `metaharvest` to extract metadata from a GEO-retrieved SOFT formatted family file;
1. `re_uniq.py` is used to reduce redundancy when STAR and RSEM logs are displayed in the console as __anqFASTQ__ progress reports.

### Common Features and Options
All suite modules enjoy some internal consistency:
* upon running `x.fastq.sh -l <target_path>` from the local ___x.FASTQ___ repository directory, each ___x.FASTQ___ module can be invoked from any location on the remote machine using its fully lowercase name (provided that `<target_path>` is already included in `$PATH`);
* by default, each script launches in the ___background___ a ___persistent___ job (or a queue of jobs) by using a custom re-implementation of the `nohup` command (namely the `_hold_on` function from `x.funx.sh`);
* each module (except __x.FASTQ__ and __metaharvest__) saves its own log file inside the project directory using the filename pattern
```
Z_<ModuleName>_<ID>_<DateStamp>.log
```
where `ID` can refer to either the single sample (or better _Run_) or the entire Series (aka BioProject within INSDC context), depending on the particular module that generated the log (the leading 'Z_' is just to get all log files at the bottom of the list when `ls -l`);
> [!IMPORTANT]  
> In the current implementation of ___x.FASTQ___, filenames are very meaningful!
>
> Each FASTQ file is required to have a name matching the regex pattern
> ```
> ^[a-zA-Z0-9]+([^a-zA-Z0-9]*.*)?\.fastq\.gz$
> ```
> i.e., beginning with an alphanumeric ID (usually an ENA Run ID of the type `(E|D|S)RR[0-9]{6,}`), immediately followed by the extension `.fastq.gz`, or separated from the rest of the filename by an underscore or other characters other than `[a-zA-Z0-9]`.
> Valid examples are `GSM34636.fastq.gz`, `SRR19592966_1.fastq.gz`, etc.
> This leading ID is propagated to the names of the log files printed by the __getFASTQ__ module and _BBDuk_ (stored in the `Trim_stats` subdirectory), as well as all output files from _FastQC_, _STAR_, and _RSEM_ (stored in the `FastQC_*` and `Counts` subfolders, respectively).
> __tabFASTQ__ will then assume each RSEM output file being saved into a sample- or run-specific subdirectory, whose name will be used for count matrix heading.
> Similarly, but at a lower level, even _MultiQC_ needs each _STAR_ and _RSEM_ output to be properly prefixed with a suitable sample or run ID to be correctly accounted for.
> Note, however, that all of this should come naturally when FASTQs are downloaded from the ENA database using the __getFASTQ__ module, since within INSDC, ENA guarantees a high degree of uniformity in its archive-generated FASTQs files, including file naming.
> In contrast, it is recommended that the user to manually name each project folder (i.e., each directory containing the entire set of FASTQ files from a single experiment) with a meaningful study ID (typically the associated GEO Series ID `GSE[0-9]+` or the ENA BioProject accession `PRJ(E|D|N)[A-Z][0-9]+`).
> The name of the project directory is used as the project `ID` by most ___x.FASTQ___ modules to name their log files.
> The same applies to the _MultiQC_ HTML global report, the PCA results and the name of the final expression matrix.
* some common flags keep the same meaning across all modules (even if not all of them are always available):
    * `-h | --help` to display the script-specific help;
    * `-v | --version` to display the script-specific version;
    * `-q | --quiet` to run the script silently;
    * `-w | --workflow` to make processes run in the foreground when used in pipelines;
    * `-p | --progress` to see the progress of possibly ongoing processes;
    * `-k | --kill` to gracefully terminate possibly ongoing processes;
    * `-a | --keep-all` not to delete intermediate files upon script execution;
* all modules are versioned according to the three-number _Semantic Versioning_ system.
`x.fastq -r` can be used to get a version report of all scripts along with the _summary version_ of the whole ___x.FASTQ___ suite;
* if `-p` is followed by no other arguments, the script will search the current directory for log files from which to infer the progress of the last namesake task;
* with the `-q` option, scripts do not print anything to the screen except for possible error messages that stop execution (i.e., fatal errors); however, logging is never disabled.

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
> [!NOTE]  
> The study chosen here as an example has non-interleaved (i.e., dual-file) paired-end (PE) reads, but ___x.FASTQ___ also supports single-ended (SE) and interleaved PE formats.
> In these cases, you must use the `[-s | --single-end]` and `[-i | --interleaved]` options, respectively, when trimming and aligning.

### Complete Workflow in Batch Mode
Previous modules can be chained together in a single pipeline to automate the entire analysis workflow by using the `-w | --workflow` option for foreground execution.
```bash
# Download FASTQs in parallel and fetch GEO-ENA cross-referenced metadata
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
tabfastq -w --isoforms --names=human --design="${groups[*]}" --metric=expected_count .

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
The final output is the "expected counts" matrix in the `./GSE138309/Counts/` folder.
If you need other metrics, you may call __tabFASTQ__ manually: __Moliere__ does not delete the quantifications.

Moliere batches the job to only download a set of FASTQ files at once per cycle, so that your hard drive does not get full with downloaded files.
It will handle this transparently for you, by default downloading `20` files at once.
Of course, the final `tabfastq` call will be performed only after *all* files in all batches are processed correctly.

In the spirit of other ___x.FASTQ___ scripts, you can check where __Moliere__ is in the analysis by issuing the command
```bash
# Look for the `.moliere` file
moliere status 
```
from the project directory.
This will give you an overall view of the analysis, plus the outputs (if relevant) of the ___x.FASTQ___ scripts when called with the `--progress` option.

If an error occurs in the analysis, fix it, then resume the process where it was left off with `moliere resume` (run from the project directory).

## Installation
As noted above, a working SSH client is the only local software requirement for using ___x.FASTQ___, provided it has already been installed on some remote server machines by the system administrator.
The procedure for installing ___x.FASTQ___ (and all its dependencies) on the server is documented step-by-step here.

### Cloning
Clone ___x.FASTQ___ repository from GitHub
```bash
cd ~/.local/bin/
git clone git@github.com:Feat-FeAR/x.FASTQ.git
```

### Symlinking (optional)
Create the symlinks in some `$PATH` directory (e.g., `~/.local/bin/`) to provide global ___x.FASTQ___ visibility and easier module invocation.
```bash
cd x.FASTQ
./x.fastq.sh -l ..
```

### Dependencies
Install and test the following software, as required by ___x.FASTQ___.
* _Development Environments_
    * Java
    * Python
    * R
    * Bioconductor Packages
        * BiocManager
        * PCAtools
        * org.Hs.eg.db
        * org.Mm.eg.db
    * CRAN Packages
        * gtools
        * stringi
* _Linux Tools_
    * hostname
    * jq
    * figlet (_optional_)
* _QC Tools_
    * FastQC
    * MultiQC
    * QualiMap
* _NGS Software_ 
    * BBDuk
    * STAR
    * RSEM

> [!NOTE]
> While the interpreters of the _Development Environments_ must be globally available (i.e., findable in `$PATH`), _NGS Software_ only needs to be present locally on the server.
> Paths to each NGS Software tool are configured later by editing the `install.paths` file (see below).
> Finally, the _QC Tools_ allow both installation modes.

The following command sequence represents the standard installation procedure on an Arch/Manjaro system.
For different Linux distributions, please refer to the installation guides for the various tools.
```bash
# Oracle Java (v.7 or higher)
yay -Syu jre jdk
java --version

# Python 3 (pip) and pipx
sudo pacman -Syu python
python --version
sudo pacman -Syu python-pip
pip --version
sudo pacman -Syu python-pipx
pipx --version

# R
sudo pacman -Syu r
R --version

# Bioconductor packages
R
```
```r
# Within R
install.packages("gtools")
install.packages("BiocManager")
BiocManager::install(version = "3.21") # Get the latest version of Bioconductor
BiocManager::install("PCAtools")
BiocManager::install("org.Hs.eg.db")
BiocManager::install("org.Mm.eg.db")

# Sometimes the following PCAtools dependencies need to be manually installed...
install.packages("stringi", "reshape2")
# ...as well as the following AnnotationDbi one.
install.packages("RCurl")

# Return to the Linux CLI
q()
```
```bash
# core/inetutils package (for hostname utility)
sudo pacman -Syu inetutils

# JQ
sudo pacman -Syu jq

# Figlet (optional)
sudo pacman -Syu figlet

# FastQC
cd ~/.local/bin
wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.12.1.zip
unzip fastqc_v0.12.1.zip
cd FastQC
./fastqc --version

# MultiQC
pipx install multiqc
multiqc --version

# QualiMap
# Support still to be added... see the related issue #23.

# BBTools (for BBDuk)
cd ~/.local/bin
wget --content-disposition https://sourceforge.net/projects/bbmap/files/BBMap_39.01.tar.gz/download
tar -xvzf BBMap_39.01.tar.gz
cd bbmap
./stats.sh in=./resources/phix174_ill.ref.fa.gz

# STAR
cd ~
git clone git@github.com:alexdobin/STAR.git
sudo mv ./STAR /opt/STAR
# Optionally make '/opt/STAR/bin/Linux_x86_64_static/STAR' globally available.
STAR --version
# Just on the first run, download the latest Genome Assembly (FASTA) and related
# Gene Annotation (GTF), and generate the STAR-compliant genome index.
# NOTE: Unless otherwise specified, Ensembl will be used as the reference
#       standard for gene annotation.
cd /data/hg38star
sudo wget https://ftp.ensembl.org/pub/release-110/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
sudo gunzip Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
sudo wget https://ftp.ensembl.org/pub/release-110/gtf/homo_sapiens/Homo_sapiens.GRCh38.110.gtf.gz
sudo gunzip Homo_sapiens.GRCh38.110.gtf.gz
sudo mkdir index
sudo chmod 777 index/
sudo STAR --runThreadN 8 --runMode genomeGenerate \
    --genomeDir /data/hg38star/index \
    --genomeFastaFiles /data/hg38star/Homo_sapiens.GRCh38.dna.primary_assembly.fa \
    --sjdbGTFfile /data/hg38star/Homo_sapiens.GRCh38.110.gtf \
    --sjdbOverhang 100

# RSEM
cd ~
git clone git@github.com:deweylab/RSEM.git
cd RSEM
make
cd ..
sudo mv ./RSEM /opt/RSEM
# Optionally make '/opt/RSEM' globally available.
rsem-calculate-expression --version
# Just on the first run, build the RSEM reference using the Ensembl annotations
# already downloaded for STAR index generation.
cd /data/hg38star
sudo mkdir ref
sudo rsem-prepare-reference \
    --gtf /data/hg38star/Homo_sapiens.GRCh38.110.gtf \
    /data/hg38star/Homo_sapiens.GRCh38.dna.primary_assembly.fa \
    /data/hg38star/ref/human_ensembl
```
> [!TIP]
> Use `x.fastq -d` to get a complete report about the current dependency status.

### Editing `install.paths`
A text file called `install.paths` is located in the `config` subdirectory and is used to store the paths that allow ___x.FASTQ___ to find the software and genome data it needs.
Each `install.paths` entry has the following format
```
hostname:tool_name:full_path
```
For a given `hostname`, each `tool_name` is searched for in `full_path`, usually the directory containing the installed executable for the tool.
Notably, multiple _hostnames_ for the same _tool_ are allowed to increase portability.
Since each ___x.FASTQ___ installation will only look at lines starting with the current `$HOSTNAME`, a single `install.paths` configuration file is required to properly run ___x.FASTQ___ on different server machines.

For a given `hostname`, each `tool_name` will be looked for in `full_path`, usually the directory containing the installed executable for the tool.
Notably, multiple _hostnames_ for the same _tool_ are allowed to increase portability.
Since each ___x.FASTQ___ installation will consider only those lines starting with the current `$HOSTNAME`, a single `install.paths` configuration file is sufficient to properly run ___x.FASTQ___ on different server machines.

> [!IMPORTANT]
> When editing the `install.paths` configuration file to adapt it to your server(s), just keep in mind that _hostname_ can be retrieved using `echo $HOSTNAME` or the `hostname` command in Bash; _tool_names_ must match the names hardcoded in the different scripts of the suite (see below for a comprehensive list); _full_paths_ are meant to be the absolute paths (i.e., `realpath`), without trailing slashes.

Here is a list of the possible `tool_name`s that can be added to `install.paths` (according to the `_get_qc_tools` and `_get_seq_sw` `x.funx.sh` functions) along with a brief explanation of the corresponding paths as used by ___x.FASTQ___ (here the string grep-ing is case-insensitive):
* **FastQC**: path to the directory containing the `fastqc` executable file [required by `qcfastq.sh`]
* **MultiQC**: path to the directory containing the `multiqc` symlink to the executable file [required by `qcfastq.sh`]
* **BBDuk**: path to the directory containing the `bbduk.sh` executable file [required by `trimmer.sh` and `trimfastq.sh`]
* **Genome**: path to the parent directory containing all the locally-stored genome data (e.g., FASTA genome assemblies, GTF gene annotation, STAR index, RSEM reference, ...) [used by `x.fastq.sh --space` option]
* **STAR**: path to the directory containing the `STAR` executable file [required by `anqfastq.sh` and `starsem.sh`]
* **S_index**: path to the directory containing the STAR index, as specified by the `--genomeDir` parameter during `STAR --runMode genomeGenerate` first run [required by `anqfastq.sh` and `starsem.sh`]
* **RSEM**: path to the directory containing the `rsem-calculate-expression` executable file [required by `anqfastq.sh` and `starsem.sh`]
* **R_ref**: path to the directory containing the RSEM reference, **including the *reference_name*** used during its creation by `rsem-prepare-reference` (e.g., `/data/hg38star/ref/human_ensembl`) [required by `anqfastq.sh` and `starsem.sh`]

> [!NOTE]
> `install.paths` is the only file to edit when installing new dependency tools or moving to different server machines.
> Only _NGS Software_ and _QC Tools_ need to be specified here.
> However, all _QC Tools_ can be called from ___x.FASTQ___ even if their path is unknown, but they have been made globally available by their inclusion in `$PATH`.

### Changing Model Organism
Similar to Human, before the first run, you must generate a new STAR genome index for each alternative model of interest, as well as the corresponding reference for RSEM.
For example, in the case of Mouse, you will need to
```bash
cd /data/mm39star/
sudo wget https://ftp.ensembl.org/pub/release-112/fasta/mus_musculus/dna/Mus_musculus.GRCm39.dna.primary_assembly.fa.gz
sudo gunzip Mus_musculus.GRCm39.dna.primary_assembly.fa.gz
sudo wget https://ftp.ensembl.org/pub/release-112/gtf/mus_musculus/Mus_musculus.GRCm39.112.gtf.gz
sudo gunzip Mus_musculus.GRCm39.112.gtf.gz

# STAR
sudo mkdir index
sudo chmod 777 index/
sudo STAR --runThreadN 8 --runMode genomeGenerate \
    --genomeDir /data/mm39star/index \
    --genomeFastaFiles /data/mm39star/Mus_musculus.GRCm39.dna.primary_assembly.fa \
    --sjdbGTFfile /data/mm39star/Mus_musculus.GRCm39.112.gtf \
    --sjdbOverhang 100

# RSEM
sudo mkdir ref
sudo rsem-prepare-reference \
    --gtf /data/mm39star/Mus_musculus.GRCm39.112.gtf \
    /data/mm39star/Mus_musculus.GRCm39.dna.primary_assembly.fa \
    /data/mm39star/ref/mouse_ensembl
```
Then, to align (and quantify) the reads on the mouse genome, it is necessary to edit these two lines in the `install.paths` file:
```
hostname:S_index:/data/mm39star/index
hostname:R_ref:/data/mm39star/ref/mouse_ensembl
```

### Message Of The Day (optional)
During alignment and quantification operations (i.e., when running __anqFASTQ__) ___x.FASTQ___ will attempt to temporarily change the _Message Of The Day_ (MOTD) contained in the `/etc/motd` file on the server machine in order to warn other users of the massive use of computational resources upon login.
Warning and idle MOTDs can be customized by editing the `./config/motd_warn` and `./config/motd_idle` files, respectively.
However, this feature is only effective if an `/etc/motd` file already exists and has write permissions for the user running ___x.FASTQ___.
So, to enable it, you must first add
```bash 
sudo chmod 666 /etc/motd                         # if the file already exists
sudo touch /etc/motd; sudo chmod 666 /etc/motd   # if no file exists
```

### Updating
To updated ___x.FASTQ___ simply `git pull` the repo.
The previous steps only need to be repeated if new script files or new dependencies are added by the developers. 

## Additional Notes
### On Trimming
In its current implementation, __trimFASTQ__ wraps _BBDuk_ to perform a quite
conservative trimming of the reads, based on three steps:
1. __Adapter trimming:__ adapters are automatically detected based on _BBDuk_'s
    `adapters.fa` database and then right-trimmed using 23-to-11 base-long kmers
    allowing for one mismatch (i.e., Hamming distance = 1). See the _KTrimmed_
    stat in the log file.
1. __Quality trimming:__ is performed on both sides of each read using a quality
    score threshold `trimq=10`. See the _QTrimmed_ stat in the log file.
1. __Length filtering:__ All reads shorter than 25 bases are discarded. See the
    _Total Removed_ stat in the log file.

In general, it's best to do adapter-trimming first, then quality-trimming,
because if you do quality-trimming first, sometimes adapters will be partially
trimmed and become too short to be recognized as adapter sequences. For this
reason, when you run _BBDuk_ with both quality-trimming and adapter-trimming in
the same run, it will do adapter-trimming first, then quality-trimming.

On top of that, it should be noted that, in case you are sequencing for counting
applications (like differential gene expression RNA-seq analysis, ChIP-seq,
ATAC-seq) __read trimming is generally not required anymore__ when using modern
aligners. For such studies _local aligners_ or _pseudo-aligners_ should be used.
Modern _local aligners_ (like _STAR_, _BWA-MEM_, _HISAT2_) will _soft-clip_
non-matching sequences. Pseudo-aligners like _Kallisto_ or _Salmon_ will also
not have any problem with reads containing adapter sequences. However, if the
data are used for variant analyses, genome annotation or genome or transcriptome
assembly purposes, read trimming is recommended, including both, adapter and
quality trimming.
> __References__
>
> * Brian Bushnell's (author of _BBTools_) [post on _SEQanswers_ forum](https://www.seqanswers.com/forum/bioinformatics/bioinformatics-aa/37399-introducing-bbduk-adapter-quality-trimming-and-filtering?postcount=5#post247619).
> * UC Davis Genome Center, DNA Technologies and Expression Analysis Core
Laboratory's FAQ [When should I trim my Illumina reads and how should I do it?](https://dnatech.genomecenter.ucdavis.edu/faqs/when-should-i-trim-my-illumina-reads-and-how-should-i-do-it/)
> * Williams et al. 2016. _Trimming of sequence reads alters RNA-Seq gene
expression estimates._ BMC Bioinformatics. 2016;17:103. Published 2016 Feb 25.
doi:[10.1186/s12859-016-0956-2](https://pubmed.ncbi.nlm.nih.gov/26911985/).

### On STAR Aligner
_STAR_ requires ~10 x GenomeSize bytes of RAM for both genome generation and
mapping. For instance, the full human genome will require ~30 GB of RAM. There
is an option to reduce it to 16GB, but it will not work with 8GB of RAM.
However, the transcriptome size is much smaller, and 8GB should be sufficient. 
> __References__
>
> Alexander Dobin's (author of _STAR_) [posts](https://groups.google.com/g/rna-star/c/GEwIu6aw6ZU).

_STAR_ index is commonly generated using `--sjdbOverhang 100` as a default
value. This parameter does make almost no difference for __reads longer than 50
bp__. However, under 50 bp it is recommended to generate _ad hoc_ indexes using
`--sjdbOverhang <readlength>-1`, also considering that indexes for longer reads
will work fine for shorter reads, but not vice versa.
> __References__
>
> Alexander Dobin's (author of _STAR_) [posts](https://groups.google.com/g/rna-star/c/x60p1C-pGbc).

_STAR_ does __not__ currently support PE interleaved FASTQ files. Check it out
the related issue at https://github.com/alexdobin/STAR/issues/686. One way to go
about this is to deinterlace PE-interleaved-FASTQs first and then run
___x.FASTQ___ in the dual-file PE default mode.
> __References__
>
> * [Posts on _Stack Overflow_](https://stackoverflow.com/questions/59633038/how-to-split-paired-end-fastq-files)
> * [Posts on _Biostar Forum_](https://www.biostars.org/p/141256/)
> * _GitHub Gist_ script [`deinterleave_fastq.sh`](https://gist.github.com/nathanhaigh/3521724)
> * _SeqFu_ subprogram [`seqfu deinterleave`](https://telatin.github.io/seqfu2/tools/deinterleave.html)

### On STAR-RSEM Coupling
_RSEM_, as well as other transcript quantification software, requires reads to
be mapped to transcriptome. For this reason, ___x.FASTQ___ runs _STAR_ with
`--quantMode TranscriptomeSAM` option to output alignments translated into
transcript coordinates in the `Aligned.toTranscriptome.out.bam` file (in
addition to alignments in genomic coordinates in `Aligned.*.sam/bam` file).

Importantly, ___x.FASTQ___ runs _STAR_ with `--outSAMtype BAM Unsorted` option,
since if you provide _RSEM_ a sorted BAM, _RSEM_ will assume every read is
uniquely aligned and converge very quickly... but the results are wrong!
> __References__
>
> Bo Li's (author of _RSEM_) [posts](https://groups.google.com/g/rsem-users/c/kwNZESUd0Es).

Currently ___x.FASTQ___ allows analyzing unstranded libraries only, meaning that
even possible stranded libraries are analyzed as unstranded. STAR does not
use library strandedness information for mapping, while RSEM has the easy basic
option `--strandedness <none|forward|reverse>` for this, with the recommendation
of using `reverse` for Illumina TruSeq Stranded protocols. Thus, in case of
need, it should be straightforward to add a new option to __anqFASTQ__ for
selecting the correct RSEM's strandedness value. An issue for this is already
open [here](https://github.com/TCP-Lab/x.FASTQ/issues/30).

### On RSEM Quantification
Among quantification tools, the biggest and most meaningful distinction is
between methods that attempt to properly quantify abundance, generally using a
generative statistical model (e.g., _RSEM_, _BitSeq_, _salmon_, etc.), and those
that try to simply count aligned reads (e.g., _HTSeq_ and _featureCounts_).
Generally, the former are more accurate than the latter at the gene level and
can also offer transcript-level estimates if desired (while counting-based
methods generally cannot).

However, in order to build such a probabilistic model, the __fragment length
distribution__ should be known. The fragment length refers to the physical
molecule of D/RNA captured in the library prep stage and (partially!) sequenced
by the sequencer. Using this information, the _effective_ transcript lengths can
be estimated, which have an effect on fragment assignment probabilities. With
paired-end reads the fragment length distribution can be learned from the FASTQ
files or the mappings of the reads, but for single-end data this cannot be done,
so it is strongly recommended that the user provide the empirical values via the
`–fragment-length-mean` and `–fragment-length-sd` options. This generally
improves the accuracy of expression level estimates from single-end data, but,
usually, the only way to get this information is through the _BioAnalyzer_
results for the sequencing run. If this is not possible and the fragment length
mean and SD are not provided, RSEM will not take a fragment length distribution
into consideration. Nevertheless, it should be noted that the inference
procedure is somewhat robust to these parameters; maximum likelihood estimates
may change a little, but, in any case, the same distributional values will be
applied in all samples and so, ideally, most results of misspecification will
wash out in subsequent differential analysis.

> __References__
>
> Rob Patro's (author of _salmon_) [posts](https://github.com/COMBINE-lab/salmon/issues/127).
>
> _Finally, [...] I don’t believe that model misspecification that may result due
to not knowing the fragment length distribution will generally have enough of a
deleterious effect on the probabilistic quantification methods to degrade their
performance to the level of counting based methods. I would still argue to
prefer probabilistic quantification (i.e., salmon) to read counting, even if
you don’t know the fragment length distribution. As I mentioned above, it may
change the maximum likelihood estimates a bit, but should do so across all
samples, hopefully minimizing the downstream effects on differential analysis._
