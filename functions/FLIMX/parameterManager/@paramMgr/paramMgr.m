classdef paramMgr < handle
    %=============================================================================================================
    %
    % @file     paramMgr.m
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
    % @brief    A class to manage ini file access
    %
    properties(GetAccess = protected, SetAccess = protected)
        data = [];
        about = [];
    end
    
    properties (Dependent = true)
        generalParams = [];
        computationParams = [];
        cleanupFitParams = [];
        preProcessParams = [];
        basicParams = [];
        initFitParams = [];
        pixelFitParams = [];
        boundsParams = [];
        optimizationParams = [];
    end
    
    methods
        function this = paramMgr(about)
            %constructor
            this.about = about;  
            this.data = this.getDefaults();
        end
        
        %% input methods 
        function goOn = setParamSection(this,sStr,new,resetResults)
            %set a parameter section to new values
            if(~isstruct(new) || ~ischar(sStr)) %isempty(this.data) ||
                %no sucess
                return
            end
            if(nargin < 4)
                resetResults = true;
            end
            if(strcmp('bounds',sStr) || strcmp('optimization',sStr) || strcmp('batchJob',sStr) || strcmp('result',sStr))
                %multiple parameter structs
                fields = intersect(fieldnames(new),paramMgr.convertSectionStr(sStr));
                for i = 1:length(fields)
                    goOn = this.setParamSection(fields{i},new.(fields{i}),resetResults);
                end
            else
                %single parameter
                goOn = this.setSection(sStr,new,resetResults);
            end
        end
        
        function out = getParamSection(this,sStr)
            %return one or multiple parameter sections
            out = [];            
            list = paramMgr.convertSectionStr(sStr);
            for i = 1:length(list)
                if(length(paramMgr.convertSectionStr(list{i})) == 1)                    
                    tmp = this.getSection(list{i});
                else
                    tmp = this.getParamSection(list{i}); 
                end
                if(~isempty(tmp))
                    out.(list{i}) = tmp;
                end
            end
            if(length(list) == 1 && ~isempty(out))
                out = out.(list{1});
            end
        end

        %% dependent properties
        function params = get.generalParams(this)
            %get general parameters
            params = this.getParamSection('general');
        end
        
        function params = get.computationParams(this)
            %get computation parameters
            params = this.getParamSection('computation');
        end
        
        function params = get.cleanupFitParams(this)
            %get cleanup fit parameters
            params = this.getParamSection('cleanup_fit');
        end
        
        function params = get.preProcessParams(this)
            %get pre processing parameters
            params = this.getParamSection('pre_processing');
        end
        
        function params = get.basicParams(this)
            %get basic fit parameters
            params = this.getParamSection('basic_fit');
        end
                
        function out = get.initFitParams(this)
            %get pixel fit parameters
            out = this.getParamSection('init_fit');
        end
        
        function out = get.pixelFitParams(this)
            %get pixel fit parameters
            out = this.getParamSection('pixel_fit');
        end
        
        function params = get.optimizationParams(this)
            %get optimization parameters
            params = this.getParamSection('optimization');
        end
        
        function params = get.boundsParams(this)
            %get bounds
            params = this.getParamSection('bounds');
        end
        
        function set.generalParams(this,val)
            %set general parameters
            this.setParamSection('general',val);
        end
        
        function set.computationParams(this,val)
            %set computation parameters
            this.getParamSection('computation',val);
        end
        
        function set.cleanupFitParams(this,val)
            %set cleanup fit parameters
            this.getParamSection('cleanup_fit',val);
        end
        
        function set.preProcessParams(this,val)
            %set pre processing parameters
            this.getParamSection('pre_processing',val);
        end
        
        function set.basicParams(this,val)
            %set basic fit parameters
            this.getParamSection('basic_fit',val);
        end
                
        function set.initFitParams(this,val)
            %set init fit parameters
            this.getParamSection('init_fit',val);
        end
        
        function set.pixelFitParams(this,val)
            %set pixel fit parameters
            this.getParamSection('pixel_fit',val);
        end
        
        function set.optimizationParams(this,val)
            %set optimization parameters
            this.getParamSection('optimization',val);
        end
        
        function set.boundsParams(this,val)
            %set bounds
            this.getParamSection('bounds',val);
        end
                
        function def = getDefaults(this)
            %get default FluoDecayFit parameters
            def.about.config_revision = this.about.config_revision;
            def.about.client_revision = this.about.client_revision;
            def.about.core_revision =  this.about.core_revision;
            def.about.results_revision = this.about.results_revision;
            
            def.pre_processing.ReflRemGrpSz             =	5;
            def.pre_processing.ReflRemWinSz             =	5;
            def.pre_processing.autoReflRem              =	1;
            def.pre_processing.autoStartPos             =	1; %1: auto, 0: manual, -1: fix
            def.pre_processing.autoEndPos               =	-1; %1: auto, 0: manual, -1: fix
            def.pre_processing.fixStartPos              =	35;
            def.pre_processing.fixEndPos                =	960;
            def.pre_processing.offsetStartPos           =	35;
            def.pre_processing.roiMode                  =   1; %0: default 1: auto 2: custom
            def.pre_processing.roiBinning               =	2;
            def.pre_processing.roiAdaptiveBinEnable     =   0;
            def.pre_processing.roiAdaptiveBinThreshold  =   200000;
            def.pre_processing.roiAdaptiveBinMax        =   10;
                        
            def.computation.useDistComp         =	0; %0: run only local, 1: multicore, 2: TU Ilmenau LSF
            def.computation.useMatlabDistComp   =   0; %0: don't use Matlabs distrubuted computing engine, 1: use Matlabs distrubuted computing engine
            def.computation.mcTargetNrWUs       =   100;
            def.computation.mcTargetPixelPerWU  =   84;
            def.computation.mcShare             =   'W:';
            def.computation.mcWorkLocal         =	0;
            def.computation.useGPU              =	0; %use matlab gpu accelaration
            
            def.basic_fit.approximationTarget   =   1; %1: lifetime; 2: anisotropy
            def.basic_fit.anisotropyChannelShift=   0; %shift between channel 1 and 2 in time channels
            def.basic_fit.anisotropyGFactor     =   1; %the g factor to take different detector sensitifities into account
            def.basic_fit.anisotropyPerpendicularFactor = 2; %impact of the perpendicular intensity on the fluorescence (usually 2)
            def.basic_fit.anisotropyR0Method    =   1; %method to compute r0; 1: directly from anisotropy; 2: using the fluorescence lifetime from the sum of both channels            
            def.basic_fit.risingEdgeErrorMargin =   4; %number of time channels model and data may differ at 80% of data maximum; only valid for fluorescence lifetime
            def.basic_fit.reconvoluteWithIRF    =   1; %switch reconvolution of model with IRF on (1) or off (0)
            def.basic_fit.amplitudeOrder        =   1; %force higher exponentials to have lower amplitudes; 0: disabled, 1: amp1 > amp2, 2: amp1 > amp2 > amp3 > ...
            def.basic_fit.tcOrder               =   1; %force time shifts (tc) of shifted exponentials to be ordered: e.g. tc3 > tc2
            def.basic_fit.lifetimeGap           =   2; %minimal gap/distance between lifetimes (relative factor, e.g. tau2 >= tau1 * factor)
            def.basic_fit.resultValidyCheckCnt  =   0; %retries for optimizer to get valid result (all amps & offset ~= zero)
            def.basic_fit.fitModel              =   0; %0: tail fit, 1: tci fit
            def.basic_fit.tailFitPreMaxSteps    =   10; %number of time points prior to the maximum which are used additionally in case of tail fits
            def.basic_fit.compMaxCorrTci        =	0;
            def.basic_fit.curIRFID              =   1;
            def.basic_fit.incompleteDecay       =	1;
            def.basic_fit.nExp                  =	3;
            def.basic_fit.neighborFit           =	0;
            def.basic_fit.neighborWeight        =	1;
            def.basic_fit.nonLinOffsetFit       =	1; %1: linear optimizer, 2: non-linear optimizer, 3: guess value
            def.basic_fit.photonThreshold       =	1000;
            def.basic_fit.tciMask               =	[0  0  0];
            def.basic_fit.stretchedExpMask      =	[0  0  0];
            def.basic_fit.hybridFit             =   1;
            def.basic_fit.constMaskSaveStrCh1   =   '';
            def.basic_fit.constMaskSaveStrCh2   =   '';
            def.basic_fit.constMaskSaveStrCh3   =   '';
            def.basic_fit.constMaskSaveStrCh4   =   '';
            def.basic_fit.constMaskSaveStrCh5   =   '';
            def.basic_fit.constMaskSaveStrCh6   =   '';
            def.basic_fit.constMaskSaveStrCh7   =   '';
            def.basic_fit.constMaskSaveStrCh8   =   '';
            def.basic_fit.constMaskSaveStrCh9   =   '';
            def.basic_fit.constMaskSaveStrCh10  =   '';
            def.basic_fit.constMaskSaveStrCh11  =   '';
            def.basic_fit.constMaskSaveStrCh12  =   '';
            def.basic_fit.constMaskSaveStrCh13  =   '';
            def.basic_fit.constMaskSaveStrCh14  =   '';
            def.basic_fit.constMaskSaveStrCh15  =   '';
            def.basic_fit.constMaskSaveStrCh16  =   '';
            def.basic_fit.constMaskSaveValCh1   =   [1];
            def.basic_fit.constMaskSaveValCh2   =   [1];
            def.basic_fit.constMaskSaveValCh3   =   [1];
            def.basic_fit.constMaskSaveValCh4   =   [1];
            def.basic_fit.constMaskSaveValCh5   =   [1];
            def.basic_fit.constMaskSaveValCh6   =   [1];
            def.basic_fit.constMaskSaveValCh7   =   [1];
            def.basic_fit.constMaskSaveValCh8   =   [1];
            def.basic_fit.constMaskSaveValCh9   =   [1];
            def.basic_fit.constMaskSaveValCh10  =   [1];
            def.basic_fit.constMaskSaveValCh11  =   [1];
            def.basic_fit.constMaskSaveValCh12  =   [1];
            def.basic_fit.constMaskSaveValCh13  =   [1];
            def.basic_fit.constMaskSaveValCh14  =   [1];
            def.basic_fit.constMaskSaveValCh15  =   [1];
            def.basic_fit.constMaskSaveValCh16  =   [1];
            def.basic_fit.linOptXTol            =   1e-005;
            def.basic_fit.fix2InitSmoothing     =   1;  
            def.basic_fit.fix2InitTargets       =   '';
            def.basic_fit.optimizerInitStrategy =   2; %1: guess values, 2: global approximation, 3: previous pixel
            def.basic_fit.globalFitMaskSaveStr  =   ''; 
            def.basic_fit.ErrorMP1              =	10;
            def.basic_fit.ErrorMP2              =	5;
            def.basic_fit.ErrorMP3              =	5;
            def.basic_fit.figureOfMerit         =   1; %1: chi², 2: least squares
            def.basic_fit.figureOfMeritModifier =	1; %figure of merit + 1: nothing(default), 2: peak boost
            def.basic_fit.chiWeightingMode      =	1; %1: Neyman (default), 2: Pearson, 3: fitted weighting, 4: Warren %fittedChiWeighting
            def.basic_fit.heightMode            =	1;
            def.basic_fit.timeInterpMethod      =   'linear';
            def.basic_fit.scatterEnable         =   0;
            def.basic_fit.scatterStudy          =   '';
            def.basic_fit.scatterIRF            =   0;
            
            
            def.cleanup_fit.enable      =   1;
            def.cleanup_fit.filterType  =   2; %1: mean; 2: median
            def.cleanup_fit.filterSize  =   7; %square size of sliding window, only odd numbers allowed
            def.cleanup_fit.target      =   ''; %e.g. tau1
            def.cleanup_fit.threshold   =   [];
            def.cleanup_fit.iterations  =   1;
            
            def.init_fit.optimizer          =   [1 2];
            def.init_fit.gridSize           =   1;
            def.init_fit.gridPhotons        =   0;
            
            def.pixel_fit.optimizer     =	[2];      
            def.pixel_fit.fitDimension  = 	1;
            
            def.fluo_decay_fit_gui.plotData               =	1;
            def.fluo_decay_fit_gui.plotDataLinewidth      =	2;
            def.fluo_decay_fit_gui.plotDataLinestyle      =	'none';
            def.fluo_decay_fit_gui.plotDataColor          =	[0 0 1];
            def.fluo_decay_fit_gui.plotDataMarkerstyle    = '.';
            def.fluo_decay_fit_gui.plotDataMarkersize     = 15;
            
            def.fluo_decay_fit_gui.plotExp                =	1;
            def.fluo_decay_fit_gui.plotExpLinewidth       =	1;
            def.fluo_decay_fit_gui.plotExpLinestyle       =	'-';
            def.fluo_decay_fit_gui.plotExp1Color          =	[0 0.75 0.75];
            def.fluo_decay_fit_gui.plotExp2Color          =	[0.75 0 0.75];
            def.fluo_decay_fit_gui.plotExp3Color          =	[0.75 0.75 0];
            def.fluo_decay_fit_gui.plotExp4Color          =	[0.615079365079365 0.384400000000000 0.244801587301587;];
            def.fluo_decay_fit_gui.plotExp5Color          =	[0.25 0.25 0.25];
            def.fluo_decay_fit_gui.plotExpMarkerstyle     = 'none';
            def.fluo_decay_fit_gui.plotExpMarkersize      = 6;
            
            def.fluo_decay_fit_gui.plotIRF                =	1;
            def.fluo_decay_fit_gui.plotIRFLinewidth       =	1;
            def.fluo_decay_fit_gui.plotIRFLinestyle       =	'-';
            def.fluo_decay_fit_gui.plotIRFColor           =	[0 1 0];
            def.fluo_decay_fit_gui.plotIRFMarkerstyle     = 'none';
            def.fluo_decay_fit_gui.plotIRFMarkersize      = 6;
            
            def.fluo_decay_fit_gui.plotExpSum             =	1;
            def.fluo_decay_fit_gui.plotExpSumLinewidth    =	2;
            def.fluo_decay_fit_gui.plotExpSumLinestyle    =	'-';
            def.fluo_decay_fit_gui.plotExpSumColor        =	[1 0 0];
            def.fluo_decay_fit_gui.plotExpSumMarkerstyle  = 'none';
            def.fluo_decay_fit_gui.plotExpSumMarkersize   = 6;            
            
            def.fluo_decay_fit_gui.plotStartEnd           =	0;
            def.fluo_decay_fit_gui.plotStartEndLinewidth  =	1;
            def.fluo_decay_fit_gui.plotStartEndLinestyle  =	'--';
            def.fluo_decay_fit_gui.plotStartEndColor      =	[0.2 0.2 0.2];
            
            def.fluo_decay_fit_gui.plotSlope              =	0;
            def.fluo_decay_fit_gui.plotSlopeLinewidth     =	1;
            def.fluo_decay_fit_gui.plotSlopeLinestyle     =	':';
            def.fluo_decay_fit_gui.plotSlopeColor         =	[0.2 0.2 0.2];
            
            def.fluo_decay_fit_gui.plotInit               = 0;
            def.fluo_decay_fit_gui.plotInitLinewidth      = 2;
            def.fluo_decay_fit_gui.plotInitLinestyle      = '-';
            def.fluo_decay_fit_gui.plotInitColor          = [0 1 1];
            def.fluo_decay_fit_gui.plotInitMarkerstyle    = 'none';
            def.fluo_decay_fit_gui.plotInitMarkersize     = 6;
            
            def.fluo_decay_fit_gui.plotCurLinesAndText              =	1;
            def.fluo_decay_fit_gui.plotCurlineswidth                =	1;
            def.fluo_decay_fit_gui.plotCurLinesStyle                =	'--';
            def.fluo_decay_fit_gui.plotCurLinesColor                =	[0 0 0];
            def.fluo_decay_fit_gui.plotCoordinateBoxColor           =	[1 1 1];
            def.fluo_decay_fit_gui.plotCoordinateBoxTransparency    =	0.9;
                  
            def.fluo_decay_fit_gui.showLegend   =	1;
            
            def.bounds_1_exp.init               =	[1  500];
            def.bounds_1_exp.lb                 =	[0.01           10];
            def.bounds_1_exp.deQuantization     =	[0.001           5];
            def.bounds_1_exp.simplexInit        =	[0.3           200];
            def.bounds_1_exp.tol                =	[0.001         0.1];
            def.bounds_1_exp.ub                 =	[1  10000];
            def.bounds_1_exp.quantization       =	[0     0];
            def.bounds_1_exp.initGuessFactor    =   [0      1];
            
            def.bounds_2_exp.init               =	[1            0.5           500           2000];
            def.bounds_2_exp.lb                 =	[0.0005          0.0001            10           100];
            def.bounds_2_exp.deQuantization     =	[0.001          0.0001            10           50];
            def.bounds_2_exp.simplexInit        =	[0.3           0.3           100           500];
            def.bounds_2_exp.tol                =	[0.01         0.01            1           5];
            def.bounds_2_exp.ub                 =	[1     1  10000  10000];
            def.bounds_2_exp.quantization       =	[0     0     0   0];
            def.bounds_2_exp.initGuessFactor    =   [0     0     0.05    0.2];
            
            def.bounds_3_exp.init               =	[0.8            0.15            0.05            100            500           2000];
            def.bounds_3_exp.lb                 =	[0.0005             0.0001             0.0001            10           100           500];
            def.bounds_3_exp.deQuantization     =	[0.01         0.01         0.005            5            50           100];
            def.bounds_3_exp.simplexInit        =	[0.15          0.1          0.05            100           500           1500];
            def.bounds_3_exp.tol                =	[0.01         0.01        0.005            1           5           10];
            def.bounds_3_exp.ub                 =	[1     1     1   1000  5000  10000];
            def.bounds_3_exp.quantization       =	[0     0     0   0  0  0];
            def.bounds_3_exp.initGuessFactor    =   [0     0     0  0.05  0.2   2.5];
            
            def.bounds_s_exp.init               =	0.5; %beta
            def.bounds_s_exp.lb                 =	0;
            def.bounds_s_exp.deQuantization     =	0.001;
            def.bounds_s_exp.simplexInit        =	0.4;
            def.bounds_s_exp.tol                =	0.001;
            def.bounds_s_exp.ub                 =	1;
            def.bounds_s_exp.quantization       =	0;
            def.bounds_s_exp.initGuessFactor    =   1;
            
            def.bounds_scatter.init         	=	[0.1  -25 0];
            def.bounds_scatter.lb           	=	[0           -1000 0];
            def.bounds_scatter.deQuantization   =	[0.01           1 0.01];
            def.bounds_scatter.simplexInit      =	[0.1           10 0.5];
            def.bounds_scatter.tol          	=	[0.001         0.1 0.001];
            def.bounds_scatter.ub           	=	[1  1000 1];
            def.bounds_scatter.quantization 	=	[0     0 0];
            def.bounds_scatter.initGuessFactor  =   [0 1 0];
                        
            def.bounds_h_shift.init         	=	0;
            def.bounds_h_shift.lb           	=	-1000;
            def.bounds_h_shift.deQuantization   =	1;
            def.bounds_h_shift.simplexInit      =	30;
            def.bounds_h_shift.tol          	=	1;
            def.bounds_h_shift.ub           	=	1000;
            def.bounds_h_shift.quantization 	=	0;
            def.bounds_h_shift.initGuessFactor  =   1;
            
            def.bounds_offset.init              =	0.1;
            def.bounds_offset.lb                =	0.01;
            def.bounds_offset.deQuantization    =	0.01;
            def.bounds_offset.simplexInit       =	0.1;
            def.bounds_offset.tol               =	0.001;
            def.bounds_offset.ub                =	100;
            def.bounds_offset.quantization      =	0;
            def.bounds_offset.initGuessFactor   =   1;
            
            def.options_de.CR                   =	0.9;
            def.options_de.F                    =	0.35;
            def.options_de.Fv                   =	0.5;
            def.options_de.NP                   =	10;
            def.options_de.displayResults       =	0;
            def.options_de.emailParams          =   '';
            def.options_de.feedSlaveProc        =	0;
            def.options_de.maxiter              =	1000;
            def.options_de.playSound            =	0;
            def.options_de.saveHistory          =	0;
            def.options_de.strategy             =	7;
            def.options_de.title                =	'Multiexponential Fluorescence Decay Fitting';
            def.options_de.iterPostProcess      =   [];
            def.options_de.bestValTol           =	0.30;
            def.options_de.maxReInitCnt         =	5;
            def.options_de.maxBestValConstCnt   =   25;
            def.options_de.minvalstddev         =   0.1;
            def.options_de.minparamstddev       =   0.025;
            def.options_de.stopVal              =   0.9;
            
            def.options_msimplexbnd.Display    	=	'none';
            def.options_msimplexbnd.FunValCheck	=	'off';
            def.options_msimplexbnd.MaxFunEvals	=	500;
            def.options_msimplexbnd.MaxIter    	=	200;
            def.options_msimplexbnd.TolFun     	=	0.001;
            def.options_msimplexbnd.initNodes   =   0;
            def.options_msimplexbnd.multipleSeedsMode    =   4; %1: best seed function value; 2: select best n+1 from all seeds; 3: %compute all seeds; 4: mean of seeds
            
            def.options_fminsearchbnd.Display    	=	'none';
            def.options_fminsearchbnd.FunValCheck	=	'off';
            def.options_fminsearchbnd.MaxFunEvals	=	500;
            def.options_fminsearchbnd.MaxIter    	=	200;
            def.options_fminsearchbnd.TolFun     	=	0.001;
            def.options_fminsearchbnd.TolX       	=	0.001;
            
            def.options_godlike.TolX    =   0.001;
            def.options_godlike.popSize =   2000;
            
            def.options_pso.CognitiveAttraction = 0.5 ;
            def.options_pso.ConstrBoundary = 'soft' ;
            %def.options_pso.AccelerationFcn = @psoiterate ;
            def.options_pso.DemoMode = 'off' ;
            def.options_pso.Display = 'off' ;
            def.options_pso.FitnessLimit = -inf ;
            def.options_pso.Generations = 200 ;
            %def.options_pso.HybridFcn = [] ;
            def.options_pso.InitialPopulation = [] ;
            def.options_pso.InitialVelocities = [] ;
            def.options_pso.KnownMin = [] ;
            %def.options_pso.PopInitRange = [0;1] ;
            def.options_pso.PopulationSize = 40 ;
            def.options_pso.PopulationType = 'doubleVector' ;
            def.options_pso.SocialAttraction = 1.25 ;
            def.options_pso.StallGenLimit = 50 ;
            def.options_pso.TimeLimit = inf ;
            def.options_pso.TolCon = 1e-6 ;
            def.options_pso.TolFun = 1e-6 ;
            def.options_pso.Vectorized = 'on' ;
            def.options_pso.VelocityLimit = [] ;
            
            def.bounds_tci.init         	=	-200;
            def.bounds_tci.lb           	=	-1000;
            def.bounds_tci.deQuantization  =	5;
            def.bounds_tci.simplexInit     =	50;%12.2152*5;
            def.bounds_tci.tol          	=	1;
            def.bounds_tci.ub           	=	0;
            def.bounds_tci.quantization 	=	0;
            def.bounds_tci.initGuessFactor  =   0.5;
            
            def.bounds_nExp.init               =	[0.05  3000];
            def.bounds_nExp.lb                 =	[0           500];
            def.bounds_nExp.deQuantization    =	[0.01           50];
            def.bounds_nExp.simplexInit       =	[0.05           1000];
            def.bounds_nExp.tol                =	[0.01           50];
            def.bounds_nExp.ub                 =	[1  10000];
            def.bounds_nExp.quantization       =   [0  0];
            def.bounds_nExp.initGuessFactor    =   [0      3];
            def.bounds_nExp.initGuessFactor    =   [0 0];
            
            def.flimvis_gui.alpha               	=	1;
            def.flimvis_gui.cluster_grp_bg_color	=	[0  0  0];
            def.flimvis_gui.color_cuts          	=	1;
            def.flimvis_gui.cutXColor           	=	[0.34921     0.34921     0.34921];
            def.flimvis_gui.cutYColor           	=	[0.30159     0.30159     0.30159];
            def.flimvis_gui.ROIColor                =	[1     1     1];
            def.flimvis_gui.ROILinestyle            =	'-';
            def.flimvis_gui.ROILinewidth            =	2;            
            def.flimvis_gui.ROI_fill_enable         =   1;
            def.flimvis_gui.fontsize            	=	10;
            def.flimvis_gui.grid                	=	1;
            def.flimvis_gui.light               	=	'none';
            def.flimvis_gui.offset_m3d          	=	1;
            def.flimvis_gui.offset_sc           	=	1;
            def.flimvis_gui.padd                	=	1;
            def.flimvis_gui.shading             	=	'interp';
            def.flimvis_gui.show_cut            	=	1;
            def.flimvis_gui.supp_plot_bg_color  	=	[1        0.95         0.9];
            def.flimvis_gui.supp_plot_color     	=	[0.2         0.2         0.2];
            def.flimvis_gui.supp_plot_linewidth 	=	2;
            def.flimvis_gui.ETDRS_subfield_values   =   'none';
            def.flimvis_gui.ETDRS_subfield_bg_enable=   1;
            def.flimvis_gui.ETDRS_subfield_bg_color =   [0.3 0.3 0.3 0.33];
            
            
            def.statistics.amp1_lb        	=	[1 1];
            def.statistics.amp1_lim       	=	[0 0];
            def.statistics.amp1_ub        	=	[1000 1000];
            def.statistics.amp1_classwidth	=	[10 10];
            def.statistics.amp2_lb        	=	[1 1];
            def.statistics.amp2_lim       	=	[0 0];
            def.statistics.amp2_ub        	=	[1000 1000];
            def.statistics.amp2_classwidth	=	[10 10];
            def.statistics.amp3_lb        	=	[1 1];
            def.statistics.amp3_lim       	=	[0 0];
            def.statistics.amp3_ub        	=	[1000 1000];
            def.statistics.amp3_classwidth	=	[10 10];
            def.statistics.ampN_lb        	=	[1 1];
            def.statistics.ampN_lim       	=	[0 0];
            def.statistics.ampN_ub        	=	[1000 1000];
            def.statistics.ampN_classwidth	=	[10 10];
            
            def.statistics.ampPer1_lb        	=	[1 1];
            def.statistics.ampPer1_lim       	=	[0 0];
            def.statistics.ampPer1_ub        	=	[1000 1000];
            def.statistics.ampPer1_classwidth	=	[1 1];
            def.statistics.ampPer2_lb        	=	[1 1];
            def.statistics.ampPer2_lim       	=	[0 0];
            def.statistics.ampPer2_ub        	=	[1000 1000];
            def.statistics.ampPer2_classwidth	=	[1 1];
            def.statistics.ampPer3_lb        	=	[1 1];
            def.statistics.ampPer3_lim       	=	[0 0];
            def.statistics.ampPer3_ub        	=	[1000 1000];
            def.statistics.ampPer3_classwidth	=	[1 1];
            def.statistics.ampPerN_lb        	=	[1 1];
            def.statistics.ampPerN_lim       	=	[0 0];
            def.statistics.ampPerN_ub        	=	[1000 1000];
            def.statistics.ampPerN_classwidth	=	[1 1];
            
            def.statistics.tau1_lb        	=	[1 1];
            def.statistics.tau1_lim       	=	[0 0];
            def.statistics.tau1_ub        	=	[1000 1000];
            def.statistics.tau1_classwidth	=	[10 10];
            def.statistics.tau2_lb        	=	[1 1];
            def.statistics.tau2_lim       	=	[0 0];
            def.statistics.tau2_ub        	=	[1000 1000];
            def.statistics.tau2_classwidth	=	[10 10];
            def.statistics.tau3_lb        	=	[1 1];
            def.statistics.tau3_lim       	=	[0 0];
            def.statistics.tau3_ub        	=	[1000 1000];
            def.statistics.tau3_classwidth	=	[10 10];
            def.statistics.tauN_lb        	=	[1 0];
            def.statistics.tauN_lim       	=	[0 0];
            def.statistics.tauN_ub        	=	[1000 1000];
            def.statistics.tauN_classwidth	=	[10 10];
            def.statistics.tauMean_lb        	=	[1 1];
            def.statistics.tauMean_lim       	=	[0 0];
            def.statistics.tauMean_ub        	=	[1000 1000];
            def.statistics.tauMean_classwidth	=	[10 10];
            
            def.statistics.c_lb        	=	[1 1];
            def.statistics.c_lim       	=	[0 0];
            def.statistics.c_ub        	=	[100 100];
            def.statistics.c_classwidth	=	[10 10];
            
            def.statistics.q1_lb        	=	[1 1];
            def.statistics.q1_lim       	=	[0 0];
            def.statistics.q1_ub        	=	[100 100];
            def.statistics.q1_classwidth	=	[1 1];
            def.statistics.q2_lb        	=	[1 1];
            def.statistics.q2_lim       	=	[0 0];
            def.statistics.q2_ub        	=	[100 100];
            def.statistics.q2_classwidth	=	[1 1];
            def.statistics.q3_lb        	=	[1 1];
            def.statistics.q3_lim       	=	[0 0];
            def.statistics.q3_ub        	=	[100 100];
            def.statistics.q3_classwidth	=	[1 1];
            def.statistics.qN_lb        	=	[1 1];
            def.statistics.qN_lim       	=	[0 0];
            def.statistics.qN_ub        	=	[100 100];
            def.statistics.qN_classwidth	=	[1 1];
            
            def.statistics.o_lb        	=	[1 1];
            def.statistics.o_lim       	=	[0 0];
            def.statistics.o_ub        	=	[1000 100];
            def.statistics.o_classwidth	=	[1 1];
            
            def.export.resampleImage    =	1;
            def.export.dpi              =	200;
            def.export.plotColorbar     =   1;
            def.export.plotBox          =   1;
            def.export.colorbarLocation =   'EastOutside';
            def.export.plotLinewidth    =	2;
            def.export.labelFontSize    =   10;
            def.export.autoAspectRatio  =   0;
            
            def.filtering.ifilter     	=	1;
            def.filtering.ifilter_size	=	3;
            def.filtering.ifilter_type	=	2;
            
            def.general.openFitGUIonStartup     = 1;
            def.general.openVisGUIonStartup     = 1;
            def.general.autoWindowSize          = 1; %0: manual, 1: automatic window size
            def.general.windowSize              = 1; %1: medium, 2: small, 3: large (fullHD)
            def.general.cmIntensityType         = 'gray|';
            def.general.cmIntensityInvert       = 0;
            def.general.cmIntensityPercentileLB = 0.1;
            def.general.cmIntensityPercentileUB = 98;
            def.general.cmType                  = 'jet|';
            def.general.cmInvert                = 1;            
            def.general.cmPercentileLB          = 0.1;
            def.general.cmPercentileUB          = 98;
            def.general.saveMaxMem              = 0;
            def.general.flimParameterView       = 1; %1: simple, 2: expert, 3: all
            def.general.reverseYDir             = 0;
        end

    end %methods
    
    methods(Access = protected)
        %internal methods            
        function goOn = setSection(this,sStr,new)
            %single parameter struct
            goOn = true;
            %update new sections
