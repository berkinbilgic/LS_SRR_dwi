% Check: the supersampled slice-profile operator with a box profile
% ('equal' weights, M*spa_res = slice thickness) reproduces the polygon-overlap
% h2l from srr_h2l_from_header. Pass any lr NIfTI views as nii_fns.
%
% e.g.  nii_fns = {'view_1.nii', 'view_5.nii'}; test_h2l_profile_box

h_hr = srr_hr_header_from_lr(mdm_nii_read_header(nii_fns{1}));
for v = 1:numel(nii_fns)
    h_lr = mdm_nii_read_header(nii_fns{v});
    M = 13;
    prof = slice_profile_setup(struct('weight_mode', 'equal', 'super_resolution', M, ...
        'spa_res', double(h_lr.pixdim(4)) / M, 'K', 16));
    A = srr_h2l_profile_from_header(h_lr, h_hr, prof);
    B = srr_h2l_from_header(h_lr, h_hr, struct('present', 1));
    fprintf('%s: rel Frobenius diff %.4f, mean column sum %.3f vs %.3f\n', nii_fns{v}, ...
        norm(A - B, 'fro') / norm(B, 'fro'), full(mean(sum(A, 1))), full(mean(sum(B, 1))));
end
