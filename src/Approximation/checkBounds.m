function x = checkBounds(x,lb,ub)
%=============================================================================================================
%
% @file     checkBounds.m
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
% @brief    A function to make sure x (size = nParams x nPop) is between lower (lb) and upper (ub) bound
%#codegen
idx = x < lb;
x(idx) = lb(idx);
idx = x > ub;
x(idx) = ub(idx);

% [~,NP,nPixels] = size(x);
% if(isa(x,'gpuArray'))
%     NP = gpuArray(NP);
%     nPixels = gpuArray(nPixels);
% end
% for i = 1:NP
%     for p = 1:nPixels
%         idx = x(:,i,p) < lb(:,p);
%         x(idx,i,p) = lb(idx,p);
%         idx = x(:,i,p) > ub(:,p);
%         x(idx,i,p) = ub(idx,p);
%     end
% end

% if(NP > 1)
%     lbM = repmat(lb(:),[1,NP,1]);
%     ubM = repmat(ub(:),1,NP);
%     idx = x < lbM;
%     x(idx) = lbM(idx);
%     idx = x > ubM;
%     x(idx) = ubM(idx);
% else
%     idx = x < lb;
%     x(idx) = lb(idx);
%     idx = x > ub;
%     x(idx) = ub(idx);
% end