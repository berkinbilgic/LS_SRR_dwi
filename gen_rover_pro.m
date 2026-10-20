function outProFiles = gen_rover_pro(view1ProFile, nViews)
% GEN_ROVER_PRO Generate Siemens .pro files for ROVER rotating-view scans.
%
% outProFiles = gen_rover_pro(view1ProFile)
% outProFiles = gen_rover_pro(view1ProFile, nViews)
%
% This function starts from an axial Siemens protocol file, treated as
% ROVER view 1, and generates the remaining rotating-view protocol files.
% The rotation is around the coronal/AP axis, matching the scanner-exported
% examples inspected in this repository.
%
% Inputs
% ------
% view1ProFile
%   Full path or relative path to the axial view-1 .pro file. This file is
%   used as the geometric reference and is not modified.
%
% nViews
%   Optional total number of rotating views over 180 degrees. If omitted,
%   the function prompts for this value in the MATLAB command window. For
%   example:
%       nViews = 12 -> angle step is 15.0 degrees
%       nViews = 8  -> angle step is 22.5 degrees
%
% Output
% ------
% outProFiles
%   A cell array containing the generated output .pro files for views 2:nViews.
%   View 1 is the input file and is not copied or regenerated.
%
% Geometric model
% ---------------
% ROVER rotates thick-slice 2D acquisitions around the phase-encoding axis.
% In the scanner-exported examples checked here, that axis is the coronal/AP
% direction. Therefore:
%
%   * sPosition.dCor is unchanged.
%   * sNormal.dCor is zero and omitted.
%   * sPosition.dSag and sPosition.dTra are rotated around the center of the
%     view-1 slice stack.
%
% The rotation center is inferred from the input view-1 protocol:
%
%   centerSag = mean of all slice sPosition.dSag values
%   centerCor = mean of all slice sPosition.dCor values
%   centerTra = mean of all slice sPosition.dTra values
%
% For the checked 28-slice scanner example this gives:
%
%   [centerSag, centerCor, centerTra] = [1.51570991725, -10.0, 25.0]
%
% Each generated view first defines a geometric plane angle:
%
%   planeAngle = (viewIndex - 1) * 180 / nViews
%
% Siemens then uses an equivalent signed angle for slice ordering:
%
%   theta = planeAngle,       when planeAngle <= 45 degrees
%   theta = planeAngle - 180, when planeAngle >  45 degrees
%
% This convention reproduces the scanner-exported examples. For example,
% view 12 of a 12-view scan has planeAngle = 165 degrees, but its slice
% positions are generated using theta = -15 degrees.
%
% and each slice position is updated as:
%
%   newSag = centerSag + cos(theta) * (oldSag - centerSag) ...
%                       - sin(theta) * (oldTra - centerTra)
%   newCor = oldCor
%   newTra = centerTra + sin(theta) * (oldSag - centerSag) ...
%                       + cos(theta) * (oldTra - centerTra)
%
% Siemens normal-vector convention
% --------------------------------
% A slice plane is unchanged if the normal vector is multiplied by -1. The
% scanner-exported ROVER examples use the following convention:
%
%   sNormal = [-sin(theta), 0, cos(theta)]
%
% This reproduces the observed 12-view scanner files where view 5 onward
% flips the normal direction while preserving the same geometric plane.
% It also matches a 20-view AP-only plan with GUI directions:
%
%   T 0, T-S 9, ..., T-S 45,
%   S-T 36, S-T 27, ..., S-T -45,
%   T-S -36, ..., T-S -9
%
% Fields updated
% --------------
% This function updates only the geometry fields supported by the scanner
% examples:
%
%   sAdjData.sAdjVolume.sNormal.* when the adjustment-volume block exists
%   sAAInitialOffset.SliceInformation.sNormal.* when the block exists (XA)
%   sGroupArray.asGroup[i].AutoAlignData.InitialOffset.Normal.* (VB10)
%   tProtocolName
%   sSliceArray.lSag / sSliceArray.lCor / sSliceArray.lTra
%   sSliceArray.asSlice[i].sPosition.*
%   sSliceArray.asSlice[i].sNormal.*
%
% Other protocol-instance fields such as lProtID, lSequenceID, frequency,
% or adjustment IDs are intentionally left unchanged because they appear to
% be scanner/export-instance noise rather than the ROVER geometry itself.
%
% Example
% -------
% outFiles = gen_rover_pro( ...
%     'C:\Users\76494\Downloads\ep2d_diff_view_1.pro', 12);

arguments
    view1ProFile (1,:) char
    nViews double = []
end

