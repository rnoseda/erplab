% PURPOSE  : Averages bin-epoched EEG dataset(s)
%
% FORMAT   :
%
% ERP = pop_averager( ALLEEG , parameters )
%
% INPUTS   :
%
% EEG or ALLEEG         - input dataset
%
% The available parameters are as follows:
%
%        'DSindex' 	- dataset index(ices) when dataset(s) are contained within the ALLEEG structure.
%                         For single bin-epoched dataset using EEG structure this value must be equal to 1 or
%                         left unspecified.
%        'Criterion'    - Inclusion/exclusion of marked epochs during artifact detection:
% 		             'all'   - include all epochs (ignore artifact detections)
% 		             'good'  - exclude epochs marked during artifact detection
% 		             'bad'   - include only epochs marked with artifact rejection
%                         NOTE: for including epochs selected by the user, specify these one as a cell array. e.g {2 8 14 21 40:89}
%
%        'SEM'              - include standard error of the mean. 'on'/'off'
%        'ExcludeBoundary'  - exclude epochs having boundary events. 'on'/'off'
%        'Saveas'           - (optional) open GUI for saving averaged ERPset. 'on'/'off'
%        'Warning'          - enable popup window warning. 'on'/'off'
%
%
% OUTPUTS  :
%
% EEG           - updated output dataset
%
% EXAMPLE  :
%
% ERP = pop_averager(ALLEEG, 'Criterion', 'good', 'DSindex', 19, 'SEM', 'on');
%
%
% See also averagerGUI.m averager.m
%
% *** This function is part of ERPLAB Toolbox ***
% Author: Javier Lopez-Calderon
% Center for Mind and Brain
% University of California, Davis,
% Davis, CA
% 2009

%b8d3721ed219e65100184c6b95db209bb8d3721ed219e65100184c6b95db209b
%
% ERPLAB Toolbox
% Copyright � 2007 The Regents of the University of California
% Created by Javier Lopez-Calderon and Steven Luck
% Center for Mind and Brain, University of California, Davis,
% javlopez@ucdavis.edu, sjluck@ucdavis.edu
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.

function [ERP, erpcom] = pop_averager(ALLEEG, varargin)
erpcom = '';
ERP    = preloadERP;
if nargin < 1
        help pop_averager
        return
end
if isobject(ALLEEG) % eegobj
        whenEEGisanObject % calls a script for showing an error window
        return
end
if nargin==1
        currdata = evalin('base', 'CURRENTSET');
        
        if currdata==0
                msgboxText =  'pop_averager() error: cannot average an empty dataset!!!';
                title      = 'ERPLAB: No data';
                errorfound(msgboxText, title);
                return
        end
        
        % read values in memory for this function
        def  = erpworkingmemory('pop_averager');
        if isempty(def)
                def = {1 1 1 1 1};
        end
        
        % epochs per dataset
        nepochperdata = zeros(1, length(ALLEEG));
        for k=1:length(ALLEEG)
                if isempty(ALLEEG(k).data)
                        nepochperdata(k) = 0; % JLC.08/20/13
                else
                        nepochperdata(k) = ALLEEG(k).trials;
                end
        end
        
        %
        % Averager GUI
        %
        answer = averagerxGUI(currdata, def, nepochperdata);
        
        if isempty(answer)
                disp('User selected Cancel')
                return
        end
        setindex = answer{1};   % datasets to average
        
        %
        % Artifact rejection criteria for averaging
        %
        %  artcrite = 0 --> averaging all (good and bad trials)
        %  artcrite = 1 --> averaging only good trials
        %  artcrite = 2 --> averaging only bad trials
        %  artcrite is cellarray  --> averaging only specified epoch indices
        artcrite  = answer{2};
        if ~iscell(artcrite)
                if artcrite==0
                        artcritestr = 'all';
                elseif artcrite==1
                        artcritestr = 'good';
                elseif artcrite==2
                        artcritestr = 'bad';
                else
                        artcritestr = artcrite;
                end
        else
                artcritestr = artcrite; % fixed bug. May 1, 2012
        end
        
        % Standard deviation option. 1= yes, 0=no
        stderror    = answer{4};
        
        % exclude epochs having boundary events
        excbound = answer{5};
        
        % store setting in memory
        def(1:5)    = {setindex, artcrite, 1, stderror, excbound};
        erpworkingmemory('pop_averager', def);
        
        if stderror==1
                stdsstr = 'on';
        else
                stdsstr = 'off';
        end
        if excbound==1
                excboundstr = 'on';
        else
                excboundstr = 'off';
        end
        
        %
        % Somersault
        %
        [ERP, erpcom]  = pop_averager(ALLEEG, 'DSindex', setindex, 'Criterion', artcritestr,...
                'SEM', stdsstr, 'Saveas', 'on', 'Warning', 'on', 'ExcludeBoundary', excboundstr, 'History', 'gui');
        pause(0.1)
        return