%             if(strcmp('volatilePixel',sStr))
%                 fields = intersect(fieldnames(new),fieldnames(this.volatilePixelParams));
%                 tmp = this.volatilePixelParams;
%                 for j = 1:length(fields)
%                     tmp.(fields{j}) = new.(fields{j});
%                 end
%                 this.volatilePixelParams = tmp;
%             elseif(strcmp('volatileChannel',sStr))
%                 if(ch > 1 && ch <= length(this.volatileChannelParams))
%                     tmp = this.volatileChannelParams{ch};
%                     fields = intersect(fieldnames(new),fieldnames(tmp));                    
%                     for j = 1:length(fields)
%                         tmp.(fields{j}) = new.(fields{j});
%                     end
%                     this.volatileChannelParams{ch} = tmp;                    
%                 end
            if(any(strcmp(sStr,fieldnames(this.data))))
                fields = intersect(fieldnames(new),fieldnames(this.data.(sStr)));
                tmp = this.data.(sStr);
                for j = 1:length(fields)
                    tmp.(fields{j}) = new.(fields{j});
                end
                this.data.(sStr) = tmp;
            else
                goOn = false;
                warning('paramMgr:setSection','Parameter section %s not found in config file. The section has been ignored.',sStr);
            end
        end
        
        function out = getSection(this,sStr)
            %get a section from the config file
            out = [];
            if(strcmp('about',sStr))
                out = this.about;
            else
