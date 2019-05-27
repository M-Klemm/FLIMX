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
[nTime,nModels,nVecs] = size(C);
nModels = uint16(nModels); nVecs = uint16(nVecs);
tol = repmat(10*eps(C(1,1))*squeeze(sum(C,[1,2],'native'))*nTime*nModels,[1,nModels]);
% Initialize vector of n zeros and Infs (to be used later)
nZeros = zeros(nModels,nVecs,'like',C);
wz = nZeros;
idxOffsetVec = reshape(1:nModels*nVecs,[nModels,nVecs]);
idxOffsetVec = idxOffsetVec(1,:);
% Initialize set of non-active columns to null
P = false(nModels,nVecs,'like',logical(d));
% Initialize set of active columns to all and the initial point to zeros
Z = true(nModels,nVecs,'like',P);
x = nZeros;
resid = zeros(size(d),'like',d);
w = wz;
%guess initial solution
for i = 1:nVecs
    x(:,i) = C(:,:,i)\d(:,i);
    if(any(x(:,i) < 0))
        x(:,i) = 0;
    end
    resid(:,i) = d(:,i) - C(:,:,i)*x(:,i);
    w(:,i) = C(:,:,i)'*resid(:,i);
end
% x2 = zeros(3,1,1024);
% x2(:,1,:) = x;
% tmp = pagefun(@mtimes,gpuArray(single(C(:,:,1:100))),gpuArray(single(x2(:,:,1:100))));
% Set up iteration criterion
outeriter = zeros(1,nVecs,'uint8');
iter = zeros(1,nVecs,'uint8');
itmax = uint8(3*nModels); %ones(1,1,'like',C);
%             exitflag = 1;

idx = any(Z) & any(w(Z) > tol(Z));
% Outer loop to put variables into set to hold positive coefficients
while any(idx)
    outeriter = outeriter + 1;
    % Reset intermediate solution z
    z = nZeros;
    % Create wz, a Lagrange multiplier vector of variables in the zero set.
    % wz must have the same size as w to preserve the correct indices, so
    % set multipliers to -Inf for variables outside of the zero set.
    wz(P) = -Inf;
    wz(Z) = w(Z);
    % Find variable with largest Lagrange multiplier
    [~,t] = max(wz,[],1);
    t = uint16(t);
    % Move variable t from zero set to positive set
    P(idxOffsetVec+t-1) = true;
    Z(idxOffsetVec+t-1) = false;
    % Compute intermediate solution using only variables in positive set
    idxOne = sum(P,1) == 1;
    Pt = P;
    Pt(:,~idxOne) = false;
    Ct = reshape(C,[nTime*nModels,nVecs]);
    Pt = reshape(Pt,[],1);
    Z(Pt) = Ct(Pt,:)'\d(:,idxOne);
    
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
    idx = any(Z) & any(w(Z) > tol(Z));
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