end

%
% Parsing inputs
%
p = inputParser;
p.FunctionName  = mfilename;
p.CaseSensitive = false;
% input(s)
p.addRequired('ALLEEG', @isstruct);
% option(s)
p.addParamValue('DSindex', 1,@isnumeric);
p.addParamValue('Criterion', 'good'); % 'all','good','bad', or numeric cell array with epoch indices
p.addParamValue('SEM', 'off', @ischar); % 'on', 'off'
p.addParamValue('Saveas', 'off', @ischar); % 'on', 'off'
p.addParamValue('Warning', 'off', @ischar); % 'on', 'off'
p.addParamValue('ExcludeBoundary', 'off', @ischar); % 'on', 'off'
p.addParamValue('History', 'script', @ischar); % history from scripting

p.parse(ALLEEG, varargin{:});

setindex = p.Results.DSindex;
artc     = p.Results.Criterion;

if ~iscell(artc)
        if strcmpi(artc, 'all')
                artcrite = 0;
        elseif strcmpi(artc, 'good')
                artcrite = 1;
        elseif strcmpi(artc, 'bad') % bad
                artcrite = 2;
        else
                artcrite =  artc; % string
        end
else
        artcrite =  artc; % cell. fixed bug Jkreither May 1, 2012
end
if ismember({p.Results.SEM}, {'on','yes'})
        stderror    = 1;
else
        stderror    = 0;
end
if ismember({p.Results.Saveas}, {'on','yes'})
        saveas    = 1;
else
        saveas    = 0;
end
if ismember({p.Results.Warning}, {'on','yes'})
        iswarn    = 1;
else
        iswarn    = 0;
end
if ismember({p.Results.ExcludeBoundary}, {'on','yes'})
        excbound    = 1;
else
        excbound    = 0;
end
if strcmpi(p.Results.History,'implicit')
        shist = 3; % implicit
elseif strcmpi(p.Results.History,'script')
        shist = 2; % script
elseif strcmpi(p.Results.History,'gui')
        shist = 1; % gui
else
        shist = 0; % off
end

nloadedset = length(ALLEEG);
wavg       = 1; % weighted average
nset       = length(setindex);     % all selected datasets
nrsetindex = unique(setindex);     % set indices with no repetitions
nrnset     = length(nrsetindex);   % N of setindex with no repetitions

if nset > nrnset
        msgboxText =  'Repeated dataset index will be ignored!';
        fprintf('\n\nERPLAB WARNING: %s\n\n', msgboxText);
        setindex   = nrsetindex;           % set indices upgraded
        nset       = length(setindex);       % nset  upgraded
end
if nset > nloadedset
        msgboxText =  ['Hey!  There are not ' num2str(nset) ' datasets, but ' num2str(nloadedset) '!'];
        title      = 'ERPLAB: pop_averager() Error';
        errorfound(msgboxText, title);
        return
