function [im_tcspc, im_chan, im_line, im_col, tcspc_bin_resolution, sync_rate, num_tcspc_channel] =  zeiss_ScanRead(sync, tcspc, channel, special, head, hWaitbar)
%=============================================================================================================
    %
    % @file     zeiss_ScanRead.m
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
    % @brief    A function to convert time-resolved fluorescence data from Zeiss microscopes using PicoQuant TCSPC hardware 
    % based on code from Ingo Grgor and Sumeet Rohilla released under MIT License: https://github.com/PicoQuant/sFLIM 
    %

tcspc_bin_resolution = 1e9*head.MeasDesc_Resolution; % in Nanoseconds
sync_rate            = head.MeasDesc_GlobalResolution*1e9; %ceil(head.MeasDesc_GlobalResolution*1e9); % in Nanoseconds
num_tcspc_channel    = max(tcspc)+1;
%num_tcspc_channel    = floor(sync_rate/tcspc_bin_resolution)+1;
num_pixel_X          = uint16(head.ImgHdr_PixX);
num_pixel_Y          = uint16(head.ImgHdr_PixY);
num_of_detectors     = max(channel);

sync = uint32(sync);
% Get Number of Frames
FrameSyncVal       = sync(special == 4);
num_of_Frames      = size(FrameSyncVal,1);
%read_data_range    = uint32(find(abs(sync - FrameSyncVal(num_of_Frames)) <= eps,1,'last'));
read_data_range    = length(sync);

% Markers necessary to make FLIM image stack
LineStartMarker = 2^(head.ImgHdr_LineStart-1);
LineStopMarker  = 2^(head.ImgHdr_LineStop-1);
FrameMarker     = 2^(head.ImgHdr_Frame-1);

L1  = sync((special == 1));
L2  = sync((special == 2));

% Get pixel dwell time values from header for PicoQuant_FLIMBee or Zeiss_LSM scanner
syncPulsesPerLine = double(floor(mean(L2(1:100,1)- L1(1:100,1))));

% Initialize Variable
currentLine        = 0;
currentSync        = 0;
syncStart          = 0;
currentPixel       = 0;
countFrame         = -1;
insideLine  = false;
insideFrame = true;
isPhoton    = false;

im_tcspc = zeros(read_data_range,1,'uint16');
im_chan  = zeros(read_data_range,1,'uint8');
im_line  = zeros(read_data_range,1,'uint16');
im_col   = zeros(read_data_range,1,'uint16');
mask = true(read_data_range,1);

oneSec = 1/24/60/60;
if(~isempty(hWaitbar))
    tStart = FLIMX.now();
    lastUpdate = tStart;
else
    tStart = 0;
    lastUpdate = 0;
end

% Read each event separately, and build the image matrix as you go
for event = 1:read_data_range    
    currentSync    = sync(event);
    special_event  = special(event);
    currentChannel = channel(event);
    currentTcspc   = tcspc(event);     
    if(special(event) == 0)
        isPhoton = true;
    else
        isPhoton = false;
    end    
    if(~isPhoton)        
        if(special_event == FrameMarker)            
            insideFrame  = true;
            countFrame   = countFrame + 1;
            currentLine  = uint16(1);
            %                 % NEW ADDITION
            %                 if countFrame  == num_of_Frames
            %                     insideFrame = false;
            %                 end
        end        
        if(special_event == LineStartMarker)% && (insideFrame ==  true))            
            insideLine = true;
            syncStart  = currentSync;            
        elseif(special_event == LineStopMarker)            
            insideLine   = false;
            currentLine  = currentLine + 1;
            syncStart    = uint32(0);
            if (currentLine > num_pixel_Y)
                insideFrame = false;
                currentLine  = uint16(1);
            end
        end
    end
    %update image_data matrix if it's a valid photon
    if(isPhoton && insideLine && insideFrame)        
        currentPixel = 1 + floor(num_pixel_X*(double(currentSync - syncStart)/syncPulsesPerLine));        
        if(currentPixel <= num_pixel_X)
            im_tcspc(event)  = uint16(currentTcspc);
            im_chan(event)   = uint8(currentChannel);
            im_line(event)   = uint16(currentLine);
            im_col(event)    = uint16(currentPixel);
%             im_tcspc  = [im_tcspc; uint16(currentTcspc)];  %#ok<AGROW>
%             im_chan   = [im_chan;  uint8(currentChannel)];   %#ok<AGROW>
%             im_line   = [im_line;  uint16(currentLine)];   %#ok<AGROW>
%             im_col    = [im_col;   uint16(currentPixel)];    %#ok<AGROW>
        else
            mask(event) = false;
        end
    else
        mask(event) = false;
    end
    if(~isempty(hWaitbar))
        tNow = FLIMX.now();
        if(tNow - lastUpdate > oneSec)
            [hours, minutes, secs] = secs2hms((tNow-tStart)/oneSec/single(event)*single(read_data_range-event)); %mean cputime for finished runs * cycles left
            minutes = minutes + hours*60;
            p = single(event) / single(read_data_range);
            hWaitbar(0.2 + 0.3*p,sprintf('Converting Zeiss scan data: %02.1f%% - Time left: %dm %.0fs',p*100,minutes,secs));
            lastUpdate = tNow;
        end
    end
    
end % end of looping for all events
if(~isempty(hWaitbar))
    hWaitbar(1,'Converting Zeiss scan data: 100%');
end
im_tcspc = im_tcspc(mask);
im_chan = im_chan(mask);
im_line = im_line(mask);
im_col = im_col(mask);

end