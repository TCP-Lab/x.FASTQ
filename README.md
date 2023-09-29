# x.FASTQ

```
$ xfastq    _____ _    ____ _____ ___   
    __  __ |  ___/ \  / ___|_   _/ _ \ 
    \ \/ / | |_ / _ \ \___ \ | || | | |
     >  < _|  _/ ___ \ ___) || || |_| |
    /_/\_(_)_|/_/   \_\____/ |_| \__\_\
       code for the Endothelion project
```

## Generality

**x.FASTQ** is a suite of Bash scripts specifically written for the
*Endothelion* project with the purpose of simplifying and automating the
workflow of the project by making each task persistent after it has been
launched in the background on the remote machine.

**x.FASTQ** currently consists of 6 scripts:
1. `x.FASTQ` as a *cover-script* to perform some general-utility tasks;
1. `getFASTQ` to download NGS raw data from ENA (as .fastq.gz);
1. `trimFASTQ` to remove adapter sequences and perform quality trimming;
1. `trimmer.sh` containing the actual trimmer script wrapped by `trimFASTQ`;
1. `qcFASTQ` for data quality control;
1. `x.funx.sh` containing variables and functions sourced by all the others.

The suite enjoys some internal consistency:
* upon running the `x.fastq.sh -l <target_path>` command from the local x.FASTQ
    directory, each **x.FASTQ** script can be invoked from any location on the
    remote machine using fully lowercase name, provided that `<target_path>` is
    already included in `$PATH`;
* each script launches in the **background** a **persistent** queue of jobs
    (i.e., main commands start with `nohup` and end with `&`);
* each script saves its own log in the experiment-specific target directory
    using a common filename pattern, namely `Z_ScriptName_FastqID_DateStamp.log`
    for sample-based logs, or `Z_ScriptName_ExperimentID_DateStamp.log` for
    series-based logs (the leading 'Z_' is just to get all log files at the
    bottom of the list when `ls -l`);
* some common flags keep the same meaning across all script:
    * `-h | --help`
    * `-v | --version`
    * `-q | --quiet`
    * `-p | --progress`
* if `-p` is not followed by any arguments, the script searches the current
    directory for log files from which to infer the progress of the last
    namesake task;
* the `--quiet` option does not print anything on the screen other than possible
    error messages that stop script execution (i.e., fatal errors);
* with the `-q` option, if the script is successful, nothing is printed to the
    screen, but a log file is saved anyway.

## Installation

### Cloning
Clone **x.FASTQ** repository from GitHub
```bash
cd ~/.local/bin/
git clone git@github.com:Feat-FeAR/x.FASTQ.git
```

### Symlinking
Create the symlinks in some `$PATH` directory (e.g., `~/.local/bin/`) to
enable global **x.FASTQ** visibility
```bash
cd x.FASTQ
./x.fastq.sh -l ..
```

### Dependencies
Install and test the following software, as required by **x.FASTQ**
* _Development Environments_
    * Java
    * Python
    * R
* _QC Tools_
    * FastQC
    * MultiQC
    * QualiMap
    * PCA
* _NGS Software_ 
    * BBDuk
    * STAR
    * RSEM

> While the interpreters of the _Development Environments_ need to be globally
> available, _NGS Software_ just has to be locally present on the remote machine
> Finally, _QC Tools_ allow both installation modes.

The following command sequence represents the standard installation procedure on
an Arch/Manjaro system. For different Linux distributions, please refer to the
specific installation guides of the different software.
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
# PCA

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
# Make '/opt/STAR/bin/Linux_x86_64_static/STAR' globally available.
STAR --version
# Just on the first run, download the latest Genome Assembly (FASTA) and related
# Gene Annotation (GTF), and generate the STAR-compliant genome index.
cd /data/hg38star
sudo wget https://ftp.ensembl.org/pub/release-110/fasta/homo_sapiens/dna/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
sudo gunzip Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz
sudo wget https://ftp.ensembl.org/pub/release-110/gtf/homo_sapiens/Homo_sapiens.GRCh38.110.gtf.gz
sudo gunzip Homo_sapiens.GRCh38.110.gtf.gz
sudo mkdir index
sudo chmod 777 index/
STAR --runThreadN 8 --runMode genomeGenerate \
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
# Make '/opt/RSEM' globally available.
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

