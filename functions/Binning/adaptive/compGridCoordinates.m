function [roiX, roiY] = compGridCoordinates(roiCoord,gridSz)
%=============================================================================================================
%
% @file     compGridCoordinates.m
% @author   Matthias Klemm <Matthias_Klemm@gmx.net>
% @version  1.0
% @date     August, 2015
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
% @brief    A function to compute grid coordinates inside ROI for a certain grid size (0 means all points)
%
roiCoord = int32(roiCoord);
gridSz = int32(gridSz);
if(gridSz == 0)
    roiX = roiCoord(1):roiCoord(2);
    roiY = roiCoord(3):roiCoord(4); 
elseif(gridSz == 1)
    roiX = int32(floor(round(mean([roiCoord(2),roiCoord(1)]))));
    roiY = int32(floor(round(mean([roiCoord(4),roiCoord(3)]))));
else
    roiCoord = double(roiCoord);
    gridSz = double(gridSz);
    roiX = int32(roiCoord(1):floor((roiCoord(2)-roiCoord(1))/(gridSz-1)):roiCoord(2));
    roiY = int32(roiCoord(3):floor((roiCoord(4)-roiCoord(3))/(gridSz-1)):roiCoord(4));
end