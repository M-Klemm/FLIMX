function out = make3DPhHist(imSzY, imSzX, im_tcspc, im_chan, im_line, im_col, nrTimeCh, spectralCh, hWaitbar)
%=============================================================================================================
    %
    % @file     make3DPhHist.m
    % @author   Matthias Klemm <Matthias_Klemm@gmx.net>
    % @version  1.0
    % @date     September, 2020
    %
    % @section  LICENSE
    %
    % Copyright (C) 2020, Matthias Klemm. All rights reserved.
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
    % @brief    A function to build a three-dimensional photon histogram (y,x,time) 
    % partly based on code from Ingo Grgor and Sumeet Rohilla released under MIT License: https://github.com/PicoQuant/sFLIM 
    %

%make three-dimensional photon histogram (y,x,time) for specific spectral channel
if(spectralCh > max(im_chan(:)))
    out = uint16([]);
    return
else
    out = zeros([imSzY,imSzX,nrTimeCh],'like',im_tcspc);
end
pool = gcp('nocreate');
if(~isempty(pool) && ~isa(pool,'parallel.ThreadPool'))
    updateProgress = true;
    oneSec = 1/24/60/60;
    tStart = FLIMX.now();
    lastUpdate = tStart;
    dataQueue = parallel.pool.DataQueue;
    afterEach(dataQueue, @nUpdateWaitbar);
    linesDone = 1;
else
    dataQueue = [];
    updateProgress = false;
end
myWaitbar = [];
if(~isa(hWaitbar,'function_handle'))
    myWaitbar = waitbar(0.5,'Building photon histogram...');
    hWaitbar = @(x,txt) waitbar(x,myWaitbar,sprintf('%s%s\n%s',fname,fext,txt));
end

idxCh = im_chan == spectralCh & im_tcspc <= nrTimeCh;
%idxTimeCh = (1:single(nrTimeCh))';
im_tcspc = im_tcspc(idxCh);
im_line = im_line(idxCh);
im_col = im_col(idxCh);
n = uint32(length(im_tcspc));
%     y = int32(0);
%     maskX = false;
%     valX = uint16(0);
%     indX = uint16(0);
%     indTmp = uint16(0);
indN = (1:n)';
%indPh = uint16(0);
%indCh = uint16(0);

%remove zeros, inf, NaN
idx = im_tcspc == 0 | isinf(im_tcspc) | isnan(im_tcspc);
im_tcspc = im_tcspc(~idx);
im_col = im_col(~idx);
im_line = im_line(~idx);
%sort data according to lines
[im_line_sort, idx] = sort(im_line);
line_counts = cumsum(histcounts(single(im_line_sort),0:single(imSzY)+1));
im_tcspc = im_tcspc(idx);
im_col = im_col(idx);
%clear idx im_line_sort

c_col = parallel.pool.Constant(im_col);
c_tcspc = parallel.pool.Constant(im_tcspc);
c_n = parallel.pool.Constant(indN);
c_lineCounts = parallel.pool.Constant(line_counts);

%ticBytes(pool);
%% y outer loop
parfor y = 1:int32(imSzY)
    if(c_lineCounts.Value(y) == c_lineCounts.Value(y+1))
        continue
    end
    indY = c_lineCounts.Value(y)+1:c_lineCounts.Value(y+1);
    curRow = out(y,:,:); %zeros([imSzX,nrTimeCh],'like',im_tcspc);
    curCols = c_col.Value(indY); %get all columns of current line
    idxCols = c_n.Value(indY); %get indices for current line
    for x = 1:imSzX
        maskCol = curCols == x; %select only current column
        if(~any(maskCol))
            continue
        end
        idxCol = idxCols(maskCol); %get indices of current column
        %tmp(x,:) = mHist(tmp(x,:), im_tcspc(idxCol), idxTimeCh);
        valCol = c_tcspc.Value(idxCol); %values in current column (photon arrival time channels)
        %             if(sum(diff(diff(idxTimeCh))) == 0)
        %                 dx = single(0);
        %                 if(nrTimeCh > 1)
        %                     dx = idxTimeCh(2)-idxTimeCh(1);
        %                 end
        %                 if(dx ~= 0)
        %                     valX = round((valX-idxTimeCh(1))/dx)+1;
        %                     xmax = round((idxTimeCh(end)-idxTimeCh(1))/dx)+1;
        %                 else
        %                     valX = round(valX-idxTimeCh(1))+1;
        %                 end
        %             else
        %                 valX = round(interp1(idxTimeCh,1:length(idxTimeCh),valX));
        %                 xmax = round(interp1(idxTimeCh,1:length(idxTimeCh),idxTimeCh(end)));
        %             end
        %end
        valCol = sort(valCol);
        curRow(1,x,valCol) = 1;
        diffTmp = diff(int8(diff([0; int8(valCol); 0]) == 0));
        idxTmp = zeros(1,1,length(valCol),'like',im_tcspc);
        idxTmp(1,1,:) = 1:cast(length(valCol),'like',im_tcspc);
        curRow(1,x,valCol(diffTmp == 1)) = curRow(1,x,valCol(diffTmp == 1)) + idxTmp(1,1,diffTmp == -1) - idxTmp(1,1,diffTmp == 1);
    end
    out(y,:,:) = curRow;
    if(updateProgress)
        send(dataQueue, y);
    end
