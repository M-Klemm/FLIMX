function [cw, lim, lb, ub] = getHistParams(statsParams,dType,dID)
%=============================================================================================================
%
% @file     getHistParams.m
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
% @brief    A function to extract histogram parameters from a structure for use in FLIMXVis
%
if(~isempty(strfind(dType,'MVGroup')))
    cw = statsParams.c_classwidth;
    lim = statsParams.c_lim;
    lb = statsParams.c_lb;
    ub = statsParams.c_ub;
    return
end

switch lower(dType)
    %                 case 'Intensity' %intensity
    %                     cw = statsParams.classwidth_i;
    %                     lim = statsParams.i_lim;
    %                     lb = statsParams.i_lb;
    %                     ub = statsParams.i_ub;
    case 'amplitudepercent'
        %amplitude percent
        if(dID < 4)
            cw = statsParams.(sprintf('ampPer%d_classwidth',dID));
            lim = statsParams.(sprintf('ampPer%d_lim',dID));
            lb = statsParams.(sprintf('ampPer%d_lb',dID));
            ub = statsParams.(sprintf('ampPer%d_ub',dID));
        else
            cw = statsParams.ampPerN_classwidth;
            lim = statsParams.ampPerN_lim;
            lb = statsParams.ampPerN_lb;
            ub = statsParams.ampPerN_ub;
        end
    case 'amplitude'
        if(dID < 4)
            cw = statsParams.(sprintf('amp%d_classwidth',dID));
            lim = statsParams.(sprintf('amp%d_lim',dID));
            lb = statsParams.(sprintf('amp%d_lb',dID));
            ub = statsParams.(sprintf('amp%d_ub',dID));
        else
            cw = statsParams.ampN_classwidth;
            lim = statsParams.ampN_lim;
            lb = statsParams.ampN_lb;
            ub = statsParams.ampN_ub;
        end
    case {'tau','tc'}
        if(dID < 4)
            cw = statsParams.(sprintf('tau%d_classwidth',dID));
            lim = statsParams.(sprintf('tau%d_lim',dID));
            lb = statsParams.(sprintf('tau%d_lb',dID));
            ub = statsParams.(sprintf('tau%d_ub',dID));
        else
            cw = statsParams.tauN_classwidth;
            lim = statsParams.tauN_lim;
            lb = statsParams.tauN_lb;
            ub = statsParams.tauN_ub;
        end
    case 'taumean'
        cw = statsParams.tauMean_classwidth;
        lim = statsParams.tauMean_lim;
        lb = statsParams.tauMean_lb;
        ub = statsParams.tauMean_ub;
    case 'q'
        if(dID < 4)
            cw = statsParams.(sprintf('q%d_classwidth',dID));
            lim = statsParams.(sprintf('q%d_lim',dID));
            lb = statsParams.(sprintf('q%d_lb',dID));
            ub = statsParams.(sprintf('q%d_ub',dID));
        else
            cw = statsParams.qN_classwidth;
            lim = statsParams.qN_lim;
            lb = statsParams.qN_lb;
            ub = statsParams.qN_ub;
        end
    otherwise
        cw = statsParams.o_classwidth;
        lim = statsParams.o_lim;
        lb = statsParams.o_lb;
        ub = statsParams.o_ub;    
end