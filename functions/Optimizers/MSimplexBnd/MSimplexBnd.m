function [x,fval,exitflag,output] = MSimplexBnd(funfcn,x,options,varargin)
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
%     if isa(funfcn,'struct')
%         [funfcn,x,options] = separateOptimStruct(funfcn);
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

[n, m] = size(x);
% if(m > n)
%     x = x';
%     [n m] = size(x);
% end
%x = mean(x,2);

tStart = 0;%clock;
userbreak = false;

lb = options.lb(:);
ub = options.ub(:);
si = options.simplexInit(:);
quant = options.quantization(:);
%initNodes = options.initNodes;
tolf = max(options.TolFun,10*eps(x(1)));
tol = options.tol(:);
maxfun = options.MaxFunEvals;
maxiter = options.MaxIter;
if(~isfield(options,'iterPostProcess')) 
    options.iterPostProcess = [];
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
x = checkBounds(checkQuantization(x,quant,lb),options.lb(:),options.ub(:));
itercount = 1;
func_evals = 0;
vTmp = zeros(n,n+1,m);
fvTmp = zeros(m,n+1);
for nx = 1:m
    [vTmp(:,:,nx), fvTmp(nx,:)] = init(x(:,nx));
end
if(m > 1)
    %select best n+1 parameters
    v = zeros(n,n+1);
    fv = zeros(1,n+1);
    ci = 1;
    for nx=1:m*n
        [~,id] = min(fvTmp(:));
        [r,c] = ind2sub([m,n+1],id);
        if(ci > 1)
            d = abs(bsxfun(@minus,v(:,1:ci-1),vTmp(:,c,r))./v(:,1:ci-1));
            if(~all(max(d)) >= 0.05)
                fvTmp(id) = inf;
                continue
            end
        end
        v(:,ci) = vTmp(:,c,r);
        fv(1,ci) = fvTmp(r,c);
        fvTmp(id) = inf;
        ci=ci+1;
        if(ci > n+1)
            break;
        end
    end
else
    v = vTmp;
    fv = fvTmp;
end

[x,fval,exitflag,output] = mainAlgorithm(v,fv,itercount);

    function [v, fv] = init(x)
        %make simplex initialization
        v = zeros(n,n+1);
        v(:,1) = x(:);
        fv = zeros(1,n+1);
        fv(1) = funfcn(x,varargin{:});
        func_evals = func_evals + 1;        
        xvec = [0 0];
        fv_tmp = [0 0];        
        for i = 1:n
            xmat = repmat(x,1,8);
            %determine shift of x(i)
            %maximum of: 10% of value (behavior if finminsearch); 1% of parameter interval; 2x quantization; user defined value
            dx = min(abs(ub(i)-lb(i))/2,max([abs(x(i)*0.90), abs(ub(i)-lb(i))/10, 2*quant(i)]));%, si(i)]); 
            xLow = -dx;%max(-dx,lb(i));%
            xHigh = dx;%min(dx,ub(i));%
            changeFlag = true;
            trials = 0; %we have 100 trials to find good starting values per parameter (prevent endless loop)            
            while(changeFlag && trials < 100)                
                trials = trials +1;
                changeFlag = false;
                xvec = [xLow+x(i) xHigh+x(i) si(i)+xLow si(i)+xHigh x(i)*1.50 x(i)*0.50 x(i)*1.10 x(i)*0.90];
                if(quant(i) ~= 0)
                    xvec = checkBounds(checkQuantization(xvec,quant(i),lb(i)),lb(i),ub(i));
                else
                    xvec = checkBounds(xvec,lb(i),ub(i));
                end
                %check if values are exactly at the borders
                idx = abs(xvec(:) - lb(i)) <= eps & abs(xvec(:) - x(i)) > eps;
                shift = max(quant(i),abs(ub(i)-lb(i))/100);
                if(any(idx))
                    %increase lower shift value                    
                    xLow = xLow + shift; %max(quant(i),abs(ub(i)-lb(i))/100);
                    xvec(idx) = xvec(idx) + shift;
                    if(idx(1))
                        changeFlag = true;
                    end
                end
                idx = abs(xvec(:) - ub(i)) <= eps & abs(xvec(:) - x(i)) > eps;
                if(any(idx))
                    %decrease upper shift value
                    xHigh = xHigh - shift; %max(quant(i),abs(ub(i)-lb(i))/100);
                    xvec(idx) = xvec(idx) - shift;
                    if(idx(2))
                        changeFlag = true;
                    end
                end
                if(changeFlag)
                    continue
                end
                %compute cost function values                
                xmat(i,:) = xvec;
                fv_tmp = funfcn(xmat,varargin{:});
                func_evals = func_evals + 8;                
                if(fv_tmp(1) == inf)
                    %this might be a tau and we might be to close to the previous tau
                    xLow = min(xHigh - abs(x(i)*0.10),xLow + max(quant(i),abs(ub(i)-lb(i))/100));
                    changeFlag = true;
                end
                if(fv_tmp(2) == inf)
                    %this might be a tau and we might be to close to the next tau
                    xHigh = max(xLow + abs(x(i)*0.10),xHigh - max(quant(i),abs(ub(i)-lb(i))/100));
                    changeFlag = true;
                end
            end
            [~,idx] = min(fv_tmp);
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
            fv(i+1) = fv_tmp(idx);
            %[fv(i+1) idx] = min(fv_tmp); %use best cost function value
            v(:,i+1) = xmat(:,idx);            
        end
        %clear xmat xvec dx fv_tmp
        % sort so v(1,:) has the lowest function value
        [fv,j] = sort(fv);
        v = v(:,j);
    end

    function [x,fval,exitflag,output] = mainAlgorithm(v,fv,itercount)
        
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
        rho = 1; chi = 2; psi = 0.5; sigma = 0.5;
        onesn = ones(1,n);
        two2np1 = 2:n+1;
        one2n = 1:n;
        
        while(func_evals < maxfun && itercount < maxiter && (max(abs(fv(1)-fv(two2np1))) > tolf || any(max(abs(v(:,two2np1)-v(:,onesn)),[],2) > tol)))
            %disp(sprintf('tolf: %02.3f; tolx: %02.2f',max(abs(fv(1)-fv(two2np1))), max(max(abs(v(:,two2np1)-v(:,onesn))))));
            %     if max(abs(fv(1)-fv(two2np1))) <= max(tolf,10*eps(fv(1))) && ...
            %             max(max(abs(v(:,two2np1)-v(:,onesn)))) <= max(tolx,10*eps(max(v(:,1))))
            %         break
            %     end            
            % Compute the reflection point
            
            % xbar = average of the n (NOT n+1) best points
            xbar = sum(v(:,one2n), 2)/n;
            xr = checkBounds(checkQuantization((1 + rho)*xbar - rho*v(:,end),quant,lb),lb,ub); %new M. Klemm;            
