# LS_SRR_dwi

MATLAB code and a public phantom example for least-squares super-resolution reconstruction (LS-SRR) of multi-view diffusion MRI. The reconstruction code originated in [Vis_NIMG_2021](https://github.com/filip-szczepankiewicz/Vis_NIMG_2021/).

## 12-view phantom example

The repository includes twelve unmodified `310 x 310 x 28` INT16 NIfTI acquisitions in `example_data/ep2d_12view_phantom/nii`. By default, `script_example_cima_QL_ep2d_batch_12view.m` selects the six odd-numbered views (`1:2:12`), retains the established view 5-9 preprocessing, creates phantom-specific high-to-low-resolution (`h2l`) operators from the NIfTI headers, and reconstructs a `310 x 310 x 224` volume with `lambda = 0.05` and `rhs_batch_size = 32`.

Run from MATLAB:

```matlab
run('script_example_cima_QL_ep2d_batch_12view.m')
```

The script resolves all paths from its own location. It requires MATLAB with sparse matrices and `decomposition`; no centrally installed FreeSurfer tree is required. The bundled `mosaic.m` only requires Image Processing Toolbox when its optional nonzero rotation argument is used.

Generated preprocessing files, per-view `h2l` operators, diagnostics, and reconstruction products are written beneath `work/`, which is ignored by Git. The default reconstruction is:

```text
work/ep2d_12view_phantom/SRR_out_views2use_6/1/srr_direction_1_la0.05.nii.gz
```

Per-view `h2l` operators are computed automatically when missing and, by default, reused on subsequent runs. Reuse is determined only by the existence of the corresponding `*_h2l.mat` file; the cached operator is not checked against the current NIfTI header geometry. If preprocessing or geometry changes, regenerate the operators before reconstruction by setting `opt_srr.use_existing_h2l = 0` in the example script for that run.

No precomputed transforms or reconstruction outputs are committed.

### Output geometry compatibility note

The existing writer behavior is intentionally preserved for reproducibility: the reconstruction's qform reports the isotropic reconstructed spacing (approximately `0.748387 mm` through-plane), while its sform retains the source `6 mm` slice scaling. Consumers of the reconstructed NIfTI should use the qform. This known mismatch has not been silently corrected because doing so would change established output-header behavior.

## Licensing

Project code, `mosaic.m`, and the bundled phantom data are distributed under the repository [MIT License](LICENSE). The files in `third_party/freesurfer_matlab` are an unmodified NIfTI-only subset of FreeSurfer 6.0.0 and remain subject to the included FreeSurfer Software License Agreement; see [their redistribution notice](third_party/freesurfer_matlab/README.md).

The phantom files contain no in-vivo or participant data. Their provenance and SHA-256 checksums are documented in `example_data/ep2d_12view_phantom`.

## Earlier examples

The original PA/AP entry points remain available as `example_cima_QL_v0.m` and `example_cima_QL_v1.m`.

Qiang Liu — qliu30@mgh.harvard.edu
