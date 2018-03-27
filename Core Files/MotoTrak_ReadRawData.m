function data = MotoTrak_ReadRawData ( rats, vns, stages, datapath, verbose_output, varargin )
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% TBI_FetchRatData.m
% Author: David Pruitt
% 
% This code is modified from ArdyMotor_Pull_Analysis.
% The purpose of this code is to take as input a list of rats, and output
% a matrix which contains all of the session data for each rat.
%
% Parameters:
%   rats = a list of rat names.  
%               Ex: rats = {'TBI2', 'TBI3', 'TBI9'};
%   vns = a binary array indicating if a rat has received VNS.
%               Ex: vns = [1 0 0];
%   stages = a list of stages that we want to load from each rat's dataset
%               Ex: stages = {'P8','P9'};
%   datapath = a fully qualified path name to where the datasets for each
%               rat are stored
%               Ex: datapath = 'Z:\Navid_Behavior_Data\'; 
%
% Modifications made in this code file from the original
% ArdyMotor_Pull_Analysis:
%   - I changed the code such that it takes the above variables as function
%   parameters, making the code thus more modular
%   - I also changed the code to not "cd" into every folder in order to
%   find data files of rats.  This was causing Matlab's current path to
%   change, which is annoying.  I have changed the code to use fully
%   qualified path names when searching for data files and opening data
%   files.
%   - The resulting dataset is returned from the function as a structure.
%   The structure itself is unchanged from the previous code.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Handle optional arguments
p = inputParser;
defaultLoadDatesAfter = [];
addOptional(p, 'LoadDatesAfter', defaultLoadDatesAfter);
parse(p, varargin{:});
load_dates_after = p.Results.LoadDatesAfter;


special = 1;

%Define an empty variable which will hold the data
data = [];

%Iterate through each rat and each stage in order to find all the
%subfolders that contain the data we will need to load into the analysis
%program
subfolders = {};                                                            
for r = rats                                                                
    for s = stages                                                          
        if exist([datapath r{1} '\' s{1}],'dir')              %If the stage folder exists for this rat...
            subfolders{end+1} = [datapath r{1} '\' s{1}];     %Save the name of this subfolder.
        end
    end
end 

%Iterate over all the subfolders, and load in each data file
for i = 1:length(subfolders)                                
    
    %Get the list of files that are contained in the subfolder for this rat
    %and stage.    
    files = dir([subfolders{i} '\*.MotoTrak']);
    
    for f = 1:length(files)               
        %Prepend the directory name to the file name so we can use it to
        %actually open the file and read from it.  We will call this the 
        %"qualified name".
        files(f).qualified_name = [subfolders{i} '\' files(f).name];
        
        %Debug message for the user to know we are reading specific files
        if (exist('dispstat') && ~verbose_output)
            output_str = ['Reading file ' num2str(f) '/' num2str(length(files))];
            if (f == 1)
                dispstat(output_str, 'keepprev');
            else
                dispstat(output_str);
            end
        else
            disp(['Reading: ' files(f).name]);
        end
        
        
        %Read the data file into a temporary variable
        temp = MotoTrakFileRead(files(f).qualified_name);   
        
        %If no trials were found, create an empty set of trials for the
        %session.
        if (~isfield(temp, 'trial'))
            temp.trial = [];
        end
        
        k = datevec(temp.start_time);
        k(4:6) = 0;
        
        new_temp.version = temp.version;
        new_temp.daycode = datenum(k);
        new_temp.booth = temp.booth;
        new_temp.rat = temp.subject;
        new_temp.position = NaN;
        new_temp.stage = temp.stage;
        new_temp.device = temp.device;
        new_temp.responsewindow = NaN;
        new_temp.bin = NaN;
        new_temp.param = [];
        new_temp.cal = temp.calibration_coefficients;
        new_temp.constraint = NaN;
        new_temp.threshtype = '';
        new_temp.pre_trial_sampling_dur = NaN;
        new_temp.pauses = [];
        new_temp.manual_feeds = [];
        new_temp.trial = struct('starttime', {}, 'hitwin', {}, 'init', {}, ...
            'thresh', {}, 'hittime', {}, 'outcome', {}, 'vnstime', {}, ...
            'sample_times', {}, 'signal', {}, 'ir', {});
        
        if (~isempty(temp.trial))
            new_temp.pre_trial_sampling_dur = temp.trial(1).pre_trial_duration;
            
            for t = 1:length(temp.trial)
                
                new_trial.starttime = temp.trial(t).start_time;
                new_trial.hitwin = temp.trial(t).hit_window_duration;
                new_trial.init = temp.trial(t).parameters(1);
                new_trial.thresh = temp.trial(t).parameters(2);
                new_trial.hittime = temp.trial(t).hit_times;
                new_trial.outcome = temp.trial(t).result;
                new_trial.vnstime = temp.trial(t).output_trigger_times;
                new_trial.sample_times = temp.trial(t).signal(1, :)';
                new_trial.signal = temp.trial(t).signal(2, :)';
                new_trial.ir = temp.trial(t).signal(3, :)';
                
                new_temp.trial(t) = new_trial;
                
            end
        end        
        
        temp = new_temp;
        temp.data_file_path = files(f).qualified_name;

        %If this is the first datafile for a rat, we need to extend our
        %"data" variable to be able to contain this new rat.
        %We can then save the session data in the variable
        if ~isfield(data,'ratname') || ...
                ~any(strcmpi(temp.rat,{data.ratname}))                  %If this the first file or a new rat...
            r = length(data) + 1;                                       %Make a new index for this rat.
            s = 1;                                                      %Save this session as the first session.
            data(r).ratname = temp.rat;                                 %Save this rat's name in the structure.
            data(r).vns = NaN;                                   %Save whether this rat got VNS or not.
        else                                                            %Otherwise...
            r = find(strcmpi(temp.rat,{data.ratname}));                 %Find the index for this rat.
            s = length(data(r).session) + 1;                            %Make a new session for this rat.
        end                

        %Save all the data for this session and rat
        try
            data(r).session(s) = temp;
        catch e
            disp('Failed to load file');
        end
        
    end
end

%Now that we have loaded all the datafiles for each rat, let's iterate
%through all of our rats and make sure the sessions are ordered
%chronologically
for r = 1:length(data)                                                      %Step through each rat.
    timestamps = zeros(1,length(data(r).session));                         	%Pre-allocate an array to hold session timestamps.
    for s = 1:length(data(r).session)                                       %Step through each session for this rat.
        if (~isempty(data(r).session(s).trial))
            timestamps(s) = data(r).session(s).trial(1).starttime;              %Grab the first trial timestamp for this session.
        else
            timestamps(s) = data(r).session(s).daycode;
        end
    end
    [timestamps, i] = sort(timestamps);                                     %Sort the timestamps, returning the sorted indices.
    data(r).session = data(r).session(i);                                   %Use the sorted indices to reorder the sessions chronologically.
end

