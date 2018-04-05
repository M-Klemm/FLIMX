classdef sddMgr < handle
    %=============================================================================================================
    %
    % @file     sddMgr.m
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
    % @brief    A class to represent the synthetic data definition manager
    %
    properties
        mySDDs = []; %list of my jobs
        myDir = []; %directory to save parameter sets
        myGUI = []; %handle to manager GUI
        FLIMXObj = []; %handle to FLIMX class
        stopFlag = false;
    end

    methods
        function this = sddMgr(flimX,myDir)
            %sdd mgr
            this.myDir = myDir;
            if(~isdir(myDir))
                [status, message, ~] = mkdir(myDir);
                if(~status)
                    error('FLIMX:sddMgr:createSDDFolder','Unable to create synthetic data definition root folder %s.\n%s',myDir,message);
                end
            end
            this.FLIMXObj = flimX;
            this.mySDDs = LinkedList();
            %this.scanForSDDs();
        end
        
        function out = newSDD(this,uid,ch)
            %add a new sdd
            %overwrite if already exists
            sdd = syntheticDataDefinition(this.myDir,uid);            
            out = sdd.newChannel(ch);
            this.mySDDs.insertID(sdd,uid,true);                      
        end
        
        function scanForSDDs(this)
            %scan the disk for sdds
            dirs = dir(this.myDir);
            for i = 1:length(dirs)
                sName = dirs(i,1).name;
                if(dirs(i,1).isdir && ~strcmp(sName,'.') && ~strcmp(sName,'..'))                    
                    %check if we have that sdd already
                    sdd = this.getSDD(sName);
                    if(isempty(sdd))
                        sdd = syntheticDataDefinition(this.myDir,sName);
                        %try to load the sdd data
                        [success, name] = sdd.loadFromDisk();
                        if(success)
                            this.mySDDs.insertID(sdd,name,false);
                        end
                    end
                end
            end
            %this.mySDDs.updateIDs();
        end
        
        function out = anyDirtySDDs(this)
            %check if at least one sdd is dirty
            out = false;
            for i = 1:this.mySDDs.queueLen
                sdd = this.mySDDs.getDataByPos(i);
                if(~isempty(sdd) && sdd.isDirty)
                    out = true;
                    return
                end
            end
        end
        
        %% modification methods
        function renameSDD(this,old,new)
            %rename sdd
            this.mySDDs.changeID(old,new);
            sdd = this.getSDD(new);
            if(~isempty(sdd))
                sdd.setUID(new);
            end
        end
        
        function deleteSDD(this,uid)
            %delete sdd with id from list
            sdd = this.getSDD(uid);
            if(isempty(sdd))
                return
            end
            sdd.selfDestruct();
            this.mySDDs.removeID(uid);
            %this.mySDDs.updateIDs();
        end
        
        function deleteAllSDDs(this)
            %delete all sdds joblist
            for i = this.mySDDs.queueLen:-1:1
                sdd = this.mySDDs.getDataByPos(i);
                if(~isempty(sdd))
                    sdd.selfDestruct();
                end
                this.mySDDs.removeID(i);                
            end
        end
        
        function saveAll(this)
            %write all dirty sdds to disk
            for i = 1:this.mySDDs.queueLen
                sdd = this.mySDDs.getDataByPos(i);
                if(~isempty(sdd) && sdd.isDirty)
                    sdd.saveToDisk();
                end
            end
            %delete removed parameter sets from hard drive
            dirs = dir(this.myDir);
            names = this.getAllSDDNames();
            for i = 1:length(dirs)
                jName = dirs(i,1).name;
                if(~ismember(jName,names) && ~strcmp(jName,'.') && ~strcmp(jName,'..'))
                    try
                        rmdir(fullfile(this.myDir,jName),'s');
                    catch
                        %no file removed
                    end
                end
            end
        end
        
        function duplicateSDD(this,oldName,newName)
            %duplicate target sdd, resets array parameters
            old = this.getSDD(oldName);
            if(isempty(old) || isempty(newName))
                return
            end
            new = old.getCopy(this.myDir,newName);
            %delete array stuff
            def = syntheticDataDefinition.getDefaults();
            new.arrayParentSDD = def.arrayParentSDD;
