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

## Slice-profile correction (rotating-view Prisma dMRI)

`slice_profile/` adds an RF slice profile to the LS-SRR forward operator, and `Vis_NIMG_2021-main/srr_s_recon_QL_batched.m` reconstructs with it. `script_example_siemens_prisma_sliceprofile.m` runs the 20-view (or 13-view) Prisma PA b0 + AP dwi data with `model = 'box'` (no correction) or `model = 'sliceprofile_M13'`.

### Model

For one coronal plane and view `v`, the measured low-resolution image is `y_v = A_v x`. The existing operator uses the overlap fraction of each high-resolution pixel `h` with low-resolution voxel `l`, which is a box along the slice direction:

```text
A_v(l, h) = |pixel_h ∩ voxel_l| / |pixel_h|
```

With a slice profile the in-plane box is kept and the through-plane box is replaced by a weight `w(u)`, where `u` is the distance from the centre of slice `l` along view `v`'s slice normal:

```text
A_v(l, h) = (1/|pixel_h|) ∫_pixel_h 1[r in column of l] · w(u_l(r)) dr
```

`w` uses the same variables and rule as the INR (ROVER) slice-profile loss, `get_psf_weights_from_slice_profile` in `rover_b0_hash_prisma_v3_tcnn_relu_charb_tv_sliceprofile.py`:

```text
z_i = spa_res · (i − (M − 1)/2),  i = 0 … M−1          (M = super_resolution)
w_i = max(interp(z_i, z_mm, Mse_slr), 0) / Σ_i w_i
w(u) = M · w_i   for |u − z_i| ≤ spa_res/2
```

`weight_mode = 'equal'` gives `w_i = 1/M`, a box `M · spa_res` wide. The integral is evaluated by supersampling each high-resolution pixel `K × K` times (`K = 16`); with a box profile this reproduces `srr_h2l_from_header` to about 1% (`slice_profile/test_h2l_profile_box.m`). The solver is unchanged: `((1−λ) AᵀA + λ · aspect · N · I) x = Aᵀ y`, factorized once and solved in batches.

Per-view slice-profile operators are cached under `opt.h2l_cache_dir`, keyed by the profile settings, never next to the input data. Keep `opt.hr_ref_fn` on the same view for every run: the cached box `*_h2l.mat` operators are reused by file existence only and refer to the high-resolution grid they were built on.

### Slice-profile files

| File | Role |
|---|---|
| **`slice_profile/rf_profile_tbwp4.mat`** | **The profile used for the Prisma reconstructions** (default of `slice_profile_setup`). 10 mm slice, TBWP 4 SLR, 3 ms excitation, 5 ms refocusing; spin-echo profile `Mse_slr` (excitation × refocusing), FWHM 8 mm, sampled on `z_mm` = −50 … 50 mm. |
| `slice_profile/rf_pulse_simulation_QL_v3.m` | Bloch simulation used to generate slice profiles and depth-layer weights (requires Pulseq MATLAB). As committed it simulates a 6 mm, 3 ms sinc 90° excitation (`Mxy_sinc`) and writes `rf_slice_profile_exc_sinc_6mm_3ms.mat`; it is not the exact script that produced `rf_profile_tbwp4.mat`. |

### Settings used (`sliceprofile_M13`)

| Variable | Value |
|---|---|
| `weight_mode` | `'sliceprofile'` |
| `rf_profile_mat` | `slice_profile/rf_profile_tbwp4.mat` |
| `super_resolution` (M) | 13 |
| `spa_res` | 0.78125 mm (13 layers span 10.16 mm) |
| `lambda` | 0.05 |

Known behaviour: with an even number of slices (20) the rotation axis lies on a slice boundary in every view, where the TBWP 4 profile is low (about 0.27 of peak). Sensitivity along that line falls about 10× below the median, and the identity regularizer darkens it, which shows as a band in sagittal and coronal views.

## Licensing

Project code, `mosaic.m`, and the bundled phantom data are distributed under the repository [MIT License](LICENSE). The files in `third_party/freesurfer_matlab` are an unmodified NIfTI-only subset of FreeSurfer 6.0.0 and remain subject to the included FreeSurfer Software License Agreement; see [their redistribution notice](third_party/freesurfer_matlab/README.md).

The phantom files contain no in-vivo or participant data. Their provenance and SHA-256 checksums are documented in `example_data/ep2d_12view_phantom`.

## Earlier examples

The original PA/AP entry points remain available as `example_cima_QL_v0.m` and `example_cima_QL_v1.m`.

Qiang Liu — qliu30@mgh.harvard.edu
