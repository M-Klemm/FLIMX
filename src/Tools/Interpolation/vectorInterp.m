function Y = vectorInterp(Y,xi)
%=============================================================================================================
%
% @file     vectorInterp.m
% @author   Matthias Klemm <Matthias_Klemm@gmx.net>
% @version  1.0
% @date     June, 2018
%
% @section  LICENSE
%
% Copyright (C) 2018, Matthias Klemm. All rights reserved.
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
% @brief    A function to interpolate values in each column in array Y by xi (-1 <= xi <= 1)

xi = xi(:)';
idxNonZero = abs(xi) > eps;
if(~any(idxNonZero))
    return
end
%out = NaN(size(Y),'like',Y);
negFlag = xi<0; %flag of negative shifts
xi(negFlag) = xi(negFlag)+1;
%idxFirstRowOverflow = ~negFlag(1,:) & sum(negFlag,1) == size(Y,1)-1;
%idxLastRowOverflow = ~flag(end,:) & sum(flag,1) == length(x)-1;
%out(1,idxFirstRowOverflow) = Y(1,idxFirstRowOverflow);
%out(end,idxLastRowOverflow) = Y(end,idxLastRowOverflow);
%out(end,:) = Y(end,:);
%out(:,~idxNonZero) = Y(:,~idxNonZero);
idxPosShift = ~negFlag & idxNonZero;
idxNegShift = negFlag & idxNonZero;
if(any(idxPosShift(:)))
    %Y(1:end-1,idxPosShift) = (1-xi(idxPosShift)).*Y(1:end-1,idxPosShift) + (xi(idxPosShift)).*Y(2:end,idxPosShift);
    Y(1:end-1,idxPosShift) = bsxfun(@times,Y(1:end-1,idxPosShift),(1-xi(idxPosShift))) + bsxfun(@times,Y(2:end,idxPosShift),(xi(idxPosShift)));
end
if(any(idxNegShift(:)))
    %Y(2:end,idxNegShift) = (1-xi(idxNegShift)).*Y(1:end-1,idxNegShift) + (xi(idxNegShift)).*Y(2:end,idxNegShift);
    Y(2:end,idxNegShift) = bsxfun(@times,Y(1:end-1,idxNegShift),(1-xi(idxNegShift))) + bsxfun(@times,Y(2:end,idxNegShift),(xi(idxNegShift)));
end

end