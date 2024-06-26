# `x.FASTQ/test` folder
The files in this folder allow the developer to test most of the ___x.FASTQ___
modules. Specifically, the `GSE22068` series allows testing the __getFASTQ__,
__trimFASTQ__, and __qcFASTQ__ modules (limited to the _FastQC_ and _MultiQC_
options), while the `GSE205739` series allows testing the __countFASTQ__ module
(and possibly the _PCA_ option of __qcFASTQ__), effectively bypassing the often
time- and resource-prohibitive alignment and quantification step. However, for
testing the __anqFASTQ__ module, the use of a server of adequate performance is
unavoidable. In contrast, the remaining __x.FASTQ__ and __metaharvest__ modules
are easily self-tested without any support files.

## `GSE22068` series
The `GSE22068_wgets.sh` file can be used as `TARGETS` argument for testing the
__getFASTQ__ module and downloading some lightweight FASTQ files from the
__ENA Database__, which can be used in turn as input to __trimFASTQ__ and
__qcFASTQ__ modules for further testing.

In particular, the two links provided in the `GSE22068_wgets.sh` file point to a
couple of samples from a 2010 miRNA-Seq study, titled *Expanding the MicroRNA
Targeting Code: A Novel Type of Site with Centered Pairing* by Shin C. *et al.*
([PMID: 20620952](https://pubmed.ncbi.nlm.nih.gov/20620952/),
DOI: 10.1016/j.molcel.2010.06.005)

* __GEO IDs__: series `GSE22068` --> samples [`GSM548640`, `GSM548634`]
    https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE22068

* __ENA IDs__: study `PRJNA128943` --> runs [`SRR058073`, `SRR058069`]
    https://www.ebi.ac.uk/ena/browser/view/PRJNA128943

The two FASTQ (.gz) example files were chosen for their small size, which allows
the developer to test __getFASTQ__ features in a reasonable amount of time,
while still leaving a few minutes to try out the progress option (`-p`).

| ENA Accession | GEO Accession | Size    | Organism       |
| ------------- | ------------- |:-------:| -------------- |
| SRR058073     | GSM548640     | 36.1 MB | _Danio rerio_  |
| SRR058069     | GSM548634     | 86.1 MB | _Homo sapiens_ |

To test the `getfastq.sh` script, just copy and paste the `GSE22068_wgets.sh`
file where you want the FASTQ files to be downloaded (`<some_path>`) and run
some of these:
```bash
cd "<some_path>"
getfastq GSE22068_wgets.sh
getfastq -m GSE22068_wgets.sh
getfastq -k
getfastq -p
```
provided that ___x.FASTQ___ modules have already been made globally visible (see
`x.fastq --links` option).

## `GSE205739` series
The `GSE205739_Counts` folder contains the first 100 lines of _all the counts
files_ generated by a standard ___x.FASTQ___ workflow applied to four FASTQ
pairs representing the four control samples of a 2022 study by Miao _et al._, in
which the authors performed a transcriptomic analysis of hCMEC/D3 cells.
Specifically, FASTQ files were downloaded (`getfastq GSE205739_wgets.sh`),
trimmed, aligned, and quantified (using `trimfastq` and `anqfastq`,
respectively). Results saved within the `Counts` subfolder were then cut down to
their first 100 lines using the `cutter.sh` script (also included here within
the test subfolder) to make following tests faster and avoid burdening the
GitHub repository.

Now, to test the __countFASTQ__ module, just copy and paste the
`GSE205739_Counts` folder somewhere locally (`<some_path>`) and run some of
these:
```bash
cd "<some_path>"/GSE205739_Counts
countfastq .
countfastq -n .
countfastq -n -i .
countfastq -n -i --design="(A A B B)" --metric=FPKM .
countfastq -p
```
then, you can also test the `PCA` option of the __qcFASTQ__ module through
```bash
qcfastq --tool=PCA .
```
again, provided that ___x.FASTQ___ modules have already been made globally
visible (see `x.fastq --links` option).