Command `x.fastq -d` can be used to check current dependency status.

### Editing `install_paths.txt`
A text file named `install_path.txt` is placed in the main project directory and
is used to store all the local paths that allow **x.FASTQ** to find the software
and genome data it requires. Each entry has the following format
```
hostname:tool_name:full_path
```
> _hostname_ can be retrieved using the `hostname` command in Bash; _tool_name_
> need to be compliant with the names hardcoded in `anqfastq.sh` and `x.funx.sh`
> (see in particular `_get_qc_tools` and `_get_seq_sw` functions); _full_path_
> is meant to be the absolute path (i.e., `realpath`), without trailing slashes.

Here is a list of the `tool_name`s and a brief explanation of the related paths
currently used by **x.FASTQ** (string grep-ing is case-insensitive):
* **FastQC**: path to the directory containing the `fastqc` executable file
    [required by `qcfastq.sh`]
* **MultiQC**: path to the directory containing the `multiqc` symlink to the
    executable file [required by `qcfastq.sh`]
* **BBDuk**: path to the directory containing the `bbduk.sh` executable file
    [required by `trimmer.sh`, `trimfastq.sh`]
* **Genome**: path to the parent directory containing the all the locally-stored
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

`install_path.txt` is the only file to edit when installing new dependency tools
or moving to new host machines. Only _NGS Software_ and _QC Tools_ paths need to
be specified here. However all _QC Tools_ can be used by **x.FASTQ** even if
their path is unknown but they have been made globally available on the remote
machine. In addition, if BBDuk cannot be found through `install_path.txt`, the
standalone `trimmer.sh` interactively prompts the user to input a new path
runtime, in contrast to `trimfastq.sh` that simply quits the program. 

### Updating
To updated **x.FASTQ** just `git pull` the repo. Previous steps need to be
repeated only when new script files or new dependencies are added.

## Notes on Trimming

In the current implementation, **x.FASTQ** (i.e., `trimFASTQ`) wraps BBDuk to
perform a quite conservative trimming of the reads, based on three steps:
1. __Adapter trimming:__ adapters are automatically detected based on BBDuk's
    `adapters.fa` database and then right-trimmed using 23-to-11 base-long kmers
    allowing for one mismatch (i.e., Hamming distance = 1). See the _KTrimmed_
    stat in the log file.
1. __Quality trimming:__ is performed on both sides of each read using a quality
    score threshold `trimq=10`.See the _QTrimmed_ stat in the log file.
1. __Length filtering:__ All reads shorter than 25 bases are discarded.See the
    _Total Removed_ stat in the log file.

> In general, it's best to do adapter-trimming first, then quality-trimming,
because if you do quality-trimming first, sometimes adapters will be partially
trimmed and become too short to be recognized as adapter sequences. For this
reason, when you run BBDuk with both quality-trimming and adapter-trimming in
the same run, it will do adapter-trimming first, then quality-trimming.
>
> On top of that, it should be noted that, in case you are sequencing for
counting applications (like differential gene expression RNA-seq analysis,
ChIP-seq, ATAC-seq) __read trimming is generally not required anymore__ when
using modern aligners. For such studies _local aligners_ or _pseudo-aligners_
should be used. Modern _local aligners_ (like STAR, BWA-MEM, HISAT2) will 
_soft-clip_ non-matching sequences. Pseudo-aligners like Kallisto or Salmon will
also not have any problem with reads containing adapter sequences. However, if
the data are used for variant analyses, genome annotation or genome or
transcriptome assembly purposes, read trimming is recommended, including both,
adapter and quality trimming.
>> __References:__
>>
>> Williams et al. 2016. _Trimming of sequence reads alters RNA-Seq gene
expression estimates._ BMC Bioinformatics. 2016;17:103. Published 2016 Feb 25.
doi:10.1186/s12859-016-0956-2
