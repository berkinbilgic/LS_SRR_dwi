function input_name = fn_find_view_nii(data_dir, view_num)
%FN_FIND_VIEW_NII Return the unique NIfTI corresponding to a view number.

file_pattern = fullfile(data_dir, sprintf('*_view_%d_*.nii', view_num));
matches = dir(file_pattern);
if isempty(matches)
    error('fn_find_view_nii:NotFound', 'No file found for view %d: %s', view_num, file_pattern);
end
if numel(matches) > 1
    error('fn_find_view_nii:NotUnique', 'Found %d files for view %d: %s', numel(matches), view_num, file_pattern);
end
input_name = fullfile(matches(1).folder, matches(1).name);
end
