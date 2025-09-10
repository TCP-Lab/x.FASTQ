# Exit Code Reference Table

| Code	| Meaning |
| :---: | ------- |
| 0		| Success exit code |
| Direct object errors ||
| 1		| Missing target argument |
| 2		| Invalid target argument |
| Adverbial phrase errors ||
| 3		| Missing option flag |
| 4		| Invalid option flag |
| 5		| Missing input value |
| 6		| Invalid input value |
| 7		| Bad value assignment |
| Local system issues ||
| 11	| Missing component (software or data) |
| 12	| Multiple instances running |
| 13	| Overwriting prevention |
| 14	| Unsupported feature |
| 15	| File(s) not found |
| Remote system issues ||
| 21	| GEO-ENA ID conversion failure |
| Internal errors ||
| 101	| Internal error: invalid target type to `_check_target ()` |
| 102	| Internal error: invalid feature to `_get_qc_tools ()` or `_get_seq_sw ()` |
| 103	| Internal error: invalid software name to `_name2cmd ()` |
| 255	| Unexpected error caught by `_interceptor ()` |
