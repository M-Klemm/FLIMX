function [eyePos, confidence, imgVessels] = eyePosition(fluoIntImg)
%=============================================================================================================
%
% @file     eyePosition.m
% @author   Matthias Klemm <Matthias_Klemm@gmx.net>
% @version  1.0
% @date     August, 2017
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
% @brief    A function to guess the position (left or right side) from fluorescence (FLIO) intensity images
%           utilizes:
%           Computer Assisted Retinal Blood Vessel Segmentation Algorithm Developed and Copyrighted by Tyler L. Coye (2015)
%

fluoIntImg = double(fluoIntImg);
fluoIntImg = fluoIntImg./max(double(fluoIntImg(:)));
% Contrast Enhancment of gray image using CLAHE
imgHE = adapthisteq(fluoIntImg,'numTiles',[8 8],'nBins',256);
% Background Exclusion
% Apply Average Filter
ks = 9;
h = fspecial('average', [ks ks]);
imgAF = imfilter(imgHE, h);
% Take the difference between the gray image and Average Filter
imgDiff = imgAF-imgHE;
% Threshold using the IsoData Method
th = isodata(imgDiff); % this is our threshold level
% Convert to Binary
%BW = im2bw(Z, level-.008)
imgBin = imbinarize(imgDiff, th*0.6);
imgBin = imresize(imgBin, 2*size(fluoIntImg));
%do morphological operations at a higher resolution
SE = strel('disk',2);
imgBin = imclose(imgBin,SE);
imgBin = imopen(imgBin,SE);
imgBin = imresize(imgBin, size(fluoIntImg));
% Remove small pixels
imgVessels = bwareaopen(imgBin, round(size(fluoIntImg,1)/4));
[~, gradDir] = imgradient(bwmorph(imgVessels,'skel',Inf),'prewitt');
gradDir = gradDir + 180;
gradDir(gradDir >= 360) = gradDir(gradDir >= 360)-360;
gradDir(gradDir >= 180) = gradDir(gradDir >= 180)-180;
gradDir = imclose(gradDir,SE);
gradDir(~bwareaopen(logical(gradDir), round(size(fluoIntImg,1)/4))) = 0;
gradDir(~imgBin) = 0;
%remove possible artifacts at the edge of the image
gradDir(:,1:5) = 0;
gradDir(:,end-4:end) = 0;
gradDir(1:5,:) = 0;
gradDir(end-4:end,:) = 0;
%divide image in 4 quadrants
hSplitLine = round(size(fluoIntImg,1)/2);
vSplitLine = round(size(fluoIntImg,2)/2);
%accepted angle variation
a = 45; %degrees
qLowLeft = gradDir(1:hSplitLine,1:vSplitLine);
qUpLeft = gradDir(hSplitLine+1:end,1:vSplitLine);
qLowRight = gradDir(1:hSplitLine,vSplitLine+1:end);
qUpRight = gradDir(hSplitLine+1:end,vSplitLine+1:end);
%assume optic disc is on the left side
leftEyeMask = zeros(size(gradDir),'logical');
leftEyeMask(1:hSplitLine,1:vSplitLine) = (qLowLeft > 0 & qLowLeft < 180); %bottom left
leftEyeMask(hSplitLine+1:end,1:vSplitLine) = (qUpLeft > 0 & qUpLeft < 180); %top left
leftEyeMask(1:hSplitLine,vSplitLine+1:end) = (qLowRight <= 180-a & qLowRight > a); %bottom right
leftEyeMask(hSplitLine+1:end,vSplitLine+1:end) = (qUpRight >= a & qUpRight < 180-a); %top right
%assume optic disc is on the right side
rightEyeMask = zeros(size(gradDir),'logical');
rightEyeMask(1:hSplitLine,1:vSplitLine) = (qLowLeft >= a & qLowLeft < 180-a); %bottom left
rightEyeMask(hSplitLine+1:end,1:vSplitLine) = (qUpLeft <= 180-a & qUpLeft > a); %top left
rightEyeMask(1:hSplitLine,vSplitLine+1:end) = (qLowRight > 0 & qLowRight < 180); %bottom right
rightEyeMask(hSplitLine+1:end,vSplitLine+1:end) = (qUpRight > 0 & qUpRight < 180); %top right
leftEyeScore = sum(leftEyeMask(:));
rightEyeScore = sum(rightEyeMask(:));
eyeRatio = leftEyeScore ./ rightEyeScore;
if(eyeRatio > 1)
    %left eye
    eyePos = 'OS';
else
    %right eye
    eyeRatio = 1./ eyeRatio;
    eyePos = 'OD';
end
confidence = eyeRatio -1;

% figure, imagesc(Gdir)
% set(gca,'YDir','normal')
% figure, imagesc(leftFull)
% set(gca,'YDir','normal')
% figure, imagesc(rightFull)
% set(gca,'YDir','normal')