function result = runOpt(apObjs,optimizationParams)
%=============================================================================================================
%
% @file     runOPt.m
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
% @brief    A function which prepares model-objects, selects appropriate optimizers and loops over multiple data vetors (pixels) if necessary
%
hostname = gethostname();
prevXVec = [];
t_start = clock;
apObj = apObjs{1};
chList = apObj.nonEmptyChannelList;
nrChannels = length(chList);%nrChannels = nr global fit channels!
%preprocess data
[result, nonLinBounds] = apObj.makeDataPreProcessing([]);
if(any([result.TotalPhotons] < apObj.basicParams.photonThreshold) && apObj.basicParams.approximationTarget == 1) %too few photons
    msg = 'Not enough Photons for Approximation!';
else %enough photons
    %restrict tci & hShift to >= starting point
    for ch = 1:nrChannels
        if(apObj.getVolatileChannelParams(chList(ch)).cMask(end) && apObj.basicParams.nonLinOffsetFit == 3)
            %set offset to offsetGuess
            cp = apObj.getVolatileChannelParams(ch);
            cp.cVec(end) = result(ch).OffsetGuess(1,1);
            apObj.setVolatileChannelParams(chList(ch),cp);
        end
%         if(apObj.basicParams.fitModel ~= 1)
%             %set model maximum position to data maximum position
%             cp = apObj.getVolatileChannelParams(chList(ch));
%             if(apObj.basicParams.nonLinOffsetFit == 1)
%                 cp.cVec(end-1) = result.hShiftGuess;
%             else
%                 cp(end) = result.hShiftGuess;
%             end
%             apObj.setVolatileChannelParams(chList(ch),cp);
%         end
        result(ch).Iterations(1,1) = 0;
        result(ch).FunctionEvaluations(1,1) = 0;
    end
    resultIsValidCnt = 1;
    if(length(apObj.pixelFitParams.optimizer) > 1 || ~any(apObj.pixelFitParams.optimizer == [2 3 5]))
        %retry only if optimizer is not a determistic variant only
        resultIsValidCnt = resultIsValidCnt+apObj.basicParams.resultValidyCheckCnt;
    end
    while(resultIsValidCnt > 0)
        optimIter = 1;
        for optimizer = apObj.pixelFitParams.optimizer
            %select initialization
            if(optimIter ~= 1 && ~isempty(prevXVec))
                iVec = prevXVec; %use result from previous optimization as initialization
            else
                if(any(apObj.volatilePixelParams.globalFitMask))
                    tmp = [];
                    for ch = 1:nrChannels
                        tmp = [tmp,apObj.getInitializationData(ch)];
                    end
                    tmp = apObj.getFullXVec(apObj.currentChannel,tmp);
                    tmp(apObj.volatilePixelParams.globalFitMask,1) = mean(tmp(apObj.volatilePixelParams.globalFitMask,:),2);
                    iVec = apObj.joinGlobalFitXVec(apObj.getNonConstantXVec(apObj.currentChannel,tmp),true);
                else
                    iVec = apObj.getInitializationData(apObj.currentChannel);
                end
            end
            %prepare fitted weighting
            if(apObj.basicParams.chiWeightingMode == 3)
                cw = ones(apObj.fileInfo(apObj.currentChannel).nrTimeChannels,length(apObj.nonEmptyChannelList));
                if(apObj.basicParams.optimizerInitStrategy == 2 && optimIter == 1 && sum(iVec(:)) ~= 0)
                    %use initialization as weights for chi computation
                    if(~isempty(apObj.currentChannel))
                        idx = apObj.nonEmptyChannelList == apObj.currentChannel;
                        cw(:,idx) = apObj.getModel(apObj.currentChannel,iVec(:,1));
                    end
                    apObj.setChiWeightData(cw);
                elseif(~isempty(prevXVec))
                    %use result from previous optimization as weights for chi computation                    
                    if(~isempty(apObj.currentChannel))
                        idx = apObj.nonEmptyChannelList == apObj.currentChannel;
                        cw(:,idx) = apObj.getModel(apObj.currentChannel,prevXVec);
                    end
                    apObj.setChiWeightData(cw);
                end
            end
            %get parameters for current optimizer
            optParams = getOptParams(optimizer,apObj.volatilePixelParams,optimizationParams,nonLinBounds);
            %                 %apply constraint for pixel jitter
            %                 for ch = chList
            %                     if(apObj.pixelFitParams.pixelJitter ~= 0 && (nrPixels > 1 && 1 > 1) && ~isempty(result(ch).xVec(1-1,:)) && sum(result(ch).xVec(1-1,:)) > 0) % || (nrPixels == 1 && 1 == 1))
            %                         prevPx = apObj.getNonConstantXVec(chList(ch),result(ch).xVec(1-1,:));
            %                         idx = true(length(prevPx),1);
            %                         idx(end-1) = false; %not for hShift
            %                         if(apObj.basicParams.heightMode == 2)%only in fixed heigt mode
            %                             idx(end-2) = false; %not for vShift
            %                         end
            %                         optParams.lb(idx) = prevPx(idx) - abs(prevPx(idx)) .* apObj.pixelFitParams.pixelJitter/100;
            %                         optParams.ub(idx) = prevPx(idx) + abs(prevPx(idx)) .* apObj.pixelFitParams.pixelJitter/100;
            %                         idx = find(optParams.quantization);
            %                         for j = 1:length(idx)
            %                             optParams.lb(idx(j)) = floor(round(prevPx(idx(j))/optParams.quantization(idx(j))) .* 1-apObj.pixelFitParams.pixelJitter/100)*optParams.quantization(idx(j));
            %                             optParams.ub(idx(j)) = ceil(round(prevPx(idx(j))/optParams.quantization(idx(j))) .* 1+apObj.pixelFitParams.pixelJitter/100)*optParams.quantization(idx(j));
            %                         end
            %                     end
            %                 end
            if(~any(iVec))
                iVec = optParams.init;
            end
            %% select optimizer
            switch optimizer
                case 0 %% brute force
                    %removed 10.03.2009                    
                case 1 %% DE
                    optParams.paramDefCell{4} = iVec(:,1);
                    [xVec, ~, ~, iter, feval] = ...
                        differentialevolution(optParams, optParams.paramDefCell, @apObj.costFcn, ...
                        [], [], optParams.emailParams, optParams.title);
                case 2 %% MSimplexBnd
                    [xVec,~,~,output] = MSimplexBnd(@apObj.costFcn, iVec, optParams);
                    iter = output.iterations;
                    feval = output.funcCount;
                case 3 %% fminsearchbnd
                    [xVec,~,~,output] = fminsearchbnd(@apObj.costFcn, iVec(:,1), optParams.lb, optParams.ub, optParams);
                    %                         [xVec,~,~,output] = fmincon(@apObj.costFcn, iVec, [],[],[],[],optParams.lb, optParams.ub,[], optParams);
                    iter = output.iterations;
                    feval = output.funcCount;
                case 4 %% PSO
                    %optParams.InitialPopulation = iVec(:);
                    [xVec,~,~,output] = pso(@apObj.costFcn,apObj.volatilePixelParams.nApproxParamsAllCh,[],[],[],[],nonLinBounds.lb',nonLinBounds.ub',[],optParams);
                    xVec = xVec';
                    iter = output.generations;
                    feval = output.generations.*optParams.PopulationSize;
                case 5 %% LMFsolve
