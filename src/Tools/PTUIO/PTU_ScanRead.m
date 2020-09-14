function [head, im_tcspc, im_chan, im_line, im_col] = PTU_ScanRead(name,hWaitbar)
%=============================================================================================================
%
% @file     PTU_ScanRead.m
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
% @brief    A function to read PicoQuant's .ptu
% based on code from Ingo Grgor and Sumeet Rohilla released under MIT License: https://github.com/PicoQuant/sFLIM 
%

head = PTU_Read_Head(name);
nphot = head.TTResult_NumberOfRecords;
oneSec = 1/24/60/60;
[~,~,fext] = fileparts(name);
if(strcmp(fext,'.ptu'))
    if(~isempty(head))
        nx = head.ImgHdr_PixX;
        ny = head.ImgHdr_PixY;
        if(head.ImgHdr_Ident == 1 || head.ImgHdr_Ident == 6)
            anzch      = 32;
            Resolution = max(1e9*head.MeasDesc_Resolution);
            chDiv      = 1e-9*Resolution/head.MeasDesc_Resolution;
            Ngate      = ceil(1e9*head.MeasDesc_GlobalResolution./Resolution)+1;
            LineStart = 4;
            LineStop  = 2;
            if(isfield(head,'ImgHdr_LineStart'))
                LineStart = 2^(head.ImgHdr_LineStart-1);
            end
            if(isfield(head,'ImgHdr_LineStop'))
                LineStop = 2^(head.ImgHdr_LineStop-1);
            end
            y        = [];
            tmpx     = [];
            chan     = [];
            markers  = [];
            dt       = zeros(ny,1);
            im_tcspc = [];
            im_chan  = [];
            im_line  = [];
            im_col   = [];
            Turns1   = [];
            Turns2   = [];
            cnt      = 0;
            tend     = 0;
            line     = 1;
            hWaitbar(0.1,'Please wait ...');
            %fprintf('\n\n');
            if(head.ImgHdr_BiDirect == 0)
                [tmpy, tmptcspc, tmpchan, tmpmarkers, num, loc] = PTU_Read(name, [cnt+1 nphot], head);
                while(num > 0)
                    cnt = cnt + num;
                    if(~isempty(y))
                        tmpy = tmpy + tend;
                    end
                    ind = (tmpmarkers>0)|((tmpchan<anzch)&(tmptcspc<Ngate*chDiv));
                    y       = [y; tmpy(ind)];                         %#ok<AGROW>
                    tmpx    = [tmpx; floor(tmptcspc(ind)./chDiv)+1;]; %#ok<AGROW>
                    chan    = [chan; tmpchan(ind)+1];                 %#ok<AGROW>
                    markers = [markers; tmpmarkers(ind)];             %#ok<AGROW>
                    if(LineStart == LineStop)
                        tmpturns = y(markers==LineStart);
                        if numel(Turns1)>numel(Turns2)           % first turn is a LineStop
                            Turns1 = [Turns1; tmpturns(2:2:end)];      %#ok<AGROW>
                            Turns2 = [Turns2; tmpturns(1:2:end)];      %#ok<AGROW>
                        else
                            Turns1 = [Turns1; tmpturns(1:2:end)];      %#ok<AGROW>
                            Turns2 = [Turns2; tmpturns(2:2:end)];      %#ok<AGROW>
                        end
                    else
                        Turns1 = [Turns1; y(markers == LineStart)]; %#ok<AGROW>
                        Turns2 = [Turns2; y(markers == LineStop)];  %#ok<AGROW>
                    end
                    ind          = (markers ~= 0);
                    y(ind)       = [];
                    tmpx(ind)    = [];
                    chan(ind)    = [];
                    markers(ind) = [];
                    tend = y(end) + loc;
                    if(numel(Turns2) > 1)
                        for j = 1:numel(Turns2)-1
                            t1 = Turns1(1);
                            t2 = Turns2(1);
                            ind          = (y<t1);
                            y(ind)       = [];
                            tmpx(ind)    = [];
                            chan(ind)    = [];
                            markers(ind) = [];
                            ind = (y>=t1)&(y<=t2);
                            im_tcspc  = [im_tcspc; uint16(tmpx(ind))];              %#ok<AGROW>
                            im_chan   = [im_chan; uint8(chan(ind))];                %#ok<AGROW>
                            im_line   = [im_line; uint16(line.*ones(sum(ind),1))];  %#ok<AGROW>
                            im_col    = [im_col;  uint16(1 + floor(nx.*(y(ind)-t1)./(t2-t1)))];  %#ok<AGROW>
                            dt(line)  = t2-t1;
                            line = line +1;
                            hWaitbar(0.1 + 0.4*line/ny,sprintf('Reading line %d of %d...',line,ny));
                            %drawnow
                            Turns1(1) = [];
                            Turns2(1) = [];
                        end
                    end
                    [tmpy, tmptcspc, tmpchan, tmpmarkers, num, loc] = PTU_Read(name, [cnt+1 nphot], head);
                end
                t1 = Turns1(end);
                t2 = Turns2(end);
                ind          = y < t1;
                y(ind)       = [];
                tmpx(ind)    = [];
                chan(ind)    = [];
                ind = (y >= t1) & (y <= t2);
                im_tcspc  = [im_tcspc; uint16(tmpx(ind))];
                im_chan   = [im_chan; uint8(chan(ind))];
                im_line   = [im_line; uint16(line.*ones(sum(ind),1))];
                im_col    = [im_col;  uint16(1 + floor(nx.*(y(ind)-t1)./(t2-t1)))];
                dt(line)  = t2-t1;
                line = line +1;
                hWaitbar(0.1 + 0.4*line/ny,sprintf('Reading line %d of %d...',line,ny));
                %drawnow
            else  % bidirectional scan
                [tmpy, tmptcspc, tmpchan, tmpmarkers, num, loc] = PTU_Read(name, [cnt+1 nphot], head);
                while(num > 0)
                    cnt = cnt + num;
                    if(~isempty(y))
                        tmpy = tmpy + tend;
                    end
                    ind = ((tmpchan < anzch) & (tmptcspc <= Ngate*chDiv));
                    y       = [y; tmpy(ind)];                         %#ok<AGROW>
                    tmpx    = [tmpx; floor(tmptcspc(ind)./chDiv)+1;]; %#ok<AGROW>
                    chan    = [chan; tmpchan(ind)+1];                   %#ok<AGROW>
                    markers = [markers; tmpmarkers(ind)];             %#ok<AGROW>
                    if(LineStart == LineStop)
                        tmpturns = y(markers == LineStart);
                        if numel(Turns1) > numel(Turns2)           % first turn is a LineStop
                            Turns1 = [Turns1; tmpturns(2:2:end)];      %#ok<AGROW>
                            Turns2 = [Turns2; tmpturns(1:2:end)];      %#ok<AGROW>
                        else
                            Turns1 = [Turns1; tmpturns(1:2:end)];      %#ok<AGROW>
                            Turns2 = [Turns2; tmpturns(2:2:end)];      %#ok<AGROW>
                        end
                    else
                        Turns1 = [Turns1; y(markers == LineStart)]; %#ok<AGROW>
                        Turns2 = [Turns2; y(markers == LineStop)];  %#ok<AGROW>
                    end
                    ind          = (markers ~= 0);
                    y(ind)       = [];
                    tmpx(ind)    = [];
                    chan(ind)    = [];
                    markers(ind) = [];
                    tend = y(end) + loc;
                    if(numel(Turns2) > 2)
                        for j = 1:2:2*floor(numel(Turns2)/2-1)
                            t1 = Turns1(1);
                            t2 = Turns2(1);
                            ind          = (y<t1);
                            y(ind)       = [];
                            tmpx(ind)    = [];
                            chan(ind)    = [];
                            markers(ind) = [];
                            ind = (y >= t1) & (y <= t2);
                            im_tcspc  = [im_tcspc; uint16(tmpx(ind))];              %#ok<AGROW>
                            im_chan   = [im_chan; uint8(chan(ind))];                %#ok<AGROW>
                            im_line   = [im_line; uint16(line.*ones(sum(ind),1))];  %#ok<AGROW>
                            im_col    = [im_col;  uint16(1 + floor(nx.*(y(ind)-t1)./(t2-t1)))];  %#ok<AGROW>
                            dt(line)  = t2-t1;
                            line = line +1;
                            t1 = Turns1(2);
                            t2 = Turns2(2);
                            ind = y < t1;
                            y(ind)       = [];
                            tmpx(ind)    = [];
                            chan(ind)    = [];
                            markers(ind) = [];
                            ind = (y >= t1) & (y <= t2);
                            im_tcspc  = [im_tcspc; uint16(tmpx(ind))];              %#ok<AGROW>
                            im_chan   = [im_chan; uint8(chan(ind))];                %#ok<AGROW>
                            im_line   = [im_line; uint16(line.*ones(sum(ind),1))];  %#ok<AGROW>
                            im_col    = [im_col;  uint16(nx - floor(nx.*(y(ind)-t1)./(t2-t1)))];  %#ok<AGROW>
                            dt(line)  = t2 - t1;
                            line = line +1;
                            hWaitbar(0.1 + 0.4*line/ny,sprintf('Reading line %d of %d...',line,ny));
                            %drawnow
                            Turns1(1:2) = [];
                            Turns2(1:2) = [];
                        end
                    end
                    [tmpy, tmptcspc, tmpchan, tmpmarkers, num, loc] = PTU_Read(name, [cnt+1 nphot], head);
                end
                if(~isempty(Turns2))
                    t1 = Turns1(end-1);
                    t2 = Turns2(end-1);
                    ind = y < t1;
                    y(ind)       = [];
                    tmpx(ind)    = [];
                    chan(ind)    = [];
                    ind = (y >= t1) & ( y<= t2);
                    im_tcspc  = [im_tcspc; uint16(tmpx(ind))];
                    im_chan   = [im_chan; uint8(chan(ind))];
                    im_line   = [im_line; uint16(line.*ones(sum(ind),1))];
                    im_col    = [im_col;  uint16(1 + floor(nx.*(y(ind)-t1)./(t2-t1)))];
                    dt(line)  = t2 - t1;
                    line = line +1;
                    t1 = Turns1(end);
                    t2 = Turns2(end);
                    ind = y < t1;
                    y(ind)       = [];
                    tmpx(ind)    = [];
                    chan(ind)    = [];
                    ind = (y >= t1) & (y <= t2);
                    im_tcspc  = [im_tcspc; uint16(tmpx(ind))];
                    im_chan   = [im_chan; uint8(chan(ind))];
                    im_line   = [im_line; uint16(line.*ones(sum(ind),1))];
                    im_col    = [im_col;  uint16(nx - floor(nx.*(y(ind)-t1)./(t2-t1)))];
                    dt(line)  = t2-t1;
                    line = line +1;
                    hWaitbar(0.1 + 0.4*line/ny,sprintf('Reading line %d of %d...',line,ny));
                    %drawnow
                end
            end
            head.ImgHdr_PixelTime = 1e9.*mean(dt)/nx/head.TTResult_SyncRate;
        elseif(head.ImgHdr_Ident == 3 || head.ImgHdr_Ident == 9)
            y        = [];
            tmpx     = [];
            chan     = [];
            marker   = [];
            dt       = zeros(ny,1,'uint32');
            im_tcspc = [];
            im_chan  = [];
            im_line  = [];
            im_col   = [];
            cnt      = 0;
            tend     = 0;
            line     = 1;
            n_frames = 0;
            f_times  = [];
            head.ImgHdr_X0       = 0;
            head.ImgHdr_Y0       = 0;
            head.ImgHdr_PixResol = 1;
            LineStart = 2^(head.ImgHdr_LineStart-1);
            LineStop  = 2^(head.ImgHdr_LineStop-1);
            Frame     = 2^(head.ImgHdr_Frame-1);
            hWaitbar(0.1,sprintf('Reading %.2f MB from disk...',nphot*4/1e6));
            if(Frame < 1)
                Frame = -1;
            end
            in_frame = false;
            if(Frame < 1)
                in_frame = true;
                n_frames = n_frames + 1;
            end
            [tmpy, tmptcspc, tmpchan, tmpmarkers, num, loc] = PTU_Read(name, [cnt+1 nphot], head);
            % Zeiss Scan Read
            if(isfield(head,'StartedByRemoteInterface'))
                cnt  = cnt + num;
                tmpchan = tmpchan+1;
                %hWaitbar(cnt/head.TTResult_NumberOfRecords,'');
                hWaitbar(0.2,'Converting Zeiss scan data');
                pool = gcp('nocreate');
                if(~isempty(pool))
                    %use multiple CPU cores
                    idxTiles = unique([1; find(tmpmarkers == 4); length(tmpy)]); %find frame markers
                    if(length(idxTiles) < 3)
                        %no markers found -> nothing to do
                        return
                    end
                    idxTiles(end) = idxTiles(end)+1;
                    tmp = cell(length(idxTiles)-1,7);
                    c_tmpy = parallel.pool.Constant(tmpy);
                    c_tmptcspc = parallel.pool.Constant(tmptcspc);
                    c_tmpchan = parallel.pool.Constant(tmpchan);
                    c_tmpmarkers = parallel.pool.Constant(tmpmarkers);
                    c_idxTiles = parallel.pool.Constant(idxTiles);
                    %                     tic;
                    %                     ticBytes(pool);
                    parfor i=1:length(idxTiles)-1
                        [tmp{i,:}] = zeiss_ScanRead(c_tmpy.Value(c_idxTiles.Value(i):c_idxTiles.Value(i+1)-1,1), c_tmptcspc.Value(c_idxTiles.Value(i):c_idxTiles.Value(i+1)-1,1),...
                            c_tmpchan.Value(c_idxTiles.Value(i):c_idxTiles.Value(i+1)-1,1), c_tmpmarkers.Value(c_idxTiles.Value(i):c_idxTiles.Value(i+1)-1,1), head, []);
                    end
                    %                     tocBytes(pool)
                    %                     toc
                    im_tcspc = vertcat(tmp{:,1});
                    im_chan = vertcat(tmp{:,2});
                    im_line = vertcat(tmp{:,3});
                    im_col = vertcat(tmp{:,4});
                    tcspc_bin_resolution = tmp{1,5};
                    tacRange = tmp{1,6};
                    %num_tcspc_channel = tmp{1,7};
                    clear tmp
                else
                    %single core execution
                    [im_tcspc, im_chan, im_line, im_col, tcspc_bin_resolution, tacRange, num_tcspc_channel] =  zeiss_ScanRead(tmpy, tmptcspc, tmpchan, tmpmarkers, head, hWaitbar);
                end
                clear tmpy tmptcspc tmpchan tmpmarkers num loc;
                head.tacRange = tacRange;
                head.nrTimeChannels = round(tacRange / tcspc_bin_resolution);% num_tcspc_channel;
                idx = im_tcspc > head.nrTimeChannels;
                im_tcspc = im_tcspc(~idx);
                im_chan = im_chan(~idx);
                im_line = im_line(~idx);
                im_col = im_col(~idx);
            else
                while(num > 0)
                    %                     t_tcspc  = [];
                    %                     t_chan   = [];
                    %                     t_line   = [];
                    %                     t_col    = [];
                    cnt = cnt + num;
                    hWaitbar(0.1 + 0.1*cnt/head.TTResult_NumberOfRecords,sprintf('Read %.2f MB of %.2f MB from disk...',nphot*4/1e6,head.TTResult_NumberOfRecords*4/1e6));
                    tmpy = tmpy+tend;
                    y       = [y; tmpy];                       %#ok<AGROW>
                    clear tmpy
                    tmpx    = [tmpx; tmptcspc];                %#ok<AGROW>
                    clear tmptcspc
                    chan    = [chan; tmpchan+1];                 %#ok<AGROW>
                    clear tmpchan
                    marker  = [marker; tmpmarkers];            %#ok<AGROW>
                    clear tmpmarkers
                    t_tcspc  = zeros(size(tmpx),'like',tmpx);
                    t_chan   = zeros(size(chan),'like',chan);
                    t_line   = zeros(size(tmpx),'like',tmpx);
                    t_col    = zeros(size(tmpx),'like',tmpx);
                    counter = 0;
                    tend    = y(end)+loc;
                    %F  = y(bitand(marker,Frame)>0);
                    F = y(marker == uint8(Frame));
                    FLen = length(F);
                    tStart = FLIMX.now();
                    lastUpdate = tStart;
                    activeMask = true(size(y));
                    while(~isempty(F) && any(activeMask))
                        tNow = FLIMX.now();
                        if(tNow - lastUpdate > oneSec)
                            FLenNow = length(F);
                            p = (FLen-FLenNow) / FLen;
                            [hours, minutes, secs] = secs2hms((tNow-tStart)/oneSec/(FLen-FLenNow)*FLenNow); %mean cputime for finished runs * cycles left
                            minutes = minutes + hours*60;
                            hWaitbar(0.2 + 0.3*p,sprintf('Converting scan data: %02.1f%% - Time left: %dm %.0fs',p*100,minutes,secs));
                            lastUpdate = tNow;
                        end
                        if(~in_frame)
                            ind = y <= F(1) & activeMask;
                            activeMask(ind) = false;
                            %                             y(ind)       = [];
                            %                             tmpx(ind)    = [];
                            %                             chan(ind)    = [];
                            %                             marker(ind)  = [];
                            line         = 1;
                            in_frame     = true;
                            n_frames     = n_frames + 1;
                            f_times      = [f_times; F(1)];
                            F(1)         = [];
                        end
                        if(~isempty(F))
                            ind = y < F(1) & activeMask; %ind = y < F(1) & activeMask;
                            if(sum(ind) == 0)
                                in_frame = false;
                                continue
                            end
                            f_y  = y(ind);
                            f_x  = tmpx(ind);
                            f_ch = chan(ind);
                            f_m  = marker(ind);
                            activeMask(ind) = false;
                            %                             y(ind)      = [];
                            %                             tmpx(ind)   = [];
                            %                             chan(ind)   = [];
                            %                             marker(ind) = [];
                        end
                        %L1 = f_y(bitand(f_m,LineStart)>0);
                        L1 = f_y(f_m == uint8(LineStart));
                        %L2 = f_y(bitand(f_m,LineStop)>0);
                        L2 = f_y(f_m == uint8(LineStop));
                        ll = line + numel(L2)-1; % this will be the last complete line in the data stack
                        if(ll > ny)
                            L1 = L1(1:ny-line+1);
                            L2 = L2(1:ny-line+1);
                        end
                        if(numel(L1) > 1)
                            for j = 1:numel(L2)
                                ind = (f_y > L1(j)) & (f_y < L2(j));
                                %                                 t_tcspc  = [t_tcspc; uint16(f_x(ind))];              %#ok<AGROW>
                                %                                 t_chan   = [t_chan; uint8(f_ch(ind))];                %#ok<AGROW>
                                %                                 t_line   = [t_line; uint16(line.*ones(sum(ind),1))];  %#ok<AGROW>
                                %                                 t_col    = [t_col;  uint16(1 + floor(nx.*(f_y(ind)-L1(j))./(L2(j)-L1(j))))];  %#ok<AGROW>
                                indLen = sum(ind);
                                t_tcspc(counter+1:counter+indLen,1)  = uint16(f_x(ind));
                                t_chan(counter+1:counter+indLen,1)   = uint8(f_ch(ind));
                                t_line(counter+1:counter+indLen,1)   = uint16(line.*ones(indLen,1));
                                t_col(counter+1:counter+indLen,1)    = uint16(1 + floor(nx.*(f_y(ind)-L1(j))./(L2(j)-L1(j))));
                                counter = counter + indLen;
                                dt(line) = dt(line) + (L2(j)-L1(j));
                                line = line +1;
                            end
                        end
                        if(line > ny)
                            in_frame = false;
                        end
                    end
                    t_tcspc = t_tcspc(1:counter,1);
                    t_chan = t_chan(1:counter,1);
                    t_line = t_line(1:counter,1);
                    t_col = t_col(1:counter,1);
                    im_tcspc  = [im_tcspc; t_tcspc];  %#ok<AGROW>
                    im_chan   = [im_chan;  t_chan];   %#ok<AGROW>
                    im_line   = [im_line;  t_line];   %#ok<AGROW>
                    im_col    = [im_col;   t_col];    %#ok<AGROW>
                    [tmpy, tmptcspc, tmpchan, tmpmarkers, num, loc] = PTU_Read(name, [cnt+1 nphot], head);
                end
                %F  = y(bitand(marker,Frame) > 0);
                F = y(marker == uint8(Frame));
                %                 t_tcspc  = [];
                %                 t_chan   = [];
                %                 t_line   = [];
                %                 t_col    = [];
                if(~in_frame)
                    if(isempty(F))
                        y       = [];
                        tmpx    = [];
                        chan    = [];
                        marker  = [];
                        line    = 1;
                    else
                        ind = y <= F(1);
                        y(ind)       = [];
                        tmpx(ind)    = [];
                        chan(ind)    = [];
                        marker(ind)  = [];
                        line         = 1;
                        n_frames     = n_frames + 1;
                        f_times      = [f_times; F(1)];
                    end
                end
                f_y = y;
                f_x = tmpx;
                f_ch = chan;
                f_m  = marker;
                clear y tmpx chan marker
                t_tcspc  = zeros(size(f_x),'like',f_x);
                t_chan   = zeros(size(f_ch),'like',f_ch);
                t_line   = zeros(size(f_x),'like',f_x);
                t_col    = zeros(size(f_x),'like',f_x);
                counter = 0;
                %L1 = f_y(bitand(f_m,LineStart) > 0);
                L1 = f_y(f_m == uint8(LineStart));
                %L2 = f_y(bitand(f_m,LineStop)>0);
                L2 = f_y(f_m == uint8(LineStop));
                ll = line + numel(L2)-1; % this will be the last complete line in the data stack
                if(ll > ny)
                    L1 = L1(1:ny-line+1);
                    L2 = L2(1:ny-line+1);
                end
                if(numel(L1) > 1)
                    for j = 1:numel(L2)
                        ind = (f_y > L1(j)) & (f_y < L2(j));
                        %                         t_tcspc  = [t_tcspc; uint16(f_x(ind))];              %#ok<AGROW>
                        %                         t_chan   = [t_chan; uint8(f_ch(ind))];                %#ok<AGROW>
                        %                         t_line   = [t_line; uint16(line.*ones(sum(ind),1))];  %#ok<AGROW>
                        %                         t_col    = [t_col;  uint16(1 + floor(nx.*(f_y(ind)-L1(j))./(L2(j)-L1(j))))];  %#ok<AGROW>
                        indLen = sum(ind);
                        t_tcspc(counter+1:counter+indLen,1)  = uint16(f_x(ind));
                        t_chan(counter+1:counter+indLen,1)   = uint8(f_ch(ind));
                        t_line(counter+1:counter+indLen,1)   = uint16(line.*ones(indLen,1));
                        t_col(counter+1:counter+indLen,1)    = uint16(1 + floor(nx.*(f_y(ind)-L1(j))./(L2(j)-L1(j))));
                        counter = counter + indLen;
                        dt(line) = dt(line) + (L2(j)-L1(j));
                        line = line +1;
                    end
                end
                t_tcspc = t_tcspc(1:counter,1);
                t_chan = t_chan(1:counter,1);
                t_line = t_line(1:counter,1);
                t_col = t_col(1:counter,1);
                im_tcspc  = [im_tcspc; t_tcspc];
                im_chan   = [im_chan;  t_chan];
                im_line   = [im_line;  t_line];
                im_col    = [im_col;   t_col];
                
                head.tacRange = head.MeasDesc_GlobalResolution*1e9;
                head.nrTimeChannels = round(head.tacRange / (1e9*head.MeasDesc_Resolution));
            end
            %head.ImgHdr_FrameTime = 1e9.*mean(diff(f_times))/head.TTResult_SyncRate;
            if(isfield(head,'TimePerPixel'))
                head.ImgHdr_PixelTime = head.TimePerPixel;
            else
                head.ImgHdr_PixelTime = 0;
            end
            %head.ImgHdr_DwellTime = head.ImgHdr_PixelTime./n_frames;
        end
        head.nrSpectralChannels = max(im_chan(:));
        %         head.nrTimeChannels = max(im_tcspc);
    end
end

% if(~isempty(head) && (plt == 1))
%     tag = zeros(nx,ny);
%     for y = 1:ny
%         ind = (im_line == y);
%         tmp1 = im_col(ind);
%         for x = 1:nx
%             tag(y,x) = sum(tmp1 == x);
%         end
%     end
%     x = head.ImgHdr_X0+(1:nx)*head.ImgHdr_PixResol;
%     y = head.ImgHdr_Y0+(1:ny)*head.ImgHdr_PixResol;
%     figure; imagesc(x,y,tag);
%     set(gca,'DataAspectRatio', [1,1,1], ...
%         'PlotBoxAspectRatio',[1 1 1], ...
%         'XDir','normal', ...
%         'YDir','reverse');
%     xlabel('x / µm');
%     ylabel('y / µm');
% end