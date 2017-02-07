function out = lineStyle2id(str)
%convert descriptive string or linestyle string to running number
if(isnumeric(str))
    out = str;
    return
end
switch str
    case {'No line','none'}
        out = 1;
    case {'Solid line','-'}
        out = 2;
    case {'Dashed line','--'}
        out = 3;
    case {'Dotted line',':'}
        out = 4;
    case {'Dash-dot line','-.'}
        out = 5;
end