%                     optParams.FunTol = 1e-4;
%                     optParams.XTol = 1e-4;
%                     optParams.MaxIter = 500;
%                     optParams.ScaleD = [];
%                     optParams.Display = 1;
%                     [xVec,~, iter] = LMFsolve(@apObj.costFcn,mean([iVec(:) prevXVec(:)],2),optParams);%LMFnlsq(@apObj.costFcn,mean([iVec(:) prevXVec(:)],2),optParams);
%                     %xVec = nlsqbnd(@apObj.costFcn,mean([iVec(:) prevXVec(:)],2),optParams.lb(:),optParams.ub(:));
%                     iter = 1;
%                     feval = iter; %todo
                    fun = @(x)apObj.getModel(1,x);
                    options = optimoptions('lsqnonlin');
                    options.Algorithm = 'Levenberg-Marquardt';
                    options.Display = 'off';
                    options.MaxFunEvals = 100;
                    [xVec,resnorm,residual,exitflag,output] = lsqnonlin(fun,iVec(:,1),nonLinBounds.lb',nonLinBounds.ub',options);
                    iter = output.iterations;
                    feval = output.funcCount;
                    
                case 6 %GODLIKE
                    %options = set_options();
                    %options.display = 'on';
                    %options.TolX = 0.001;
                    %options.DE.Fub = 0.5;
                    [sol, ~, ~, output] = GODLIKE(@apObj.costFcn, optParams.popSize, optParams.lb, optParams.ub,[],optParams);
                    xVec = sol';
                    iter = output.funcCount;
                    feval = output.funcCount;
                case 7 %optimize
                    [sol, ~, ~, output] = optimize(@apObj.costFcn, iVec(:,1), optParams.lb, optParams.ub);
                    xVec = sol;
                    iter = output.funcCount;
                    feval = output.funcCount;
                otherwise
                    error('Wrong optimizer specified');
            end %end switch optimizers
            prevXVec = xVec;
            if(any(apObj.volatilePixelParams.globalFitMask))
                for ch = chList
                    %                         result(ch).x_vec(1,:) = apObj.getFullXVec(ch,xArray(:,ch));
                    result(ch).Iterations(1,1) = result(ch).Iterations(1,1)+iter;
                    result(ch).FunctionEvaluations(1,1) = result(ch).FunctionEvaluations(1,1)+feval;
                end
            else
                %                     result.x_vec(1,:) = apObj.getFullXVec(apObj.currentChannel,xVec);
                result.Iterations(1,1) = result.Iterations(1,1)+iter;
                result.FunctionEvaluations(1,1) = result.FunctionEvaluations(1,1)+feval;
            end
            optimIter = optimIter+1;
        end %for optimizer
        dt = etime(clock,t_start);
        %% assemble result-structure
        lbCh = apObj.divideGlobalFitXVec(nonLinBounds.lb,true);
        ubCh = apObj.divideGlobalFitXVec(nonLinBounds.ub,true);
        xArray = apObj.divideGlobalFitXVec(xVec,true);
        for ch = 1:nrChannels
            result(ch).Time(1,1) = dt;
            %                 result(ch).TotalPhotons(1,1) = sum(data(result(ch).StartPosition:result(ch).EndPosition));
            %% recompute chi² results
            gfOld = apObj.volatilePixelParams.globalFitMask;
            bpOld = apObj.basicParams;
            apObj.volatilePixelParams.globalFitMask = false(size(apObj.volatilePixelParams.globalFitMask));
            apObj.basicParams.errorMode = 1;
            apObj.basicParams.chiWeightingMode = 1;
            apObj.basicParams.neighborFit = 0;
            apObj.setCurrentChannel(chList(ch));
            %apObj.makeDataPreProcessing(allInitVec); %we have to run pre-processing again to set the linear bounds
            [result(ch).chi2(1,1), ampsH, ampsScH, osetH, result(ch).chi2Tail(1,1)] = apObj.costFcn(xArray(:,ch));
            qs = apObj.getExponentials(chList(ch),xArray(:,ch));
            %compute percentage
            qses = trapz(qs(:,1:end-1-apObj.volatilePixelParams.nScatter),1); %remove offset and scatter components and integrate over each component
            qses = 100*qses./sum(qses(:));
            %excluding scatter
            for n = 1:length(qses)
                result(ch).(sprintf('RAUC%d',n)) = qses(n);
            end
            %including scatter
            if(apObj.volatilePixelParams.nScatter > 0)
                qsis = trapz(qs(:,1:end-1),1); %remove offset and integrate over each component
                qsis = 100*qsis./sum(qsis(:));
                for n = 1:length(qsis)
                    result(ch).(sprintf('RAUCIS%d',n)) = qsis(n);
                end
            end
            apObj.volatilePixelParams.globalFitMask = gfOld;
            apObj.basicParams = bpOld;
            %% normalize xVec
            [amps, taus, tcis, betas, scAmps, scShifts, scOset, hShift, oset] = apObj.getXVecComponents(xArray(:,ch),true,chList(ch));
            if(apObj.basicParams.hybridFit)
                amps = ampsH;%./sum(ampsH(:,ch));
                oset = osetH;
                scAmps = ampsScH;
            end