end
if max(setindex) > nloadedset
        igrtr       = setindex(setindex>nloadedset);
        indxgreater = num2str(igrtr);
        if length(igrtr)==1
                msgboxText =  ['Hey!  dataset #' indxgreater ' does not exist!'];
        else
                msgboxText =  ['Hey!  dataset #' indxgreater ' do not exist!'];
        end
        title = 'ERPLAB: pop_averager() Error';
        errorfound(msgboxText, title);
        return
end
if nset==1 && wavg
        %fprintf('\n********************************************************************\n')
        %fprintf('NOTE: Weighted averaging is only available for multiple datasets.\n')
        %fprintf('      ERPLAB will perform a classic averaging over this single dataset.\n')
        %fprintf('********************************************************************\n\n')
elseif nset>1 && wavg
        fprintf('\n********************************************************************\n')
        fprintf('NOTE: Multiple datasets are being averaged together.\n')
        fprintf('Weighted averaging will be performed (each trial will be treated equally, as if all trials were in a single dataset).\n')
        fprintf('********************************************************************\n\n')
end
cversion = geterplabversion;
noconti = 0; %
for i=1:nset
        if isempty(ALLEEG(setindex(i)).data) % JLC.08/20/13
                msgboxText =  'Dataset #%g is empty.\nERPLAB has canceled the averaging process.';
                title = 'ERPLAB: pop_averager() Error';
                errorfound(sprintf(msgboxText,  setindex(i)), title);
                noconti = 1; % "no continue" is enabled
                break
        end
        if isempty(ALLEEG(setindex(i)).epoch)
                msgboxText =  ['You should epoch your dataset #' ...
                        num2str(setindex(i)) ' before perform averager.m'];
                title = 'ERPLAB: pop_averager() Error';
                errorfound(msgboxText, title);
                return
        end
        if ~isfield(ALLEEG(setindex(i)),'EVENTLIST')
                msgboxText =  'You should create/add a EVENTLIST before perform Averaging!';
                title      = 'ERPLAB: pop_averager() Error';
                errorfound(msgboxText, title);
                return
        end
        if isempty(ALLEEG(setindex(i)).EVENTLIST)
                msgboxText =  'You should create/add a EVENTLIST before perform Averaging!';
                title      = 'ERPLAB: pop_averager() Error';
                errorfound(msgboxText, title);
                return
        end
        if ~strcmp(ALLEEG(setindex(i)).EVENTLIST.version, cversion) && iswarn==1
                question = ['WARNING: Dataset %g was created from a different ERPLAB version.\n'...
                        'ERPLAB will try to make it compatible with the current version.\n\n'...
                        'Do you want to continue?'];
                title    = ['ERPLAB: erp_loaderp() for version: ' ALLEEG(setindex(i)).EVENTLIST.version] ;
                button = askquest(sprintf(question, setindex(i)), title);
                
                if ~strcmpi(button,'yes')
                        disp('User selected Cancel')
                        return
                end
        elseif ~strcmp(ALLEEG(setindex(i)).EVENTLIST.version, cversion) && iswarn==0
                fprintf('\n\nWARNING:\n')
                fprintf('ERPLAB: pop_averager() detected version %s\n', ALLEEG(setindex(i)).EVENTLIST.version);
                fprintf('Dataset #%g was created from an older ERPLAB version\n\n', setindex(i));
        end
end
if noconti
        disp('WARNING: ERPLAB canceled the averaging process because an empty dataset was found.')
        return
end

%
% Read file
%
if ischar(artcrite) % read a file having indices (only for 1 dataset so far)
        %
        % open file containing epoch indices
        %
        artcrite = readepochindx(artcrite);
end
if iscell(artcrite) % read a file having indices (only for 1 dataset so far)
        if size(artcrite, 1)==1 && size(artcrite, 1)< nset
                artcrite = repmat(artcrite, nset, 1);
        elseif size(artcrite, 1)>1 && size(artcrite, 1)~=nset
                if isempty(ALLEEG(setindex(i)).EVENTLIST)
                        msgboxText =  'List of epochs specified for averaging accross datasets does not match the number of datasets.';
                        title      = 'ERPLAB: pop_averager() Error';
                        errorfound(msgboxText, title);
                        return
                end
        end
