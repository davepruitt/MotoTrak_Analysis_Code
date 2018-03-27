function [file, path] = uigetmultiplefiles (filespec, window_label)

    [file, path] = uigetfile(filespec, window_label, 'MultiSelect', 'on');
    if (isscalar(file))
        file = {};
    elseif (~iscell(file))
        file = {file};
    end

end
