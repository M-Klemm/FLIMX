function out = id2LineStyle(id)
%convert descriptive string or running number to linestyle string
switch id
    case {'No line',1}
        out = 'none';
    case {'Solid line',2}
        out = '-';
    case {'Dashed line',3}
        out = '--';
    case {'Dotted line',4}
        out = ':';
    case {'Dash-dot line',5}
        out = '-.';
    otherwise
        out = id;
end