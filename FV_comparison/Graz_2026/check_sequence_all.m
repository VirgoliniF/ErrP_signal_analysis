clc
clear all
folderPath = '/home/braingear/Research/FV_data/gdf_recordings/wheelchair_errp/vestibular';
%folderPath = '/home/braingear/Research/Piero_data/gdf_recordings/wheelchiar_errp/Alessio';
extension = '.gdf';

% ========== FIND ALL .GDF FILES RECURSIVELY ==========
fileStruct = dir(fullfile(folderPath, '**', ['*' extension]));
file_names = fullfile({fileStruct.folder}, {fileStruct.name})';

fprintf('Found %d .gdf files in all subfolders.\n', numel(file_names));

% ========== EVENT DEFINITIONS ==========
if strfind(folderPath, 'vestibular') ~= 0
    eventCodes = [361 363 5361 5363 461 463 5461 5463];
else
    eventCodes = [131 133 5131 5133];
end

eventLabels = { ...
    'correct left (361)', ...
    'correct right (363)', ...
    'error feedback left (5361)', ...
    'error feedback right (5363)', ...
    'error movement left 1 (461)', ...
    'error movement right 1 (463)', ...
    'error movement left 2 (5461)', ...
    'error movement right 2 (5463)', ...
    };

% ========== STORE SEQUENCES ==========
allSequences = cell(numel(file_names), 1);
fileNames_ok = {};

fprintf('\n==================== EVENT SEQUENCES PER FILE ====================\n');

for fId = 1:numel(file_names)
    fname = file_names{fId};
    [~, baseName, ext] = fileparts(fname);

    try
        [~, header] = sload(fname);
        typ = header.EVENT.TYP(:);
    catch ME
        fprintf('\nFile: %s%s\n', baseName, ext);
        fprintf('  [SKIP] Error: %s\n', ME.message);
        continue
    end

    % Extract only events of interest
    mask = ismember(typ, eventCodes);
    sequence = typ(mask);

    allSequences{fId} = sequence;
    fileNames_ok{end+1} = [baseName, ext];

    fprintf('\nFile: %s%s\n', baseName, ext);
    fprintf('  Sequence length: %d\n', numel(sequence));
    fprintf('  First 10 events: ');
    disp(sequence(1:min(10,end))');
end

% ========== COMPARE SEQUENCES ==========
fprintf('\n==================== SEQUENCE COMPARISON ====================\n');

validIdx = ~cellfun(@isempty, allSequences);
sequences = allSequences(validIdx);

if numel(sequences) < 2
    fprintf('Not enough valid files to compare.\n');
else
    refSeq = sequences{1};
    allMatch = true;

    for fId = 2:numel(sequences)
        currSeq = sequences{fId};

        if isequal(refSeq, currSeq)
            fprintf('  File %s vs %s : MATCH\n', fileNames_ok{1}, fileNames_ok{fId});
        else
            allMatch = false;
            fprintf('  File %s vs %s : MISMATCH\n', fileNames_ok{1}, fileNames_ok{fId});

            % Find first difference
            minLen = min(numel(refSeq), numel(currSeq));
            diffIdx = find(refSeq(1:minLen) ~= currSeq(1:minLen));

            if ~isempty(diffIdx)
                fprintf('    First difference at position %d: ref=%d, curr=%d\n', ...
                    diffIdx(1), refSeq(diffIdx(1)), currSeq(diffIdx(1)));
            end

            if numel(refSeq) ~= numel(currSeq)
                fprintf('    Length mismatch: ref=%d, curr=%d\n', ...
                    numel(refSeq), numel(currSeq));
            end
        end
    end

    if allMatch
        fprintf('\nALL FILES HAVE THE SAME EVENT SEQUENCE.\n');
    else
        fprintf('\nWARNING: SOME FILES HAVE DIFFERENT EVENT SEQUENCES.\n');
    end
end

% ========== BUILD SEQUENCE MATRIX ==========
fprintf('\n==================== SEQUENCE MATRIX ====================\n');

validSeqs = allSequences(validIdx);

if isempty(validSeqs)
    fprintf('No valid sequences found.\n');
    return;
end

maxLen = max(cellfun(@numel, validSeqs));
seqMatrix = NaN(maxLen, numel(validSeqs));

for fId = 1:numel(validSeqs)
    s = validSeqs{fId};
    seqMatrix(1:numel(s), fId) = s;
end

% Print matrix
fprintf('Rows = event positions, Columns = files\n');

fprintf('%-6s', 'Pos');
for fId = 1:numel(fileNames_ok)
    fprintf('%-15s', fileNames_ok{fId}(1:min(14,end)));
end
fprintf('\n');

for row = 1:maxLen
    fprintf('%-6d', row);
    for col = 1:size(seqMatrix,2)
        if isnan(seqMatrix(row,col))
            fprintf('%-15s', 'NaN');
        else
            fprintf('%-15d', seqMatrix(row,col));
        end
    end
    fprintf('\n');
end

fprintf('==========================================================\n');

% ========== LOCAL FUNCTIONS ==========
function fileList = findFilesByName(folderPath, nameString, extension)
    if ~isfolder(folderPath)
        error('The specified folder does not exist.');
    end
    if extension(1) ~= '.'
        extension = ['.' extension];
    end
    searchPattern = fullfile(folderPath, ['*' nameString '*' extension]);
    files = dir(searchPattern);
    fileList = cell(length(files), 1);
    for i = 1:length(files)
        fileList{i} = fullfile(files(i).folder, files(i).name);
    end
    if isempty(fileList)
        fprintf('No matching files found.\n');
    else
        fprintf('Found %d matching files:\n', length(fileList));
        disp(fileList)
    end
end