%             xe = checkBounds(checkQuantization((1 + rho*chi)*xbar - rho*chi*v(:,end),quant,lb),lb,ub); %new M. Klemm
%             xc = checkBounds(checkQuantization((1 + psi*rho)*xbar - psi*rho*v(:,end),quant,lb),lb,ub); %new M. Klemm
            xcc = checkBounds(checkQuantization((1-psi)*xbar + psi*v(:,end),quant,lb),lb,ub); %new M. Klemm
            %xSpec = [xr xe xc xcc]; %new M. Klemm
            xSpec = [xr xcc]; %new M. Klemm
%             fxr = funfcn(xr,varargin{:});
%             func_evals = func_evals+1;
            fv_tmp = funfcn(xSpec,varargin{:}); %new M. Klemm
            func_evals = func_evals+2;
            fxr = fv_tmp(1);
            if fxr < fv(:,1)
                % Calculate the expansion point
                xe = checkBounds(checkQuantization((1 + rho*chi)*xbar - rho*chi*v(:,end),quant,lb),lb,ub); %new M. Klemm;
                fxe = funfcn(xe,varargin{:});
                func_evals = func_evals+1;
%                 fxe = fv_tmp(2);
                if fxe < fxr 
                    v(:,end) = xe;
                    fv(:,end) = fxe;
                    how = 'expand';
                else
                    v(:,end) = xr;
                    fv(:,end) = fxr;
                    how = 'reflect';
                end
            else % fv(:,1) <= fxr
                if fxr < fv(:,n)
                    v(:,end) = xr;
                    fv(:,end) = fxr;
                    how = 'reflect';
                else % fxr >= fv(:,n)
                    % Perform contraction
                    if fxr < fv(:,end)
                        % Perform an outside contraction
                        xc = checkBounds(checkQuantization((1 + psi*rho)*xbar - psi*rho*v(:,end),quant,lb),lb,ub); %new M. Klemm
                        fxc = funfcn(xc,varargin{:});
                        func_evals = func_evals+1;
%                         fxc = fv_tmp(3);
                        if fxc <= fxr
                            v(:,end) = xc;
                            fv(:,end) = fxc;
                            how = 'contract outside';
                        else
                            % perform a shrink
                            how = 'shrink';
                        end
                    else
                        % Perform an inside contraction
%                         xcc = checkBounds(checkQuantization((1-psi)*xbar + psi*v(:,end),quant,lb),lb,ub); %new M. Klemm
%                         fxcc = funfcn(xcc,varargin{:});
%                         func_evals = func_evals+1;
                        fxcc = fv_tmp(2);
                        if fxcc < fv(:,end)
                            v(:,end) = xcc;
                            fv(:,end) = fxcc;
                            how = 'contract inside';
                        else
                            % perform a shrink
                            how = 'shrink';
                        end
                    end
                    if strcmp(how,'shrink')
                        v(:,two2np1) = checkBounds(checkQuantization(bsxfun(@plus,sigma*bsxfun(@minus,v(:,two2np1),v(:,1)),v(:,1)),quant,lb),lb,ub); %new M. Klemm
                        fv(:,two2np1) = funfcn(v(:,two2np1),varargin{:}); %new M. Klemm
%                         for j=two2np1
%                             v(:,j) = checkBounds(checkQuantization(v(:,1)+sigma*(v(:,j) - v(:,1)),quant,lb),lb,ub); %new M. Klemm
%                             fv(:,j) = funfcn(v(:,j),varargin{:});
%                         end
                        func_evals = func_evals + n;
                    end
                end
            end
            [fv,j] = sort(fv);
            v = v(:,j);
            itercount = itercount + 1;
            
            if( isa(options.iterPostProcess, 'function_handle') )
                if(options.iterPostProcess(itercount,maxiter,tStart,v(:,1),fv(:,1)))
                    userbreak = true;
                    break;
                end
            end
            
        end   % while
        
        x = v(:,1);
        fval = fv(:,1);        
        output.iterations = itercount;
        output.funcCount = func_evals;
        output.algorithm = 'Nelder-Mead simplex direct search';
        msg = '';
        if(userbreak)
%             msg = sprintf(['Exiting: Optimization canceled by user.\n' ...
%                 '         Current function value: %f \n'], fval);
            exitflag = 0;
        else
            if func_evals >= maxfun
%                 msg = sprintf(['Exiting: Maximum number of function evaluations has been exceeded\n' ...
%                     '         - increase MaxFunEvals option.\n' ...
%                     '         Current function value: %f \n'], fval);
                exitflag = 0;
            elseif itercount >= maxiter
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