%             new.arrayParamName = def.arrayParamName;
%             new.arrayParamNr = def.arrayParamNr;
%             new.arrayParamStart = def.arrayParamStart;
%             new.arrayParamStep = def.arrayParamStep;
%             new.arrayParamEnd = def.arrayParamEnd;
            new.arrayParamVal = def.arrayParamVal;            
            this.mySDDs.insertID(new,newName,true);
        end
        
        function out = makeArrayParamSet(this,parentName,hGenData)
            %make array parameter set, returns list with created sdds
            out = [];
            parent = this.getSDD(parentName);
            if(isempty(parent))
                return
            end
            paraArray = parent.arrayParamStart : parent.arrayParamStep : parent.arrayParamEnd;
            maxDigit = ceil(log10(parent.arrayParamEnd)+1);
            for i = 1:length(paraArray);
                %add parameter sets
                childName = eval(sprintf('sprintf(''%%s %%s %%0%dd'',parentName,parent.arrayParamName,paraArray(i));',maxDigit));
                if(~ismember(childName,this.getAllSDDNames))
                    %insert parameter set only if ID is an unique name
                    child = parent.getCopy(this.myDir,childName);
                    this.mySDDs.insertID(child,childName,true);
                    child.arrayParentSDD = parentName;
                    for ch = 1:parent.nrSpectralChannels
                        sdc = child.getChannel(ch);
                        if(isempty(sdc))
                            continue
                        end
                        switch parent.arrayParamNr
                            case 1 %'Photons'
                                sdc.nrPhotons = paraArray(i);
                            case 2 %'Offset'
                                %offset
                                xVec = sdc.xVec;
                                xVec(end) = paraArray(i)/100;
                                sdc.offset = paraArray(i)/100;
                                sdc.xVec = xVec;
                            otherwise
                                %xvec parameter
                                xVec = sdc.xVec;
                                amps = xVec(1:sdc.nrExponentials);
                                taus = xVec(sdc.nrExponentials+1:2*sdc.nrExponentials);
                                qs = simFLIM.computeQs(amps,taus);
                                if(parent.arrayParamNr <= sdc.nrExponentials+2)
                                    %convert percent values for amplitudes to absolute values
                                    xVec(parent.arrayParamNr-2) = paraArray(i)/100;
                                else
                                    xVec(parent.arrayParamNr-2) = paraArray(i);
                                end
                                if(sdc.fixedQ)
                                    amps = xVec(1:sdc.nrExponentials);
                                    taus = xVec(sdc.nrExponentials+1:2*sdc.nrExponentials);
                                    %find out which parameter was changed
                                    if(parent.arrayParamNr <= sdc.nrExponentials+2)
                                        %amplitude changed -> calculate tau
                                        taus = simFLIM.computeTausFromQs(amps,taus,qs,parent.arrayParamNr-2);
                                        xVec(sdc.nrExponentials+1:2*sdc.nrExponentials) = taus;
                                    elseif(parent.arrayParamNr > sdc.nrExponentials+2 && parent.arrayParamNr <= 2*sdc.nrExponentials+2)
                                        %tau changed -> calculate amplitudes
                                        amps = simFLIM.computeAmpsFromQs(amps,taus,qs,parent.arrayParamNr-2-sdc.nrExponentials);
                                        xVec(1:sdc.nrExponentials) = amps;
                                    elseif(parent.arrayParamNr > 2*sdc.nrExponentials+2 && parent.arrayParamNr <= 3*sdc.nrExponentials+2)
                                        %tc changed, make sure it is negative
                                        xVec(2*sdc.nrExponentials+1:3*sdc.nrExponentials) = -abs(xVec(2*sdc.nrExponentials+1:3*sdc.nrExponentials));
                                    end
                                end
                                sdc.xVec = xVec;
                        end
                        %create raw data and model
                        if(sdc.dataSourceType == 3)
                            sdc.rawData = feval(hGenData,1,1,sdc);
                        else
                            [sdc.rawData, sdc.modelData] = feval(hGenData,1,1,sdc);
                        end
                    end
                end
                %this.updateProgressbar(i/length(paraArray),'Create Parameter Set Array');
            end
        end
        
        %% output methods
        function [names, chStr] = getAllSDDNames(this)
            %get names of all defs
            names = this.mySDDs.getAllIDs();
            if(nargout == 2)
                %get the numbers of non-empty channels for all sdds
                chStr = cell(length(names),1);
                for i = 1:length(names)
                    sdd = this.mySDDs.getDataByID(names{i});
                    if(~isempty(sdd))
                        chStr{i} = sdd.nonEmptyChannelStr();
                    end
                end
            end
        end
        
        function out = getAllArrayParamSetNames(this,ch)
            %get the names of all parameter set arrays, option for channel ch
            out = cell(this.mySDDs.queueLen,1);
            for i = 1:this.mySDDs.queueLen
                sdd = this.mySDDs.getDataByPos(i);
                if((isempty(ch) || ~isempty(sdd.getChannel(ch))) && ~isempty(sdd.arrayParentSDD))
                    out(i) = {sprintf('%s %s',sdd.arrayParentSDD,sdd.arrayParamName)};
                end                
            end
            out(cellfun('isempty',out)) = [];
            out = unique(out);
        end
        
        function [sdcs, names] = getArrayParamSet(this,ch,arrayName)
            %get the sdcs of a parameter set array
            sdcs = cell(this.mySDDs.queueLen,1);
            names = cell(this.mySDDs.queueLen,1);
            for i = 1:this.mySDDs.queueLen
                sdd = this.mySDDs.getDataByPos(i);
                if((isempty(ch) || ~isempty(sdd.getChannel(ch))) && ~isempty(sdd.arrayParentSDD) && strcmp(arrayName,sprintf('%s %s',sdd.arrayParentSDD,sdd.arrayParamName)))
                    sdcs{i} = sdd.getChannel(ch);
                    names{i} = sdd.UID;
                end 
            end
            sdcs(cellfun('isempty',sdcs)) = [];
            names(cellfun('isempty',names)) = [];
        end
                
        function out = getSDD(this,uid)
            %get specific sdd
            out = this.mySDDs.getDataByID(uid);            
        end
        
        function out = getSDDChannel(this,uid,ch)
            %get channel of sdd
            out = [];
            if(isempty(uid) || isempty(ch) || ~isnumeric(ch) || isnan(ch) || isinf(ch))
                return
            end
            sdd = this.getSDD(uid);
            if(~isempty(sdd))
                out = sdd.getChannel(ch);
            end
        end
                
    end
end