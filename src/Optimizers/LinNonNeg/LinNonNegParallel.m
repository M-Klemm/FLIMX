function x = LinNonNegParallel(C,d,tol) %,resnorm,resid,exitflag,output,lambda]
%=============================================================================================================
%
% @file     LinNonNegParallel.m
% @author   Matthias Klemm <Matthias_Klemm@gmx.net>
% @version  2.0
% @date     March, 2021
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
if(isa(C,'gpuArray'))
    gpuFlag = true;
else
    gpuFlag = false;
end
%nModels = (nModels); 
nVecs = uint16(nVecs);
if(gpuFlag)
    Ccpu = gather(C);
else
    Ccpu = C;
end
tol = repmat(10*eps(Ccpu(1,1))*squeeze(sum(Ccpu,[1,2],'native'))*nTime*nModels,[1,nModels])';
% Initialize vector of n zeros and Infs (to be used later)
nZeros = zeros(nModels,nVecs,underlyingType(C));
wz = nZeros;
idxOffsetVec = reshape(1:nModels*nVecs,[nModels,nVecs]);
idxOffsetVec = idxOffsetVec(1,:);
% Initialize set of non-active columns to null
P = false(nModels,nVecs,'logical');
% Initialize set of active columns to all and the initial point to zeros
Z = true(nModels,nVecs,'like',P);
% x = nZeros;
% resid = zeros(size(d),'like',d);
% w = wz;
%guess initial solution
if(gpuFlag)
    x = gather(pagefun(@mldivide,C,d));
else
    for i = nVecs:-1:1
        Ct(i).e = C(:,:,i);
        Ct(i).d = d(:,:,i);
    end
    x = zeros(nModels,1,nVecs,'like',C);
    x(:,1,:) = cell2mat(arrayfun(@(x) mldivide(x.e,x.d),Ct,'UniformOutput',false));
end
x(:,:,squeeze(any(x < 0))) = 0;
% for i = 1:nVecs
%     x(:,i) = C(:,:,i)\d(:,i);
%     if(any(x(:,i) < 0))
%         x(:,i) = 0;
%     end
%     resid(:,i) = d(:,i) - C(:,:,i)*x(:,i);
%     w(:,i) = C(:,:,i)'*resid(:,1,i);
% end

resid = d - pagemtimes(C,x);
w = gather(squeeze(pagemtimes(permute(C,[2,1,3]),resid)));
% x2 = zeros(3,1,1024);
% x2(:,1,:) = x;
% tmp = pagefun(@mtimes,gpuArray(single(C(:,:,1:100))),gpuArray(single(x2(:,:,1:100))));
% Set up iteration criterion
outeriter = 0; % zeros(1,nVecs,'uint8');
iter = zeros(1,nVecs,'uint8');
iterAtMax = false(1,nVecs);
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
    % Move variable t from zero set to positive set
    P(idxOffsetVec+uint16(t)-1) = true;
    Z(idxOffsetVec+uint16(t)-1) = false;
    % Compute intermediate solution using only variables in positive set
    
    sols = sum(P,1);
    uSols = unique(sols);
    uSols(uSols < 1) = [];
    for i = 1:length(uSols)
        idxSol = sols == uSols(i);
        nSol = sum(idxSol);
        Ptmp = reshape(P(:,idxSol),[1,nModels*nSol]);        
        if(gpuFlag)
            Ctmp = reshape(C(:,:,idxSol),[nTime,nModels*nSol]);
            z(P(:,idxSol)) = gather(pagefun(@mldivide,reshape(Ctmp(:,Ptmp),[nTime,uSols(i),nSol]),d(:,:,idxSol)));
        else
            for j = length(idxSol):-1:1
                if(idxSol(j))
                    Ct(j).P = P(:,j);
                end
            end
            z(P(:,idxSol)) = cell2mat(arrayfun(@(x) mldivide(x.e(:,x.P),x.d),Ct(idxSol),'UniformOutput',false));
        end        
%         Ctmp = Ctmp(:,Ptmp);
%         Ctmp = reshape(Ctmp,[nTime,uSols(i),nSol]);
%         C(:,:,idxSol) = Ctmp;
%         z(P) = pagefun(@mldivide,Ctmp,d(:,:,idxSol));
        %P = reshape(Ptmp,[nModels,nSol]);
    end
