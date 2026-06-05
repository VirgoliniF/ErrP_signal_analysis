function info = errp_util_get_info(filename, addfields)
% info = errp_util_get_info(filename)
%
% Given a standard filename format, the function return a structure with
% fields retrieved from the filename. Standard filename format is defined
% as follows:   SUBJECT.DATE.TIME.TASK.[EXTRA*].EXTENSION
%
% The returned structure has the following fields:
%
%   info
%       .subject
%       .date
%       .time
%       .task
%       .[EXTRA*]
%       .filepath
%       .extension

    if nargin == 1
        addfields = {};
    end

    [path, name, ext] = fileparts(filename);
    
    fields = regexp(name, '\.', 'split');
    nfields = length(fields);
    
    % Default
    ndeffields = 4;
    info.subject    = fields{1};
    info.date       = fields{2};
    info.time       = fields{3};
    info.task       = fields{4};
    
    naddfields   = length(addfields);
    nextrafields = nfields - (ndeffields + naddfields);
    
    efields = cat(2, addfields, strcat(repmat({'extra'}, 1, nextrafields), cellstr(num2str( (1:nextrafields)' ))'));
    
    for efId = 1:length(efields)
        info.(efields{efId}) = fields{efId+ndeffields};
    end
    
    info.filepath   = path;
    info.extension  = ext;

end
