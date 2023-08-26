# x.FASTQ

```
$ xfastq    _____ _    ____ _____ ___   
    __  __ |  ___/ \  / ___|_   _/ _ \ 
    \ \/ / | |_ / _ \ \___ \ | || | | |
     >  < _|  _/ ___ \ ___) || || |_| |
    /_/\_(_)_|/_/   \_\____/ |_| \__\_\
        ...a part of the Endothelion project
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

`ScriptName_FastqID_DateStamp.log`
`ScriptName_ExperimentID_DateStamp.log`

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
