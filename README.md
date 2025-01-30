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
___x.FASTQ___ is a suite of __Bash__ scripts that wrap original and third-party
software with the purpose of making RNA-Seq data analysis more accessible and
automated.

## First Principles and Background
___x.FASTQ___ was originally written for the
[*Endothelion*](https://github.com/TCP-Lab/Endothelion)
project with the intention of _abstracting_ our standard analysis pipeline for
NGS transcriptional data. The main idea was to make the whole procedure more
faster, scalable, but also affordable for _wet collaborators_ without a specific
bioinformatics background, even those possibly operating from different labs or
departments. To meet these needs, we designed ___x.FASTQ___ to have the
following specific features:
* __Remote operability__: Given the typical hardware requirements needed for
    read alignment and transcript abundance quantification, ___x.FASTQ___ is
    assumed to be installed just on one or few remote servers accessible to all
    collaborators via SSH. Each ___x.FASTQ___ module, launched via CLI as a Bash
    command, will run in the background and persistently (i.e., ignoring the
    hangup signal `HUP`) so that the user is not bound to keep the connection
    active for the entire duration of the analysis, but only for job scheduling.
* __Standardization__: Most ___x.FASTQ___ scripts are wrappers of lower-level
    applications commonly used as standard tools in RNA-Seq data analysis and
    widely appreciated for their performance (e.g., FastQC, BBDuk, STAR, RSEM).
* __Simplification__: Scripts expose a limited number of options by making
    extensive use of default settings (suitable for the majority of standard
    RNA-Seq analyses) and taking charge of managing input and output data
    formats and their organization.
* __Automation__: All scripts are designed to loop over sets of _target files_
    properly stored within the same directory. Although designed as independent
    modules, each step can optionally be chained to the next one in a single
    pipeline to automate the entire analysis workflow.
* __Completeness__: The tools provided by ___x.FASTQ___ allow for a complete
    workflow, from raw reads retrieval to count matrix generation.
* __No bioinformatics skills required__: Each ___x.FASTQ___ module comes with an
    `--help` option providing extensive documentation. The only requirement for
    the user is a basic knowledge of the Unix shell and a SSH client installed
    on its local machine.
* __Reproducibility__: although (still) not containerized, each ___x.FASTQ___
    module is tightly versioned and designed to save detailed log files at each
    run. Also, utility functions are available to print complete version reports
    about ___x.FASTQ___ modules and dependencies (i.e., `x.fastq -r` and `-d`
    options, respectively).

## Modules
### Overview
___x.FASTQ___ currently consists of 7 modules designed to be run directly by the
end-user, each one of them addressing a precise step of a general pipeline for
RNA-Seq data analysis, which goes from the retrieval of raw reads to the
generation of the expression matrix.
1. __x.FASTQ__ is a *cover-script* that performs some general-utility tasks,
    such dependency check, symlink creation, version monitoring, and disk usage
    reporting;
1. __getFASTQ__ allows local downloading of NGS raw data in FASTQ format from
    [ENA database](https://www.ebi.ac.uk/ena/browser/home);
1. __trimFASTQ__ uses _BBDuk_ (from the
    [BBTools suite](https://jgi.doe.gov/data-and-tools/software-tools/bbtools/))
    to remove adapter sequences and perform quality trimming;
1. __anqFASTQ__ uses [STAR](https://github.com/alexdobin/STAR) and
    [RSEM](https://github.com/deweylab/RSEM) to align reads and quantify
    transcript abundance, respectively;
1. __qcFASTQ__ is an interface for multiple quality-control tools, including
    [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) and
    [MultiQC](https://multiqc.info/);
1. __tabFASTQ__ assembles counts from multiple samples/runs into a single TSV
    expression table, choosing among multiple metrics (TPM, FPKM, RSEM expected
    counts) and levels (gene or isoform); optionally, it injects experimental
    design information into the matrix heading and appends annotations regarding
    gene symbol, gene name, and gene type (__Ensembl gene/transcript IDs are
    required for annotation__);
1. __metaharvest__ fetches sample and series metadata from
    [GEO](https://www.ncbi.nlm.nih.gov/geo/) and/or
    [ENA](https://www.ebi.ac.uk/ena/browser/home)
    databases, then it parses the retrieved metadata and saves a local copy of
    them as a CSV-formatted table (useful for both documentation and subsequent
    ___x.FASTQ___ analysis steps).

In addition, ___x.FASTQ___ includes a number of auxiliary scripts (written in
__Bash__, __R__, or __Python__) that are not meant to be directly run by the end
user, but are called by the main modules. Most of them are found in the
`workers` subfolder.
1. `x.funx.sh` contains variables and functions that need to be shared among
    (i.e., _sourced_ by) all ___x.FASTQ___ modules;
1. `progress_funx.sh` is a script that collects all the functions for tracking
    the progress of the different modules (see the `-p` option below);
1. `trimmer.sh` is the actual trimming script, wrapped by __trimFASTQ__;
1. `starsem.sh` is the actual aligner/quantifier script, wrapped by
    __trimFASTQ__;
1. `assembler.R` implements the matrix assembly procedure required by
    __tabFASTQ__;
1. `pca_hc.R` implements Principal Component Analysis and Hierarchical
    Clustering of samples as required by the `qcfastq --tool=PCA ...` option;
1. `fuse_csv.R` is used by `metaharvest` to merge the cross-referenced metadata
    downloaded from both GEO and ENA databases;
1. `parse_series.R` is used by `metaharvest` to extract metadata from a
    GEO-retrieved SOFT formatted family file;
1. `re_uniq.py` is used to reduce redundancy when STAR and RSEM logs are
    displayed in console as __anqFASTQ__ progress reports.

### Common Features and Options
All suite modules enjoy some internal consistency:
* upon running `x.fastq.sh -l <target_path>` from the local ___x.FASTQ___
    repository directory, each ___x.FASTQ___ module can be invoked from any
    location on the remote machine using its fully lowercase name (provided that
    `<target_path>` is already included in `$PATH`);
* by default, each script launches in the ___background___ a ___persistent___
    job (or a queue of jobs) by using a custom re-implementation of the `nohup`
    command;
* each module (except __x.FASTQ__ and __metaharvest__) saves its own log file in
    inside the experiment-specific target directory using a common filename
    pattern, namely
    ```
    Z_<ScriptID>_<FastqID>_<DateStamp>.log
    Z_<ScriptID>_<StudyID>_<DateStamp>.log
    ```
    for sample-based or series-based logs, respectively (the leading 'Z_' is
    just to get all log files at the bottom of the list when `ls -l`);
> [!IMPORTANT]  
> In the current implementation of ___x.FASTQ___, filenames are very meaningful!
>
> Each FASTQ file is required to have a name matching the regex pattern
> ```
> ^[a-zA-Z0-9]+[^a-zA-Z0-9]*.*\.fastq\.gz
> ```
> i.e., beginning with an alphanumeric ID (usually an ENA run ID of this type
> `(E|D|S)RR[0-9]{6,}`) immediately followed by the extension `.fastq.gz` or
> separated from the remaining filename by an underscore or some other
> characters not in `[a-zA-Z0-9]`. Valid examples are `GSM34636.fastq.gz`,
> `SRR19592966_1.fastq.gz`, etc. This leading ID will be propagated to the names
> of the log files printed by the __getFASTQ__ module and _BBDuk_ (saved in
> `Trim_stats` subdirectory), as well as to all output files from _FastQC_
> (stored in `FastQC_*` subdirectories) and _STAR_/_RSEM_ (i.e., `Counts`
> subfolders and all files contained therein). __tabFASTQ__ will then assume
> each RSEM output file being saved into a sample- or run-specific subdirectory,
> whose name will be used for count matrix heading. Similarly, but at a lower
> level, even _MultiQC_ needs each _STAR_ and _RSEM_ output to be properly
> prefixed with a suitable sample or run ID to be correctly accounted for.
> Notice, however, that all this should occur spontaneously if FASTQs are
> downloaded from ENA database using the __getFASTQ__ module.
>
> In contrast, it is important for the user to manually name each project folder
> (i.e., each directory that will contain the entire set of FASTQ files from one
> single experiment) with a name uniquely assigned to the study (typically the
> related GEO Series ID `GSE[0-9]+` or the ENA Project accession
> `PRJ(E|D|N)[A-Z][0-9]+`). Log files created by most of the ___x.FASTQ___
> modules rely on the name of the target directory for the assignment of the
> `StudyID` label, and the same holds for the _MultiQC_ HTML global report and
> the file name of the final expression matrix.
* some common flags keep the same meaning across all modules (even if not all of
    them are always available):
    * `-h | --help` to display the script-specific help;
    * `-v | --version` to display the script-specific version;
    * `-q | --quiet` to run the script silently;
    * `-p | --progress` to see the progress of possibly ongoing processes;
    * `-k | --kill` to gracefully terminate possibly ongoing processes;
    * `-a | --keep-all` not to delete intermediate files upon script execution;
* all modules are versioned according to the three-number _Semantic Versioning_
    system. `x.fastq -r` can be used to get a version report of all scripts
    along with the _summary version_ of the whole ___x.FASTQ___ suite;
* if `-p` is not followed by any other arguments, the script searches the
    current directory for log files from which to infer the progress of the
    latest namesake task;
* with the `-q` option, scripts do not print anything on the screen other than
    possible error messages that stop the execution (i.e., fatal errors);
    logging activity is never disabled, though.

## Usage
Assuming you have identified a study of interest from GEO (e.g., `GSE138309`),
have already created a project folder somewhere (`mkdir '<anyPath>'/GSE138309`),
and moved in there (`cd '<anyPath>'/GSE138309`), here are a couple of possible
example workflows.

> [!IMPORTANT]  
> Given the hard-coded background execution of most ___x.FASTQ___ modules, it is
> not possible (at present) to use these command sequences for creating
> automated pipelines. On the contrary, before launching each module, it is
> necessary to ensure that the previous one has successfully terminated.

### Minimal Workflow
```bash
# Download FASTQs, align, quantify, and assemble a gene-level count matrix
getfastq -u GSE138309 > ./GSE138309_wgets.sh
getfastq GSE138309_wgets.sh
anqfastq .
tabfastq .
```

### Complete Workflow
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
tabfastq --isoforms --names --design="${groups[*]}" --metric=expected_count .

# Explore samples through PCA
qcfastq --tool=PCA .
```
> [!NOTE]  
> The study chosen here as an example features non-interleaved (i.e., dual-file)
> paired-end (PE) reads, however ___x.FASTQ___ also supports single-ended (SE)
> and interleaved PE formats. In those cases, just add, respectively,
> `[-s | --single-end]` or `[-i | --interleaved]` options, when running
> __trimFASTQ__ and __anqFASTQ__ modules.

## Installation
As already stressed, a working SSH client is the only local software requirement
for using ___x.FASTQ___, provided it has already been installed on some remote
server machines by the system administrator. The procedure for installing
___x.FASTQ___ (and all its dependencies) on the server is here documented step
by step.

### Cloning
Clone ___x.FASTQ___ repository from GitHub
```bash
cd ~/.local/bin/
git clone git@github.com:Feat-FeAR/x.FASTQ.git
```

### Symlinking (optional)
Create the symlinks in some `$PATH` directory (e.g., `~/.local/bin/`) to enable
global ___x.FASTQ___ visibility and easier module invocation.
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
> While the interpreters of the _Development Environments_ need to be globally
> available (i.e., findable in `$PATH`), _NGS Software_ just has to be locally
> present on the server. Paths to each NGS Software tool will be configured
> later by editing the `install.paths` file (see below). Finally, _QC Tools_
> allow both installation modes.

The following command sequence represents the standard installation procedure on
an Arch/Manjaro system. For different Linux distributions, please refer to the
installation guides of the different tools.
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
install.packages("BiocManager")
install.package("gtools")
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
A text file named `install.paths` can be found in the `config` sub-directory and
it is meant to store the paths that allow ___x.FASTQ___ to find the software and
genome data it requires. Each `install.paths` entry has the following format:
```
hostname:tool_name:full_path
```
For a given `hostname`, each `tool_name` will be looked for in `full_path`,
usually the directory containing the installed executable for the tool. Notably,
multiple _hostnames_ for the same _tool_ are allowed to increase portability.
Since each ___x.FASTQ___ installation will consider only those lines starting
with the current `$HOSTNAME`, a single `install.paths` configuration file is
needed to properly run ___x.FASTQ___ on different server machines.

> [!IMPORTANT]
> When editing the `install.paths` configuration file to adapt it to your
> server(s), just keep in mind that _hostname_ can be retrieved using
> `echo $HOSTNAME` or the `hostname` command in Bash; _tool_names_ need to be
> compliant with the names hardcoded in `anqfastq.sh` and `x.funx.sh` scripts
> (see next paragraph for a comprehensive list of them); _full_paths_ are meant
> to be the absolute paths (i.e., `realpath`), without trailing slashes.

Here is a list of the possible `tool_name`s that can be added to `install.paths`
(according to `_get_qc_tools` and `_get_seq_sw` `x.funx.sh` functions) along
with a brief explanation of the related paths as used by ___x.FASTQ___ (here
string grep-ing is case-insensitive):
* **FastQC**: path to the directory containing the `fastqc` executable file
    [required by `qcfastq.sh`]
* **MultiQC**: path to the directory containing the `multiqc` symlink to the
    executable file [required by `qcfastq.sh`]
* **BBDuk**: path to the directory containing the `bbduk.sh` executable file
    [required by `trimmer.sh`, `trimfastq.sh`]
* **Genome**: path to the parent directory containing all the locally-stored
    genome data (e.g., FASTA genome assemblies, GTF gene annotation, STAR index,
    RSEM reference, ...) [used by `x.fastq.sh --space` option]
* **STAR**: path to the directory containing the `STAR` executable file
    [required by `anqfastq.sh`]
* **S_index**: path to the directory containing the STAR index, as specified by
    the `--genomeDir` parameter during `STAR --runMode genomeGenerate` first run
    [required by `anqfastq.sh`]
* **RSEM**: path to the directory containing the `rsem-calculate-expression`
    executable file [required by `anqfastq.sh`]
* **R_ref**: path to the directory containing the RSEM reference, **including
    the *reference_name*** used during its creation by `rsem-prepare-reference`
    (e.g., `/data/hg38star/ref/human_ensembl`) [required by `anqfastq.sh`]

> [!NOTE]
> `install.paths` is the only file to edit when installing new dependency tools
> or moving to different server machines. Only _NGS Software_ and _QC Tools_
> need to be specified here. However, all _QC Tools_ can be run by ___x.FASTQ___
> even if their path is unknown but they have been made globally available
> by `$PATH` inclusion. In addition, when _BBDuk_ cannot be found by means of
> `install.paths` file, the standalone (and __non-persistent__) `trimmer.sh`
> script interactively prompts the user to input an alternative path runtime, in
> contrast to its wrapper (`trimfastq.sh`) that simply quits the program.

### Changing Model Organism
Similar to what was done for Human, before the first run, you need to generate a
new STAR genome index for the alternative model of interest, as well as the
related reference for RSEM. For example, in the case of Mouse, you need to:
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
Now, in order to align (and quantify) reads on the mouse genome, it will be
enough to edit these two lines of the `install.paths` file:
```
hostname:S_index:/data/mm39star/index
hostname:R_ref:/data/mm39star/ref/mouse_ensembl
```

### Message Of The Day (optional)
During alignment and quantification operations (i.e., when running __anqFASTQ__)
___x.FASTQ___ attempts to temporarily change the _Message Of The Day_ (MOTD)
contained in the `/etc/motd` file on the server machine in order to alert at
login any other users of the massive occupation of computational resources.
Warning and idle MOTDs can be customized by editing `./config/motd_warn` and
`./config/motd_idle` text files, respectively. However, this feature is only
effective if an `/etc/motd` file already exists and has write permissions for
the user running ___x.FASTQ___. So, to enable it, you preliminarily have to
```bash 
sudo chmod 666 /etc/motd                         # if the file already exists
sudo touch /etc/motd; sudo chmod 666 /etc/motd   # if no file exists
```

### Updating
To updated ___x.FASTQ___ just `git pull` the repo. Previous steps need to be
repeated only when new script files or new dependencies are added.

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