if ~isfile(view1ProFile)
    error('Input view-1 .pro file does not exist: %s', view1ProFile);
end

if isempty(nViews)
    nViews = input('How many ROVER views do you need? ');
end
local_validateNViews(nViews);

[inputFolder, ~, inputExt] = fileparts(view1ProFile);
if isempty(inputFolder)
    inputFolder = pwd;
end
if isempty(inputExt)
    inputExt = '.pro';
end

txt = fileread(view1ProFile);
protocolName = local_readProtocolName(txt);
protocolBaseName = local_protocolBaseName(protocolName);

outputDir = fullfile(inputFolder, sprintf('%s_rover_%dviews', protocolBaseName, nViews));
if ~isfolder(outputDir)
    mkdir(outputDir);
end

newlineText = local_detectNewline(txt);
sliceCount = local_getRequiredNumber(txt, 'sSliceArray\.lSize\s*=\s*([-+0-9.eE]+)');
sliceCount = round(sliceCount);

view1Pos = local_readSlicePositions(txt, sliceCount);
center = mean(view1Pos, 1);

outProFiles = cell(nViews - 1, 1);

fprintf('Input view 1: %s\n', view1ProFile);
fprintf('Input tProtocolName: %s\n', protocolName);
fprintf('Output basename: %s\n', protocolBaseName);
fprintf('Output folder: %s\n', outputDir);
fprintf('Number of views: %d\n', nViews);
fprintf('Angle step: %.12g degrees\n', 180 / nViews);
fprintf('Rotation center: dSag = %.12g, dCor = %.12g, dTra = %.12g\n', ...
    center(1), center(2), center(3));

for viewIndex = 2:nViews
    planeAngleDeg = (viewIndex - 1) * 180 / nViews;
    thetaDeg = local_roverSignedTheta(viewIndex, nViews);
    viewTxt = txt;

    normal = local_roverNormal(thetaDeg);
    newPos = local_rotatePositionsAroundCor(view1Pos, center, normal);

    viewTxt = local_tryUpdateAdjVolumeNormal(viewTxt, normal, newlineText);
    viewTxt = local_tryUpdateAAInitialOffsetNormal(viewTxt, thetaDeg, newlineText);
    viewTxt = local_updateSliceArrayCount(viewTxt, sliceCount, normal, newlineText);

    for sliceIndex = sliceCount-1:-1:0
        viewTxt = local_updateSliceGeometry(viewTxt, sliceIndex, ...
            newPos(sliceIndex+1, :), normal, newlineText);
    end

    outputProtocolName = sprintf('%s_view%d', protocolBaseName, viewIndex);
    outProFile = local_makeOutputFileName(outputProtocolName, inputExt, outputDir);
    viewTxt = local_updateProtocolName(viewTxt, outputProtocolName);
    local_writeTextFile(outProFile, viewTxt);
    outProFiles{viewIndex - 1} = outProFile;

    guiDirection = local_roverGuiDirection(thetaDeg);
    fprintf(['Wrote view %d: plane angle = %.12g deg, theta = %.12g deg, ', ...
             'GUI = %s, file = %s\n'], ...
        viewIndex, planeAngleDeg, thetaDeg, guiDirection, outProFile);
end

end

function protocolName = local_readProtocolName(txt)
% Read tProtocolName from the input protocol.
%
% The generated file names are based on this field rather than on the input
% file name, because the file name may be a temporary export name while
% tProtocolName is the scanner-visible protocol identity.

token = regexp(txt, 'tProtocolName\s*=\s*"([^"]*)"', 'tokens', 'once');
if isempty(token)
    error('Could not find tProtocolName in the input protocol.');
end

protocolName = token{1};

end

function baseName = local_protocolBaseName(protocolName)
% Convert a view-1 protocol name into the basename used for generated views.
%
% Examples:
%   ep2d_view1        -> ep2d
%   ep2d_view_1      -> ep2d
%   ep2d_diff_view_1 -> ep2d_diff
%
% If the input protocol name does not end in a view-1 suffix, use it as-is.

baseName = regexprep(protocolName, '[_-]?view[_-]?1$', '', 'ignorecase');
if isempty(baseName)
    error('Could not derive a nonempty basename from tProtocolName: %s', protocolName);
end

end

function txt = local_updateProtocolName(txt, protocolName)
% Update the user-visible Siemens protocol name.
%
% Scanner-exported files contain a field such as:
%
%   tProtocolName = "ep2d_diff_view_2"
%
% Keeping this synchronized with the generated view file name makes the
% protocols distinguishable on the scanner and in downstream bookkeeping.

