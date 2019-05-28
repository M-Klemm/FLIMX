function [x,fcnEvalCount,exitflag,output] = MSimplexBnd(costFcn,x,options,pixelIDs,varargin)
%=============================================================================================================
%
% @file     MSimplexBnd.m
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
% @brief    based on Matlab's FMINSEARCH Multidimensional unconstrained nonlinear minimization (Nelder-Mead).
%
% % Detect problem structure input
% if nargin == 1
%     if isa(costFcn,'struct')
%         [costFcn,x,options] = separateOptimStruct(costFcn);
%     else % Single input and non-structure
%         error('MATLAB:fminsearch:InputArg','The input to MSimplexBnd should be either a structure with valid fields or consist of at least two arguments.');
%     end
% end
%
% if nargin == 0
%     error('MATLAB:fminsearch:NotEnoughInputs',...
%         'MSimplexBnd requires at least two input arguments');
% end
%
% % Check for non-double inputs
% if ~isa(x,'double') && ~isa(x,'single')
%     error('MATLAB:fminsearch:NonDoubleInput', ...
%         'MSimplexBnd only accepts inputs of data type double or single.')
% end

[nParams, nSeeds, nPixels] = size(x);
if(nPixels ~= length(pixelIDs))
    error('FLIMX:MSimplexBnd','Number of pixels in starting point(%d) and pixelIDs(%d) do not match.',size(x,3),length(pixelIDs));
end
% if(m > n)
%     x = x';
%     [n m] = size(x);
% end
%x = mean(x,2);

tStart = 0;%clock;
userbreak = false;

lb = cast([options.lb],'like',x);
lbShrink = reshape(repmat(lb,[nSeeds*(nParams+1),1,1]),[nParams,size(lb,2)*nSeeds,nParams+1]);
ub = cast([options.ub],'like',x);
ubShrink = reshape(repmat(ub,[nSeeds*(nParams+1),1,1]),[nParams,size(ub,2)*nSeeds,nParams+1]);
si = cast([options.simplexInit],'like',x);
quant = cast([options.quantization],'like',x);
quantShrink = reshape(repmat(quant,[nSeeds*(nParams+1),1,1]),[nParams,size(quant,2)*nSeeds,nParams+1]);
tolf = repmat(max([options.TolFun],10*eps(x(1))),[1,nSeeds]);
tol = repmat(cast([options.tol],'like',x),[1,nSeeds]);
maxfun = repmat(cast([options.MaxFunEvals],'uint16'),[1,nSeeds]);
maxiter = repmat(cast([options.MaxIter],'uint16'),[1,nSeeds]);
if(~isfield(options,'iterPostProcess')) 
    hIterPostProcess = [];
else
    hIterPostProcess = options(1).iterPostProcess;
end

% Following improvement suggested by L.Pfeffer at Stanford
% usual_delta = 0.50;             % 5 percent deltas for non-zero terms
% zero_term_delta = 0.00025;      % Even smaller delta for zero elements of x

% % In case the defaults were gathered from calling: optimset('fminsearch'):
%
% if ischar(maxfun)
%     if isequal(lower(maxfun),'200*numberofvariables')
%         maxfun = 200*n;
%     else
%         error('MATLAB:fminsearch:OptMaxFunEvalsNotInteger',...
%             'Option ''MaxFunEvals'' must be an integer value if not the default.')
%     end
% end
% if ischar(maxiter)
%     if isequal(lower(maxiter),'200*numberofvariables')
%         maxiter = 200*n;
%     else
%         error('MATLAB:fminsearch:OptMaxIterNotInteger',...
%             'Option ''MaxIter'' must be an integer value if not the default.')
%     end
% end

% Set up a simplex near the initial guess.
for s = 1:nSeeds
    x(:,s,:) = checkBounds(checkQuantization(squeeze(x(:,s,:)),quant(:,pixelIDs),lb(:,pixelIDs)),lb(:,pixelIDs),ub(:,pixelIDs));
end
iterCount = ones(1,nPixels,'uint16');
fcnEvalCount = zeros(1,nPixels,'uint16');

