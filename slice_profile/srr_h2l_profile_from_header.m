function h2l_s = srr_h2l_profile_from_header(h_lr, h_hr, prof)
% function h2l_s = srr_h2l_profile_from_header(h_lr, h_hr, prof)
%
% h2l operator for one view with a slice-profile-weighted through-plane
% response, built by supersampling each hr pixel with prof.K x prof.K points.
%
%   A(l,h) = 1/K^2 * sum_{sub-points r in hr pixel h}
%              rect_x(r in lr column of l) * w(u(r) - u_l)
%
% u is the distance (mm) along the lr slice normal from the centre of lr
% slice l, w is the through-plane weight from slice_profile_weight().
% With a box w (prof.mode = 'box') this reduces to the overlap-area
% fraction used by srr_h2l_from_header.

hr = geom_from_header(h_hr);
lr = geom_from_header(h_lr);

K = prof.K;
n_hr = prod(hr.size);
n_lr = prod(lr.size);

[I, J] = ndgrid(0:hr.size(1)-1, 0:hr.size(2)-1);
hr_ind = reshape(1:n_hr, 1, []);
local_c = [I(:)' * hr.pixdim_x; J(:)' * hr.qfac * hr.pixdim_z];

sub = ((1:K) - 0.5) / K - 0.5;
D = ceil(prof.support_mm / lr.pixdim_z) + 1;   % neighbouring lr slices to test

rows = cell(K, K); cols = cell(K, K); vals = cell(K, K);
for a = 1:K
    for b = 1:K
        local = local_c + [sub(a) * hr.pixdim_x; sub(b) * hr.qfac * hr.pixdim_z];
        pos = hr.R * local + [hr.qoffset_x; hr.qoffset_z];
        c = (lr.R \ (pos - [lr.qoffset_x; lr.qoffset_z])) ./ [lr.pixdim_x; lr.qfac * lr.pixdim_z];

        il = round(c(1, :)) + 1;
        j0 = round(c(2, :)) + 1;
        r_all = []; c_all = []; v_all = [];
        for d = -D:D
            jl = j0 + d;
            u_mm = (c(2, :) - (jl - 1)) * lr.pixdim_z;
            w = slice_profile_weight(u_mm, prof);
            ok = w > 0 & il >= 1 & il <= lr.size(1) & jl >= 1 & jl <= lr.size(2);
            r_all = [r_all, il(ok) + (jl(ok) - 1) * lr.size(1)]; %#ok<AGROW>
            c_all = [c_all, hr_ind(ok)]; %#ok<AGROW>
            v_all = [v_all, w(ok)]; %#ok<AGROW>
        end
        rows{a, b} = r_all; cols{a, b} = c_all; vals{a, b} = v_all;
    end
end

h2l_s = sparse([rows{:}], [cols{:}], [vals{:}] / K^2, n_lr, n_hr);
end

function p = geom_from_header(h)
% same conventions as srr_h2l_from_header
p.size = double([h.dim(2) h.dim(4)]);
b = h.quatern_b; c = h.quatern_c; d = h.quatern_d;
a = sqrt(1.0 - (b*b + c*c + d*d));
if a < 10e-6
    a = 0;
end
p.qfac = double(h.pixdim(1));
R = double(quat2rotm([a b c d]));
p.R = R([1 3], [1 3]);
p.pixdim_x = double(h.pixdim(2));
p.pixdim_z = double(h.pixdim(4));
p.qoffset_x = double(h.qoffset_x);
p.qoffset_z = double(h.qoffset_z);
end
