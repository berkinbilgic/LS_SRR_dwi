function s_out = srr_s_recon_QL_batched(s, s1, o_dir, o_fn, opt)
% function s_out = srr_s_recon_QL_batched(s, s1, o_dir, o_fn, opt)
%
% Batched version of srr_s_recon_QL: the h2l operator (geometry) is built
% from the headers of s (e.g. PA b0 NII_reset), while the data that is
% reconstructed is read from s1 (e.g. AP dwi). The regularized normal
% matrix is factorized once (Cholesky) and all slice/volume right-hand
% sides are solved in batches of opt.rhs_batch_size.
%
% opt.rot_views : indices (into s1) of views whose data is rotated by
%                 rot90(., opt.rot_k) before recon (default: none)
% opt.rot_k     : rot90 multiplier (default -1)
% opt.hr_ref_fn : nii whose header defines the hr grid (default s{1}); keep it
%                 at the view the cached *_h2l.mat operators were built for
% opt.slice_profile : struct from slice_profile_setup(); when set, the h2l
%                 operator uses that through-plane weighting instead of the
%                 box overlap (cached in opt.h2l_cache_dir)

nii_fn_out = [o_dir filesep o_fn];

if nargin < 5
    opt.present = 1;
end
opt = srr_opt(opt);
opt = msf_ensure_field(opt, 'rhs_batch_size', 32);
opt = msf_ensure_field(opt, 'rot_views', []);
opt = msf_ensure_field(opt, 'rot_k', -1);
opt = msf_ensure_field(opt, 'slice_profile', []);
opt = msf_ensure_field(opt, 'h2l_cache_dir', fullfile(o_dir, 'h2l_cache'));
opt = msf_ensure_field(opt, 'hr_ref_fn', s{1}.nii_fn);

% hr header from first lr (geometry) image, 4D size from data images
h_lr = mdm_nii_read_header(opt.hr_ref_fn);
h_hr = srr_hr_header_from_lr(h_lr);

h_lr_ap = mdm_nii_read_header(s1{1}.nii_fn);
h_hr_ap = srr_hr_header_from_lr(h_lr_ap);

t_h2l = tic;
if isempty(opt.slice_profile)
    h2l = srr_h2l_from_s(s, h_hr, opt);
else
    h2l_views = srr_h2l_profile_views(s, h_hr, opt.slice_profile, opt.h2l_cache_dir);
    h2l = vertcat(h2l_views{:});
    clear h2l_views
end
fprintf('h2l ready: %.1f s\n', toc(t_h2l));

n_ims = length(s);
aspect = h_lr.pixdim(4) / h_lr.pixdim(2);
n_elem = h_lr.dim(2) * h_lr.dim(4);

hr_size4d = floor(h_hr_ap.dim(2:5)');
hr_size2d = hr_size4d([1 3]);

if opt.meas_ind == -1
    meas_ind = 1:h_hr_ap.dim(5);
else
    meas_ind = opt.meas_ind;
end

if opt.slice_ind == -1
    slice_ind = 1:h_hr_ap.dim(3);
else
    slice_ind = opt.slice_ind;
end

% read in data nii, keep only the requested volumes
I = cell(1, n_ims);
for n = 1:n_ims
    [tmp, ~] = mdm_nii_read(s1{n}.nii_fn);
    tmp = tmp(:, :, :, meas_ind);
    if ismember(n, opt.rot_views)
        tmp = rot90(tmp, opt.rot_k);
    end
    I{n} = tmp;
end
clear tmp

hr_out = zeros([hr_size4d(1:3) numel(meas_ind)]);
n_slices = numel(slice_ind);
n_jobs = numel(meas_ind) * n_slices;

t_fact = tic;
normal_matrix = (1 - opt.lambda) * (h2l.' * h2l) + ...
    (opt.lambda * aspect * n_ims) * speye(size(h2l, 2));
try
    solver = decomposition(normal_matrix, 'chol');
catch chol_exception
    warning('srr_s_recon_QL_batched:CholeskyFallback', ...
        'Cholesky unsuitable (%s), using automatic decomposition.', chol_exception.message);
    solver = decomposition(normal_matrix);
end
clear normal_matrix
fprintf('Normal matrix + factorization: %.1f s\n', toc(t_fact));

t_solve = tic;
batch_size = min(opt.rhs_batch_size, n_jobs);
for batch_start = 1:batch_size:n_jobs
    batch_end = min(batch_start + batch_size - 1, n_jobs);
    job_ind = batch_start:batch_end;
    lr_batch = zeros(n_elem * n_ims, numel(job_ind));

    for k = 1:numel(job_ind)
        meas_pos = floor((job_ind(k) - 1) / n_slices) + 1;
        slice_index = slice_ind(mod(job_ind(k) - 1, n_slices) + 1);
        for n = 1:n_ims
            lr_image = double(squeeze(I{n}(:, slice_index, :, meas_pos)));
            lr_batch((n - 1) * n_elem + 1 : n * n_elem, k) = lr_image(:);
        end
    end

    fprintf('Reconstructing jobs %d-%d out of %d\n', batch_start, batch_end, n_jobs);
    hr_batch = solver \ (h2l.' * lr_batch);

    for k = 1:numel(job_ind)
        meas_pos = floor((job_ind(k) - 1) / n_slices) + 1;
        slice_index = slice_ind(mod(job_ind(k) - 1, n_slices) + 1);
        hr_out(:, slice_index, :, meas_pos) = reshape(hr_batch(:, k), [hr_size2d(1) 1 hr_size2d(2)]);
    end
end
fprintf('Solve: %.1f s\n', toc(t_solve));

% write output nifti (only the reconstructed volumes)
mdm_nii_write(single(hr_out), nii_fn_out, h_hr);

h2l_fn_out = srr_h2l_fn_from_nii_fn(nii_fn_out);
save(h2l_fn_out, 'h2l', 'n_ims');

s_out = mdm_s_from_nii(nii_fn_out);
end
