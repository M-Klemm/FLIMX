function ROCdata=roc(varargin)
% ROC - Receiver Operating Characteristics.
% The ROC graphs are a useful tecnique for organizing classifiers and
% visualizing their performance. ROC graphs are commonly used in medical
% decision making.
% If you have downloaded partest
% http://www.mathworks.com/matlabcentral/fileexchange/12705
% the routine will compute several data on test performance.
%
% Syntax: roc(x,alpha)
%
% Input: x - This is the data matrix. The first column is the column of the data value;
%            The second column is the column of the tag: unhealthy (1) and
%            healthy (0).
%        Thresholds - If you want to use all unique values in x(:,1) then
%            set this variable to 0 or leave it empty; else set how many
%            unique values you want to use (min=3);
%        alpha - significance level (default 0.05)
%
% Output: The ROC plot;
%         The Area under the curve with Standard error and Confidence
%         interval and comment.
%         Cut-off point for best sensitivity and specificity.
%         (Optional) the test performances at cut-off point.
%
% Example:
%           load rocdata
%           roc(x) % to use all data
%
%           roc(x,5) %to use 5 thresholds
%
%           Created by Giuseppe Cardillo
%           giuseppe.cardillo-edta@poste.it
%
% To cite this file, this would be an appropriate format:
% Cardillo G. (2008) ROC curve: compute a Receiver Operating Characteristics curve.
% http://www.mathworks.com/matlabcentral/fileexchange/19950
%
% MODIFIED by Matthias Klemm 2015/07 (removed plot functons)
%
%Input Error handling
args=cell(varargin);
nu=numel(args);
if isempty(nu)
    error('Warning: almost the data matrix is required')
elseif nu>4
    error('Warning: Max four input data are required')
end
default.values = {[],0,0.05,1};
default.values(1:nu) = args;
[x threshold alpha verbose] = deal(default.values{:});
if isvector(x)
    error('Warning: X must be a matrix')
end
if ~all(isfinite(x(:))) || ~all(isnumeric(x(:)))
    error('Warning: all X values must be numeric and finite')
end
x(:,2)=logical(x(:,2));
if all(x(:,2)==0)
    error('Warning: there are only healthy subjects!')
end
if all(x(:,2)==1)
    error('Warning: there are only unhealthy subjects!')
end
if nu>=2
    if isempty(threshold)
        threshold=0;
    else
        if ~isscalar(threshold) || ~isnumeric(threshold) || ~isfinite(threshold)
            error('Warning: it is required a numeric, finite and scalar THRESHOLD value.');
        end
        if threshold ~= 0 && threshold <3
            error('Warning: Threshold must be 0 if you want to use all unique points or >=2.')
        end
    end
    if nu>=3
        if isempty(alpha)
            alpha=0.05;
        else
            if ~isscalar(alpha) || ~isnumeric(alpha) || ~isfinite(alpha)
                error('Warning: it is required a numeric, finite and scalar ALPHA value.');
            end
            if alpha <= 0 || alpha >= 1 %check if alpha is between 0 and 1
                error('Warning: ALPHA must be comprised between 0 and 1.')
            end
        end
    end
    if nu>=4
        verbose=logical(verbose);
    end
%     if nu<5
%         if(verbose)
%             hAxes = subplot(1,2,1);
%         else
%             hAxes = [];
%         end
%     end
%     if nu<6
%         if(verbose)
%             hAxesMirror = subplot(1,2,2);
%         else
%             hAxesMirror = [];
%         end
%     end
    
end
clear args default nu

tr=repmat('-',1,80);
lu=length(x(x(:,2)==1)); %number of unhealthy subjects
lh=length(x(x(:,2)==0)); %number of healthy subjects
z=sortrows(x,1);
if threshold==0
    labels=unique(z(:,1));%find unique values in z
else
    K=linspace(0,1,threshold+1); K(1)=[];
    labels=quantile(unique(z(:,1)),K)';
