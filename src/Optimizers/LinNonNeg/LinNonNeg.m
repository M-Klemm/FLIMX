function x = LinNonNeg(C,d,tol) %,resnorm,resid,exitflag,output,lambda]
%=============================================================================================================
%
% @file     LinNonNeg.m
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
% @brief    A function to implement a non-negative linear optimizer based on MATLAB's lsqnonneg
%
tol = 10*eps(C(1,1))*sum(C(:),'native')*numel(C);
n = size(C,2);
% Initialize vector of n zeros and Infs (to be used later)
nZeros = zeros(n,1,'like',C);
wz = nZeros;

% Initialize set of non-active columns to null
P = false(n,1,'like',logical(d));
% Initialize set of active columns to all and the initial point to zeros
Z = true(n,1,'like',P);
%x = nZeros;
%guess initial solution
x = C\d;
if(any(x < 0))
    x = nZeros;
end
resid = d - C*x;
w = C'*resid;

% Set up iteration criterion
outeriter = zeros(1,1,'uint8');
iter = zeros(1,1,'uint8');
itmax = uint8(3*n); %ones(1,1,'like',C);
%             exitflag = 1;

% Outer loop to put variables into set to hold positive coefficients
while any(Z) && any(w(Z) > tol)
    outeriter = outeriter + 1;
    % Reset intermediate solution z
    z = nZeros;
    % Create wz, a Lagrange multiplier vector of variables in the zero set.
    % wz must have the same size as w to preserve the correct indices, so
    % set multipliers to -Inf for variables outside of the zero set.
    wz(P) = -Inf;
    wz(Z) = w(Z);
    % Find variable with largest Lagrange multiplier
    [~,t] = max(wz);
    % Move variable t from zero set to positive set
    P(t) = true;
    Z(t) = false;
    % Compute intermediate solution using only variables in positive set
    z(P) = C(:,P)\d;
    % inner loop to remove elements from the positive set which no longer belong
    while any(z(P) <= tol)
        iter = iter + 1;
        if iter > itmax
            %                         msg = sprintf(['Exiting: Iteration count is exceeded, exiting LSQNONNEG.', ...
            %                             '\n','Try raising the tolerance (OPTIONS.TolX).']);
            %                         if verbosity
            %                             disp(msg)
            %                         end
            %                         exitflag = 0;
            %                         output.iterations = outeriter;
            %                         output.message = msg;
            %                         output.algorithm = 'active-set';
            %                         resnorm = sum(resid.*resid);
            x = z;
            %                         lambda = w;
            return
        end
        % Find indices where intermediate solution z is approximately negative
        Q = (z <= tol) & P;
        % Choose new x subject to keeping new x nonnegative
        alpha = min(x(Q)./(x(Q) - z(Q)));
        x = x + alpha*(z - x);
        % Reset Z and P given intermediate values of x
        Z = ((abs(x) < tol) & P) | Z;
        P = ~Z;
        z = nZeros;           % Reset z
        z(P) = C(:,P)\d;      % Re-solve for z
    end
    x = z;
    resid = d - C*x;
    w = C'*resid;
end

%             lambda = w;
%             resnorm = resid'*resid;
%             output.iterations = outeriter;
%             output.algorithm = 'active-set';
%             msg = 'Optimization terminated.';
%             if verbosity > 1
%                 disp(msg)
%             end
%             output.message = msg;
end