function s_out = srr_s_recon_batched(s, o_dir, o_fn, opt)
% function s_out = srr_s_recon_batched(s, o_dir, o_fn, opt)
%
% Reconstructs multiple low-resolution datasets into one high-resolution
% dataset. The regularized normal matrix is factorized once, and multiple
% slice/measurement right-hand sides are solved in configurable batches.

nii_fn_out = [o_dir filesep o_fn];

if nargin < 4
    opt.present = 1;
end
opt = srr_opt(opt);
opt = msf_ensure_field(opt, 'rhs_batch_size', 32);
validate_rhs_batch_size(opt.rhs_batch_size);

% get hr header from first lr image
h_lr = mdm_nii_read_header(s{1}.nii_fn);
h_hr = srr_hr_header_from_lr(h_lr);

% create h2l operator
h2l = srr_h2l_from_s(s, h_hr, opt);

n_ims = length(s);
aspect = h_lr.pixdim(4) / h_lr.pixdim(2);
n_elem = h_lr.dim(2) * h_lr.dim(4);

hr_size4d = floor(h_hr.dim(2:5)');
hr_size3d = hr_size4d([1 2 3]);
hr_size2d = hr_size4d([1 3]);

% read in nii
I = cell(1, n_ims);
for n = 1:n_ims
    [I{n}, ~] = mdm_nii_read(s{n}.nii_fn);
end

if opt.meas_ind == -1
    meas_ind = 1:h_hr.dim(5);
else
    meas_ind = opt.meas_ind;
end

if opt.slice_ind == -1
    slice_ind = 1:h_hr.dim(3);
else
    slice_ind = opt.slice_ind;
end

% Reconstruct selected volumes and coronal slices. Jobs are ordered with
% slices varying fastest, matching the loop order in srr_s_recon.
hr_out = zeros(hr_size4d);
n_slices = numel(slice_ind);
n_jobs = numel(meas_ind) * n_slices;

if n_jobs > 0
    normal_matrix = build_normal_matrix(h2l, opt.lambda, aspect, n_ims);
    solver = build_reusable_solver(normal_matrix);
    clear normal_matrix
    batch_size = min(opt.rhs_batch_size, n_jobs);

    for batch_start = 1:batch_size:n_jobs
        batch_end = min(batch_start + batch_size - 1, n_jobs);
        job_ind = batch_start:batch_end;
        n_batch_jobs = numel(job_ind);
        lr_batch = zeros(n_elem * n_ims, n_batch_jobs);

        for batch_column = 1:n_batch_jobs
            current_job = job_ind(batch_column);
            meas_position = floor((current_job - 1) / n_slices) + 1;
            slice_position = mod(current_job - 1, n_slices) + 1;
            meas_index = meas_ind(meas_position);
            slice_index = slice_ind(slice_position);

            for n = 1:n_ims
                row_start = (n - 1) * n_elem + 1;
                row_end = n * n_elem;
                lr_image = double(squeeze(I{n}(:, slice_index, :, meas_index)));
                lr_batch(row_start:row_end, batch_column) = lr_image(:);
            end
        end

        fprintf('Reconstructing jobs %d-%d out of %d\n', batch_start, batch_end, n_jobs);
        normal_rhs_batch = h2l.' * lr_batch;
        clear lr_batch
        hr_batch = solver \ normal_rhs_batch;
        clear normal_rhs_batch

        for batch_column = 1:n_batch_jobs
            current_job = job_ind(batch_column);
            meas_position = floor((current_job - 1) / n_slices) + 1;
            slice_position = mod(current_job - 1, n_slices) + 1;
            meas_index = meas_ind(meas_position);
            slice_index = slice_ind(slice_position);
            reconstructed_slice = reshape(hr_batch(:, batch_column), [hr_size2d(1) 1 hr_size2d(2)]);
            hr_out(:, slice_index, :, meas_index) = reconstructed_slice;
        end
    end
end

% write output nifti
mdm_nii_write(single(hr_out), nii_fn_out, h_hr);

% save merged h2l
h2l_fn_out = srr_h2l_fn_from_nii_fn(nii_fn_out);
save(h2l_fn_out, 'h2l', 'n_ims');

s_out = mdm_s_from_nii(nii_fn_out);

% save lr image on hr grid
if opt.savelonh == 1
    for n = 1:n_ims
        [I_single, ~] = mdm_nii_read(s{n}.nii_fn);
        lonh = zeros(hr_size3d);
        h2lstruct = load(srr_h2l_fn_from_nii_fn(s{n}.nii_fn));
        h2l_single = h2lstruct.h2l;
        for i = meas_ind
            tmp2 = zeros(hr_size3d);
            for j = slice_ind
                lr_im = squeeze(double(I_single(:, j, :, i)));
                lr_c = h2l_single' * lr_im(:);
                tmp2(:, j, :) = reshape(lr_c, hr_size2d);
            end
            lonh(:, :, :, i) = tmp2;
        end
        niilr_name = [o_dir filesep sprintf('lonh_rot%d.nii.gz', n)];
        mdm_nii_write(single(lonh), niilr_name, h_hr);
    end
end
end

function normal_matrix = build_normal_matrix(h2l, lambda, aspect, n_ims)
data_term = (1 - lambda) * (h2l.' * h2l);
regularization_scale = lambda * aspect * n_ims;
regularizer = regularization_scale * speye(size(h2l, 2));
normal_matrix = data_term + regularizer;
end

function solver = build_reusable_solver(normal_matrix)
try
    solver = decomposition(normal_matrix, 'chol');
catch chol_exception
    fallback_message = 'Cholesky decomposition was unsuitable (%s). Using MATLAB automatic decomposition instead.';
    warning('srr_s_recon_batched:CholeskyFallback', fallback_message, chol_exception.message);
    solver = decomposition(normal_matrix);
end
end

function validate_rhs_batch_size(rhs_batch_size)
is_valid_scalar = isnumeric(rhs_batch_size) && isreal(rhs_batch_size) && isscalar(rhs_batch_size);
is_valid_value = is_valid_scalar && isfinite(rhs_batch_size) && rhs_batch_size >= 1;
is_valid_integer = is_valid_value && rhs_batch_size == floor(rhs_batch_size);
if ~is_valid_integer
    error('srr_s_recon_batched:InvalidBatchSize', 'opt.rhs_batch_size must be a positive integer scalar.');
end
end
