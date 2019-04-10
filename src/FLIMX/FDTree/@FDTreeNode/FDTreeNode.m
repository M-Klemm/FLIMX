classdef FDTreeNode < handle
    %=============================================================================================================
    %
    % @file     FDTreeNode.m
    % @author   Matthias Klemm <Matthias_Klemm@gmx.net>
    % @version  1.0
    % @date     January, 2019
    %
    % @section  LICENSE
    %
    % Copyright (C) 2019, Matthias Klemm. All rights reserved.
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
    % @brief    A class to represent a node in FDTree
    %
    properties(SetAccess = protected, GetAccess = public)
        name = [];
        myParent = [];
    end
    properties(SetAccess = protected, GetAccess = protected)
        
    end
    properties(SetAccess = private, GetAccess = private)
        myChildren = [];
    end
    
    properties (Dependent = true)
        nrChildren = 0;
    end
    
    methods
        function this = FDTreeNode(parentObj,myName)
            %FDTreeNode Construct an instance of this class
            %save the parent and initialize children
            this.name = myName;
            this.myParent = parentObj;
            this.myChildren = LinkedList();
        end
        
        %% input methods
        function addChildByName(this,child,name)
            %add a new child to myChildren, sorted by name
            %todo: check if this is a FDTreeNode class
            this.myChildren.insertID(child,name);
        end
        
        function addChildAtEnd(this,child)
            %add a new child to myChildren at the end of the list
            %todo: check if this is a FDTreeNode class
            this.myChildren.insertEnd(child,child.name);
        end
        
        function addChildAtPos(this,child,pos)
            %add a new child to myChildren at specific position
            %todo: check if this is a FDTreeNode class
            this.myChildren.insertPos(pos,child);
        end
        
        function renameChild(this,oldID,newID)
            %change name or running number of child
            this.myChildren.changeID(oldID,newID);
        end
        
        function deleteChildByName(this,name)
            %delete child from myChildren
            this.myChildren.removeID(name);
        end
        
        function deleteChildByPos(this,pos)
            %delete child at specific position from myChildren
            this.myChildren.removePos(pos);
        end
        
        function deleteAllChildren(this)
            %delete all children
            this.myChildren = LinkedList();
        end
        
        function clearAllCIs(this,varargin)
            %clear all current images in all children with certain ID and additional arguments
            for i = 1:this.myChildren.queueLen
                this.myChildren.getDataByPos(i).clearAllCIs(varargin);
            end            
        end
        
        function clearAllFIs(this,varargin)
            %clear all filtered raw images in all children with certain ID and additional arguments
            for i = 1:this.myChildren.queueLen
                this.myChildren.getDataByPos(i).clearAllFIs(varargin);
            end
        end
        
        function clearAllRIs(this,varargin)
            %clear all raw images in all children with certain ID and additional arguments
            for i = 1:this.myChildren.queueLen
                this.myChildren.getDataByPos(i).clearAllRIs(varargin);
            end
        end        
        
        %% output methods 
        function [childObj, childID] = getChild(this,childID)
            %check if child is in myChildren
            if(ischar(childID))
                [childObj, childID] = this.myChildren.getDataByID(childID);
            elseif(~isempty(childID) && isnumeric(childID) && ~isnan(childID) && ~isinf(childID))
                if(this.myChildren.IDisChar)
                    %child ids are characters, but a numeric child is requested
                    [childObj, childID] = this.myChildren.getDataByPos(childID);
                else
                    %child ids are numbers 
                    [childObj, childID] = this.myChildren.getDataByID(childID);
                end
            else
                childID = [];
                childObj = [];
            end
        end
        
        function [childObj, childID] = getChildAtPos(this,childID)
            %check if child is in myChildren
            if(isnumeric(childID) && ~isnan(childID) && ~isinf(childID))
                %child number is the input data
                if(childID > this.myChildren.queueLen)
                    %child is not in list
                    childID = [];
                    childObj = [];
                else
                    [childObj, childID] = this.myChildren.getDataByPos(childID);
                end
            else
                childID = [];
                childObj = [];
            end
        end
        
        function out = getFDataObj(this,name,varargin)
            %get FData object with certain name from myChildren                       
            out = this.myChildren.getDataByID(name); 
        end
        
        function out = getMyParentName(this)
            %return the name of my parent
            if(~isempty(this.myParent))
                out = this.myParent.getSubjectName();
            else
                out = '';
            end
        end
        
        function out = getMyPositionInParent(this)
            %return the current running number from my parent
            if(~isempty(this.myParent))
                out = this.myParent.getChildPositionNr(this);
            else
                out = [];
            end
        end
        
        function out = getChildPositionNr(this,callingChildObj) %old: getMyChannelNr
            %return the running number of a child
            for out = 1:this.myChildren.queueLen
                childObj = this.myChildren.getDataByPos(out);
                if(~isempty(childObj) && childObj == callingChildObj)
                    return
                end
            end
            out = [];
        end
        
        function out = getChildName(this,callingChildObj)
            %return the name of a child in myChildren list
            for i = 1:this.myChildren.queueLen
                [childObj,out] = this.myChildren.getDataByPos(i);
                if(~isempty(childObj) && childObj == callingChildObj)
                    return
                end
            end
            out = [];
        end
        
        function out = getNamesOfAllChildren(this)
            %return a string of all children names
            out = this.myChildren.funOnAllElements(@(x) x.name);
%             out = cell(this.myChildren.queueLen,1);
%             for i=1:this.myChildren.queueLen
%                 out(i,1) = {this.myChildren.getDataByPos(i).name};
%             end
        end
        
        function out = getIDsOfAllChildren(this)
            %return a string of all children names
            try
                out = this.myChildren.funOnAllElements(@(x) x.id);
            catch
                out = [];
            end
        end
        
        function out = getMemorySize(this)
            %determine memory size of the tree
            out = this.myChildren.funOnAllElements(@(x) x.getMemorySize);
%             out = 0;
%             for i = 1:this.myChildren.queueLen
%                 child = this.myChildren.getDataByPos(i);
%                 if(~isempty(child))
%                     out = out + child.getMemorySize();
%                 end
%             end
            %fprintf(1, 'FDTree size (%s) %d bytes\n',this.name,out);
        end
        
        function out = getChildenDirtyFlags(this)
            %return dirty flags for each child
            try
                out = this.myChildren.funOnAllElements(@(x) x.isDirty);
            catch
                out = [];
            end
        end
        
        %dependent properties
        function out = get.nrChildren(this)
            %return number of my children
            out = this.getNrOfChildren();
        end
        
    end
    
    methods (Access = protected)
        function out = getNrOfChildren(this) %getNrElements
            %return number of my children
            out = this.myChildren.queueLen;
        end
    end
end