%                 if(isempty(this.data))
%                     %try to read the config file
%                     this.readConfig()
%                 end
                if(isempty(this.data) || ~ischar(sStr))
                    %no success
                    return
                end
                if(isfield(this.data,sStr))
                    out = this.data.(sStr);
                end
            end
        end
        
    end %methods(Access = protected)
    
    methods(Static)
        function out = convertSectionStr(sStr)
            %convert groups of sections into a list their single sections
            switch sStr
                case 'bounds'
                    out = {'bounds_1_exp','bounds_2_exp','bounds_3_exp','bounds_s_exp',...
                        'bounds_nExp','bounds_tci','bounds_scatter','bounds_v_shift','bounds_h_shift','bounds_offset'};
                case 'optimization'
                    out = {'options_de','options_msimplexbnd', 'options_fminsearchbnd','options_pso','options_godlike'};
                case 'batchJob'
                    out = {'pre_processing','basic_fit','init_fit','pixel_fit','cleanup_fit','bounds','optimization','volatilePixel','volatileChannel'};
                case 'result'
                    out = {'pre_processing','basic_fit','init_fit','pixel_fit','cleanup_fit','bounds','optimization','volatilePixel','volatileChannel','computation'};
                otherwise
                    if(ischar(sStr))
                        out = {sStr};
                    else
                        out = {''};
                    end
            end
        end
        
        function [volatilePixel, volatileChannel] = makeVolatileParams(basicParams,nrSpectralChannels)
            %compute volatile paramters
            if(isempty(nrSpectralChannels) || nrSpectralChannels < 1)
                nrSpectralChannels = 1;
            end
            volatilePixel.modelParamsString = cell(2*basicParams.nExp,1);
            %volatilePixel.nModelParamsPerCh = 2*basicParams.nExp;