end
ll=length(labels); %count unique value
a=zeros(ll,2); %array preallocation
ubar=mean(x(x(:,2)==1),1); %unhealthy mean value
hbar=mean(x(x(:,2)==0),1); %healthy mean value
for K=1:ll
    if hbar<ubar
        TP=length(x(x(:,2)==1 & x(:,1)>labels(K)));
        FP=length(x(x(:,2)==0 & x(:,1)>labels(K)));
        FN=length(x(x(:,2)==1 & x(:,1)<=labels(K)));
        TN=length(x(x(:,2)==0 & x(:,1)<=labels(K)));
    else
        TP=length(x(x(:,2)==1 & x(:,1)<labels(K)));
        FP=length(x(x(:,2)==0 & x(:,1)<labels(K)));
        FN=length(x(x(:,2)==1 & x(:,1)>=labels(K)));
        TN=length(x(x(:,2)==0 & x(:,1)>=labels(K)));
    end
    a(K,:)=[TP/(TP+FN) TN/(TN+FP)]; %Sensitivity and Specificity
end

if hbar<ubar
    xroc=flipud([1; 1-a(:,2); 0]); yroc=flipud([1; a(:,1); 0]); %ROC points
    labels=flipud(labels);
else
    xroc=[0; 1-a(:,2); 1]; yroc=[0; a(:,1); 1]; %ROC points
end

Area=trapz(xroc,yroc); %estimate the area under the curve
%standard error of area
Area2=Area^2; Q1=Area/(2-Area); Q2=2*Area2/(1+Area);
V=(Area*(1-Area)+(lu-1)*(Q1-Area2)+(lh-1)*(Q2-Area2))/(lu*lh);
Serror=realsqrt(V);

%confidence interval
cv=realsqrt(2)*erfcinv(alpha);
ci=Area+[-1 1].*(cv*Serror);
if ci(2)>1
    ci(2)=1;
end
%z-test
SAUC=(Area-0.5)/Serror; %standardized area
p=1-0.5*erfc(-SAUC/realsqrt(2)); %p-value

