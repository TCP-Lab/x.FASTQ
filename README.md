# x.FASTQ

```
$ x.fastq        _____   _      ____   _____   ___
    __  __      |  ___| / \    / ___| |_   _| / _ \
    \ \/ /      | |_   / _ \   \___ \   | |  | | | |
     >  <    _  |  _| / ___ \   ___) |  | |  | |_| |
    /_/\_\  (_) |_|  /_/   \_\ |____/   |_|   \__\_\
                  modules for the remote analysis of
                                        RNA-Seq data
```

## Generality

**x.FASTQ** is a suite of Bash wrappers originally written for the
[*Endothelion*](https://github.com/TCP-Lab/Endothelion) project with the aim of
simplifying and automating the analysis workflow by making each task persistent
once it has been launched in the background on a remote server machine.

**x.FASTQ** currently consists of 6 modules designed to be run directly by the
end-user, each one of them addressing a precise step in the RNA-Seq pipeline
that goes from the retrieval of raw reads to the generation of the expression
matrix.
1. `x.FASTQ` is a *cover-script* that performs some general-utility tasks;
1. `getFASTQ` allows downloading of NGS raw data from ENA (as .fastq.gz);
1. `qcFASTQ` is an interface for multiple quality-control tools;
1. `trimFASTQ` uses BBDuk to remove adapter sequences and perform quality
trimming;
1. `anqFASTQ` uses STAR and RSEM to align reads and quantify transcript
abundance, respectively;
1. `countFASTQ` assembles counts from multiple samples into one single
expression matrix.
1. `metaharvest` fetches and parses metadata from GEO and fusing it with
   ENA data to create metadata more usable in conjuction with x.FASTQ-processed
   expression matrices.

In addition, there are a number of auxiliary scripts (written in Bash or R),
that are not meant to be directly run, but are called by the main modules. 
1. `x.funx.sh` contains variables and functions sourced by all other scripts;
1. `trimmer.sh` is the actual trimming script, wrapped by `trimFASTQ`;
1. `cc_assembler.R` implements the assembly procedure used by `countFASTQ`;
1. `cc_pca.R` implements the `qcfastq --tool=PCA ...` option.

All suite modules enjoy some internal consistency:
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
* some common flags keep the same meaning across all modules (even if not all of
    them are always available):
    * `-h | --help` to display the script-specific help
    * `-v | --version` to display the script-specific version
    * `-q | --quiet` to run the script quietly
    * `-p | --progress` to see the progress of possibly ongoing processes
    * `-k | --kill` to terminate possibly ongoing processes
    * `-a | --keep-all` not to delete any files upon script execution
* all modules are versioned according to the three-number _Semantic Versioning_
    system (`x.fastq -r` can be used to get a version report of all scripts
    along with the _summary version_ of the whole **x.FASTQ** suite);
* if `-p` is not followed by any arguments, the script searches the current
    directory for log files from which to infer the progress of the last
    namesake task;
* with the `-q` option, scripts do not print anything on the screen other than
    possible error messages that stop the execution (i.e., fatal errors);
    logging activity is not disabled, though.

## Installation

### Cloning
Clone **x.FASTQ** repository from GitHub
```bash
cd ~/.local/bin/
git clone git@github.com:Feat-FeAR/x.FASTQ.git
```

### Symlinking (optional)
Create the symlinks in some `$PATH` directory (e.g., `~/.local/bin/`) to
enable global **x.FASTQ** visibility and more easily invoke the scripts.
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
    * JQ
    * Bioconductor packages
        * BiocManager
        * PCAtools
        * org.Hs.eg.db
        * org.Mm.eg.db
* _QC Tools_
    * FastQC
    * MultiQC
    * QualiMap
* _NGS Software_ 
    * BBDuk
    * STAR
    * RSEM

> While the interpreters of the _Development Environments_ need to be globally
> available (i.e findable in `$PATH`), _NGS Software_ just has to be locally
> present on the remote machine. Paths to each NGS Software tool will be
> configured later in the `install.paths` file. Read more about it below.
> _QC Tools_ allow both installation modes.

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

# JQ
sudo pacman -Syu jq

# Bioconductor packages
R
```
```r
# Within R
install.packages("BiocManager")
BiocManager::install("PCAtools")
BiocManager::install("org.Hs.eg.db")
BiocManager::install("org.Mm.eg.db")

# Sometimes the following PCAtools dependencies need to be manually installed...
install.packages("stringi", "reshape2")
# ...as well as the following AnnotationDbi one.
install.packages("RCurl") 
```
```bash
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
Command `x.fastq -d` can be used to check the current dependency status.

### Editing `install.paths`
A text file named `install.paths` is placed in the main project directory and it
is used to store all the local paths that allow **x.FASTQ** to find the software
and genome data it requires. Each entry has the following format
```
hostname:tool_name:full_path
```

The `x.FASTQ` suite of scripts will consider only lines starting with the current
`hostname`, for increased portability.
For example, if the current machine's hostname is `analysis`, only lines with
`analysis` as their hostname will be considered when determining installation
paths.
For a given hostname, each `tool_name` will be looked for in `full_path`,
usually the directory containing the installed executable for the tool.

> _hostname_ can be retrieved using the `hostname` command in Bash; _tool_name_
> need to be compliant with the names hardcoded in `anqfastq.sh` and `x.funx.sh`
> (see in particular `_get_qc_tools` and `_get_seq_sw` functions); _full_path_
> is meant to be the absolute path (i.e., `realpath`), without trailing slashes.

Here is a list of the possible `tool_name`s that can be found in `install.paths`
and a brief explanation of the related paths used by **x.FASTQ**
(string grep-ing is case-insensitive):
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

`install.paths` is the only file to edit when installing new dependency tools or
moving to new host machines. Only _NGS Software_ and _QC Tools_ paths need to be
specified here. However all _QC Tools_ can be used by **x.FASTQ** even if their
path is unknown but they have been made globally available on the remote
machine. In addition, if BBDuk cannot be found through `install.paths`, the
standalone `trimmer.sh` interactively prompts the user to input a new path
runtime, in contrast to `trimfastq.sh` that simply quits the program. 

### Message_Of_The_Day (optional)
During alignment and quantification operations (i.e., when running `anqfastq`)
**x.FASTQ** attempts to temporarily change the _Message Of The Day_ contained in
the `/etc/motd` file in order to alert at login any other users of the massive
occupation of computational resources. This is only possible if an `/etc/motd`
file already exists and has write permissions for the user running **x.FASTQ**.
So, to enable this feature, please
```bash 
sudo chmod 666 /etc/motd                         # if the file already exists
sudo touch /etc/motd; sudo chmod 666 /etc/motd   # if no file exists
```

### Updating
To updated **x.FASTQ** just `git pull` the repo. Previous steps need to be
repeated only when new script files or new dependencies are added.

## Notes

### On Trimming
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

In general, it's best to do adapter-trimming first, then quality-trimming,
because if you do quality-trimming first, sometimes adapters will be partially
trimmed and become too short to be recognized as adapter sequences. For this
reason, when you run BBDuk with both quality-trimming and adapter-trimming in
the same run, it will do adapter-trimming first, then quality-trimming.

On top of that, it should be noted that, in case you are sequencing for counting
applications (like differential gene expression RNA-seq analysis, ChIP-seq,
ATAC-seq) __read trimming is generally not required anymore__ when using modern
aligners. For such studies _local aligners_ or _pseudo-aligners_ should be used.
Modern _local aligners_ (like STAR, BWA-MEM, HISAT2) will _soft-clip_
non-matching sequences. Pseudo-aligners like Kallisto or Salmon will also not
have any problem with reads containing adapter sequences. However, if the data
are used for variant analyses, genome annotation or genome or transcriptome
assembly purposes, read trimming is recommended, including both, adapter and
quality trimming.
> Williams et al. 2016. _Trimming of sequence reads alters RNA-Seq gene
expression estimates._ BMC Bioinformatics. 2016;17:103. Published 2016 Feb 25.
doi:10.1186/s12859-016-0956-2

### On STAR Aligner
STAR requires ~10 x GenomeSize bytes of RAM for both genome generation and
mapping. For instance, the full human genome will require ~30 GB of RAM. There
is an option to reduce it to 16GB, but it will not work with 8GB of RAM.
However, the transcriptome size is much smaller, and 8GB should be sufficient. 

STAR index is commonly generated using `--sjdbOverhang 100` as a default value.
This parameter does make almost no difference for **reads longer than 50 bp**.
However, under 50 bp it is recommended to generate *ad hoc* indexes using
`--sjdbOverhang <readlength>-1`, also considering that indexes for longer reads
will work fine for shorter reads, but not vice versa.
(https://groups.google.com/g/rna-star/c/x60p1C-pGbc)

STAR does **not** currently support PE interleaved FASTQ files. Check it out the
related issue at https://github.com/alexdobin/STAR/issues/686. One way to go
about this is to deinterlace PE-interleaved-FASTQs first and then run
**x.FASTQ** in the dual-file PE default mode.
> * Posts
>    - https://stackoverflow.com/questions/59633038/how-to-split-paired-end-fastq-files
>    - https://www.biostars.org/p/141256/
> * `deinterleave_fastq.sh` on GitHub Gist
>    - https://gist.github.com/nathanhaigh/3521724
> * `seqfu deinterleave`
>    - https://telatin.github.io/seqfu2/tools/deinterleave.html

### On STAR-RSEM Coupling
RSEM, as well as other transcript quantification software, requires reads to be
mapped to transcriptome. For this reason, **x.FASTQ** runs STAR with
`--quantMode TranscriptomeSAM` option to output alignments translated into
transcript coordinates in the `Aligned.toTranscriptome.out.bam` file (in
addition to alignments in genomic coordinates in `Aligned.*.sam/bam` file).

Importantly, **x.FASTQ** runs STAR with `--outSAMtype BAM Unsorted` option,
since if you provide RSEM a sorted BAM, RSEM will assume every read is uniquely
aligned and converge very quickly... but the results are wrong!
(https://groups.google.com/g/rsem-users/c/kwNZESUd0Es)

### On RSEM Quantification
Among quantification tools, the biggest and most meaningful distinction is
between methods that attempt to properly quantify abundance, generally using a
generative statistical model (e.g., *RSEM*, *BitSeq*, *salmon*, etc.), and those
that try to simply count aligned reads (e.g., *HTSeq* and *featureCounts*).
Generally, the former are more accurate than the latter at the gene level and
can also offer transcript-level estimates if desired (while counting-based
methods generally cannot).
(https://github.com/COMBINE-lab/salmon/issues/127)

However, in order to build such a probabilistic model, the **fragment length
distribution** should be known. The fragment length refers to the physical
molecule of D/RNA captured in the library prep stage and (partially!) sequenced
by the sequencer. Using this information, the *effective* transcript lengths can
be estimated, which have an effect on fragment assignment probabilities. With
paired-end reads the fragment length distribution can be learned from the FASTQ
files or the mappings of the reads, but for single-end data this cannot be done,
so it is strongly recommended that the user provide the empirical values via the
`–fragment-length-mean` and `–fragment-length-sd` options. This generally
improves the accuracy of expression level estimates from single-end data, but,
usually, the only way to get this information is through the *BioAnalyzer*
results for the sequencing run. If this is not possible and the fragment length
mean and SD are not provided, RSEM will not take a fragment length distribution
into consideration. Nevertheless, it should be noted that the inference
procedure is somewhat robust to these parameters; maximum likelihood estimates
may change a little, but, in any case, the same distributional values will be
applied in all samples and so, ideally, most results of misspecification will
wash out in subsequent differential analysis.

> Finally, [...] I don’t believe that model misspecification that may result due
to not knowing the fragment length distribution will generally have enough of a
deleterious effect on the probabilistic quantification methods to degrade their
performance to the level of counting based methods. I would still argue to
prefer probabilistic quantification (i.e., *salmon*) to read counting, even if
you don’t know the fragment length distribution. As I mentioned above, it may
change the maximum likelihood estimates a bit, but should do so across all
samples, hopefully minimizing the downstream effects on differential analysis.
>
> Rob Patro
