clc
clear all
folderPath = '/home/braingear/Research/Piero_data/gdf_recordings/wheelchiar_errp/learn';
nameString = 'learn_errp_l4_1';
new_folderPath = fullfile(folderPath, nameString);
extension = '.gdf';
file_names = findFilesByName(new_folderPath, nameString, extension);
% eventCodes = [461 463 5461 5463 5361 5363];
% eventLabels = { ...
%     'error visual left (461)', ...
%     'error visual right (463)', ...
%     'error movement left (5461)', ...
%     'error movement right (5463)', ...
%     'unknown left (5361)', ...
%     'unknown right (5363)'};

eventCodes = [131 133 5231 5233 5131 5133];
eventLabels = { ...
    'error visual left (131)', ...
    'error visual right (133)', ...
    'error movement left (5231)', ...
    'error movement right (5233)', ...
    'unknown left (5131)', ...
    'unknown right (5133)'};
% Totali complessivi (su tutti i file)
totalCounts = zeros(1, numel(eventCodes));
fprintf('\n==================== EVENT COUNTS PER FILE ====================\n');
for fId = 1:numel(file_names)
    fname = file_names{fId};
    [~, baseName, ext] = fileparts(fname);
    try
        [data, header] = sload(fname); %#ok<ASGLU>
        typ = header.EVENT.TYP(:);  % colonna
    catch ME
        fprintf('\nFile: %s%s\n', baseName, ext);
        fprintf('  [SKIP] Errore lettura con sload: %s\n', ME.message);
        continue
    end
    % Conta eventi per ciascun codice
    counts = zeros(1, numel(eventCodes));
    for k = 1:numel(eventCodes)
        counts(k) = sum(typ == eventCodes(k));
    end
    % Aggiorna totali
    totalCounts = totalCounts + counts;
    % Stampa per file
    fprintf('\nFile: %s%s\n', baseName, ext);
    for k = 1:numel(eventCodes)
        fprintf('  %-28s : %d\n', eventLabels{k}, counts(k));
    end
    fprintf('  %-28s : %d\n', 'TOTAL (selected codes)', sum(counts));
end
% Stampa riepilogo totale
fprintf('\n==================== TOTAL OVER ALL FILES =====================\n');
for k = 1:numel(eventCodes)
    fprintf('  %-28s : %d\n', eventLabels{k}, totalCounts(k));
end
fprintf('  %-28s : %d\n', 'TOTAL (selected codes)', sum(totalCounts));
fprintf('==============================================================\n');
% all_typ_events = [];
% 
% for fId = 1:length(file_names)
%     [data, header] = sload(file_names{fId});
%     all_typ_events = [all_typ_events; header.EVENT.TYP];
% end
% for fId = 1:numel(file_names)
%     fname = file_names{fId};
%     fprintf("\n--- %d/%d ---\n%s\n", fId, numel(file_names), fname);
% 
%     if ~isfile(fname)
%         warning("File non trovato, salto.");
%         continue
%     end
% 
%     try
%         HDR = sopen(fname, 'r');   % <--- prova apertura
%         if HDR.FILE.FID < 0
%             warning("sopen non è riuscito ad aprire il file (FID<0).");
%             continue
%         end
% 
%         [data, HDR] = sread(HDR);  % <--- leggi i dati
%         HDR = sclose(HDR);
% 
%     catch ME
%         warning("Errore BioSig su questo file:\n%s", ME.message);
%         continue
%     end
% 
%     % Eventi
%     if isfield(HDR,'EVENT') && isfield(HDR.EVENT,'TYP')
%         TYP_events = HDR.EVENT.TYP;
%         disp(unique(TYP_events))
%     else
%         warning("Nessun campo EVENT.TYP trovato in HDR.");
%     end
% end
% %[data, header] = sload('learn_errp_l8_1.20260209.164956.learn.wheelchair_errp.gdf');
% [data, header] = sload('/home/braingear/Research/FV_data/gdf_recordings/wheelchair_errp/learn/learn_errp_d7_2/learn_errp_d7_2.20260225.105457.learn.wheelchair_errp.gdf');
% 
% % I codici degli eventi sono qui:
% disp('Codici evento trovati:');
% disp(header.EVENT.TYP);
% 
% % Se vuoi vedere anche a che secondo sono avvenuti:
% campionamento = header.SampleRate;
% tempi_secondi = header.EVENT.POS / campionamento;
% table(header.EVENT.TYP, tempi_secondi, 'VariableNames', {'Codice', 'Tempo_Secondi'})
function fileList = findFilesByName(folderPath, nameString, extension)
% findFilesByName finds files in a folder containing a specific string
% and with a specific extension.
%
% INPUT:
%   folderPath  - path of the folder to search in
%   nameString  - string that must be contained in the filename
%   extension   - file extension (e.g. '.mat', '.txt', '.gdf')
%
% OUTPUT:
%   fileList    - cell array containing full paths of matching files
    % Check inputs
    if ~isfolder(folderPath)
        error('The specified folder does not exist.');
    end
    if extension(1) ~= '.'
        extension = ['.' extension];
    end
    % Create search pattern
    searchPattern = fullfile(folderPath, ['*' nameString '*' extension]);
    % Get matching files
    files = dir(searchPattern);
    % Store full paths
    fileList = cell(length(files),1);
    for i = 1:length(files)
        fileList{i} = fullfile(files(i).folder, files(i).name);
    end
    % Optional: display results
    if isempty(fileList)
        fprintf('No matching files found.\n');
    else
        fprintf('Found %d matching files:\n', length(fileList));
        disp(fileList)
    end
end

