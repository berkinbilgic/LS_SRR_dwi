% LS-SRR of rotating-view Siemens Prisma dMRI (PA b0 + AP dwi) with and
% without slice-profile correction of the forward operator.
%
% Geometry (h2l) comes from the preprocessed PA b0 headers (NII_reset), data
% from the raw AP dwi. PA views 7-15 were permuted+flipped in preprocessing,
% so the matching raw AP views are rotated by rot90(., -1) before recon.
%
% Set before running (defaults below):
%   model : 'box' (no correction) or 'sliceprofile_M13'
%   views : 1-based view numbers, e.g. 1:20 or [2,4,6,7,8,10,11,12,14,16,17,18,20]
% e.g.  matlab -batch "model='sliceprofile_M13'; views=1:20; script_example_siemens_prisma_sliceprofile"
%
% Qiang Liu

if ~exist('model', 'var'), model = 'sliceprofile_M13'; end
if ~exist('views', 'var'), views = 1:20; end

repo_dir = fileparts(mfilename('fullpath'));
addpath(repo_dir);
addpath(fullfile(repo_dir, 'third_party', 'freesurfer_matlab'));
addpath(genpath(fullfile(repo_dir, 'md-dmri-master')));
addpath(genpath(fullfile(repo_dir, 'Vis_NIMG_2021-main')));
addpath(fullfile(repo_dir, 'slice_profile'));

%% data (edit for your site)
data_dir   = '/scratch/home/ql087/data_bwh/prisma_data/nii_10_02/pa/NII_reset/';
com_str    = '2025_10_02_bwh_invivo_Diffusion_SMS2_R3_PA_30dir_';
base_dir   = '/scratch/home/ql087/data_bwh/prisma_data/nii_10_02/ap/';
com_str_ap = '2025_10_02_bwh_invivo_Diffusion_SMS2_R3_AP_30dir_';
out_dir    = fullfile(repo_dir, 'work', 'prisma_sliceprofile');
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

nv = numel(views);
s = cell(1, nv); s_ap = cell(1, nv);
for j = 1:nv
    i = views(j);
    s{j} = mdm_s_from_nii(fullfile(data_dir, [com_str, num2str(i-1), '.nii']), 1);
    files = dir([base_dir, com_str_ap, num2str(i-1), '_*.nii']);
    s_ap{j} = mdm_s_from_nii(fullfile(files(1).folder, files(1).name), 1);
end

%% options
% hr grid always from view 1: the cached box *_h2l.mat next to the PA inputs
% are reused by file existence only, so they must all refer to one hr grid
opt = struct('lambda', 0.05, 'rhs_batch_size', 256, ...
    'hr_ref_fn', fullfile(data_dir, [com_str, '0.nii']), ...
    'h2l_cache_dir', fullfile(out_dir, 'h2l_cache'));
switch model
    case 'box'
        % existing polygon-overlap operator (no slice-profile correction)
    case 'sliceprofile_M13'
        % same variables as the INR (ROVER) slice-profile loss
        opt.slice_profile = slice_profile_setup(struct( ...
            'weight_mode', 'sliceprofile', ...
            'rf_profile_mat', fullfile(repo_dir, 'slice_profile', 'rf_profile_tbwp4.mat'), ...
            'super_resolution', 13, ...
            'spa_res', 0.78125, ...
            'slice_thickness_mm', 10));
    otherwise
        error('unknown model %s', model);
end

%% PA b0
t = tic;
srr_s_recon_QL_batched(s, s, out_dir, sprintf('srr_pa_b0_%dviews_%s_la%.5g.nii.gz', nv, model, opt.lambda), opt);
fprintf('[%s] PA b0 done: %.1f s\n', model, toc(t));

%% AP, all volumes
t = tic;
opt_ap = opt; opt_ap.meas_ind = -1; opt_ap.rot_k = -1;
opt_ap.rot_views = find(ismember(views, 7:15));   % positions of original views 7-15 in this subset
srr_s_recon_QL_batched(s, s_ap, out_dir, sprintf('srr_ap_%dviews_%s_la%.5g.nii.gz', nv, model, opt.lambda), opt_ap);
fprintf('[%s] AP done: %.1f s\n', model, toc(t));
