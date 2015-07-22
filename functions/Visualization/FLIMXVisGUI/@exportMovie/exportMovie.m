classdef exportMovie < handle
    %=============================================================================================================
    %
    % @file     measurementFile.m
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
    % @brief    A class to control generation of movies from FLIMXVisGUI
    %
    properties(GetAccess = public, SetAccess = private)
        visObj = [];
        visHandles = [];
        startObj = [];
        endObj = [];
        prevObj = [];
        prodObj = [];        
    end
    
    properties (Dependent = true)
        side = 'r';
        viewStart = [];
        viewEnd = [];
        viewDelta = [];
        nrFrames = 100;
        fps = 25;
        nrSeconds = 4;
        screenWidth = 0;
        screenHeight = 0;
        movieWidth = 0;
        movieHeight = 0;
        cMap = [];
        projectionMode = '';
        camAngleMode = 0;
        zScaling = 0;
        alphaMode = 0;
        intAtBottom = 0;
        dropLastFrame = 0;
    end
    
    methods
        function this = exportMovie(visObj)
            %constructor
            if(isempty(visObj))               
                error('Handle to FLIMVis object required!');
            end
            this.visObj = visObj;
        end
        
        function closeCallback(this)
            %executed when figure should be closed
            if(this.isOpenVisWnd())
                delete(this.visHandles.exportMovieFigure);
            end
        end
        
        function out = isOpenVisWnd(this)
            %check if figure is still open
            out = ~(isempty(this.visHandles) || ~ishandle(this.visHandles.exportMovieFigure) || ~strcmp(get(this.visHandles.exportMovieFigure,'Tag'),'exportMovieFigure'));
        end
        
        function checkVisWnd(this)
            %if not reopen
            if(~this.isOpenVisWnd())
                %no window - open one
                this.createVisWnd();
            end
            this.setupGUI();
            this.updateGUI();
            figure(this.visHandles.exportMovieFigure);
        end
        
        function getMovieObjs(this)
            %create movie object from visObj display object
            this.startObj = FMovie(this.visObj.objHandles.(sprintf('%sdo',this.side)),this.visHandles.axesStart);
            this.startObj.setDispView(this.viewStart);
            this.endObj = FMovie(this.visObj.objHandles.(sprintf('%sdo',this.side)),this.visHandles.axesEnd);
            this.endObj.setDispView(this.viewEnd);
            this.prevObj = FMovie(this.visObj.objHandles.(sprintf('%sdo',this.side)),this.visHandles.axesPreview);
            this.prevObj.setDispView(this.viewStart);
            this.prodObj = FMovie(this.visObj.objHandles.(sprintf('%sdo',this.side)),this.visHandles.axesStart);
            this.prodObj.setDispView(this.viewStart);
        end
        
        function updateGUI(this)
            %update gui
            this.nrSeconds = this.nrFrames / this.fps;
            
            this.startObj.updatePlots();
            this.endObj.updatePlots();
            this.prevObj.updatePlots();            
                        
            set(this.visHandles.textFrameCounter,'String','1');
            set(this.visHandles.textFrameTime,'String','0');
            set(this.visHandles.textRealTime,'String','0');
            this.setupGUI();
        end
        
        %% GUI callbacks
        function GUI_popupSource_Callback(this,hObject, eventdata)
            %
            this.getMovieObjs();
            this.setupGUI();
            this.updateGUI();
        end
        
        function GUI_popupCamViewAngle_Callback(this,hObject, eventdata)
            %change camera view angle mode
            
        end
        
        function GUI_popupProjection_Callback(this,hObject, eventdata)
            %set colormap for figure
            this.updateGUI();
        end
        
        
        function GUI_buttonStart_Callback(this,hObject, eventdata)
            %actually make a movie
            formats = {'*.avi','Uncompressed AVI (*.avi)';
                '*.avi','Motion JPEG AVI (*.avi)';
                '*.mj2','Lossless Motion JPEG 2000 (*.mj2)';
                '*.mj2','Compressed Motion JPEG 2000 (*.mj2)';
                '*.m4v','MPEG4 (*.m4v)';
                };
            [file, path, filterindex] = uiputfile(formats,'Export Movie as','movie.avi');
            if ~path ; return ; end
            fn = fullfile(path,file);
            %open up a new figure
            sVP = this.prodObj.getStaticVisParams();
            if(this.alphaMode == 1)
                %we don't need alpha
                hFig = figure('Units','Pixels','Position',[50 50 this.movieWidth+20 this.movieHeight+20],'Color',sVP.supp_plot_bg_color,'Renderer','zbuffer');
            else
                %we want to use alpha
                hFig = figure('Units','Pixels','Position',[50 50 this.movieWidth+20 this.movieHeight+20],'Color',sVP.supp_plot_bg_color,'Renderer','openGL');
            end
            hAx = axes('Parent',hFig,'Units','Pixels','Position',[1 1 this.movieWidth this.movieHeight]);
            if(get(this.visHandles.checkAxis,'Value'))
                axis(hAx,'on');
            else
                axis(hAx,'off');
            end
            if(get(this.visHandles.checkGrid,'Value'))
                grid(hAx,'on');
            else
                grid(hAx,'off');
            end
            %setup FMovie object
            this.prodObj.setHandleMainAxes(hAx);
            %set colormap
            colormap(hAx,this.cMap);
            %create video writer object
            switch filterindex
                case 1
                    profile = 'Uncompressed AVI';
                case 2
                    profile = 'Motion JPEG AVI';
                case 3
                    profile = 'Archival';
                case 4
                    profile = 'Motion JPEG 2000';
                case 5
                    profile = 'MPEG-4';
            end
            writerObj = VideoWriter(fn,profile);
            writerObj.FrameRate = this.fps;
            if(filterindex == 2 || filterindex == 5)
                writerObj.Quality = 100;
            end
            open(writerObj);            
            this.makeVideo(hAx,hFig,writerObj);
            close(writerObj);
            close(hFig);
            this.prodObj.setHandleMainAxes(this.visHandles.axesStart);
        end
        
        function makeVideo(this,hAx,hFig,writerObj)
            %make the video
            z2D = 0.01; %final z value for "flat" colored image
            rc = []; %this.ROICoordinates;
            rt = 0; %this.ROIType;
            rs = 1; %this.ROISubType;
            ri = 0; %this.ROIInvertFlag;
            %cla(hAx);
            hfdInt = this.prodObj.myhfdInt;
            hfd = this.prodObj.myhfdMain;
            hfd = hfd{1};
            %make 3D plot
            current_img = double(hfd.getROIImage(rc,rt,rs,ri));
            zMin = double(hfd.getCImin(rc,rt,rs,ri));
            zMax = double(hfd.getCImax(rc,rt,rs,ri));            
            %z scaling
            if(hfd.MSZ)
                [~, MSZMin, MSZMax ] = hfd.getMSZ();
                if(MSZMin ~= -inf)
                    zMin = MSZMin;
                end
                zMax = MSZMax;
            end  
            current_img = (current_img - zMin)/(zMax-zMin);
            zMin = 0;
            zMax = 1;
            if(isempty(hfd.getCIColor(rc,rt,rs,ri))) 
                colors = current_img - zMin;
                colors = colors/(zMax-zMin)*(size(this.visObj.dynParams.cm,1)-1)+1; %mapping for colorbar
                colors(isnan(colors)) = 1;
            end
            colors = this.visObj.dynParams.cm(round(reshape(colors,[],1)),:); 
            alphaData = ones(size(colors,1),1);
            colors = reshape(colors,[size(current_img) 3]);
            alphaData = reshape(alphaData,size(current_img));
            if(this.prodObj.intOver)
                %merge with intensity
                colors = this.prodObj.makeIntOverlay(colors,hfdInt.getROIImage(rc,rt,rs,ri));
            end
            %determine image size
            [ysize, xsize] = size(current_img);
            %main plot            
            hMainSurf = surf(hAx,current_img,colors,'LineStyle','none','EdgeColor','none','FaceLighting','phong');%,'FaceAlpha','flat','AlphaDataMapping','none','AlphaData',alphaData);
            %daspect(hAx,[1 1 1]);
            view(hAx,this.viewStart);
            %pbaspect(hAx,pbaspect(hAx)); 
            axis(hAx,'off');            
            pbaspect(hAx,[xsize/ysize 1 1]);
            drawnow;
            %break point HERE!
            set(hAx,'Projection',this.projectionMode,'DataAspectRatioMode','manual','CameraViewAngleMode','manual','CameraPositionMode','manual');            
            zDataMain = get(hMainSurf,'zData');
            %intensity plot
            if(this.intAtBottom)
                %user wants a gray flat intensity image at the bottom
                int_img = double(hfdInt.getROIImage(rc,rt,rs,ri));
                zMin = double(hfdInt.getCImin(rc,rt,rs,ri));
                zMax = double(hfdInt.getCImax(rc,rt,rs,ri));
                int_img = (int_img - zMin)/(zMax-zMin);
                zInt = 0.1; %z value for intensity image at bottom 
                zMin = 0;
                zMax = zInt;
                int_img = int_img.*zInt;
                %color mapping
                cm = gray(256);
                colors = int_img - zMin;
                colors = colors/(zMax-zMin)*(size(cm,1)-1)+1; %mapping for colorbar
                colors(isnan(colors)) = 1;
                colors = cm(round(reshape(colors,[],1)),:);
                colors = reshape(colors,[size(int_img) 3]);
                %plot
                hold(hAx,'on');
                hIntSurf = surf(hAx,int_img,colors,'LineStyle','none','EdgeColor','none','FaceLighting','phong');%,'FaceAlpha','flat','AlphaDataMapping','none','AlphaData',alphaData);
                zDataInt = get(hIntSurf,'zData');
                hold(hAx,'off');
            end
            alim(hAx,[0 1]);
            caxis(hAx,[min(current_img(:)) max(current_img(:))]);
            set(hAx,'color',this.prodObj.staticVisParams.supp_plot_bg_color,'Box','off','XLim',[1 xsize],'YLim',[1 ysize],'ZLim',[0 1]);            
            shading(hAx,this.prodObj.staticVisParams.shading);            
            n = this.nrFrames;
            %linear view steps
            viewSteps = bsxfun(@plus, bsxfun(@times,repmat(0:n-1,2,1)',this.viewDelta./n),this.viewStart);
            %% custom view steps
            customView = 2;
            x = linspace(0,1,n)';
            if(customView == 1)
                %slow start, hardcoded for 50 frames
                steps(:,1) = x.^4.0.*(1.8);
                steps(:,2) = x.^1.0.*(viewSteps(2,2)-viewSteps(1,2));
                steps(:,2) = steps(:,2).*sin(linspace(0,pi,n))';
                steps(:,1) = steps(:,1)*1.0+(this.viewDelta(1)-(sum(steps(:,1)*1.0)))/n;
                steps(:,2) = steps(:,2)*3.0+(this.viewDelta(2)-(sum(steps(:,2)*3.0)))/n;
            elseif(customView == 2)
                %slow end, hardcoded for 150 frames
                steps(:,1) = (1.8).*cos(linspace(0,pi/2,n))';
                steps(:,2) = x.^1.0.*(viewSteps(2,2)-viewSteps(1,2));
                %steps = steps(end:-1:1,:);
                %compensate missing distance by offset (and factor)
                steps(:,1) = steps(:,1)*1+(this.viewDelta(1)-(sum(steps(:,1)*1)))/n;
                steps(:,2) = steps(:,2)*3.0+(this.viewDelta(2)-(sum(steps(:,2)*3.0)))/n;
            end
            if(customView > 0)
                steps(isinf(steps)) = 0;
                steps(isnan(steps)) = 0;
                viewSteps(:,1) = cumsum(steps(:,1))+this.viewStart(1);
                viewSteps(:,2) = cumsum(steps(:,2))+this.viewStart(2);
            end
            %% animation
            n = n-1;                            
            if(this.camAngleMode == 1)
                %fixed view angle
                %determine max view angle first
                vAStart = 0;
                set(hAx,'CameraViewAngleMode','auto')
                for i = 1:n
                    view(hAx,viewSteps(i,:));
                    drawnow;
                    vAStart = max(vAStart,get(hAx,'CameraViewAngle'));
                end
                view(hAx,this.viewEnd);
                drawnow
                vAStart = max(vAStart,get(hAx,'CameraViewAngle'));
                %fix view angle to maximum
                set(hAx,'CameraViewAngle',vAStart);
            end
            
            if(this.camAngleMode == 3) %zoom
                vAStart = 6.034;
                set(hAx,'CameraViewAngle',vAStart);
            elseif(this.camAngleMode == 4) %@max
                vAStart = 11.4203;
                set(hAx,'CameraViewAngle',vAStart);
            end
            vAEnd = 11.2090;
            vADelta = vAEnd-vAStart;        
            if(~isempty(writerObj)) %production
            else %preview
                tStart = clock;
            end
            zDown = linspace(1,z2D,this.nrFrames);
            zUp = linspace(z2D,1,this.nrFrames);
            %% do final animation
            for i = 1:n
                view(hAx,viewSteps(i,:));
                %change camera view angle
                if(this.camAngleMode == 3)
                    set(hAx,'CameraViewAngle',vAStart+i*vADelta/n);
                end
                %change z values
                if(this.zScaling == 2) %100% -> 1%
                    set(hMainSurf,'zData',zDataMain.*zDown(i));
                elseif(this.zScaling == 3) %1% -> 100%
                    set(hMainSurf,'zData',zDataMain.*zUp(i));
                elseif(this.zScaling == 4) %100% -> 1% @ z = 0.5
                    set(hMainSurf,'zData',zDataMain.*zDown(i)+(i-1)*0.5/this.nrFrames);
                    set(hIntSurf,'zData',zDataInt.*zDown(i)+(i-1)*0.5/this.nrFrames);
                end
                %change alpha
%                 if(this.alphaMode == 2) %100% -> 0%
%                     set(hMainSurf,'AlphaData',alphaData*(1-i/n));
%                 elseif(this.alphaMode == 3) %0% -> 100%
%                     set(hMainSurf,'AlphaData',alphaData*i/n);
%                 end
                drawnow;
                if(~isempty(writerObj)) %production
                    frame = getframe(hFig,[1 1 this.movieWidth this.movieHeight]);
                    writeVideo(writerObj,frame);
                else %preview
                    set(this.visHandles.textFrameCounter,'String',num2str(i+1));
                    set(this.visHandles.textFrameTime,'String',num2str((i+1)/this.fps));
                    set(this.visHandles.textRealTime,'String',etime(clock, tStart));
                end
            end
            %make last frame
            view(hAx,this.viewEnd);
            if(this.zScaling == 4) %100% -> 1% @ 0.5
                set(hMainSurf,'zData',zDataMain.*zDown(end)+0.5);
                set(hIntSurf,'zData',zDataInt.*zDown(end)+0.5);
            end
            drawnow;
            if(~this.dropLastFrame)                
                if(~isempty(writerObj))
                    frame = getframe(hFig,[1 1 this.movieWidth this.movieHeight]);
                    writeVideo(writerObj,frame);
                else
                    set(this.visHandles.textFrameCounter,'String',num2str(this.nrFrames));
                    set(this.visHandles.textFrameTime,'String',num2str((this.nrFrames)/this.fps));
                    set(this.visHandles.textRealTime,'String',etime(clock, tStart));
                end
            end
        end
        
        function GUI_buttonPreview_Callback(this,hObject, eventdata)
            %show a preview of the movie in the gui
            this.makeVideo(this.prevObj.h_m_ax,[],[]);            
        end  
        
        function GUI_buttonClose_Callback(this,hObject, eventdata)
            %close the gui
            this.closeCallback();
        end  
        
        function GUI_buttonColorBackground_Callback(this,hObject, eventdata)
            %change the color of the background
            cs = GUI_Colorselection(1);
            if(length(cs) == 3)
                %set new color
                sVP = this.startObj.getStaticVisParams();
                sVP.supp_plot_bg_color = cs;
                this.startObj.setStaticVisParams(sVP);
                this.endObj.setStaticVisParams(sVP);
                this.prevObj.setStaticVisParams(sVP);
                this.prodObj.setStaticVisParams(sVP);
            end
            this.setupGUI();
        end
        
        function GUI_radioResolution_Callback(this,hObject, eventdata)
            %
            switch get(hObject,'Tag')
                case 'radioRes720p'
                    this.movieWidth = 1280;
                    this.movieHeight = 720;
                    set(this.visHandles.radioRes1080p,'Value',0)
                    set(this.visHandles.radioResCustom,'Value',0);
                case 'radioRes1080p'
                    this.movieWidth = 1920;
                    this.movieHeight = 1080;
                    set(this.visHandles.radioRes720p,'Value',0)
                    set(this.visHandles.radioResCustom,'Value',0);
                case 'radioResCustom'
                    this.movieWidth = str2double(get(this.visHandles.editSzMovieX,'String'));
                    this.movieHeight = str2double(get(this.visHandles.editSzMovieY,'String'));
                    set(this.visHandles.radioRes720p,'Value',0)
                    set(this.visHandles.radioRes1080p,'Value',0)
            end
            this.setupGUI();
        end        
        
        function GUI_editSizeMovie_Callback(this,hObject, eventdata)
            %
            set(this.visHandles.radioResCustom,'Value',1);
            GUI_radioResolution_Callback(this,this.visHandles.radioResCustom, eventdata);
        end
        
        function GUI_frames_Callback(this,hObject, eventdata)
            %
            if(strcmp(get(hObject,'Tag'),'editFps'))
                this.nrFrames = round(this.nrSeconds * str2double(get(hObject,'string')));
            elseif(strcmp(get(hObject,'Tag'),'editTotalTime'))
                this.nrFrames = str2double(get(hObject,'string')) * this.fps;
            end
            this.updateGUI();
        end
        
        function GUI_tableCoordEdit_Callback(this,hObject, eventdata)
            %
            switch eventdata.Indices(2)
                case 1
                    this.viewStart(eventdata.Indices(1)) = eventdata.NewData;
                case 2
                    this.viewEnd(eventdata.Indices(1)) = eventdata.NewData;
                case 3 %delta
                    this.viewEnd(eventdata.Indices(1)) = this.viewStart(eventdata.Indices(1)) + eventdata.NewData;
            end
            this.startObj.setDispView(this.viewStart);
            this.endObj.setDispView(this.viewEnd);
            this.prevObj.setDispView(this.viewStart);
            this.prodObj.setDispView(this.viewStart);
            this.updateGUI();
        end
        
        function GUI_checkGrid_Callback(this,hObject, eventdata)
            %
            this.updateGUI();
        end
        
        function GUI_checkAxis_Callback(this,hObject, eventdata)
            %
            this.setupGUI();
        end
        
        
        %% dependent properties
        function out = get.side(this)
            %returns source side: 'l' for left side or 'r' for right side
            out = 'l';
            if(get(this.visHandles.popupSource,'Value') == 2)
                out = 'r';
            end
        end
        
        function out = get.viewStart(this)
            %returns view for start frame
            out = get(this.visHandles.tableCoordinates,'Data');
            out = out(:,1)';
        end
        
        function out = get.viewEnd(this)
            %returns view for last frame
            out = get(this.visHandles.tableCoordinates,'Data');
            out = out(:,2)';
        end
        
        function out = get.viewDelta(this)
            %returns difference between first and last view
            out = get(this.visHandles.tableCoordinates,'Data');
            out = out(:,3)';
        end
        
        function set.viewStart(this,val)
            %returns view for start frame
            out = get(this.visHandles.tableCoordinates,'Data');
            out(:,1) = val;
            out(:,3) = out(:,2) - out(:,1);
            set(this.visHandles.tableCoordinates,'Data',out);
        end
        
        function set.viewEnd(this,val)
            %returns view for last frame
            out = get(this.visHandles.tableCoordinates,'Data');
            out(:,2) = val;
            out(:,3) = out(:,2) - out(:,1);
            set(this.visHandles.tableCoordinates,'Data',out);
        end
        
        function out = get.nrFrames(this)
            %returns view for start frame
            out = str2double(get(this.visHandles.editNrFrames,'String'));
        end
        
        function out = get.fps(this)
            %returns view for last frame
            out = str2double(get(this.visHandles.editFps,'String'));
        end
        
        function out = get.nrSeconds(this)
            %returns view for last frame
            out = str2double(get(this.visHandles.editTotalTime,'String'));
        end
        
        function set.nrFrames(this,val)
            %returns view for start frame
            set(this.visHandles.editNrFrames,'String',num2str(val));
        end
        
        function set.fps(this,val)
            %returns view for last frame
            set(this.visHandles.editFps,'String',num2str(val));
        end
        
        function set.nrSeconds(this,val)
            %returns view for last frame
            set(this.visHandles.editTotalTime,'String',num2str(val));
        end
                
        function out = get.screenWidth(this)
            %returns view for start frame
            out = str2double(get(this.visHandles.editSzScreenX,'String'));
        end
        
        function out = get.screenHeight(this)
            %returns view for last frame
            out = str2double(get(this.visHandles.editSzScreenX,'String'));
        end        
        
        function set.screenWidth(this,val)
            %returns view for start frame
            set(this.visHandles.editSzScreenX,'String',num2str(val));
        end
        
        function set.screenHeight(this,val)
            %returns view for last frame
            set(this.visHandles.editSzScreenY,'String',num2str(val));
        end
        
        function out = get.movieWidth(this)
            %returns view for start frame
            out = str2double(get(this.visHandles.editSzMovieX,'String'));
        end
        
        function out = get.movieHeight(this)
            %returns view for last frame
            out = str2double(get(this.visHandles.editSzMovieY,'String'));
        end        
        
        function set.movieWidth(this,val)
            %returns view for start frame
            set(this.visHandles.editSzMovieX,'String',num2str(min(val,this.screenWidth)));
        end
        
        function set.movieHeight(this,val)
            %returns view for last frame
            set(this.visHandles.editSzMovieY,'String',num2str(min(val,this.screenHeight)));
        end
%         
%         function out = get.cMap(this)
%             %get current colormap
%             str = get(this.visHandles.popupColormap,'String');
%             str = str{get(this.visHandles.popupColormap,'Value')};
%             out = eval(sprintf('%s(256)',lower(str)));
%         end
        function out = get.cMap(this)
            %get current colormap
            out = this.visObj.dynParams.cm;            
        end
        
        function str = get.projectionMode(this)
            %returns view for last frame
            str = get(this.visHandles.popupProjection,'String');
            str = str{get(this.visHandles.popupProjection,'Value')};
        end
        
        function out = get.camAngleMode(this)
            %returns view for last frame
            out = get(this.visHandles.popupCamViewAngle,'Value');
        end
        
        function out = get.zScaling(this)
            %returns z scaling id
            out = get(this.visHandles.popupZScaling,'Value');
        end
        
        function out = get.alphaMode(this)
            %returns alpha mode
            out = get(this.visHandles.popupAlpha,'Value');
        end
        
        function out = get.intAtBottom(this)
            %returns true if intensity should be plotted at the bottom
            out = get(this.visHandles.checkIntAtBottom,'Value');
        end
        
        function out = get.dropLastFrame(this)
            %returns true if last frame should be dropped
            out = get(this.visHandles.checkDropLastFrame,'Value');
        end
    end
    
    methods(Access = protected)
        %internal methods
        function createVisWnd(this)
            %make a window for visualization of current fit
            this.visHandles = ExportMovieFigure();
            figure(this.visHandles.exportMovieFigure);
            %set callbacks
            %buttons
            set(this.visHandles.buttonStart,'Callback',@this.GUI_buttonStart_Callback);
            set(this.visHandles.buttonPreview,'Callback',@this.GUI_buttonPreview_Callback);
            set(this.visHandles.buttonClose,'Callback',@this.GUI_buttonClose_Callback);
            set(this.visHandles.buttonColorBackground,'Callback',@this.GUI_buttonColorBackground_Callback);
            %popups
            set(this.visHandles.popupSource,'Callback',@this.GUI_popupSource_Callback);
            set(this.visHandles.popupCamViewAngle,'Callback',@this.GUI_popupCamViewAngle_Callback);
            set(this.visHandles.popupProjection,'Callback',@this.GUI_popupProjection_Callback);
%             set(this.visHandles.popupZScaling,'Callback',@this.GUI_popupZScaling_Callback);
            %radio buttons
            set(this.visHandles.radioRes720p,'Callback',@this.GUI_radioResolution_Callback);
            set(this.visHandles.radioRes1080p,'Callback',@this.GUI_radioResolution_Callback);
            set(this.visHandles.radioResCustom,'Callback',@this.GUI_radioResolution_Callback);
            %edit fields
            set(this.visHandles.editSzMovieX,'Callback',@this.GUI_editSizeMovie_Callback);
            set(this.visHandles.editSzMovieY,'Callback',@this.GUI_editSizeMovie_Callback);
            set(this.visHandles.editNrFrames,'Callback',@this.GUI_frames_Callback);
            set(this.visHandles.editFps,'Callback',@this.GUI_frames_Callback);
            set(this.visHandles.editTotalTime,'Callback',@this.GUI_frames_Callback);
            %check boxes
            set(this.visHandles.checkGrid,'Callback',@this.GUI_checkGrid_Callback);
            set(this.visHandles.checkAxis,'Callback',@this.GUI_checkAxis_Callback);
%             set(this.visHandles.editNrFrames,'Callback',@this.GUI_editROI_Callback);
%             set(this.visHandles.editFps,'Callback',@this.GUI_editROI_Callback);
%             set(this.visHandles.editTotalTime,'Callback',@this.GUI_editROI_Callback);
            %table
            set(this.visHandles.tableCoordinates,'CellEditCallback',@this.GUI_tableCoordEdit_Callback);
%             %mouse
%             set(this.visHandles.exportMovieFigure,'WindowButtonDownFcn',@this.GUI_mouseButtonDown_Callback);
%             set(this.visHandles.exportMovieFigure,'WindowButtonUpFcn',@this.GUI_mouseButtonUp_Callback);
%             set(this.visHandles.exportMovieFigure,'WindowButtonMotionFcn',@this.GUI_mouseMotion_Callback);            
            this.getMovieObjs();
        end
        
        function setupGUI(this)
            %setup gui controls
            sVP = this.startObj.getStaticVisParams();
            set(this.visHandles.buttonColorBackground,'BackgroundColor',sVP.supp_plot_bg_color);
            set(this.visHandles.exportMovieFigure,'Color',sVP.supp_plot_bg_color);
            set(this.visHandles.checkGrid,'Value',sVP.grid);
            screenSz = java.awt.Toolkit.getDefaultToolkit().getScreenSize();
            this.screenWidth = screenSz.getWidth();
            this.screenHeight = screenSz.getHeight();          
            if(get(this.visHandles.checkAxis,'Value'))
                str = 'on';
            else
                str = 'off';
            end
            axis(this.visHandles.axesStart,str);
            axis(this.visHandles.axesEnd,str);
            axis(this.visHandles.axesPreview,str);
%             daspect(this.visHandles.axesPreview,[1 1 100]);
            if(get(this.visHandles.checkGrid,'Value'))
                str = 'on';
            else
                str = 'off';
            end
            grid(this.visHandles.axesStart,str);
            grid(this.visHandles.axesEnd,str);
            grid(this.visHandles.axesPreview,str);
            pbaspect(this.visHandles.axesStart,[this.movieWidth this.movieHeight 1]);
            pbaspect(this.visHandles.axesEnd,[this.movieWidth this.movieHeight 1]);
            pbaspect(this.visHandles.axesPreview,[this.movieWidth this.movieHeight 1]);
%             pbaspect(this.visHandles.axesStart,pbaspect(this.visHandles.axesStart));
%             pbaspect(this.visHandles.axesEnd,pbaspect(this.visHandles.axesEnd));
%             pbaspect(this.visHandles.axesPreview,pbaspect(this.visHandles.axesPreview));
            %perspectice, disable fill to stretch
            set(this.visHandles.axesStart,'Projection',this.projectionMode,'DataAspectRatioMode','manual','PlotBoxAspectRatioMode','manual','CameraViewAngleMode','manual');
            set(this.visHandles.axesEnd,'Projection','perspective','DataAspectRatioMode','manual','PlotBoxAspectRatioMode','manual','CameraViewAngleMode','manual');
            set(this.visHandles.axesPreview,'Projection','perspective','DataAspectRatioMode','manual','PlotBoxAspectRatioMode','manual','CameraViewAngleMode','manual');
            %set colormap
            colormap(this.visHandles.axesStart,this.cMap);
        end
        
    end
end