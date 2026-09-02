# EP2D 12-view phantom data

This directory contains twelve unmodified NIfTI inputs acquired from an MRI phantom on 2026-08-06, with exactly one file for each view 1-12. Every input is `310 x 310 x 28`, stored as INT16, and has qform and sform codes set to 1.

The files are the raw inputs to the public example. Preprocessed NIfTIs, `h2l` operators, diagnostics, and reconstructions are generated beneath the repository's ignored `work/` directory.

The phantom data contain no in-vivo or participant data and are distributed under the repository's MIT License. `SHA256SUMS` records the source checksums so copied files can be verified byte-for-byte:

```bash
cd example_data/ep2d_12view_phantom/nii
sha256sum -c ../SHA256SUMS
```
