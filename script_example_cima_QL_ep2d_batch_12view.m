% Reconstruct the bundled 12-view phantom acquisition with LS-SRR.

clear

repo_dir = fileparts(mfilename('fullpath'));
data_dir_R3 = fullfile(repo_dir, 'example_data', 'ep2d_12view_phantom', 'nii');
work_dir = fullfile(repo_dir, 'work', 'ep2d_12view_phantom');

addpath(repo_dir);
addpath(fullfile(repo_dir, 'third_party', 'freesurfer_matlab'));
addpath(genpath(fullfile(repo_dir, 'md-dmri-master')));
addpath(genpath(fullfile(repo_dir, 'Vis_NIMG_2021-main')));

num_all_views = 12;
views2use = 1:2:12;
num_views2use = length(views2use);

input_files = dir(fullfile(data_dir_R3, '*.nii'));
if numel(input_files) ~= num_all_views
    error('Expected %d phantom NIfTI inputs in %s, but found %d.', num_all_views, data_dir_R3, numel(input_files));
end

for view_idx = views2use
    input_name = fn_find_view_nii(data_dir_R3, view_idx);
    input_nii = MRIread(input_name);
    mosaic(input_nii.vol, 4, 7, 100 + view_idx, '', [0, 3e2]);
end

% Preprocess the PA volume. Views 5-9 retain the acquisition-specific
% permutation, flip, and header update used by the original workflow.
data_dir = data_dir_R3;
dir2use = 1;
out_nii_dir = fullfile(work_dir, sprintf('nii_out_%d', dir2use));
script_change_nii_QL_v9_msepi_b1k_views2use

nii_fn_cell = cell(1, num_views2use);
for view_position = 1:num_views2use
    view_idx = views2use(view_position);
    nii_fn_cell{view_position} = fullfile(out_nii_dir, sprintf('view_%d.nii', view_idx));
end

bdelta = 1;
s = cell(1, numel(nii_fn_cell));
for view_position = 1:numel(nii_fn_cell)
    s{view_position} = mdm_s_from_nii(nii_fn_cell{view_position}, bdelta);
end

% No precomputed transforms are bundled. srr_s_recon_batched generates a
% phantom-specific h2l operator beside each preprocessed input on first run.
srr_dir_name = sprintf('SRR_out_views2use_%d', num_views2use);
out_srr_dir = fullfile(work_dir, srr_dir_name, num2str(dir2use));
if ~exist(out_srr_dir, 'dir')
    mkdir(out_srr_dir);
end

opt_srr.lambda = 0.05;
opt_srr.rhs_batch_size = 32;
out_srr_fn = sprintf('srr_direction_%d_la%.5g.nii.gz', dir2use, opt_srr.lambda);

tic
s_out = srr_s_recon_batched(s, out_srr_dir, out_srr_fn, opt_srr);
toc
