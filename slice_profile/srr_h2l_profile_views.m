function h2l_views = srr_h2l_profile_views(s, h_hr, prof, cache_dir)
% function h2l_views = srr_h2l_profile_views(s, h_hr, prof, cache_dir)
%
% Per-view slice-profile h2l operators (cell array), cached in
% cache_dir/<prof.tag>_K<K>/ so the source data folder is never touched.

sub_dir = fullfile(cache_dir, sprintf('%s_K%d', prof.tag, prof.K));
if ~exist(sub_dir, 'dir'), mkdir(sub_dir); end

h2l_views = cell(1, numel(s));
for n = 1:numel(s)
    [~, nm] = fileparts(s{n}.nii_fn);
    fn = fullfile(sub_dir, [nm '_h2l.mat']);
    if exist(fn, 'file')
        tmp = load(fn); h2l_views{n} = tmp.h2l_s;
    else
        h_lr = mdm_nii_read_header(s{n}.nii_fn);
        h2l_s = srr_h2l_profile_from_header(h_lr, h_hr, prof);
        save(fn, 'h2l_s', 'prof');
        h2l_views{n} = h2l_s;
    end
end
end
