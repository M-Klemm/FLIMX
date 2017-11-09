function [cw, lim, lb, ub] = getHistParams(statsParams,ch,dType,dID)
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
if(contains(dType,'MVGroup'))
    cw = channelSel(statsParams.c_classwidth,ch);
    lim = channelSel(statsParams.c_lim,ch);
    lb = channelSel(statsParams.c_lb,ch);
    ub = channelSel(statsParams.c_ub,ch);
    
    return
end

switch lower(dType)
    %                 case 'Intensity' %intensity
    %                     cw = channelSel(statsParams.classwidth_i;
    %                     lim = channelSel(statsParams.i_lim;
    %                     lb = channelSel(statsParams.i_lb;
    %                     ub = channelSel(statsParams.i_ub;
    case 'amplitudepercent'
        %amplitude percent
        if(dID < 4)
            cw = channelSel(statsParams.(sprintf('ampPer%d_classwidth',dID)),ch);
            lim = channelSel(statsParams.(sprintf('ampPer%d_lim',dID)),ch);
            lb = channelSel(statsParams.(sprintf('ampPer%d_lb',dID)),ch);
            ub = channelSel(statsParams.(sprintf('ampPer%d_ub',dID)),ch);
        else
            cw = channelSel(statsParams.ampPerN_classwidth,ch);
            lim = channelSel(statsParams.ampPerN_lim,ch);
            lb = channelSel(statsParams.ampPerN_lb,ch);
            ub = channelSel(statsParams.ampPerN_ub,ch);
        end
    case 'amplitude'
        if(dID < 4)
            cw = channelSel(statsParams.(sprintf('amp%d_classwidth',dID)),ch);
            lim = channelSel(statsParams.(sprintf('amp%d_lim',dID)),ch);
            lb = channelSel(statsParams.(sprintf('amp%d_lb',dID)),ch);
            ub = channelSel(statsParams.(sprintf('amp%d_ub',dID)),ch);
        else
            cw = channelSel(statsParams.ampN_classwidth,ch);
            lim = channelSel(statsParams.ampN_lim,ch);
            lb = channelSel(statsParams.ampN_lb,ch);
            ub = channelSel(statsParams.ampN_ub,ch);
        end
    case {'tau','tc'}
        if(dID < 4)
            cw = channelSel(statsParams.(sprintf('tau%d_classwidth',dID)),ch);
            lim = channelSel(statsParams.(sprintf('tau%d_lim',dID)),ch);
            lb = channelSel(statsParams.(sprintf('tau%d_lb',dID)),ch);
            ub = channelSel(statsParams.(sprintf('tau%d_ub',dID)),ch);
        else
            cw = channelSel(statsParams.tauN_classwidth,ch);
            lim = channelSel(statsParams.tauN_lim,ch);
            lb = channelSel(statsParams.tauN_lb,ch);
            ub = channelSel(statsParams.tauN_ub,ch);
        end
    case 'taumean'
        cw = channelSel(statsParams.tauMean_classwidth,ch);
        lim = channelSel(statsParams.tauMean_lim,ch);
        lb = channelSel(statsParams.tauMean_lb,ch);
        ub = channelSel(statsParams.tauMean_ub,ch);
    case 'q'
        if(dID < 4)
            cw = channelSel(statsParams.(sprintf('q%d_classwidth',dID)),ch);
            lim = channelSel(statsParams.(sprintf('q%d_lim',dID)),ch);
            lb = channelSel(statsParams.(sprintf('q%d_lb',dID)),ch);
            ub = channelSel(statsParams.(sprintf('q%d_ub',dID)),ch);
        else
            cw = channelSel(statsParams.qN_classwidth,ch);
            lim = channelSel(statsParams.qN_lim,ch);
            lb = channelSel(statsParams.qN_lb,ch);
            ub = channelSel(statsParams.qN_ub,ch);
        end
    otherwise
        cw = channelSel(statsParams.o_classwidth,ch);
        lim = channelSel(statsParams.o_lim,ch);
        lb = channelSel(statsParams.o_lb,ch);
        ub = channelSel(statsParams.o_ub,ch);    
end

function out = channelSel(in,ch)
    %select parameter in specific channel
    if(length(in) < ch)
        out = in(1);
    else
        out = in(ch);
    end    
end
end