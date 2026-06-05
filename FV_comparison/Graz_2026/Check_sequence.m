clc
clear all
folderPath = '/home/braingear/Research/FV_data/gdf_recordings/wheelchair_errp/vestibular/learn';
nameString = 'learn_errp_i7_2';
new_folderPath = fullfile(folderPath, nameString);
extension = '.gdf';
file_names = findFilesByName(new_folderPath, nameString, extension);

%eventCodes = [131 133 5431 5433 5131 5133];
eventCodes = [361 363 5361 5363 461 463 5461 5463];
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

% Store sequences for all files
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

    % Extract ONLY the events belonging to our codes of interest, in order
    mask = ismember(typ, eventCodes);
    sequence = typ(mask);
    allSequences{fId} = sequence;
    fileNames_ok{end+1} = [baseName, ext];

    fprintf('\nFile: %s%s\n', baseName, ext);
    fprintf('  Sequence length (selected codes): %d\n', numel(sequence));
    fprintf('  First 10 events: ');
    disp(sequence(1:min(10,end))');
end

% ========== COMPARE SEQUENCES ACROSS FILES ==========
fprintf('\n==================== SEQUENCE COMPARISON ====================\n');

% Remove empty cells (skipped files)
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
            fprintf('  File %s  vs  File %s : MATCH\n', fileNames_ok{1}, fileNames_ok{fId});
        else
            allMatch = false;
            fprintf('  File %s  vs  File %s : MISMATCH\n', fileNames_ok{1}, fileNames_ok{fId});

            % Show WHERE they differ
            minLen = min(numel(refSeq), numel(currSeq));
            diffIdx = find(refSeq(1:minLen) ~= currSeq(1:minLen));
            if ~isempty(diffIdx)
                fprintf('    First difference at position %d: ref=%d, curr=%d\n', ...
                    diffIdx(1), refSeq(diffIdx(1)), currSeq(diffIdx(1)));
            end
            if numel(refSeq) ~= numel(currSeq)
                fprintf('    Sequence lengths differ: ref=%d, curr=%d\n', ...
                    numel(refSeq), numel(currSeq));
            end
        end
    end

    if allMatch
        fprintf('\n  ALL FILES HAVE THE SAME EVENT SEQUENCE.\n');
    else
        fprintf('\n  WARNING: SOME FILES HAVE DIFFERENT EVENT SEQUENCES.\n');
    end
end

% ========== SAVE SEQUENCES IN A MATRIX (columns = files) ==========
fprintf('\n==================== SEQUENCE MATRIX ====================\n');

validSeqs = allSequences(validIdx);

% Pad shorter sequences with NaN to match the longest one
maxLen = max(cellfun(@numel, validSeqs));
seqMatrix = NaN(maxLen, numel(validSeqs));

for fId = 1:numel(validSeqs)
    s = validSeqs{fId};
    seqMatrix(1:numel(s), fId) = s;
end

% Display with file names as column headers
fprintf('Rows = event positions, Columns = files\n');
fprintf('%-6s', 'Pos');
for fId = 1:numel(fileNames_ok)
    fprintf('%-12s', fileNames_ok{fId}(1:min(11,end)));
end
fprintf('\n');
for row = 1:maxLen
    fprintf('%-6d', row);
    for col = 1:size(seqMatrix,2)
        if isnan(seqMatrix(row,col))
            fprintf('%-12s', 'NaN');
        else
            fprintf('%-12d', seqMatrix(row,col));
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