replacement = sprintf('tProtocolName\t = \t"%s"', protocolName);
[startIdx, endIdx] = regexp(txt, ...
    '(?m)^tProtocolName\s*=\s*"[^"]*"(?=\r?$)', ...
    'start', 'end', 'once');

if isempty(startIdx)
    warning('gen_rover_pro:MissingProtocolName', ...
        'Could not find tProtocolName; leaving protocol name unchanged.');
    return
end

txt = [txt(1:startIdx-1), replacement, txt(endIdx+1:end)];

end

function newlineText = local_detectNewline(txt)
% Preserve the input file line-ending style when writing generated files.

if contains(txt, sprintf('\r\n'))
    newlineText = sprintf('\r\n');
else
    newlineText = newline;
end

end

function local_validateNViews(nViews)
% Validate total number of ROVER views after optional command-window input.

if ~isnumeric(nViews) || ~isscalar(nViews) || ~isfinite(nViews) || ...
        nViews ~= round(nViews) || nViews <= 1
    error('nViews must be an integer greater than 1.');
end

end

function value = local_getRequiredNumber(txt, pattern)
% Read a required numeric value from protocol text.

token = regexp(txt, pattern, 'tokens', 'once');
if isempty(token)
    error('Could not find required protocol field matching: %s', pattern);
end

value = str2double(token{1});
if isnan(value)
    error('Could not parse numeric value for field matching: %s', pattern);
end

end

function value = local_getOptionalNumber(txt, pattern, defaultValue)
% Read an optional numeric value from protocol text.
%
% Siemens omits zero vector components in many exported protocols. Missing
% position or normal components are therefore treated as zero.

token = regexp(txt, pattern, 'tokens', 'once');
if isempty(token)
    value = defaultValue;
else
    value = str2double(token{1});
    if isnan(value)
        value = defaultValue;
    end
end

end

function positions = local_readSlicePositions(txt, sliceCount)
% Read all slice center positions from the input axial view.
%
% The returned columns are [dSag, dCor, dTra].

positions = zeros(sliceCount, 3);

for sliceIndex = 0:sliceCount-1
    prefix = sprintf('sSliceArray\\.asSlice\\[%d\\]\\.sPosition\\.', sliceIndex);
    positions(sliceIndex+1, 1) = local_getOptionalNumber(txt, ...
        [prefix, 'dSag\s*=\s*([-+0-9.eE]+)'], 0);
    positions(sliceIndex+1, 2) = local_getOptionalNumber(txt, ...
        [prefix, 'dCor\s*=\s*([-+0-9.eE]+)'], 0);
    positions(sliceIndex+1, 3) = local_getOptionalNumber(txt, ...
        [prefix, 'dTra\s*=\s*([-+0-9.eE]+)'], 0);
end

end

function thetaDeg = local_roverSignedTheta(viewIndex, nViews)
% Return the signed angle used by Siemens for slice position ordering.

planeAngleDeg = (viewIndex - 1) * 180 / nViews;
if planeAngleDeg <= 45
    thetaDeg = planeAngleDeg;
else
    thetaDeg = planeAngleDeg - 180;
end

end

function positions = local_rotatePositionsAroundCor(view1Pos, center, normal)
% Rotate slice positions around the coronal/AP axis.
%
% The scanner appears to use the six-decimal normal values when writing
% positions. Using the same rounded direction cosines reproduces the checked
% scanner files exactly, rather than differing by about 1e-5 mm.

positions = view1Pos;
sinTheta = -normal(1);
cosTheta = normal(3);

relativeSag = view1Pos(:, 1) - center(1);
relativeTra = view1Pos(:, 3) - center(3);

positions(:, 1) = center(1) + cosTheta * relativeSag - sinTheta * relativeTra;
positions(:, 2) = view1Pos(:, 2);
positions(:, 3) = center(3) + sinTheta * relativeSag + cosTheta * relativeTra;

positions = local_removeTinyValues(positions);

end

function normal = local_roverNormal(thetaDeg)
% Return the scanner-style normal vector for a ROVER view.
%
% Vector order is [dSag, dCor, dTra].

normal = [-sind(thetaDeg), 0, cosd(thetaDeg)];
normal = round(normal, 6);
normal = local_removeTinyValues(normal);

end

function txt = local_tryUpdateAdjVolumeNormal(txt, normal, newlineText)
% Update sAdjData.sAdjVolume.sNormal when the adjustment-volume block exists.
%
% Some protocols do not contain sAdjData.sAdjVolume anchors. ROVER imaging
% geometry is controlled by sSliceArray, so missing adjustment-volume fields
% should not prevent generating the rotating imaging volumes.

