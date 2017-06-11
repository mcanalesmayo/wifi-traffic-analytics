function [ num ] = customhex2num( hex )
    if ~strcmp(hex, '') && strcmp(hex, strrep(hex, '...', ''))
        num = double(hex2dec(hex));
    else
        num = NaN(1);
    end
end

