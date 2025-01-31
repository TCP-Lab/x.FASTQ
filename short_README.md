# x.FASTQ

___x.FASTQ___ is a suite of __Bash__ wrappers for original and third-party software designed to make RNA-Seq data analysis more accessible and automated.


___x.FASTQ___ provides tools for the entire RNA-Seq data analysis workflow, from raw read retrieval to count matrix generation:

| Module Name     | Performed Task |
| :-------------: | -------------- |
| __getFASTQ__    | downloads NGS raw data in FASTQ format from the [ENA database](https://www.ebi.ac.uk/ena/browser/home) |
| __trimFASTQ__   | performs adapter and quality trimming by running [_BBDuk_](https://jgi.doe.gov/data-and-tools/software-tools/bbtools/) |
| __anqFASTQ__    | aligns reads and quantifies transcript abundance by running [STAR](https://github.com/alexdobin/STAR) and [RSEM](https://github.com/deweylab/RSEM) |
| __qcFASTQ__     | runs quality-control tools, such as [FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/) and [MultiQC](https://multiqc.info/) |
| __tabFASTQ__    | merges counts from multiple samples into a single expression table |
| __metaharvest__ | fetches metadata from [GEO](https://www.ncbi.nlm.nih.gov/geo/) and/or [ENA](https://www.ebi.ac.uk/ena/browser/home) databases |
| __x.FASTQ__     | performs common tasks of general utility (disk usage monitor, dependency report...) |

All modules can be run independently as individual analysis steps.
Alternatively, they can be chained together in a single pipeline to automate the entire workflow.





Each ___x.FASTQ___ module is a CLI-executable Bash command with a `--help` option that provides extensive documentation.


Full documentation can be found in `docs` folder.