txt = regexprep(txt, ...
    '(?m)^\s*sAdjData\.sAdjVolume\.sNormal\.d(?:Sag|Cor|Tra)\s*=\s*[-+0-9.eE]+\s*\r?\n?', ...
    '');

normalBlock = local_formatVectorBlock('sAdjData.sAdjVolume.sNormal', ...
    normal, newlineText, 6);

anchorPattern = '(?m)^(sAdjData\.sAdjVolume\.sPosition\.dTra\s*=\s*[-+0-9.eE]+\s*)\r?$';
[~, endIdx] = regexp(txt, anchorPattern, 'start', 'end', 'once');
if isempty(endIdx)
    anchorPattern = '(?m)^(sAdjData\.sAdjVolume\.dReadoutFOV\s*=\s*[-+0-9.eE]+\s*)\r?$';
    [~, endIdx] = regexp(txt, anchorPattern, 'start', 'end', 'once');
end

if isempty(endIdx)
    return
end

txt = local_insertBlockAfterLine(txt, endIdx, normalBlock, newlineText);

end

function txt = local_tryUpdateAAInitialOffsetNormal(txt, thetaDeg, newlineText)
% Update the AutoAlign initial-offset normal when the block exists.
%
% Newer scanner software re-applies this "initial offset" normal after the
% protocol is loaded. If it stays axial while sSliceArray is rotated, the
% scanner snaps the slice group back to axial. Scanner-exported rotated
% protocols write this normal with 12 decimals, so the unrounded normal is
% used here.
%
% XA spells it sAAInitialOffset.SliceInformation.sNormal; VB10 moved it
% into each slice group as sGroupArray.asGroup[i].AutoAlignData.InitialOffset.Normal.

normal = [-sind(thetaDeg), 0, cosd(thetaDeg)];
normal = round(normal, 12);
normal = local_removeTinyValues(normal);

prefixes = {'sAAInitialOffset.SliceInformation.sNormal'};
groupTokens = regexp(txt, ...
    '(?m)^\s*(sGroupArray\.asGroup\[\d+\]\.AutoAlignData\.InitialOffset\.Normal)\.d', ...
    'tokens');
if ~isempty(groupTokens)
    prefixes = [prefixes, unique(cellfun(@(t) t{1}, groupTokens, ...
        'UniformOutput', false), 'stable')];
end

for i = 1:numel(prefixes)
    linePattern = ['(?m)^\s*', regexptranslate('escape', prefixes{i}), ...
        '\.d(?:Sag|Cor|Tra)\s*=\s*[-+0-9.eE]+\s*\r?\n?'];
    startIdx = regexp(txt, linePattern, 'start', 'once');
    if isempty(startIdx)
        continue
    end

    txt = regexprep(txt, linePattern, '');
    normalBlock = local_formatVectorBlock(prefixes{i}, normal, newlineText, 12);
    txt = [txt(1:startIdx-1), normalBlock, txt(startIdx:end)];
end

end

function txt = local_updateSliceArrayCount(txt, sliceCount, normal, newlineText)
% Update Siemens lSag/lCor/lTra count fields using observed scanner behavior.
%
% In checked ROVER examples, no lTra field is written for transverse-dominant
% views or exact 45-degree ties, while lSag = sliceCount is written only for
% sagittal-dominant views.

txt = regexprep(txt, ...
    '(?m)^\s*sSliceArray\.l(?:Sag|Cor|Tra)\s*=\s*[-+0-9.eE]+\s*\r?\n?', ...
    '');

absNormal = abs(normal);
if absNormal(1) <= absNormal(3) && absNormal(2) <= absNormal(3)
    return
end

fieldNames = {'lSag', 'lCor', 'lTra'};
[~, dominantAxis] = max(absNormal);
countBlock = sprintf('sSliceArray.%s\t = \t%d%s', ...
    fieldNames{dominantAxis}, sliceCount, newlineText);

anchorPattern = '(?m)^(sSliceArray\.lSize\s*=\s*[-+0-9.eE]+\s*)\r?$';
[~, endIdx] = regexp(txt, anchorPattern, 'start', 'end', 'once');
if isempty(endIdx)
    error('Could not find sSliceArray.lSize in the input protocol.');
end

txt = local_insertBlockAfterLine(txt, endIdx, countBlock, newlineText);

end

function txt = local_updateSliceGeometry(txt, sliceIndex, position, normal, newlineText)
% Update one slice position and normal.

slicePattern = sprintf('sSliceArray\\.asSlice\\[%d\\]', sliceIndex);

