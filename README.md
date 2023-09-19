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
workflow of the project by making each task persistent after it is launched in
the background on the remote machine.

**x.FASTQ** currently consists of 3 scripts:

> 1. `getFASTQ` to download NGS raw data from ENA (as .fastq.gz);
> 1. `trimFASTQ` to remove adapter sequences from reads;
> 1. `qcFASTQ` for data quality control.

The suite enjoys some internal consistency:

* each **x.FASTQ** script can be invoked from any location on the remote machine
using fully lowercase name
* each script launches in the background a persistent queue of jobs (i.e., main
commands start with `nohup` and end with `&`)
* If the script is successful, each script saves specific logs in the experiment
target directory with the same filename pattern:

`ScriptName_FastqID_DateStamp.log`          sample-based log
`ScriptName_ExperimentID_DateStamp.log`     series-based log

* some flags have common meanings for each script:
    * `-h | --help`
    * `-v | --version`
    * `-q | --quiet`
    * `-p | --progress`
* if `-p` is not followed by any arguments, the script searches the current
directory for log files from which to infer the progress of the last namesake
task
* the `--quiet` option does not print anything on the screen other than any
error messages that stop the execution of the script (fatal error)
* with the `-q` option, if the script is successful, nothing is printed to the
screen, but a log file is saved anyway.

## Installation

clone from GitHub
Create the links somewhere
    cd <install_dir>
    ./x.FASTQ -ml <target>

e.g.,

./x.FASTQ.sh -ml ~/.local/bin/
that usually is already in $PATH

or

./x.FASTQ.sh -ml .
then add <install_dir> to $PATH

install dependencies

dependency check: java, bbduk, fastqc, multiqc, python, (QualiMap, PCA, R) 

java v.7 (or higher) globally installed
BBTools dowloaded and extracted somewhere in the local machine
(X.FASTQ's trimfastq requires installation path to be specified in install_path.txt file, while the standalone trimmer allows the user also to specify a local path runtime)
FastQC downloaded and extracted somewhere in the local machine (installation path needs to be specified in install_path.txt file or, alternatively, fastqc can be made globally visible by making a link in some $PATH folder)

Install and test
[bash]
    # Oracle Java
    yay -Syu jre jdk
    java --version

    # BBTools
    cd ./local/bin
    wget --content-disposition https://sourceforge.net/projects/bbmap/files/BBMap_39.01.tar.gz/download
    tar -xvzf BBMap_39.01.tar.gz
    cd bbmap
    ./stats.sh in=./resources/phix174_ill.ref.fa.gz

    # FastQC
    cd ./local/bin
    wget https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.12.1.zip
    unzip fastqc_v0.12.1.zip
    cd FastQC
    ./fastqc --version
[\bash]


Compile the install_paths.txt

to updated just git pull the repo
(repeat previous step only if new files or new dependencies are added)



Trim
It's best to do adapter-trimming first, then quality-trimming, because if you do quality-trimming first, sometimes adapters will be partially trimmed and become too short to be recognized as adapter sequence. When you run BBDuk with both quality-trimming and adapter-trimming in the same run, it will do adapter-trimming first, then quality-trimming.


Adapter trimming
Quality trimming:
Length filtering:

see in log
Input:                      3790323 reads       102338721 bases.
QTrimmed:                   1920929 reads (50.68%)  32988313 bases (32.23%)
KTrimmed:                   414 reads (0.01%)   11178 bases (0.01%)
Total Removed:              1183293 reads (31.22%)  32999491 bases (32.25%)
Result:                     2607030 reads (68.78%)  69339230 bases (67.75%)


Quality and Length trimming are very conservative...