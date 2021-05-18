function [out, lbl_x, lbl_y] = mergeScatterPlotData(m1,lbl_x1,lbl_y1,m2,lbl_x2,lbl_y2,cw)
%=============================================================================================================
%
% @file     mergeScatterPlotData.m
% @author   Matthias Klemm <Matthias_Klemm@gmx.net>
% @version  1.0
% @date     July, 2015
%
% @section  LICENSE
%
% Copyright (C) 2015, Matthias Klemm. All rights reserved.
%
% Redistribution and use in source and binary forms, with or without modification, are permitted provided that
% the following conditions are met:
%     * Redistributions of source code must retain the above copyright notice, this list of conditions and the
%       following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
%       the following disclaimer in the documentation and/or other materials provided with the distribution.
%     * Neither the name of FLIMX authors nor the names of its contributors may be used
%       to endorse or promote products derived from this software without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
% WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
% PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
% INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
% PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
% HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
% NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
%
%
% @brief    A function to merge two 2D arrays of possibly different sizes and their axis labels
%
%if m1 is filled with zeros m2 is cut to fit in m1
if(isempty(m1) || isempty(lbl_x1) || isempty(lbl_y1))
    out = m2;
    lbl_x = lbl_x2;
    lbl_y = lbl_y2;
    return;
elseif(isempty(m2)  || isempty(lbl_x2)  || isempty(lbl_y2))
    out = m1;
    lbl_x = lbl_x1;
    lbl_y = lbl_y1;
    return;
end
% Rif(any(m2(:)))%determine first and last value for x & y
    lbl_x_min = min(lbl_x1(1),lbl_x2(1));
    lbl_x_max = max(lbl_x1(end),lbl_x2(end));
    lbl_y_min = min(lbl_y1(1),lbl_y2(1));
    lbl_y_max = max(lbl_y1(end),lbl_y2(end));
% else
%     lbl_x_min = lbl_x1(1);
%     lbl_x_max = lbl_x1(end);
%     lbl_y_min = lbl_y1(1);
%     lbl_y_max = lbl_y1(end);
% end
%determine matrix size
sx = ceil((lbl_x_max-lbl_x_min)/cw)+1;
sy = ceil((lbl_y_max-lbl_y_min)/cw)+1;
%allocate
out = zeros(sy,sx);
%determine indicies and write to resulting matrix
[y1, x1] = size(m1);
[y2, x2] = size(m2);
%matrix 1
x_low_o = 1 + round((lbl_x1(1)-lbl_x_min)/cw);
x_high_o = x_low_o + x1 - 1;
y_low_o = 1 + round((lbl_y1(1)-lbl_y_min)/cw);
y_high_o = y_low_o + y1 - 1;
out(y_low_o:y_high_o, x_low_o:x_high_o) = m1;
%matrix 2
%todo: separate ids for out and m2
x_low_diff = round((lbl_x2(1)-lbl_x_min)/cw);
if(x_low_diff > 0)
    %offset m2
    x_low_i = 1;
    x_low_o = 1 + x_low_diff;
    x_high_o = x_low_o + x2 - 1;
    x_high_i = x2;
else
    %cut m2
    x_low_i = -x_low_diff + 1;
    x_low_o = 1;
    x_high_o = min(sx,x2 - x_low_i + 1);
    x_high_i = x_high_o-x_low_o+x_low_i;
end

y_low_diff = round((lbl_y2(1)-lbl_y_min)/cw);
if(y_low_diff > 0)
    %offset m2
    y_low_i = 1;
    y_low_o = 1 + y_low_diff;    
    y_high_o = y_low_o + y2 - 1;
    y_high_i = y2;
else
    %cut m2
    y_low_i = -y_low_diff + 1;
    y_low_o = 1;
    y_high_o = min(sy,y2 - y_low_i + 1);
    y_high_i = y_high_o-y_low_o+y_low_i;
end
out(y_low_o:y_high_o, x_low_o:x_high_o) = out(y_low_o:y_high_o, x_low_o:x_high_o) + m2(y_low_i:y_high_i,x_low_i:x_high_i);
%make resuting labels
lbl_x = lbl_x_min : cw : lbl_x_max;
lbl_y = lbl_y_min : cw : lbl_y_max;