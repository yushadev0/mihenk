function figDir = g1_setup()
%G1_SETUP Put models/, g1/ and every g1/v*/ folder on the path.
%   Returns the figures folder. Every G1 script starts with:
%       addpath(fileparts(fileparts(mfilename('fullpath'))));
%       figDir = g1_setup();

root = fileparts(mfilename('fullpath'));
addpath(root, fullfile(root, '..', 'models'));
v = dir(fullfile(root, 'v*'));
for i = 1:numel(v)
    if v(i).isdir, addpath(fullfile(root, v(i).name)); end
end
figDir = fullfile(root, '..', 'figures');
if ~isfolder(figDir), mkdir(figDir); end
end