%             for i = 1:basicParams.nExp
                volatilePixel.modelParamsString(1:basicParams.nExp,1) = sprintfc('Amplitude %d',1:basicParams.nExp);
                volatilePixel.modelParamsString(basicParams.nExp+1:2*basicParams.nExp,1) = sprintfc('Tau %d',1:basicParams.nExp);
%             end
            %volatilePixel.nModelParamsPerCh = volatilePixel.nModelParamsPerCh+sum(basicParams.tciMask(:));%tcis
            if(any(basicParams.tciMask(:)))
                tmp = find(basicParams.tciMask(:));
                volatilePixel.modelParamsString(end+1:end+length(tmp),1) = sprintfc('tc %d',tmp);
            end
            %volatilePixel.nModelParamsPerCh = volatilePixel.nModelParamsPerCh+sum(basicParams.stretchedExpMask(:));%betas
            if(any(basicParams.stretchedExpMask(:)))
                tmp = find(basicParams.stretchedExpMask(:));
                volatilePixel.modelParamsString(end+1:end+length(tmp),1) = sprintfc('Beta %d',tmp);
            end
            %volatilePixel.nModelParamsPerCh = volatilePixel.nModelParamsPerCh+1; %offset            
            volatilePixel.nScatter = 0;
            if(basicParams.scatterEnable)
                if(~isempty(basicParams.scatterStudy))
                    volatilePixel.nScatter = 1;
                end
                volatilePixel.nScatter = volatilePixel.nScatter + basicParams.scatterIRF;
            end
            for i = 1:volatilePixel.nScatter
                volatilePixel.modelParamsString{end+1,1} = sprintf('ScatterAmplitude %d',i);
                volatilePixel.modelParamsString{end+1,1} = sprintf('ScatterShift %d',i);
                volatilePixel.modelParamsString{end+1,1} = sprintf('ScatterOffset %d',i);
            end
            volatilePixel.modelParamsString{end+1,1} = 'hShift';
            volatilePixel.modelParamsString{end+1,1} = 'Offset';
            %volatilePixel.nModelParamsPerCh = volatilePixel.nModelParamsPerCh + 3*volatilePixel.nScatter +1; %3* = scAmps, scShifts, scOffset, hShift
            volatilePixel.nModelParamsPerCh = size(volatilePixel.modelParamsString,1);
            volatilePixel.globalFitMask = paramMgr.makeGlobalFitMask(basicParams,volatilePixel);
            volatileChannel = cell(2,1);
            for ch = 1:nrSpectralChannels
                %we got maximum number of model parameters, determine number of constant/hybrid parameters
                [vcp.cMask, vcp.cVec] = paramMgr.makeCMaskCVec(basicParams,volatilePixel,ch);
                vcp.nApproxParamsPerCh = volatilePixel.nModelParamsPerCh - length(vcp.cVec); %-constants
                vcp.nGFApproxParamsPerCh = sum(volatilePixel.globalFitMask) - sum(volatilePixel.globalFitMask & vcp.cMask);
                volatileChannel{ch} = vcp;
            end
            volatilePixel.nApproxParamsAllCh = volatileChannel{1}.nApproxParamsPerCh;            
            if(nrSpectralChannels ~= 0 && any(volatilePixel.globalFitMask))                
                volatilePixel.nApproxParamsAllCh = sum(volatilePixel.globalFitMask);
                for ch = 1:nrSpectralChannels
                    volatilePixel.nApproxParamsAllCh = volatilePixel.nApproxParamsAllCh + volatileChannel{ch}.nApproxParamsPerCh;
                end
            end
        end
        
        function [cMask, cVec] = makeCMaskCVec(basicParams,volatilePixelParams,ch)
            %update cMask according to fitparams
            cMask = zeros(volatilePixelParams.nModelParamsPerCh,1);
            cVec = zeros(volatilePixelParams.nModelParamsPerCh,1);
            %hybrid fit?
            if(basicParams.hybridFit == 1)
                %amps
                cMask(1:basicParams.nExp) = -1.*ones(basicParams.nExp,1);
                %offset
                switch basicParams.nonLinOffsetFit
                    case 1 %linear offset fit
                        cMask(end) = -1;
                    case 2 %nonlinear offset fit
                        cMask(end) = 0;
                    case 3 %use guess value
                        cMask(end) = 1;
                end
                %scatter amps
                if(volatilePixelParams.nScatter > 0)
                    %cMask(end-2-volatilePixelParams.nScatter*3+1:end-2-volatilePixelParams.nScatter*3+volatilePixelParams.nScatter) = -1;
                    cMask(strncmp(volatilePixelParams.modelParamsString,'ScatterAmplitude',16)) = -1;
                end
            end
            %analyze which parameters are constant
            saveStr = basicParams.(sprintf('constMaskSaveStrCh%d',ch));
            saveVal = basicParams.(sprintf('constMaskSaveValCh%d',ch));
            for i = 1:length(saveStr)
                idx = find(strcmp(saveStr{i},volatilePixelParams.modelParamsString),1);
                if(any(idx))
                    cMask(idx) = 1;
                    cVec(idx) = saveVal(i);
                end            
            end
            %offset
            if(basicParams.nonLinOffsetFit == 3) %use guess value
                cMask(end) = 1;
                cVec(end) = 0;
            end
            cVec = cVec(logical(cMask));
        end
        
        function gMask = makeGlobalFitMask(basicParams,volatilePixelParams)
            %update global fit mask according to fitparams
            gMask = false(volatilePixelParams.nModelParamsPerCh,1);
            %analyze which parameters are to be globally fitted
            for i = 1:length(basicParams.globalFitMaskSaveStr)
                idx = find(strcmp(basicParams.globalFitMaskSaveStr{i},volatilePixelParams.modelParamsString),1);
                if(any(idx))
                    gMask(idx) = true;
                end            
            end            
