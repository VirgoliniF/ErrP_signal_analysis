function rename_bags(subjects, error_modality, task)
% RENAME_BAGS  Move the difficulty tag (high/low/medium) from the middle of
%              bag filenames to the end, before the .bag extension.
%
%  Input bag name pattern (current, wrong):
%    <subject>_wheelchair_errp_learn_<tag>_<timestamp>.bag
%  Output bag name pattern (correct):
%    <subject>_wheelchair_errp_learn_<timestamp>_<tag>.bag
%
%  Usage:
%    rename_bags({'learn_errp_f2_3'}, 'vestibular', 'learn')

    if nargin < 3
        task = 'learn';
    end

    difficulty_tags = {'high', 'medium', 'low'};
    tags_str        = strjoin(difficulty_tags, '|');

    rootpath = '/home/braingear/Research/FV_data';

    if strcmp(error_modality, 'visual')
        folder = 'gdf_recordings/wheelchair_errp/visual';
    else
        folder = 'gdf_recordings/wheelchair_errp/vestibular';
    end

    bags_root = fullfile(rootpath, folder, task);

    if ~exist(bags_root, 'dir')
        error('[rename_bags] Bags root directory not found: %s', bags_root);
    end

    pat_wrong   = ['^(.+_wheelchair_errp_learn)_(' tags_str ')_(\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2})(\d*)\.bag$'];
    pat_correct = ['^(.+_wheelchair_errp_learn)_(\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2})(\d*)_(' tags_str ')\.bag$'];

    renamed = 0;
    skipped = 0;
    already = 0;

    for s = 1:length(subjects)
        subj = subjects{s};

        % Try increasing depth levels until files are found or we give up
        bag_files = {};
        for depth = 1:4
            try
                bag_files = util_getfile3(bags_root, '.bag', 'include', {subj}, 'exclude', {}, 'level', depth);
                if ~isempty(bag_files)
                    fprintf('[rename_bags] Subject "%s": found %d bag file(s) at depth %d.\n', subj, length(bag_files), depth);
                    break
                end
            catch
                % util_getfile3 throws when nothing is found — just continue
            end
        end

        if isempty(bag_files)
            fprintf('[rename_bags] No .bag files found for subject "%s" under %s\n', subj, bags_root);
            continue
        end

        for f = 1:length(bag_files)
            fpath                  = bag_files{f};
            [folder_f, fname, ext] = fileparts(fpath);
            full_name              = [fname ext];

            tokens = regexp(full_name, pat_wrong, 'tokens', 'once');

            if isempty(tokens)
                if ~isempty(regexp(full_name, pat_correct, 'once'))
                    fprintf('  [ok]      Already correctly named: %s\n', full_name);
                    already = already + 1;
                else
                    fprintf('  [skip]    No difficulty tag found, leaving untouched: %s\n', full_name);
                    skipped = skipped + 1;
                end
                continue
            end

            prefix    = tokens{1};
            tag       = tokens{2};
            timestamp = tokens{3};
            suffix    = tokens{4};

            new_name = [prefix '_' timestamp suffix '_' tag '.bag'];
            new_path = fullfile(folder_f, new_name);

            if exist(new_path, 'file')
                fprintf('  [skip]    Target already exists, skipping: %s\n', new_name);
                skipped = skipped + 1;
                continue
            end

            fprintf('  [rename]  %s\n          -> %s\n', full_name, new_name);
            movefile(fpath, new_path);
            renamed = renamed + 1;
        end
    end

    fprintf('\n[rename_bags] Done. Renamed: %d | Already correct: %d | Skipped: %d\n', ...
        renamed, already, skipped);
end