txt = regexprep(txt, ...
    ['(?m)^\s*', slicePattern, '\.sPosition\.d(?:Sag|Cor|Tra)', ...
     '\s*=\s*[-+0-9.eE]+\s*\r?\n?'], ...
    '');
txt = regexprep(txt, ...
    ['(?m)^\s*', slicePattern, '\.sNormal\.d(?:Sag|Cor|Tra)', ...
     '\s*=\s*[-+0-9.eE]+\s*\r?\n?'], ...
    '');

positionBlock = local_formatVectorBlock( ...
    sprintf('sSliceArray.asSlice[%d].sPosition', sliceIndex), ...
    position, newlineText, 11);
normalBlock = local_formatVectorBlock( ...
    sprintf('sSliceArray.asSlice[%d].sNormal', sliceIndex), ...
    normal, newlineText, 6);
geometryBlock = [positionBlock, normalBlock];

anchorPattern = sprintf( ...
    '(?m)^(sSliceArray\\.asSlice\\[%d\\]\\.dReadoutFOV\\s*=\\s*[-+0-9.eE]+\\s*)\\r?$', ...
    sliceIndex);
[~, endIdx] = regexp(txt, anchorPattern, 'start', 'end', 'once');
if isempty(endIdx)
    error('Could not find dReadoutFOV for slice %d.', sliceIndex);
end

txt = local_insertBlockAfterLine(txt, endIdx, geometryBlock, newlineText);

end

function txt = local_insertBlockAfterLine(txt, endIdx, block, newlineText)
% Insert a formatted block after a matched line, avoiding blank extra lines.

% Anchor patterns may swallow the CR of a CRLF line ending via \s*.
while endIdx > 0 && txt(endIdx) == sprintf('\r')
    endIdx = endIdx - 1;
end

txtAfterAnchor = txt(endIdx+1:end);
if startsWith(txtAfterAnchor, newlineText)
    txtAfterAnchor = txtAfterAnchor(numel(newlineText)+1:end);
elseif startsWith(txtAfterAnchor, newline)
    txtAfterAnchor = txtAfterAnchor(2:end);
end

txt = [txt(1:endIdx), newlineText, block, txtAfterAnchor];

end

function guiDirection = local_roverGuiDirection(thetaDeg)
% Return the scanner GUI direction label implied by the signed theta.
%
% This is only used for informative command-window output. The .pro geometry
% is written through sNormal and sPosition fields, not through this text.

thetaDeg = local_removeTinyValues(thetaDeg);

if thetaDeg == 0
    guiDirection = 'T 0';
elseif thetaDeg == -90
    guiDirection = 'S';
elseif thetaDeg > 0
    guiDirection = sprintf('T-S %s', local_formatNumber(thetaDeg, 6));
elseif thetaDeg <= -45
    guiDirection = sprintf('S-T %s', local_formatNumber(-thetaDeg - 90, 6));
else
    guiDirection = sprintf('T-S %s', local_formatNumber(thetaDeg, 6));
end

end

function block = local_formatVectorBlock(prefix, values, newlineText, maxDecimals)
% Format nonzero vector components in Siemens protocol text style.
%
% Zero components are omitted because Siemens commonly omits them.

fieldNames = {'dSag', 'dCor', 'dTra'};
lines = cell(1, nnz(values));
lineCount = 0;

for i = 1:numel(values)
    if values(i) == 0
        continue
    end

    lineCount = lineCount + 1;
    lines{lineCount} = sprintf('%s.%s\t = \t%s', ...
        prefix, fieldNames{i}, local_formatNumber(values(i), maxDecimals));
end

block = strjoin(lines, newlineText);
block = [block, newlineText];

end

function outProFile = local_makeOutputFileName(protocolName, ext, outputDir)
% Build the output file name from the scanner protocol name.

outProFile = fullfile(outputDir, [protocolName, ext]);

end

function local_writeTextFile(fileName, txt)
% Write text using the byte content prepared in memory.

fid = fopen(fileName, 'w');
if fid < 0
    error('Could not open output file for writing: %s', fileName);
end

cleanupObj = onCleanup(@() fclose(fid));
fwrite(fid, txt, 'char');

end

function values = local_removeTinyValues(values)
% Clean numerical roundoff from exact angles such as 0, 90, and 180 degrees.

values(abs(values) < 1e-12) = 0;

end

function s = local_formatNumber(value, maxDecimals)
% Format a protocol number compactly while keeping at least one decimal.

fmt = sprintf('%%.%df', maxDecimals);
s = sprintf(fmt, value);
s = regexprep(s, '(\.\d*?)0+$', '$1');
s = regexprep(s, '\.$', '.0');

end