if(nSeeds > 1)
    x = reshape(x,[nParams,nSeeds*nPixels]);
    newPIs = reshape(repmat(pixelIDs,nSeeds,1),[1,nSeeds*nPixels]);
    switch options(1).multipleSeedsMode
        case 1 %best seed function value
            fv = costFcn(x,newPIs,varargin{:});
            fcnEvalCount = fcnEvalCount + nSeeds;
            fv = reshape(fv,nSeeds,nPixels);
            [~,bestSeeds] = min(fv,[],1);
            id = false(size(fv));
            for nx = 1:nSeeds
                id(nx,bestSeeds == nx) = true;
            end
            id = reshape(id,[1,nSeeds*nPixels]);
            x = x(:,id);
            [vTmp, fvTmp] = init(x,pixelIDs);
            [x,~,exitflag,iterCnt,feCnt] = mainAlgorithm(vTmp,fvTmp,pixelIDs);
        case 2
            %select best n+1 from all seeds
            [vTmp, fvTmp] = init(x,newPIs);
            for nx = 1:pixelIDs
                %todo: reshape for single pixels and do the below for each pixel
                [~,id] = sort(fvTmp(:));
                v = reshape(vTmp,nParams,[]);
                ci = v(:,id(1:nParams+1));
                fv = zeros(1,nParams+1);
            end
            [x,~,exitflag,iterCnt,feCnt] = mainAlgorithm(v,fv,pixelIDs);
        case 3 %compute all seeds           
            [vTmp, fvTmp] = init(x,newPIs);
            %seedIDs = repmat(1:nSeeds,1,nPixels);
            [x,fv,exitflag,iterCnt,feCnt] = mainAlgorithm(vTmp,fvTmp,newPIs);
            fv = reshape(fv,nSeeds,nPixels);
            iterCnt = reshape(iterCnt,nSeeds,nPixels);
            feCnt = reshape(feCnt,nSeeds,nPixels);
            [~,bestSeeds] = min(fv,[],1);
            id = false(size(fv));
            for nx = 1:nSeeds
                id(nx,bestSeeds == nx) = true;
            end
            id = reshape(id,[1,nSeeds*nPixels]);
            x = x(:,id);            
        case 4 %mean of seeds
            x = reshape(x,[nParams,nSeeds,nPixels]);
            [vTmp, fvTmp] = init(squeeze(mean(x,2)),pixelIDs);
            [x,~,exitflag,iterCnt,feCnt] = mainAlgorithm(vTmp,fvTmp,pixelIDs);
    end
else
    [vTmp, fvTmp] = init(squeeze(x),pixelIDs);
    [x,~,exitflag,iterCnt,feCnt] = mainAlgorithm(vTmp,fvTmp,pixelIDs);
end
iterCount = iterCount + sum(iterCnt,1,'native');
fcnEvalCount = fcnEvalCount + sum(feCnt,1,'native');
output.iterations = iterCount;
output.funcCount = fcnEvalCount;

