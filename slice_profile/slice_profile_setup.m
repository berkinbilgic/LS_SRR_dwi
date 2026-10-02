function prof = slice_profile_setup(opt)
% function prof = slice_profile_setup(opt)
%
% Depth-layer slice-profile weights, same variables and rule as
% get_psf_weights_from_slice_profile() in
% 1-ROVER_MRI-main/rover_b0_hash_prisma_v3_tcnn_relu_charb_tv_sliceprofile.py:
%
%   z_i = spa_res * (i - (M-1)/2),  i = 0..M-1     (M = super_resolution)
%   w_i = max(interp(z_i, z_mm, Mse_slr), 0),  w = w / sum(w)
%
% opt.weight_mode      : 'equal' (w_i = 1/M) or 'sliceprofile'
% opt.rf_profile_mat   : .mat with z_mm and Mse_slr (default: the bundled
%                        rf_profile_tbwp4.mat, the profile used for the Prisma data)
% opt.super_resolution : M, number of depth layers (default 13)
% opt.spa_res          : layer spacing along the slice normal, mm (default 0.78125)
% opt.slice_thickness_mm : nominal slice thickness, logging only (default 10)
% opt.K                : hr-pixel sub-samples per axis when building h2l (default 16)
%
% In LS-SRR, layer i is the strip |u - z_i| <= spa_res/2 around the lr slice
% centre and carries weight M*w_i, so 'equal' is a box of width M*spa_res.

if nargin < 1, opt = struct; end
opt = msf_ensure_field(opt, 'weight_mode', 'sliceprofile');
opt = msf_ensure_field(opt, 'rf_profile_mat', fullfile(fileparts(mfilename('fullpath')), 'rf_profile_tbwp4.mat'));
opt = msf_ensure_field(opt, 'super_resolution', 13);
opt = msf_ensure_field(opt, 'spa_res', 0.78125);
opt = msf_ensure_field(opt, 'slice_thickness_mm', 10);
opt = msf_ensure_field(opt, 'K', 16);

M = opt.super_resolution;
z_layer_mm = opt.spa_res * ((0:M-1) - (M-1)/2);

switch opt.weight_mode
    case 'equal'
        weights = ones(1, M) / M;
    case 'sliceprofile'
        data = load(opt.rf_profile_mat);
        z_mm = double(data.z_mm(:));
        Mse_slr = double(data.Mse_slr(:, 1));
        profile_at_layers = max(interp1(z_mm, Mse_slr, z_layer_mm, 'linear', 'extrap'), 0);
        if sum(profile_at_layers) <= 0
            error('slice_profile_setup:empty', 'Slice profile sum is non-positive after interpolation.');
        end
        weights = profile_at_layers / sum(profile_at_layers);
    otherwise
        error('slice_profile_setup:mode', 'weight_mode must be ''equal'' or ''sliceprofile''.');
end

prof = opt;
prof.z_layer_mm = z_layer_mm;
prof.weights = weights;
prof.support_mm = (z_layer_mm(end) + opt.spa_res/2);
prof.tag = sprintf('%s_M%d_res%.5g', opt.weight_mode, M, opt.spa_res);

fprintf('PSF weighting mode : %s, M = %d, spa_res = %.5g mm (span %.2f mm, nominal slice %.3g mm)\n', ...
    opt.weight_mode, M, opt.spa_res, M * opt.spa_res, opt.slice_thickness_mm);
for i = 1:M
    fprintf('  layer %2d  z = %+6.2f mm   weight = %.6f\n', i, z_layer_mm(i), weights(i));
end
fprintf('  Sum = %.8f\n', sum(weights));
end