%             cOffset = basicParams.nExp;
%             %taus
%             [~, pNrs] = paramMgr.extractParamsFromString('Tau',basicParams.nExp,basicParams.globalFitMaskSaveStr,[],true);
%             if(~isempty(pNrs))
%                 gMask(pNrs + cOffset) = true;
%             end
%             cOffset = cOffset + basicParams.nExp;
%             %tci
%             tcis = find(basicParams.tciMask);
%             [~, pNrs] = paramMgr.extractParamsFromString('tc',basicParams.nExp,basicParams.globalFitMaskSaveStr,[],true);
%             for i = 1:length(pNrs)
%                 idx = find(pNrs(i) == tcis);
%                 gMask(idx + cOffset) = true;
%             end
        end
        
        function [pVals, pNrs] = extractParamsFromString(pStr,nExp,maskSaveStr,maskSaveVal,multiFlag)
            %get values of constant parameters (and parameter number for multiple parameters)
            pVals = []; pNrs = [];
            idx = strncmp(pStr,maskSaveStr,length(pStr));
            if(~any(idx))
                return
            end
            if(multiFlag)
                params = maskSaveStr(idx);
                pNrs = zeros(length(params),1);
                for i = 1:length(params)
                    testStr = params{i};
                    pNrs(i) = str2double(testStr(isstrprop(testStr, 'digit')));
                end
                pNrs = pNrs(pNrs <= nExp);
            else
                pNrs = 1;
            end
            if(~isempty(maskSaveVal))
                pVals = maskSaveVal(idx);
            end
        end
        
        function Result = ini2struct(FileName)
            %==========================================================================
            %  Author: Andriy Nych ( nych.andriy@gmail.com )
            % Version:        733341.4155741782200
            %==========================================================================
            %
            % INI = ini2struct(FileName)
            %
            % This function parses INI file FileName and returns it as a structure with
            % section names and keys as fields.
            %
            % Sections from INI file are returned as fields of INI structure.
            % Each fiels (section of INI file) in turn is structure.
            % It's fields are variables from the corresponding section of the INI file.
            %
            % If INI file contains "oprhan" variables at the beginning, they will be
            % added as fields to INI structure.
            %
            % Lines starting with ';' and '#' are ignored (comments).
            %
            % See example below for more information.
            %
            % Usually, INI files allow to put spaces and numbers in section names
            % without restrictions as long as section name is between '[' and ']'.
            % It makes people crazy to convert them to valid Matlab variables.
            % For this purpose Matlab provides GENVARNAME function, which does
            %  "Construct a valid MATLAB variable name from a given candidate".
            % See 'help genvarname' for more information.
            %
            % The INI2STRUCT function uses the GENVARNAME to convert strange INI
            % file string into valid Matlab field names.
            %
            % [ test.ini ]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            %
            %     SectionlessVar1=Oops
            %     SectionlessVar2=I did it again ;o)
            %     [Application]
            %     Title = Cool program
            %     LastDir = c:\Far\Far\Away
            %     NumberOFSections = 2
            %     [1st section]
            %     param1 = val1
            %     Param 2 = Val 2
            %     [Section #2]
            %     param1 = val1
            %     Param 2 = Val 2
            %
            % ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            %
            % The function converts this INI file it to the following structure:
            %
            % [ MatLab session (R2006b) ]~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            %  >> INI = ini2struct('test.ini');
            %  >> disp(INI)
            %         sectionlessvar1: 'Oops'
            %         sectionlessvar2: 'I did it again ;o)'
            %             application: [1x1 struct]
            %             x1stSection: [1x1 struct]
            %            section0x232: [1x1 struct]
            %
            %  >> disp(INI.application)
            %                    title: 'Cool program'
            %                  lastdir: 'c:\Far\Far\Away'
            %         numberofsections: '2'
            %
            %  >> disp(INI.x1stSection)
            %         param1: 'val1'
            %         param2: 'Val 2'
            %
            %  >> disp(INI.section0x232)
            %         param1: 'val1'
            %         param2: 'Val 2'
            %
            % ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
            %
            % NOTE.
            % WhatToDoWithMyVeryCoolSectionAndVariableNamesInIniFileMyVeryCoolProgramWrites?
            % GENVARNAME also does the following:
            %   "Any string that exceeds NAMELENGTHMAX is truncated". (doc genvarname)
            % Period.
            %
            % =========================================================================
            Result = [];                            % we have to return something
            CurrMainField = '';                     % it will be used later
            f = fopen(FileName,'r');                % open file
            if(f < 0)
                %     uiwait(errordlg(sprintf('Error opening ini-file: %s',FileName),'Error opening ini-file','modal'));
                return
            end
            while ~feof(f)                          % and read until it ends
                s = strtrim(fgetl(f));              % Remove any leading/trailing spaces
                if isempty(s)
                    continue;
                end;
                if (s(1)==';')                      % ';' start comment lines
                    continue;
                end;
                if (s(1)=='#')                      % '#' start comment lines
                    continue;
                end;
                if ( s(1)=='[' ) && (s(end)==']' )
                    % We found section
                    CurrMainField = genvarname(s(2:end-1)); %lower
                    Result.(CurrMainField) = [];    % Create field in Result
                else
                    % ??? This is not a section start
                    [par,val] = strtok(s, '=');
                    val = paramMgr.CleanValue(val);
                    if(any(isstrprop(val, 'digit')))
                        [val_cand, status] = str2num(val);%allow numeric data
                        if(status)
                            val = val_cand;
                        end
                    end
                    if ~isempty(CurrMainField)
                        % But we found section before and have to fill it
                        Result.(CurrMainField).(genvarname(par)) = val; %lower
                    else
                        % No sections found before. Orphan value
                        Result.(genvarname(par)) = val; %lower
                    end
                end
            end
            fclose(f);
            return;
        end
        
        function res = CleanValue(s)
            %==========================================================================
            %  Author: Andriy Nych ( nych.andriy@gmail.com )
            res = strtrim(s);
            if(isempty(res))
                res='';
            elseif(strcmpi(res(1),'='))
                res(1)='';
            end
            res = strtrim(res);
        end
        
        function struct2ini(filename,Structure)
            %==========================================================================
            % Author:      Dirk Lohse ( dirklohse@web.de )
            % Version:     0.1a
            % Last change: 2008-11-13
            %==========================================================================
            %
            % struct2ini converts a given structure into an ini-file.
            % It's the opposite to Andriy Nych's ini2struct. Only
            % creating an ini-file is implemented. To modify an existing
            % file load it with ini2struct.m from:
            %       Andriy Nych ( nych.andriy@gmail.com )
            % change the structure and write it with struct2ini.
            %
            
            % Open file, or create new file, for writing
            % discard existing contents, if any.
            fid = fopen(filename,'W');
            if(fid < 0)
                warning('struct2ini:FileNotFound','Could not find or create file %s to save ini data.',filename);
                return
            end
            Structure = orderfields(Structure); %M. Klemm
            Sections = fieldnames(Structure);                     % returns the Sections
            
            for i=1:length(Sections)
                Section = char(Sections(i));                       % convert to character
                
                fprintf(fid,'\n[%s]\r\n',Section);                       % output [Section]
                
                member_struct = Structure.(Section);               % returns members of Section
                if ~isempty(member_struct)                         % check if Section is empty
                    member_struct = orderfields(member_struct); %M. Klemm
                    member_names = char(fieldnames(member_struct));
                    for j=1:size(member_names,1)
                        member_name = member_names(j,:);
                        member_value = Structure.(Section).(strtrim(member_name));
                        if(isnumeric(member_value)) %M. Klemm
                            member_value = num2str(member_value);
                        end
                        fprintf(fid,'%s\t=\t%s\r\n',member_name,member_value); % output member name and value
                        
                    end % for-END (Members)
                end % if-END
                fprintf(fid,'\r\n'); % empty row for better readability
            end % for-END (Sections)
            
            fclose(fid); % close file
        end
        
        
    end %methods(Static)
end