end

%
% Tests
%
if nset>1
        
        %
        % basic test for number of channels (for now...)19 sept 2008
        %
        totalchannelA = sum(cell2mat({ALLEEG(setindex).nbchan}));  % fixed october 03, 2008 JLC
        totalchannelB = (cell2mat({ALLEEG(setindex(1)).nbchan}))*nset;  % fixed october 03, 2008 JLC
        
        if totalchannelA~=totalchannelB
                msgboxText =  'Datasets have different number of channels!';
                title      = 'ERPLAB: pop_averager() Error';
                errorfound(msgboxText, title);
                return
        end
        
        %
        % basic test for number of points (for now...)19 sept 2008
        %
        totalpointA = sum(cell2mat({ALLEEG(setindex).pnts})); % fixed october 03, 2008 JLC
        totalpointB = (cell2mat({ALLEEG(setindex(1)).pnts}))*nset; % fixed october 03, 2008 JLC
        
        if totalpointA ~= totalpointB
                msgboxText =  'Datasets have different number of points!';
                title      = 'ERPLAB: pop_averager() Error';
                errorfound(msgboxText, title);
                return
        end
        
        %
        % basic test for time axis (for now...)
        %
        tminB = ALLEEG(setindex(1)).xmin;
        tmaxB = ALLEEG(setindex(1)).xmax;
        
        for j=2:nset
                tminA = ALLEEG(setindex(j)).xmin;
                tmaxA = ALLEEG(setindex(j)).xmax;
                
                if tminA ~= tminB || tmaxA~=tmaxB
                        msgboxText =  'Datasets have different time axis!';
                        title      = 'ERPLAB: pop_averager() Error';
                        errorfound(msgboxText, title);
                        return
                end
        end
        
        %
        % basic test for channel labels
        %
        labelsB = {ALLEEG(setindex(1)).chanlocs.labels};
        
        for j=2:nset
                labelsA = {ALLEEG(setindex(j)).chanlocs.labels};
                [tla, indexla] = ismember(labelsA, labelsB);
                condlab1 = length(tla)==nnz(tla);   % do both datasets have the same channel labels?
                
                if ~condlab1
                        msgboxText = 'Datasets have different channel labels.\n';
                        if iswarn
                                msgboxText = [msgboxText 'Do you want to continue anyway?'];
                                title = 'ERPLAB: pop_averager() WARNING';
                                button = askquest(sprintf(msgboxText), title);
                                
                                if ~strcmpi(button,'yes')
                                        disp('User selected Cancel')
                                        return
                                end
                        else
                                msgboxText = ['ERPLAB Warning: ' msgboxText];
                                try
                                        colormsg = [1 0.52 0.2];
                                        cprintf(colormsg, msgboxText');
                                catch
                                        fprintf(msgboxText);
                                end
                        end
                end
                if isrepeated(indexla)
                        %fprintf('\nWARNING: Some channels have the same label.\n\n')
                        if ismember(0,strcmp(labelsA, labelsB)) && iswarn
                                msgboxText =  'Datasets have different channel labels.\n';
                                
                                if iswarn
                                        msgboxText = [msgboxText 'Do you want to continue anyway?'];
                                        title = 'ERPLAB: pop_averager() WARNING';
                                        button = askquest(sprintf(msgboxText), title);
                                        
                                        if ~strcmpi(button,'yes')
                                                disp('User selected Cancel')
                                                return
                                        end
                                else
                                        msgboxText = ['ERPLAB Warning: ' msgboxText];
                                        try
                                                colormsg = [1 0.52 0.2];
                                                cprintf(colormsg, msgboxText');
                                        catch
                                                fprintf(msgboxText);
                                        end
                                end
                        end
                else
                        condlab2 = issorted(indexla);       % do the channel labels match by channel number?
                        if ~condlab2 && iswarn
                                msgboxText =  'Channel numbering and channel labeling do not match among datasets!\n';
                                
                                if iswarn
                                        msgboxText = [msgboxText 'Do you want to continue anyway?'];
                                        title = 'ERPLAB: pop_averager() WARNING';
                                        button = askquest(sprintf(msgboxText), title);
                                        
                                        if ~strcmpi(button,'yes')
                                                disp('User selected Cancel')
                                                return
                                        end
                                else
                                        msgboxText = ['ERPLAB Warning: ' msgboxText];
                                        try
                                                colormsg = [1 0.52 0.2];
                                                cprintf(colormsg, msgboxText');
                                        catch
                                                fprintf(msgboxText);
                                        end
                                end
                        end
                end
        end
end

%
% Define ERP
%
nch  = ALLEEG(setindex(1)).nbchan;
pnts = ALLEEG(setindex(1)).pnts;
nbin = ALLEEG(setindex(1)).EVENTLIST.nbin;
histoflags = zeros(nbin,16);
flagbit    = bitshift(1, 0:15);
conti = 1;

longwarnmsg = ['It appears that you have combined EEGLAB?s artifact detection '...
        'routines with ERPLAB?s artifact detection routines.\n  The information about '...
        'rejected epochs is stored in separate places by these routines.\n\nTo merge the '...
        'information, so that all epochs with artifacts are marked in the EVENTLIST '...
        'structure, you should select ERPLAB > Artifact detection in epoched data > '...
        'Synchronize artifact info in EEG and EVENTLIST before averaging.\nEven if you '...
        'do not merge, the averaging routine will exclude both groups of marked epochs. '...
        'However, the EVENTLIST in the average will not contain the correct information '...
        'about which epochs were excluded.\n\n'];
buttonA = 'Continue without merging';
buttonB = 'Cancel';

if nset>1
        sumERP  = zeros(nch,pnts,nbin);      % makes a zero erp
        if stderror
                sumERP2 = zeros(nch,pnts,nbin);   % makes a zero weighted sum of squares: Sum(wi*xi^2)
        end
        oriperbin  = zeros(1,nbin);             % original number of trials per bin counter init
        tperbin    = zeros(1,nbin);
        invperbin  = zeros(1,nbin);
        workfnameArray = {[]};
        chanlocs       = [];
        
        for j=1:nset
                %
                % Multiple Dataset
                %
                %
                % Note: the standard error for multiple epoched datasets is the stderror across the corresponding averages;
                % Individual stds will be lost.
                fprintf('\nAveraging dataset #%g...\n', setindex(j));
                
                %  artcrite = 0 --> averaging all (good and bad trials)
                %  artcrite = 1 --> averaging only good trials
                %  artcrite = 2 --> averaging only bad trials
                %  artcrite is cellarray  --> averaging only specified epoch indices
                %  artcrite is char  --> averaging only specified epoch indices contained in a text file called artcrite
                
                if ~iscell(artcrite) && ~ischar(artcrite)
                        if artcrite~=0
                                %
                                % Tests synchronization of artifact marking
                                %
                                sync_status = checksynchroar(ALLEEG(setindex(j)));
                                
                                if sync_status==2
                                        
                                        msgboxText = ['It looks like you have deleted some epochs from your dataset named %s.\n'...
                                                'At the current version of ERPLAB, artifact info synchronization cannot be performed in this this case.\n'...
                                                'So, artifact info synchronization will be skipped, and the corresponding averaged ERP will rely on the\n'...
                                                'information at EEG.event only.\n'];
                                        
                                        msgboxText = sprintf(msgboxText, ALLEEG(setindex(j)).setname);
                                        
                                        if iswarn
                                                msgboxText = [msgboxText 'Do you want to continue anyway?'];
                                                title = 'ERPLAB: pop_averager() WARNING';
                                                button = askquest(sprintf(msgboxText), title);
                                                
                                                if ~strcmpi(button,'yes')
                                                        disp('User selected Cancel')
                                                        conti = 0;
                                                        break
                                                end
                                        else
                                                msgboxText = ['ERPLAB Warning: ' msgboxText];
                                                try
                                                        colormsg = [1 0.52 0.2];
                                                        cprintf(colormsg, msgboxText');
                                                catch
                                                        fprintf(msgboxText);
                                                end
                                        end
                                elseif sync_status==0 && iswarn% bad synchro
                                        msgboxText =  ['Artifact info is not synchronized at dataset #%g!\n\n'...
                                                longwarnmsg];
                                        title  = 'ERPLAB: pop_averager(), artifact info synchronization';
                                        button = askquest(sprintf(msgboxText, setindex(j)), title, buttonA, buttonA, buttonB);
                                        
                                        if ~strcmpi(button, buttonA)
                                                disp('User selected Cancel')
                                                conti = 0;
                                                break
                                        end
                                elseif sync_status==0 && ~iswarn% bad synchro
                                        msgboxText =  ['ERPLAB Warning: Artifact info is not synchronized at dataset #%g!\n\n'...
                                                longwarnmsg];
                                        msgboxText = sprintf(msgboxText, setindex(j));
                                        try
                                                colormsg = [1 0.52 0.2];
                                                cprintf(colormsg, msgboxText');
                                        catch
                                                fprintf(msgboxText);
                                        end
                                end
                        end
                        artif = artcrite;
                elseif iscell(artcrite)
                        artif = artcrite(j, :); % cell
                end
                
                %
                % subroutine
                %
                %
                % Get individual averages
                %
                [ERP, EVENTLISTi, countbiORI, countbinINV, countbinOK, countflags, workfname] = averager(ALLEEG(setindex(j)), artif, stderror, excbound);
                
                %
                % Checks criteria for bad subject (dataset)
                %
                %TotOri = sum(countbiORI,2);
                %TotOK  = sum(countbinOK,2);
                %pREJ   = (TotOri-TotOK)*100/TotOri;  % Total trials rejected percentage
                oriperbin = oriperbin + countbiORI;
                tperbin   = tperbin   + countbinOK;    % only good trials (total)
                invperbin = invperbin + countbinINV;   % invalid trials
                ALLEVENTLIST(j) = EVENTLISTi;
                
                for bb=1:nbin
                        for m=1:16
                                C = bitand(flagbit(m), countflags(bb,:));
                                histoflags(bb, m) = histoflags(bb, m) + nnz(C);
                        end
                end
                if wavg
                        for bb=1:nbin
                                sumERP(:,:,bb) = sumERP(:,:,bb)  + ERP.bindata(:,:,bb).*countbinOK(bb);
                                if stderror
                                        sumERP2(:,:,bb) = sumERP2(:,:,bb)  + (ERP.bindata(:,:,bb).^2).*countbinOK(bb); % weighted sum of squares: Sum(wi*xi^2)
                                end
                        end
                else % frozen...
                        sumERP = sumERP + ERP.bindata;
                        if stderror
                                sumERP2 = sumERP2 + ERP.bindata.^2;  % general sum of squares: Sum(xi^2)
                        end
                end
                
                workfnameArray{j} = workfname;
                
                if isfield(ERP.chanlocs, 'theta')
                        chanlocs = ERP.chanlocs;
                else
                        [chanlocs(1:length(ERP.chanlocs)).labels] = deal(ERP.chanlocs.labels);
                end
        end
        if conti==0
                return
        end
        
        ERP.chanlocs = chanlocs;
        
        if wavg  % weighted average. It was forced to be 1 by Steve...
                for bb=1:nbin
                        if tperbin(bb)>0                                
                                ERP.bindata(:,:,bb) = sumERP(:,:,bb)./tperbin(bb); % get ERP!                                
                                %
                                % Standard deviation (weighted)
                                %
                                if stderror
                                        fprintf('\nEstimating weighted standard error of the mean...\n');
                                        insqrt = sumERP2(:,:,bb).*tperbin(bb) - sumERP(:,:,bb).^2;
                                        
                                        if nnz(insqrt<0)>0
                                                ERP.binerror(:,:,bb) = zeros(nch, pnts, 1);
                                        else
                                                ERP.binerror(:,:,bb) = (1/tperbin(bb))*sqrt(insqrt);
                                        end
                                end
                        else
                                ERP.bindata(:,:,bb) = zeros(nch,pnts,1);  % makes a zero erp
                        end
                end
        else
                % frozen...
                %
                ERP.bindata = sumERP./nset; % get ERP!
                
                %
                % Standard deviation
                %
                if stderror
                        fprintf('\nEstimating standard error of the mean...\n');
                        ERP.binerror = sqrt(sumERP2.*(1/nset) - ERP.bindata.^2) ; % ERP stderror
                end
        end
else
        %
        % Single Dataset
        %
        fprintf('\nAveraging  a unique dataset #%g...\n', setindex(1));
        
        if ~iscell(artcrite) && ~ischar(artcrite)
                if artcrite~=0
                        %
                        % Tests synchronization of artifact marking
                        %
                        sync_status = checksynchroar(ALLEEG(setindex(1)));
                        
                        if sync_status==2
                                
                                msgboxText = ['It looks like you have deleted some epochs from your dataset.\n'...
                                        'At the current version of ERPLAB, artifact info synchronization cannot be performed in this this case. '...
                                        'So, artifact info synchronization will be skipped, and the corresponding averaged ERP will rely on the '...
                                        'information at EEG.event only.\n'];                                
                                msgboxText = sprintf(msgboxText);                                
                                if iswarn
                                        msgboxText = [msgboxText 'Do you want to continue anyway?'];
                                        title = 'ERPLAB: pop_averager() WARNING';
                                        button = askquest(sprintf(msgboxText), title);                                        
                                        if ~strcmpi(button,'yes')
                                                disp('User selected Cancel')
                                                return
                                        end
                                else
                                        msgboxText = ['ERPLAB Warning: ' msgboxText];
                                        try
                                                colormsg = [1 0.52 0.2];
                                                cprintf(colormsg, msgboxText');
                                        catch
                                                fprintf(msgboxText);
                                        end
                                end
                        elseif sync_status==0 && iswarn% bad synchro
                                msgboxText =  ['Artifact info is not synchronized!\n\n'...
                                        longwarnmsg];
                                title  = 'ERPLAB: pop_averager(), artifact info synchronization';
                                button = askquest(sprintf(msgboxText), title, buttonA, buttonA, buttonB);                                
                                if ~strcmpi(button, buttonA)
                                        disp('User selected Cancel')
                                        return
                                end
                        elseif sync_status==0 && ~iswarn% bad synchro
                                msgboxText =  ['ERPLAB Warning: Artifact info is not synchronized.\n\n'...
                                        longwarnmsg];
                                msgboxText = sprintf(msgboxText);
                                try
                                        colormsg = [1 0.52 0.2];
                                        cprintf(colormsg, msgboxText');
                                catch
                                        fprintf(msgboxText);
                                end
                        end
                end
                artif = artcrite;
        elseif iscell(artcrite)
                artif = artcrite(1, :); % just in case...(till cell)
        end
        
        %
        % subroutine
        %
        %
        % Get individual average
        %
        [ERP, EVENTLISTi, countbiORI, countbinINV, countbinOK, countflags, workfname] = averager(ALLEEG(setindex(1)), artif, stderror, excbound);
        
        %
        % Checks criteria for bad subject (dataset)
        %
        %TotOri = sum(countbiORI,2);
        %TotOK  = sum(countbinOK,2);
        %pREJ   = (TotOri-TotOK)*100/TotOri;  % Total trials rejected percentage
        oriperbin    = countbiORI;
        tperbin      = countbinOK;  % only good trials
        invperbin    = countbinINV; % invalid trials
        ALLEVENTLIST = EVENTLISTi;
        
        for bb=1:nbin
                for m=1:16
                        C = bitand(flagbit(m), countflags(bb,:));
                        histoflags(bb, m) = nnz(C);
                end
        end
        
        workfnameArray  = cellstr(workfname);
        
        %
        % Note: the standard error for a unique epoched dataset is the stderror across the corresponding epochs;
        %
end

ERP.erpname   = [];
ERP.workfiles = workfnameArray;

if wavg % weighted average. It was forced to be 1 by Steve...
        fprintf('\n *** %g datasets were averaged. ***\n\n', nset);
else
        % frozen...
        fprintf('\n *** %g datasets were averaged (arithmetic mean). ***\n\n', nset);
end

ERP.ntrials.accepted  = tperbin;
ERP.ntrials.rejected  = oriperbin - tperbin;
ERP.ntrials.invalid   = invperbin;
pexcluded             = round(1000*(sum(ERP.ntrials.rejected)/(sum(ERP.ntrials.accepted)+sum(ERP.ntrials.rejected))))/10; % 1 decimal
ERP.pexcluded         = pexcluded;
tempflagcount         = fliplr(histoflags);          % Total per flag. Flag 1 (LSB) at the rightmost bit
ERP.ntrials.arflags   = tempflagcount(:,9:16);       % show only the less significative byte (artifact flags)
ERP.EVENTLIST         = ALLEVENTLIST;
[ERP, serror]         = sorterpstruct(ERP);

if serror
        error('ERPLAB says: pop_averager() Your datasets are not compatibles')
end

%
% History
%
skipfields = {'ALLEEG', 'Saveas','Warning','History'};
fn     = fieldnames(p.Results);
if length(setindex)==1 && setindex(1)==1
        inputvari  = 'EEG'; % Thanks to Felix Bacigalupo for this suggestion. Dic 12, 2011
        skipfields = [skipfields 'DSindex']; % SL
else
        inputvari = inputname(1);
end
erpcom = sprintf( 'ERP = pop_averager( %s ', inputvari);

for q=1:length(fn)
        fn2com = fn{q};
        if ~ismember(fn2com, skipfields)
                fn2res = p.Results.(fn2com);
                if ~isempty(fn2res)
                        if ischar(fn2res)
                                if ~strcmpi(fn2res,'off')
                                        erpcom = sprintf( '%s, ''%s'', ''%s''', erpcom, fn2com, fn2res);
                                end
                        else
                                if iscell(fn2res)
                                        fn2resstr = vect2colon(cell2mat(fn2res), 'Sort','on');
                                        fnformat = '{%s}';
                                else
                                        fn2resstr = vect2colon(fn2res, 'Sort','on');
                                        fnformat = '%s';
                                end
                                erpcom = sprintf( ['%s, ''%s'', ' fnformat], erpcom, fn2com, fn2resstr);
                        end
                end
        end
end
erpcom = sprintf( '%s );', erpcom);

%
% Save ERPset
%
if saveas
        [ERP, issave, erpcom_save] = pop_savemyerp(ERP,'gui','erplab', 'History', 'implicit');
        if issave>0
                if issave==2
                        erpcom = sprintf('%s\n%s', erpcom, erpcom_save);
                        msgwrng = '*** Your ERPset was saved on your hard drive.***';
                else
                        msgwrng = '*** Warning: Your ERPset was only saved on the workspace.***';
                end
        else
                msgwrng = 'ERPLAB Warning: Your changes were not saved';
        end
        try cprintf([1 0.52 0.2], '%s\n\n', msgwrng); catch,fprintf('%s\n\n', msgwrng);end ;
end
% get history from script. ERP
switch shist
        case 1 % from GUI
                %fprintf('%%Equivalent command:\n%s\n\n', erpcom);
                displayEquiComERP(erpcom);
        case 2 % from script
                ERP = erphistory(ERP, [], erpcom, 1);
        case 3
                % implicit
        otherwise %off or none
                erpcom = '';
end
%
% Completion statement
%
msg2end
return



