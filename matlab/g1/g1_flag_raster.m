function g1_flag_raster(th, F, labels, D)
%G1_FLAG_RASTER Channels x time raster of blame flags (black = blamed),
%   with fault onsets (red) and heater burst (blue) marked.
imagesc(th, 1:size(F, 2), double(F)');
yticks(1:size(F, 2)); yticklabels(labels); colormap(flipud(gray));
for f = D.S.faults(:)'
    xline(f.t0/3600, 'r--');
end
if ~isempty(D.S.heaterOn)
    xline(D.S.heaterOn/3600, 'b--');
end
end