%             switch apObj.basicParams.heightMode
%                 %                     case 1 %auto height
%                 %                         amps = amps;%./result(ch).MaximumPhotons(1,1);
%                 %                         scAmps = scAmps;%./result(ch).MaximumPhotons(1,1);
%                 case 2 %fixed height
%                     as = sum([amps; scAmps oset]);
%                     amps = amps./as.*result(ch).MaximumPhotons(1,1);
%                     scAmps = scAmps./as.*result(ch).MaximumPhotons(1,1);
%                     oset = oset./as.*result(ch).MaximumPhotons(1,1);
%             end
            xVec = apObj.getFullXVec(chList(ch),amps,taus,tcis,betas,scAmps,scShifts,scOset,hShift,oset);
            %xVec(end) = xVec(end) ./ result(ch).MaximumPhotons(1,1);
            % check if all amps are > 0 and values are not at borders
            if(all([amps; oset] > eps) && all((apObj.getNonConstantXVec(chList(ch),xVec) - lbCh(:,ch)) > eps) && all((ubCh(:,ch) - apObj.getNonConstantXVec(chList(ch),xVec)) > eps))
                resultIsValidCnt = 0;
                %                     if(apObj.basicParams.optimizerInitStrategy == 3)
                %                         %save current solution for next pixel
                %                         if(sum(xVec) ~= 0)
                %                             prevXVec = xVec;
                %                         end
                %                     end
            else
                %give optimizer another try to find a good solution
                resultIsValidCnt = resultIsValidCnt -1;
            end
            %% write back xVec
            result(ch).x_vec(1,:) = xVec;
        end %for
    end %while(resultIsValid)
    %% save message
    msg = 'Parameter approximation successful.';
