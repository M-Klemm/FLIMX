classdef LinkedList < handle
    %=============================================================================================================
    %
    % @file     LinkedList.m
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
    % @brief    A class to represent a doubly-linked list.
    %
    properties(SetAccess = protected,GetAccess = public)
        %queue = 0;
        myList = cell(0,2);
        IDisChar = false;
    end
    properties(SetAccess = protected,GetAccess = protected)
        
    end
    properties (Dependent = true)
        queueLen = 0;
    end
    
    methods
        function this = LinkedList()
            % Constructor for LinkedList.
            this.myList = cell(0,2);
        end
        
        function out = get.queueLen(this)
            %returns the length of the list
            out = size(this.myList,1);
        end
        
        function insertID(this,data,id,overWrite)
            %insert data with specific ID
            %default: overwrite if id already exists
            if(nargin == 3)
                overWrite = true;
            end
            if(this.queueLen == 0)
                this.setIDType(id);
            end
            [~, pos] = this.getDataByID(id);
            if(isempty(pos))
                %we don't have that ID yet
                this.insertEnd(data,id);
                this.sort();
            else
                %we have that ID already
                if(overWrite)
                    this.myList(pos,1) = {data};
                else
                    %insert before, this may lead to undefined behaviour
                    newList = cell(this.queueLen+1,2);
                    newList(1:pos-1,:) = this.myList(1:pos-1,:);
                    newList(pos,:) = {data,id};
                    newList(pos+1:end,:) = this.myList(pos:end,:);
                    %this.queue = this.queue +1;
                    this.myList = newList;
                end
            end
        end
        
        function insertPos(this,pos,data)
            %insert data at specific postion
            %this will update all IDs!!
            if(isempty(pos))
                return
            end
            if(pos > this.queueLen)
                this.insertEnd(data);
                return
            end
            if(this.queueLen == 0)
                this.setIDType(id);
            end
            newList = cell(this.queueLen+1,2);
            newList(1:pos-1,:) = this.myList(1:pos-1,:);
            newList(pos,:) = {data,pos};
            newList(pos+1:end,:) = this.myList(pos:end,:);
            %this.queue = this.queue +1;
            this.myList = newList;
            this.updateIDs();
        end
        
        function id = insertEnd(this, theData, id)
            %insert data at the end of the list
            if(nargin < 3)
                if(this.queueLen == 0)
                    id = 1;
                else
                    id = this.myList{end,2}+1;
                end
            end
            if(this.queueLen == 0)
                this.setIDType(id);
            end
            this.myList(end+1,:) = {theData,id};
            %this.queue = this.queue +1;
        end
        
        function [data, pos] = getDataByID(this,id)
            %get data with id
            data = []; pos = [];
            if(this.queueLen == 0)
                return
            end
            if(ischar(id) && this.IDisChar)
                %find first match for id
                pos = find(strcmp(id,this.myList(:,2)),1);
            elseif(isnumeric(id) && ~this.IDisChar)
                pos = find(id == [this.myList{:,2}],1);
            else
                pos = [];
            end
            if(~isempty(pos))
                data = this.myList{pos,1};
            end
        end
        
        function [data, id] = getDataByPos(this,pos)
            %get data at position pos in list
            if(isempty(pos) || pos > this.queueLen)
                data = [];
                id = [];
                return
            end
            data = this.myList{pos,1};
            id = this.myList{pos,2};
        end
        
        function id = getIDByPos(this,pos)
            %get id of node at position pos
            if(isempty(pos) || pos > this.queueLen)
                id = [];
                return
            end
            id = this.myList{pos,2};
        end
        
        function id = getIDByData(this,data)
            %get id of the FIRST node loaded with data 'data'
            for i = 1:this.queueLen
                if(this.myList{i,1} == data)
                    id = this.myList{i,2};
                    return
                end
            end
            %no match in list
            id = [];
        end
        
        function pos = getPosByData(this,data)
            %get position of the FIRST node loaded with data 'data'
            for pos = 1:this.queueLen
                if(this.myList{pos,1} == data)
                    return
                end
            end
            %no match in list
            pos = [];
        end
        
        function out = getAllIDs(this)
            %get all ids of the list
            out = this.myList(:,2);
        end
        
        function updateIDs(this)
            %update ids of nodes according to their position in the list
            if(this.queueLen < 1 || this.IDisChar)
                return %nothing to do
            end
            for i = 1:this.queueLen
                this.myList(i,2) = {i};
            end
        end
        
        function changeID(this,id,new)
            % change id of node
            for i = 1:this.queueLen
                if(strcmp(id,this.myList{i,2}))
                    this.myList(i,2) = {new};
                    this.sort();
                    break;
                end
            end
        end
        
        function setSequence(this,seq)
            %reorder list according to seq
            if(this.queueLen ~= length(seq))
                return %mask does not match
            end
            this.myList = this.myList(seq,:);
        end
        
        function sort(this)
            %sort list according to ids
            if(this.queueLen > 1)
                switch this.IDisChar
                    case true
                        [this.myList(:,2), idx] = sort(this.myList(:,2));
                    otherwise %numeric ids
                        [list, idx] = sort([this.myList{:,2}]);
                        this.myList(:,2) = num2cell(list);
                end
                this.myList(:,1) = this.myList(idx,1);
            end
        end
        
        function removeID(this,id)
            %remove node with given id
            [~, pos] = this.getDataByID(id);
            this.removePos(pos);
        end
        
        function removePos(this,pos)
            %remove node with given id
            if(pos > this.queueLen)
                return
            end
            this.myList(pos,:) = [];
            %this.queue = max(0,this.queue-1);
        end
        
        function removeAll(this)
            %remove all elements of the list
            this.myList = cell(0,2);
            %this.queue = 0;
        end
    end %methods
    
    methods(Access = protected)
        function setIDType(this,id)
            %define ID type
            if(ischar(id))
                this.IDisChar = true;
            else
                this.IDisChar = false;
            end
        end
    end
    
    methods(Static)
        function out = IDCompare(id1,id2,relOp)
            %compare 2 ids using the relational operation relOp
            if(isnumeric(id1) && isnumeric(id2))
                out = eval(sprintf('%f %s %f',id1,relOp,id2));
            else
                %we assume characters
                switch relOp
                    case '=='
                        out = strcmp(id1,id2);
                    case '<'
                        s = sort([{id1},{id2}]);
                        out = strcmp(s(1),id1);
                end
            end
        end
    end
end %classdef