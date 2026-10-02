function w = slice_profile_weight(u_mm, prof)
% function w = slice_profile_weight(u_mm, prof)
%
% Through-plane weight at distance u (mm) from the lr slice centre:
% layer i (centre prof.z_layer_mm(i), width prof.spa_res) has weight
% M * prof.weights(i), so 'equal' weights give 1 inside the slab.

M = numel(prof.weights);
i = round(u_mm / prof.spa_res + (M - 1) / 2) + 1;   % nearest layer index
w = zeros(size(u_mm));
ok = i >= 1 & i <= M;
w(ok) = M * prof.weights(i(ok));
end