end
%tocBytes(pool)

if(~isempty(myWaitbar))
    close(myWaitbar);
end

    function nUpdateWaitbar(~)
        tNow = FLIMX.now();
        if(tNow - lastUpdate > oneSec)
            [hours, minutes, secs] = secs2hms((tNow-tStart)/oneSec/linesDone*(double(imSzY)-linesDone)); %mean cputime for finished runs * cycles left
            minutes = minutes + hours*60;
            hWaitbar(0.5+0.5*linesDone/double(imSzY),sprintf('Building photon histogram: %02.1f%% - Time left: %dm %.0fs',linesDone/double(imSzY)*100,minutes,secs));
            lastUpdate = tNow;
        end
        linesDone = linesDone + 1;
    end
end

%% x outer loop
%     parfor x = 1:imSzX
%         indX = find(im_col == x);
%         tmp = squeeze(out(:,x,:)); %zeros([imSzX,nrTimeCh],'like',im_tcspc);
%         for y = 1:int32(imSzY)
%             if(line_counts(y) == line_counts(y+1))
%                 continue
%             end
%             valX = im_col(indY);
%             indY = line_counts(y)+1:line_counts(y+1);
%             ind = intersect(indX,indY);
%             if(isempty(ind))
%                 continue
%             end
%             tmp(x,:) = mHist(tmp(y,:), im_tcspc(ind),idxTimeCh);
%         end
%         out(:,x,:) = tmp;
%     end

%% save column indices -> slower
%     col_save = cell(imSzX,1);
%
%     %calculate line 1 to get x data
%     indY = line_counts(1)+1:line_counts(2);
%     for x = 1:imSzX
%         maskX = (im_col == x);
%         col_save{x,:} = find(maskX);
%         if(~isempty(col_save{x,1}))
%             %nothing was ever detected in this column!
%             continue
%         end
%         ind = intersect(col_save{x,1},indY);
%         out(1,x,:) = mHist(squeeze(out(1,x,:))', im_tcspc(ind),idxTimeCh);
%     end
%
%     for y = 1:int32(imSzY)
%         if(line_counts(y) == line_counts(y+1))
%             continue
%         end
%         indY = line_counts(y)+1:line_counts(y+1);
%         tmp = squeeze(out(y,:,:)); %zeros([imSzX,nrTimeCh],'like',im_tcspc);
%         for x = 1:imSzX
%             if(isempty(col_save{x,1}))
%                 %nothing was ever detected in this column!
%                 continue
%             end
%             ind = intersect(col_save{x,1},indY);
%             if(isempty(ind))
%                 %nothing was ever detected in this column!
%                 continue
%             end
%             tmp(x,:) = mHist(tmp(x,:), im_tcspc(ind),idxTimeCh);
%
%         end
%         out(y,:,:) = tmp;
%     end

%% ref
%     parfor y = 1:int32(imSzY)
%         maskY = (im_line == y);
%         if(~any(maskY))
%             continue
%         end
%         tmp = squeeze(out(y,:,:)); %zeros([imSzX,nrTimeCh],'like',im_tcspc);
%         for x = 1:imSzX
%             valX = im_col(maskY);
%             indTmp = indN(maskY);
%             maskX = valX == x;
%             if(~any(maskX))
%                 continue
%             end
%             indX = indTmp(maskX);
%             %maskX = (im_col == x);
%             %indPh = im_tcspc(maskY & maskX);
%             %indCh = im_chan(maskY & maskX);
%
%             %for ch = 1:nrSpectralCh
%                 %tmp(x,:) = mHist(tmp(x,:), indPh(indCh == spectralCh),1:nrTimeCh);
%             %end
%             tmp(x,:) = mHist(tmp(x,:), im_tcspc(indX),idxTimeCh);
%         end
%         out(y,:,:) = tmp;
%     end