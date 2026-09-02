% Preprocess selected views from the 12-rotation Cima acquisition.
% Views 5-9 require the acquisition-specific permutation and flip.

if ~exist('data_dir', 'var') || ~exist('out_nii_dir', 'var') || ~exist('views2use', 'var')
    error('Define data_dir, out_nii_dir, and views2use before running this script.');
end

if ~exist(out_nii_dir, 'dir')
    mkdir(out_nii_dir);
    fprintf('Created output folder: %s\n', out_nii_dir);
end

unchanged_views = [1:4, 10:12];
for view_idx = unchanged_views
    if ismember(view_idx, views2use)
        input_name = fn_find_view_nii(data_dir, view_idx);
        output_name = fullfile(out_nii_dir, sprintf('view_%d.nii', view_idx));
        input_nii = MRIread(input_name);
        MRIwrite(input_nii, output_name);
        fprintf('Copied view %d -> %s\n', view_idx, output_name);
    end
end

for view_idx = 5:9
    if ismember(view_idx, views2use)
        input_name = fn_find_view_nii(data_dir, view_idx);
        output_name = fullfile(out_nii_dir, sprintf('view_%d.nii', view_idx));

        input_nii = MRIread(input_name);
        output_data = permute(input_nii.vol, [2 1 3]);
        output_data = flip(output_data, 1);

        vox2ras = input_nii.vox2ras;
        vox2ras_new = vox2ras(:, [2 1 3 4]);
        vox2ras_new(:, 2) = -vox2ras_new(:, 2);
        ras_origin = vox2ras * [0 0 0 1]';
        center_new = ras_origin - vox2ras_new(:, 1:3) * [0 273 0]';
        vox2ras_new(:, 4) = center_new;

        output_nii = input_nii;
        output_nii.vol = output_data;
        output_nii.vox2ras = vox2ras_new;
        output_nii.vox2ras0 = vox2ras_new;

        MRIwrite(output_nii, output_name);
        fprintf('Processed view %d -> %s\n', view_idx, output_name);
    end
end