% [x,func_evals,exitflag,output] = mainAlgorithm(v,fv,itercount);

    function [v, fv] = init(x,pixelIDs)
        %make simplex initialization
        nPIs = length(pixelIDs);
        sortIDCache = repmat(uint16(1:nParams+1),nPIs,1);
        v = zeros(nParams,nPIs,nParams+1,'like',x);
        v(:,:,1) = x;
        fv = zeros(nPIs,nParams+1,'like',x);
        fv(:,1) = costFcn(x,pixelIDs,varargin{:});
        fcnEvalCount = fcnEvalCount + nSeeds;
        initPIs = repmat(pixelIDs,1,8);
        %xvec = []; %zeros(1,8*nPIs);
        fv_tmp = zeros(1,8*nPIs,'like',x);        
        for i = 1:nParams
            xmat = repmat(x,[1,8]);
            pixelIDMask = true(size(initPIs));
            %determine shift of x(i)
            %maximum of: 10% of value (behavior if finminsearch); 1% of parameter interval; 2x quantization; user defined value
            dx = min([abs(ub(i,pixelIDs)-lb(i,pixelIDs))/2;max([abs(x(i,:)*0.90); abs(ub(i,pixelIDs)-lb(i,pixelIDs))/10; 2*quant(i,pixelIDs);],[],1);],[],1);%, si(i)]);
            xLow = -dx;%max(-dx,lb(i));%
            xHigh = dx;%min(dx,ub(i));%
            trials = 0; %we have 100 trials to find good starting values per parameter (prevent endless loop)
            xvec = [xLow+x(i,:) xHigh+x(i,:) si(i,pixelIDs)+xLow si(i,pixelIDs)+xHigh x(i,:)*1.50 x(i,:)*0.50 x(i,:)*1.10 x(i,:)*0.90];
            while(true)
                trials = trials +1;
                changeFlag = false(size(pixelIDMask));
                if(any(quant(i,:)))
                    xvec(pixelIDMask) = checkBounds(checkQuantization(xvec(pixelIDMask),quant(i,initPIs(pixelIDMask)),lb(i,initPIs(pixelIDMask))),lb(i,initPIs(pixelIDMask)),ub(i,initPIs(pixelIDMask)));
                else
                    xvec(pixelIDMask) = checkBounds(xvec(pixelIDMask),lb(i,initPIs(pixelIDMask)),ub(i,initPIs(pixelIDMask)));
                end
                %check if values are exactly at the borders
                idx = abs(xvec - lb(i,initPIs)) <= eps | abs(xvec - xmat(i,:)) <= eps('single'); %ismembertol(xvec,x(i,:),eps('single')); %& abs(xvec(:) - x(i,:)) > eps;
                shift = max(quant(i,initPIs),abs(ub(i,initPIs)-lb(i,initPIs))/100);
                if(any(idx))
                    %increase lower shift value
                    %xLow = xLow(initPIs(idx)) + shift(pixelIDs(idx)); %max(quant(i),abs(ub(i)-lb(i))/100);
                    xvec(idx) = xvec(idx) + (0.5+0.5*rand(1,sum(idx))).*shift(idx);
                    changeFlag = changeFlag | idx;
                end
                idx = abs(xvec - ub(i,initPIs)) <= eps | abs(xvec - xmat(i,:)) <= eps('single'); %ismembertol(xvec,x(i,:),eps('single')); %& abs(xvec(:) - x(i)) > eps;
                if(any(idx))
                    %decrease upper shift value
                    %xHigh = xHigh - shift(pixelIDs); %max(quant(i),abs(ub(i)-lb(i))/100);
                    xvec(idx) = xvec(idx) - (0.5+0.5*rand(1,sum(idx))).*shift(idx);
                    changeFlag = changeFlag | idx;
                end
                if(~any(changeFlag) || trials > 100)                    
                    break
                end
                pixelIDMask = changeFlag;
            end
            %compute cost function values
            xmat(i,:) = xvec;
            fv_tmp(1,:) = costFcn(xmat,initPIs,varargin{:});
            fv_tmp = reshape(fv_tmp,[nPIs,8]);
            fcnEvalCount = fcnEvalCount + 8;
            %                 if(fv_tmp(1) == inf)
            %                     %this might be a tau and we might be to close to the previous tau
            %                     xLow = min(xHigh - abs(x(i)*0.10),xLow + max(quant(i),abs(ub(i)-lb(i))/100));
            %                     changeFlag = true;
            %                 end
            %                 if(fv_tmp(2) == inf)
            %                     %this might be a tau and we might be to close to the next tau
            %                     xHigh = max(xLow + abs(x(i)*0.10),xHigh - max(quant(i),abs(ub(i)-lb(i))/100));
            %                     changeFlag = true;
            %                 end
            
            [fv(:,i+1),idx] = min(fv_tmp,[],2);
            fv_tmp = reshape(fv_tmp,[1,nPIs*8]);
            %             for j = 1:length(fv_tmp)-1
            %                 if(abs(fv(1) - fv_tmp(idx)) < fv(1)*0.05 || isinf(fv_tmp(idx)))
            %                     %difference of function value in comparison to initial solution is smaller than 5% -> use biggest distance to initial solution
            %                     fv_tmp(idx) = inf;
            %                     [~,idx] = min(fv_tmp);
            %                     %[~,idx] = max(abs(xvec - x(i)));
            %                 else
            %                     break
            %                 end
            %             end
            %fv(1,i+1,:) = fv_tmp(:,idx');
            %[fv(i+1) idx] = min(fv_tmp); %use best cost function value
            xmat = reshape(xmat,[nParams,nPIs,8]);
            for p = 1:nPIs
                v(:,p,i+1) = xmat(:,p,idx(p));
            end
        end
        %clear xmat xvec dx fv_tmp
        % sort so v(1,:) has the lowest function value
        [fv,sortIDs] = sort(fv,2);
        sortMask = ~all(uint16(sortIDs) == sortIDCache,2);
        for p = 1:nPIs
            if(sortMask(p))
                v(:,p,:) = v(:,p,sortIDs(p,:));
            end
        end
    end

    function [x,fval,exitflag,iterCount,fcnEvalCount] = mainAlgorithm(v,fv,pixelIDs)
        
        % Main algorithm: iterate until
        % (a) the maximum coordinate difference between the current best point and the
        % other points in the simplex is less than or equal to TolX. Specifically,
        % until max(||v2-v1||,||v2-v1||,...,||v(n+1)-v1||) <= TolX,
        % where ||.|| is the infinity-norm, and v1 holds the
        % vertex with the current lowest value; AND
        % (b) the corresponding difference in function values is less than or equal
        % to TolFun. (Cannot use OR instead of AND.)
        % The iteration stops if the maximum number of iterations or function evaluations
        % are exceeded
        
        % Initialize parameters
        nPIs = uint16(length(pixelIDs));
        rho = ones(1,1,'like',v); chi = 2*rho; psi = 0.5*rho; sigma = 0.5*rho;
        iterCount = ones(1,nPIs,'uint16');
        fcnEvalCount = zeros(1,nPIs,'uint16');
        onesn = ones(1,nParams,'uint8');
        two2np1 = uint8(2:nParams+1);
        one2n = uint8(1:nParams);
        totalPIDs = uint16(length(pixelIDs));
        pixelIDMask = true(size(pixelIDs));
        sortIDCache = repmat(uint16(1:nParams+1),nPIs,1);
        allPIPos = uint16(1:length(pixelIDMask));
        nSeeds = uint16(totalPIDs / length(unique(pixelIDs)));
        nPixels = uint16(totalPIDs / nSeeds);        
        
        %while(all(fcnEvalCount < maxfun(pixelIDs)) && all(iterCount < maxiter(pixelIDs)) && any(max(abs(fv(:,1)-fv(:,two2np1))',[],1) > tolf(pixelIDs) | any(max(abs(v(:,:,two2np1)-v(:,:,onesn)),[],3) > tol(:,pixelIDs))))
        while(any(pixelIDMask))
            %disp(sprintf('tolf: %02.3f; tolx: %02.2f',max(abs(fv(1)-fv(two2np1))), max(max(abs(v(:,two2np1)-v(:,onesn))))));
            %     if max(abs(fv(1)-fv(two2np1))) <= max(tolf,10*eps(fv(1))) && ...
            %             max(max(abs(v(:,two2np1)-v(:,onesn)))) <= max(tolx,10*eps(max(v(:,1))))
            %         break
            %     end            
            curPIs = pixelIDs(pixelIDMask);
            curPIPos = allPIPos(pixelIDMask);
            % Compute the reflection point
            % xbar = average of the n (NOT n+1) best points
            xbar = mean(v(:,pixelIDMask,one2n), 3,'native');
            xr = checkBounds(checkQuantization((1 + rho)*xbar - rho*v(:,pixelIDMask,end),quant(:,curPIs),lb(:,curPIs)),lb(:,curPIs),ub(:,curPIs));
            fxr = costFcn(xr,curPIs,varargin{:});
            fcnEvalCount(pixelIDMask) = fcnEvalCount(pixelIDMask)+1;
            idxXRltFV1 = fxr(:) < fv(pixelIDMask,1);
            if(any(idxXRltFV1))%if fxr < fv(:,1)
                % Calculate the expansion point
                tmpPIPos = curPIPos(idxXRltFV1);
                xe = checkBounds(checkQuantization((1 + rho*chi)*xbar(:,idxXRltFV1) - rho*chi*v(:,tmpPIPos,end),quant(:,curPIs(idxXRltFV1)),lb(:,curPIs(idxXRltFV1))),lb(:,curPIs(idxXRltFV1)),ub(:,curPIs(idxXRltFV1)));
                fxe = costFcn(xe,curPIs(idxXRltFV1),varargin{:});
                fcnEvalCount(tmpPIPos) = fcnEvalCount(tmpPIPos)+1;
                
                idxXEltXR = fxe < fxr(idxXRltFV1);
                if(any(idxXEltXR))%if fxe < fxr
                    v(:,tmpPIPos(idxXEltXR),end) = xe(:,idxXEltXR);
                    fv(tmpPIPos(idxXEltXR),end) = fxe(idxXEltXR);
                    %how = 'expand';
                end
                if(any(~idxXEltXR)) %else
                    idxXR2 = idxXRltFV1;
                    idxXR2(idxXR2) = ~idxXEltXR;
                    v(:,tmpPIPos(~idxXEltXR),end) = xr(:,idxXR2);
                    fv(tmpPIPos(~idxXEltXR),end) = fxr(idxXR2); 
                    %how = 'reflect';
                end
            end
            if(any(~idxXRltFV1))%else % fv(:,1) <= fxr
                idxXRltFVn = fxr(:) < fv(pixelIDMask,nParams) & ~idxXRltFV1;
                if(any(idxXRltFVn))%if fxr < fv(:,nParams)
                    v(:,curPIPos(idxXRltFVn),end) = xr(:,idxXRltFVn);
                    fv(curPIPos(idxXRltFVn),end) = fxr(idxXRltFVn);
                    %how = 'reflect';
                end
                idxXRgtFVn = ~idxXRltFVn & ~idxXRltFV1;
                if(any(idxXRgtFVn))%else % fxr >= fv(:,n) % & ~idxXRltFV1
                    % Perform contraction
                    idxXRltFVnp1 = fxr(:) < fv(pixelIDMask,end) & idxXRgtFVn;% & ~idxXRltFV1;
                    if(any(idxXRltFVnp1)) %if fxr < fv(:,end)
                        % Perform an outside contraction
                        tmpPIs = curPIs(idxXRltFVnp1);
                        tmpPIPos = curPIPos(idxXRltFVnp1);
                        xc = checkBounds(checkQuantization((1 + psi*rho)*xbar(:,idxXRltFVnp1) - psi*rho*v(:,tmpPIPos,end),quant(:,tmpPIs),lb(:,tmpPIs)),lb(:,tmpPIs),ub(:,tmpPIs));
                        fxc = costFcn(xc,tmpPIs,varargin{:});
                        fcnEvalCount(tmpPIPos) = fcnEvalCount(tmpPIPos)+1;
                        idxXCCltXR = fxc <= fxr(idxXRltFVnp1);
                        if(any(idxXCCltXR))%if fxc <= fxr
                            v(:,tmpPIPos(idxXCCltXR),end) = xc(:,idxXCCltXR);
                            fv(tmpPIPos(idxXCCltXR),end) = fxc(idxXCCltXR);
                            %how = 'contract outside';
                        end
                        if(any(~idxXCCltXR))
                            % perform a shrink
                            %how = 'shrink';
                            idxShrink = ~idxXCCltXR;
                            n = sum(idxShrink);
                            tmpPIs = tmpPIs(idxShrink);
                            tmpPIPos = tmpPIPos(idxShrink);
                            tmp = bsxfun(@plus,sigma*bsxfun(@minus,v(:,tmpPIPos,two2np1),v(:,tmpPIPos,1)),v(:,tmpPIPos,1));
                            tmp = checkBounds(checkQuantization(tmp,quantShrink(:,tmpPIs,two2np1),lbShrink(:,tmpPIs,two2np1)),lbShrink(:,tmpPIs,two2np1),ubShrink(:,tmpPIs,two2np1));
                            v(:,tmpPIPos,two2np1) = tmp;
                            tmp = costFcn(reshape(tmp,[nParams,n*nParams]),repmat(tmpPIs,1,nParams),varargin{:});
                            fv(tmpPIPos,two2np1) = reshape(tmp,n,nParams);
                            fcnEvalCount(tmpPIPos) = fcnEvalCount(tmpPIPos)+nParams;
                        end
                    end
                    idxXRgtFVnp1 = fxr(:) >= fv(pixelIDMask,end) & ~idxXRltFV1 & ~idxXRltFVn & ~idxXRltFVnp1;
                    %idxXRgtFVnp1 = ~idxXRltFVnp1;% & ~idxXRltFV1 & ;
                    if(any(idxXRgtFVnp1))
                        % Perform an inside contraction
                        %xcc = checkBounds(checkQuantization((1-psi)*xbar + psi*v(:,end),quant,lb),lb,ub); %new M. Klemm
                        %fxcc = costFcn(xcc,varargin{:});
                        tmpPIs = curPIs(idxXRgtFVnp1);
                        tmpPIPos = curPIPos(idxXRgtFVnp1);
                        xcc = checkBounds(checkQuantization((1-psi)*xbar(:,idxXRgtFVnp1) + psi*v(:,tmpPIPos,end),quant(:,tmpPIs),lb(:,tmpPIs)),lb(:,tmpPIs),ub(:,tmpPIs));
                        fxcc = costFcn(xcc,tmpPIs,varargin{:});
                        fcnEvalCount(tmpPIPos) = fcnEvalCount(tmpPIPos)+1;
                        idxXCCltFVnp1 = fxcc(:) < fv(tmpPIPos,end);
                        if(any(idxXCCltFVnp1)) %if fxcc < fv(:,end)
                            v(:,tmpPIPos(idxXCCltFVnp1),end) = xcc(:,idxXCCltFVnp1);
                            fv(tmpPIPos(idxXCCltFVnp1),end) = fxcc(idxXCCltFVnp1);
                            %how = 'contract inside';
                        end
                        if(any(~idxXCCltFVnp1))
                            % perform a shrink
                            %how = 'shrink';
                            idxShrink = ~idxXCCltFVnp1;
                            n = sum(idxShrink);
                            tmpPIs = tmpPIs(idxShrink);
                            tmpPIPos = tmpPIPos(idxShrink);                           
                            tmp = bsxfun(@plus,sigma*bsxfun(@minus,v(:,tmpPIPos,two2np1),v(:,tmpPIPos,1)),v(:,tmpPIPos,1));
                            tmp = checkBounds(checkQuantization(tmp,quantShrink(:,tmpPIs,two2np1),lbShrink(:,tmpPIs,two2np1)),lbShrink(:,tmpPIs,two2np1),ubShrink(:,tmpPIs,two2np1)); %new M. Klemm
                            v(:,tmpPIPos,two2np1) = tmp;
                            tmp = costFcn(reshape(tmp,[nParams,n*nParams]),repmat(tmpPIs,1,nParams),varargin{:});
                            fv(tmpPIPos,two2np1) = reshape(tmp,n,nParams);
                            fcnEvalCount(tmpPIPos) = fcnEvalCount(tmpPIPos)+nParams;
                        end
                    end
                end
            end
%             [fv,j] = sort(fv);
%             v = v(:,j);            
            [fv,sortIDs] = sort(fv,2);
            sortIDs = uint16(sortIDs);
            sortMask = ~all(sortIDs == sortIDCache,2);
            for p = 1:nPIs
                if(pixelIDMask(p) && sortMask(p))
                    v(:,p,:) = v(:,p,sortIDs(p,:));
                end
            end            
            iterCount(pixelIDMask) = iterCount(pixelIDMask) + 1;
            if(isa(hIterPostProcess, 'function_handle'))
                if(hIterPostProcess(iterCount,maxiter,tStart,v(:,:,1),fv(:,1)))
                    userbreak = true;
                    break;
                end
            end
            idxStop = ~(fcnEvalCount(pixelIDMask) < maxfun(pixelIDMask) & iterCount(pixelIDMask) < maxiter(pixelIDMask) & (max(abs(fv(pixelIDMask,1)-fv(pixelIDMask,two2np1))',[],1) > tolf(pixelIDMask) | any(max(abs(v(:,pixelIDMask,two2np1)-v(:,pixelIDMask,onesn)),[],3) > tol(:,pixelIDMask))));
            if(any(idxStop))
                %find the pixel IDs which fulfill the abort criteria and have the lowest function value per pixel
                %idx5 = ~pixelIDMask | ~idx5;
                pixelIDMask(curPIPos(idxStop)) = false;
                if(nSeeds > 1)
                    %find pixel IDs where optimization of 1 pixel has stopped but at least one other seed of that pixel is still being optimized
                    removeIDsAll = curPIs(idxStop);
                    removeIDs = unique(removeIDsAll);
                    removeIDsCnts  = histc(removeIDsAll,removeIDs);
                    idxAllSeeds = removeIDsCnts == nSeeds;
                    if(any(idxAllSeeds))
                        %all seeds of at least one pixel have stopped in this iteration -> remove them from the next iteration and from further checks
                        idxPixel = ismember(pixelIDs,removeIDs(idxAllSeeds));
                        pixelIDMask(idxPixel) = false;
                        idxStop = find(idxStop);
                        idxAllSeedPos = ismember(removeIDsAll,removeIDs(idxAllSeeds));
                        idxStop(idxAllSeedPos) = [];
                        removeIDs(idxAllSeeds) = [];
                        if(isempty(removeIDs))
                            continue
                        end
                    end
                    %find the other seeds of those pixels
                    idxPixel = ismember(pixelIDs,removeIDs);
                    %get the function values for the seeds
                    %determine stopped seeds which have the smallest function value for each (to be removed pixel)
                    idxMin = abs(min(reshape(fv(idxPixel,1),[],length(removeIDs)),[],1) - fv(curPIPos(idxStop),1)') < eps('single');
                    removeIDs(~idxMin) = [];
                    idxPixel = ismember(pixelIDs,removeIDs);
                    %remove all seeds of that pixel from computation
                    pixelIDMask(idxPixel) = false;
                end
            end
        end   % while
        
        x = v(:,:,1);
        fval = fv(:,1);        
        %output.iterations = iterCount;
        %output.funcCount = fcnEvalCount;
        %output.algorithm = 'Nelder-Mead simplex direct search';
        msg = '';
        if(userbreak)
%             msg = sprintf(['Exiting: Optimization canceled by user.\n' ...
%                 '         Current function value: %f \n'], fval);
            exitflag = 0;
        else
            if fcnEvalCount >= maxfun(pixelIDs)
%                 msg = sprintf(['Exiting: Maximum number of function evaluations has been exceeded\n' ...
%                     '         - increase MaxFunEvals option.\n' ...
%                     '         Current function value: %f \n'], fval);
                exitflag = 0;
            elseif iterCount >= maxiter(pixelIDs)
%                 msg = sprintf(['Exiting: Maximum number of iterations has been exceeded\n' ...
%                     '         - increase MaxIter option.\n' ...
%                     '         Current function value: %f \n'], fval);
                exitflag = 0;
            else
                %     msg = ...
                %         sprintf(['Optimization terminated:\n', ...
                %         ' the current x satisfies the termination criteria using OPTIONS.TolX of %e \n' ...
                %         ' and F(X) satisfies the convergence criteria using OPTIONS.TolFun of %e \n'], ...
                %         tolx, tolf);
%                 msg = ...
%                     sprintf(['Optimization terminated:\n', ...
%                     ' the current x satisfies the termination criteria\n']);
                exitflag = 1;
            end
        end        
        output.message = msg;
    end
end