end %if 'enough photons'
%% make (redundant) result for easier access
for ch = 1:nrChannels
    %rebuild (combined) xVec and slice into parts
    [amps, taus, tcis, betas, scAmps, scShifts, scOset, hShift, oset] = apObj.getXVecComponents(result(ch).x_vec(1,:)',false,chList(ch));
    %         if(apObj.basicParams.hybridFit)
    %             amps = ampsH(:,ch);
    %             oset = osetH(ch);
    %         elseif(~apObj.basicParams.hybridFit && apObj.basicParams.heightMode == 1)
    %             %multiply each amp with peak photon counts
    % %             oset = oset .* result(ch).MaximumPhotons(1,1);
    %             amps = amps .* result(ch).MaximumPhotons(1,1);
    %         end
    %save offset, vShift and hShift
    result(ch).Offset(1,1) = oset;
    result(ch).hShift(1,1) = hShift;
    %save amps in photons counts
    for l = 1 : apObj.basicParams.nExp
        result(ch).(sprintf('Amplitude%d',l))(1,1) = amps(l);
        result(ch).(sprintf('Tau%d',l))(1,1) = taus(l);
    end
    %make 'corrected tc1' (difference between global (merged) max and local max postions)
    %         if(params.basicParams.compMaxCorrTci)
    %             result(ch).tc1_corrected(1,1) = (fileInfo(ch).mergeMaxPos - result(ch).MaximumPosition(1,1) - result(ch).hShift(1,1)) * fileInfo(ch).timeChannelWidth;
    %         end
    if(any(apObj.basicParams.tciMask))
        tci_ids = find(apObj.basicParams.tciMask);
        for l = 1:length(tcis)
            %cur_tci = params.basicParams.nExp - allFitParams.n_tci + l;
            tci_str = sprintf('tc%d',tci_ids(l));
            result(ch).(tci_str)(1,1) = tcis(l);
            %                 if(params.basicParams.compMaxCorrTci)
            %                     tcic_str = sprintf('tc%d_corrected',tci_ids(l));
            %                     result(ch).(tcic_str)(1,1) = tcis(l) + result(ch).tc1_corrected(1,1);
            %                 end
        end
    end
    %stretched exponentials
    if(any(apObj.basicParams.stretchedExpMask))
        se_ids = find(apObj.basicParams.stretchedExpMask);
        for l = 1:length(betas)
            %cur_tci = params.basicParams.nExp - allFitParams.n_tci + l;
            se_str = sprintf('Beta%d',se_ids(l));
            result(ch).(se_str)(1,1) = betas(l);
        end
    end
    %scatter light
    %scAmps = scAmps .* result(ch).MaximumPhotons(1,1);
    for l = 1 : apObj.volatilePixelParams.nScatter
        result(ch).(sprintf('ScatterAmplitude%d',l))(1,1) = scAmps(l);
        result(ch).(sprintf('ScatterShift%d',l))(1,1) = scShifts(l);
        result(ch).(sprintf('ScatterOffset%d',l))(1,1) = scOset(l).*result(ch).MaximumPhotons(1,1);
    end    
    %% save auxiliary information
    result(ch).hostname{1,1} = hostname;
    result(ch).standalone(1,1) = isdeployed();
    result(ch).Message(1,1) = {msg};
    %% save 'per channel' stuff
    %         result(ch).cVec = params.volatile.cVec;
    %         result(ch).cMask = params.volatile.cMask;
    %         result(ch).reflectionMask = fileInfo(ch).reflectionMask;
end %for ch =
result = orderfields(result);

%     function iVec = scaleInitVec2Data(iVec,ch)
%         %scale amplitudes and offset of initialization to data maximum
%         if(isempty(iVec))
%             return
%         end
%         iArray = apObj.divideGlobalFitXVec(iVec,true);
%         %iVec = [];
%         %for chIdx = 1:length(chList)
%             maxPhotons = result(ch).MaximumPhotons(1,1);
%             [amps, taus, tcis, betas, scAmps, scShifts, scOset, hShift, oset] = apObj.getXVecComponents(iArray(:,ch),true,chList(chIdx));
%             amps = amps .* maxPhotons;
%             scAmps = scAmps .* maxPhotons;
%             iVec = apObj.getNonConstantXVec(ch,amps,taus,tcis,betas,scAmps,scShifts,scOset,hShift,oset);
%         %end
%         %iVec = apObj.joinGlobalFitXVec(iVec,true);
%     end

    function bounds = getOptParams(opt,fitParams,allOptParams,bounds)
        %get parameters for optimizer opt
        switch opt
            case 1 %DE
                fn = fieldnames(allOptParams.options_de);
                dp = getdefaultparams;
                for i = 1:length(fn)
                    dp.(fn{i}) = allOptParams.options_de.(fn{i});
                end
                bounds = catstruct(bounds,dp);
                bounds.NP = fitParams.nApproxParamsAllCh * bounds.NP;
                bounds.paramDefCell = cell(fitParams.nApproxParamsAllCh,3);
                bounds.paramDefCell = {'', [bounds.lb bounds.ub], bounds.deQuantization, bounds.init};
                bounds.useInitParams = 2;
                
            case 2 %MSimplexBnd
                bounds = catstruct(bounds,allOptParams.options_msimplexbnd);
                
            case 3 %fminsearchbnd
                % Set up optimization options - you can leave any of these blank and fminsearch will use
                bounds = catstruct(bounds,allOptParams.options_fminsearchbnd);
                
            case 4 %pso
                fn = fieldnames(allOptParams.options_pso);
                dp = psooptimset;
                for i = 1:length(fn)
                    dp.(fn{i}) = allOptParams.options_pso.(fn{i});
                end
                dp.PopulationSize = dp.PopulationSize * fitParams.nApproxParamsAllCh;
                %         bounds = catstruct(bounds,dp);
                bounds = dp;
            case 5 %lsqnonlin
                
            case 6 %GODLIKE
                bounds = catstruct(bounds,set_options(),allOptParams.options_godlike);
                
                %     original DE
                %         %[ub lb ss init] = getUbLbInit(d_max,n_exp,n_tci,offset);
                %         bounds.I_NP         = fitParams.nApproxParamsAllCh*10; %number of population members
                %         bounds.F_weight     = 0.4; %DE-stepsize F_weight ex [0, 2]
                %         bounds.F_CR         = 0.9; %crossover probabililty constant ex [0, 1]
                %         bounds.I_D          = fitParams.nApproxParamsAllCh;% number of parameters of the objective function
                %         % FVr_minbound,FVr_maxbound   vector of lower and bounds of initial population
                %         %    		the algorithm seems to work especially well if [FVr_minbound,FVr_maxbound]
                %         %    		covers the region where the global minimum is expected
                %         %               *** note: these are no bound constraints!! ***
                %         bounds.FVr_minbound = bounds.lb;
                %         bounds.FVr_maxbound = bounds.ub;
                %         bounds.I_bnd_constr = 1;  %1: use bounds as bound constraints, 0: no bound constraints
                %         bounds.I_itermax    = 100; %maximum number of iterations (generations)
                %         bounds.F_VTR        = 0; %"Value To Reach" (stop when ofunc < F_VTR)
                %         % I_strategy     1 --> DE/rand/1:
                %         %                      the classical version of DE.
                %         %                2 --> DE/local-to-best/1:
                %         %                      a version which has been used by quite a number
                %         %                      of scientists. Attempts a balance between robustness
                %         %                      and fast convergence.
                %         %                3 --> DE/best/1 with jitter:
                %         %                      taylored for small population sizes and fast convergence.
                %         %                      Dimensionality should not be too high.
                %         %                4 --> DE/rand/1 with per-vector-dither:
                %         %                      Classical DE with dither to become even more robust.
                %         %                5 --> DE/rand/1 with per-generation-dither:
                %         %                      Classical DE with dither to become even more robust.
                %         %                      Choosing F_weight = 0.3 is a good start here.
                %         %                6 --> DE/rand/1 either-or-algorithm:
                %         %                      Alternates between differential mutation and three-point-
                %         %                      recombination.
                %         bounds.I_strategy   = 1;
                %         bounds.I_refresh    = 0;
                %         bounds.I_plotting   = 0;
        end %switch
    end

end