%     Pt = P;
%     Pt(:,~idxOne) = false;
%     Pt = reshape(Pt,[],1);
    %Z(Pt) = Ct(Pt,:)'\d(:,idxOne);
    %z(P) = pagefun(@mldivide,Ctmp,d(:,:,idxSol));
    
    % inner loop to remove elements from the positive set which no longer belong
    idxInner = any(z <= tol & P,1) & ~iterAtMax;
    while any(idxInner)
        iter(idxInner) = iter(idxInner) + 1;
        if(any(iter > itmax)) %TODO!
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
            x(:,:,idxInner) = z(:,idxInner);
            %                         lambda = w;
            %return
            iterAtMax(idxInner) = true;
            if(all(iterAtMax(:)))
                return
            end
        end
        % Find indices where intermediate solution z is approximately negative
        xInner = gather(squeeze(x(:,:,idxInner)));
        zInner = z(:,idxInner);
        %nInner = sum(idxInner(:));
        Q = (zInner <= tol(:,idxInner)) & P(:,idxInner);
        % Choose new x subject to keeping new x nonnegative
        tmpInner = xInner ./ (xInner - zInner);
        tmpInner(~Q) = NaN;
        alpha = min(tmpInner,[],1,'omitnan');        
        xInner = xInner + alpha.*(zInner - xInner);
        % Reset Z and P given intermediate values of x
        Z(:,idxInner) = ((abs(xInner) < tol(:,idxInner)) & P(:,idxInner)) | Z(:,idxInner);
        P(:,idxInner) = ~Z(:,idxInner);
        zInner = nZeros(:,idxInner);           % Reset z
%         Cinner = C(:,:,idxInner);
%         Pinner = reshape(P(:,idxInner),[1,nModels*nInner]);
%         Cinner = reshape(Cinner,[nTime,nModels*nInner]);
%         Cinner = Cinner(:,Pinner);
%         Cinner = reshape(Cinner,[nTime,size(Cinner,2)/nInner,nInner]);
%         Pinner = reshape(Pinner,[nModels,nInner]);
%         zInner(Pinner) = pagefun(@mldivide,Cinner,d(:,:,idxInner));
        
        Pinner = P(:,idxInner);
        if(gpuFlag)
            Cinner = Ccpu(:,:,idxInner);
        else
            for j = length(idxInner):-1:1
                if(idxInner(j))
                    Ct(j).P = P(:,j);
                end
            end
            Cinner = Ct(idxInner);            
        end
        sols = sum(P(:,idxInner),1);
        uSols = unique(sols);
        uSols(uSols < 1) = [];
        for i = 1:length(uSols)
            idxSol = sols == uSols(i);
            nSol = sum(idxSol);
            Ptmp = reshape(Pinner(:,idxSol),[1,nModels*nSol]);
            if(gpuFlag)
                Ctmp = reshape(Cinner(:,:,idxSol),[nTime,nModels*nSol]);
                zInner(Pinner(:,idxSol)) = pagefun(@mldivide,reshape(Ctmp(:,Ptmp),[nTime,uSols(i),nSol]),d(:,:,idxSol));
            else
                zInner(Pinner(:,idxSol)) = cell2mat(arrayfun(@(x) mldivide(x.e(:,x.P),x.d),Cinner(idxSol),'UniformOutput',false));
            end
            %         Ctmp = Ctmp(:,Ptmp);
            %         Ctmp = reshape(Ctmp,[nTime,uSols(i),nSol]);
            %         C(:,:,idxSol) = Ctmp;
            %         z(P) = pagefun(@mldivide,Ctmp,d(:,:,idxSol));
            %P = reshape(Ptmp,[nModels,nSol]);
        end
    
        %z(P) = C(:,P)\d;      % Re-solve for z
        z(:,idxInner) = zInner;
        idxInner = any(z <= tol & P,1) & ~iterAtMax;
    end
    x(:,:,:) = z;
    %resid = d - C*x;
    resid = d - pagemtimes(C,x);
    %w = C'*resid;
    w = gather(squeeze(pagemtimes(permute(C,[2,1,3]),resid)));
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