% if verbose
%     %Performance of the classifier
%     if Area==1
%         str='Perfect test';
%     elseif Area>=0.90 && Area<1
%         str='Excellent test';
%     elseif Area>=0.80 && Area<0.90
%         str='Good test';
%     elseif Area>=0.70 && Area<0.80
%         str='Fair test';
%     elseif Area>=0.60 && Area<0.70
%         str='Poor test';
%     elseif Area>=0.50 && Area<0.60
%         str='Fail test';
%     else
%         str='Failed test - less than chance';
%     end
%     
%     %display results
%     disp('ROC CURVE DATA')
%     disp(tr)
%     fprintf('Cut-off point\t\tSensivity\tSpecificity\n')
%     table=[labels'; yroc(2:end-1)'; 1-xroc(2:end-1)';]';
%     fprintf('%0.4f\t\t%0.4f\t\t%0.4f\n',table')
%     disp(tr)
%     disp(' ')
%     disp('ROC CURVE ANALYSIS')
%     disp(' ')
%     disp(tr)
%     str2=['AUC\t\t\tS.E.\t\t\t\t' num2str((1-alpha)*100) '%% C.I.\t\t\tComment\n'];
%     fprintf(str2)
%     disp(tr)
%     fprintf('%0.5f\t\t\t%0.5f\t\t\t%0.5f\t\t%0.5f\t\t\t%s\n',Area,Serror,ci,str)
%     disp(tr)
%     fprintf('Standardized AUC\t\t1-tail p-value\n')
%     fprintf('%0.4f\t\t\t\t%0.6f',SAUC,p)
%     if p<=alpha
%         fprintf('\t\tThe area is statistically greater than 0.5\n')
%     else
%         fprintf('\t\tThe area is not statistically greater than 0.5\n')
%     end
%     disp(' ')
%     %display graph
% end
% if(ishandle(hAxes))
%     HR1=plot(hAxes,xroc,yroc,'r.-');
%     hold(hAxes,'on');
%     HRC1=plot(hAxes,[0 1],[0 1],'k');
%     plot(hAxes,[0 1],[1 0],'g')
%     hold(hAxes,'off');
%     xlabel(hAxes,'False positive rate (1-Specificity)')
%     ylabel(hAxes,'True positive rate (Sensitivity)')
%     title(hAxes,'ROC curve')
%     axis(hAxes,'square');
% end
% if(ishandle(hAxesMirror))
%     HR2=plot(hAxesMirror,1-xroc,yroc,'r.-');
%     hold(hAxesMirror,'on');
%     plot(hAxesMirror,[0 1],[0 1],'g')
%     HRC2=plot(hAxesMirror,[0 1],[1 0],'k');
%     hold(hAxesMirror,'off');
%     xlabel(hAxesMirror,'True negative rate (Specificity)')
%     ylabel(hAxesMirror,'True positive rate (Sensitivity)')
%     title(hAxesMirror,'Mirrored ROC curve')
%     axis(hAxesMirror,'square');
% end
lStr = {'ROC curve','Random classifier'};
%if partest.m was downloaded
%if p<=alpha
try
    %the best cut-off point is the closest point to (0,1)
    d=realsqrt(xroc.^2+(1-yroc).^2); %apply the Pitagora's theorem
    [~,J]=min(d); %find the least distance
    co=labels(J-1); %Set the cut-off point
    cutOffPos = [xroc(J),yroc(J)];
%     if(ishandle(hAxes))
%         hold(hAxes,'on');
%         HCO1=plot(hAxes,xroc(J),yroc(J),'bo');
%         hold(hAxes,'off');
        %legend(hAxes,[HR1,HRC1,HCO1],'ROC curve','Random classifier','Cut-off point','Location','NorthOutside')
%     end
%     if(ishandle(hAxesMirror))
%         hold(hAxesMirror,'on');
%         HCO2=plot(hAxesMirror,1-xroc(J),yroc(J),'bo');
%         hold(hAxesMirror,'off');
%         legend(hAxesMirror,[HR2,HRC2,HCO2],'ROC curve','Random classifier',,'Location','NorthOutside')
%     end
    lStr(end+1) = {'Cut-off point'};
%     if(true)%verbose
%         disp(' ')
%         fprintf('Cut-off point for best Sensitivity and Specificity (blu circle in plot)= %0.4f\n',co)
%         disp('In the ROC plot, the cut-off point is the closest to [0,1] point or, if you want, the closest to the green line')
        %disp('Press a key to continue'); pause
        %table at cut-off point
        if hbar<ubar
            TP=length(x(x(:,2)==1 & x(:,1)>co));
            FP=length(x(x(:,2)==0 & x(:,1)>co));
            FN=length(x(x(:,2)==1 & x(:,1)<=co));
            TN=length(x(x(:,2)==0 & x(:,1)<=co));
        else
            TP=length(x(x(:,2)==1 & x(:,1)<co));
            FP=length(x(x(:,2)==0 & x(:,1)<co));
            FN=length(x(x(:,2)==1 & x(:,1)>=co));
            TN=length(x(x(:,2)==0 & x(:,1)>=co));
        end
        cotable=[TP FP; FN TN];
%         disp('Table at cut-off point')
%         disp(cotable)
%         disp(' ')
%         try
            cutOffData = partest(cotable);
%         catch ME
%             disp(ME)
%             disp('If you want to calculate the test performance at cutoff point please download partest.m from Fex')
%             disp('http://www.mathworks.com/matlabcentral/fileexchange/12705')
%         end
%     end
    tmp = cell(size(cutOffData.tableData,1)+2,1);
    tmp(1,1) = {sprintf('Cut off threshold: %02.2f', co)};
    tmp(2,1) = {sprintf('Area under curve (AUC): %02.2f', Area)};
    tmp(3:end,1) = cutOffData.tableData;
    cutOffData.tableData = tmp;    
%else
catch
    cutOffPos = [];
    cutOffData = [];
    co = [];
end
if nargout
    ROCdata.AUC=Area;
    ROCdata.SE=Serror;
    ROCdata.xr=xroc;
    ROCdata.yr=yroc;
    ROCdata.cutOffPos = cutOffPos;
    ROCdata.cutOffData = cutOffData;
    ROCdata.cutOffThreshold = co;
    ROCdata.legend = lStr;
end
