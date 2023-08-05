# `getfastq.sh` test TARGETS

The two links in this folder point to a couple of samples from the miRNA-Seq
study *Expanding the MicroRNA Targeting Code: A Novel Type of Site with Centered
Pairing* by Shin C. *et al.*

* __GEO IDs__: series `GSE22068` --> samples [`GSM548640`, `GSM548634`]
    https://www.ncbi.nlm.nih.gov/geo/query/acc.cgi?acc=GSE22068

* __ENA IDs__: study `PRJNA128943` --> runs [`SRR058073`, `SRR058069`]
    https://www.ebi.ac.uk/ena/browser/view/PRJNA128943

The two FASTQ (.gz) sample files were chosen for their small size, which allows
the `getfastq` script to be tested in a reasonable amount of time, while still
allowing some minutes to test the progress display options (`-p`).

| ENA Accession | GEO Accession | Size    | Organism       |
| ------------- | ------------- |:-------:| -------------- |
| SRR058073     | GSM548640     | 36.1 MB | _Danio rerio_  |
| SRR058069     | GSM548634     | 86.1 MB | _Homo sapiens_ |

To test the `getfastq.sh` script, just copy and paste the `GSE22068_wgets.sh`
file where you want the FASTQ files to be downloaded and run

```bash
./getfastq.sh "<some_path>"/GSE22068_wgets.sh
```
