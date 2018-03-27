classdef PA_Rat
    %PA_RAT contains everything necessary for a rat and its data.
    
    properties
        Days
        RatName
        Group
    end
    
    methods
        %Constructor
        function obj = PA_Rat(ratname, group, sessions, varargin)
            %stage transforms should be of the following format:
            %struct('from', str, 'to', str)
            %where each string is the string of the stage that the session
            %will be change from/to.
            
            %Handle optional parameters
            defaultStageShortening = 1;
            defaultIsSustainedPull = 0;
            defaultTrashIndividualPulls = 0;
            defaultTrashIndividualTrials = 0;
            defaultTrashHeavyDataWithinPullsAndTrials = 0;
            defaultTrashDaysWithLessThanNTrials = 10;
            defaultStageTransforms = [];
            defaultOnlyAnalyzeBasicData = 0;
            defaultCreatePullObjects = 1;
            defaultDoPowerAnalysis = 1;
            
            p = inputParser;
            p.CaseSensitive = false;
            addOptional(p, 'StageShortening', defaultStageShortening, @isnumeric);
            addOptional(p, 'StageTransforms', defaultStageTransforms);
            addOptional(p, 'TrashIndividualPulls', defaultTrashIndividualPulls, @isnumeric);
            addOptional(p, 'TrashIndividualTrials', defaultTrashIndividualTrials, @isnumeric);
            addOptional(p, 'TrashHeavyDataWithinPullsAndTrials', defaultTrashHeavyDataWithinPullsAndTrials, @isnumeric);
            addOptional(p, 'IsSustainedPull', defaultIsSustainedPull, @isnumeric);
            addOptional(p, 'TrashDaysWithLessThanNTrials', defaultTrashDaysWithLessThanNTrials, @isnumeric);
            addOptional(p, 'OnlyAnalyzeBasicData', defaultOnlyAnalyzeBasicData, @isnumeric);
            addOptional(p, 'CreatePullObjects', defaultCreatePullObjects, @isnumeric);
            addOptional(p, 'DoPowerAnalysis', defaultDoPowerAnalysis, @isnumeric);
            
            parse(p, varargin{:});
            do_standard_stage_shortening = p.Results.StageShortening;
            stage_transforms = p.Results.StageTransforms;
            trash_heavy_data = p.Results.TrashHeavyDataWithinPullsAndTrials;
            trash_trials = p.Results.TrashIndividualTrials;
            trash_pulls = p.Results.TrashIndividualPulls;
            is_sustained_pull = p.Results.IsSustainedPull;
            trials_lower_bound_for_trashing = p.Results.TrashDaysWithLessThanNTrials;
            only_analyze_basic_data = p.Results.OnlyAnalyzeBasicData;
            create_pull_objects = p.Results.CreatePullObjects;
            do_power_analysis = p.Results.DoPowerAnalysis;
            
            %Handle required parameters
            obj.RatName = ratname;
            obj.Group = group;
            
            %Shorten each stage name to the standard short name
            if (do_standard_stage_shortening)
                for s = 1:length(sessions)
                    sessions(s).stage = strtok(sessions(s).stage, ':');
                end
            end
            
            %Check to see if there are any necessary stage transforms
            if (~isempty(stage_transforms))
                for i = 1:length(stage_transforms)
                    logical_indices_of_sessions = strcmpi(stage_transforms(i).from, {sessions.stage});
                    indices = find(logical_indices_of_sessions);
                    for s = indices
                        sessions(s).stage = stage_transforms(i).to;
                    end
                end
            end
            
            %Now that stage transforms have been applied, we can analyze
            %the data
            
            %Grab all unique daycodes that are in our data
            unique_daycodes = unique([sessions.daycode]);
            
            %Sort all the daycodes so that the days are in order
            unique_daycodes = sort(unique_daycodes);
            
            days = [];
            for d = unique_daycodes
                sessions_with_this_daycode = sessions([sessions.daycode] == d);
                new_day = PA_Day(sessions_with_this_daycode, 'IsSustainedPull', is_sustained_pull, 'OnlyAnalyzeBasicData', only_analyze_basic_data, ...
                    'CreatePullObjects', create_pull_objects, 'DoPowerAnalysis', do_power_analysis);
                
                %If the user has set a lower bound for trials/day, check
                %and see if the new day we just analyzed meets that
                %criterion.  If it doesn't, then trash the day.
                %Trashing the day is simply done by using the "continue"
                %command to go to the next iteration of the loop.
                trial_count_for_day = length(new_day.Trials);
                if (trial_count_for_day < trials_lower_bound_for_trashing)
                    continue;
                end
                
                %Handle data trashing if need be
                if (trash_trials)
                    %Completely empty out all trials, leaving only the
                    %calculated data for this day.
                    new_day.Trials = [];
                elseif (trash_pulls)
                    for t = 1:length(new_day.Trials)
                        %Trash all pulls within trials if this option was
                        %selected.
                        new_day.Trials.TrialPulls = [];
                    end
                end
                
                %Another option for data trashing - this primarily takes
                %out large memory consuming bits of trials and pulls.
                if (trash_heavy_data)
                    for t = 1:length(new_day.Trials)
                        new_day.Trials(t).Signal = [];
                        new_day.Trials(t).TrialPSD = [];
                        new_day.Trials(t).TrialFreqs = [];
                        for p = 1:length(new_day.Trials(t).TrialPulls)
                            new_day.Trials(t).TrialPulls(p).Signal = [];
                            new_day.Trials(t).TrialPulls(p).PullPSD = [];
                            new_day.Trials(t).TrialPulls(p).PullFreqs = [];
                        end
                    end
                end
                
                %Assign this day of data to our days array.
                days = [days new_day];
            end
            
            obj.Days = days;
        end
        
        %Methods
        function data = NumberOfDaysOnStage(obj, stage_name)
            
            stages = {obj.Days.Stage};
            data = length(find(strcmpi(stages, stage_name) == 1));
            
        end
        
        function data = RetrieveData(obj, varargin)
            %Handle inputs
            defaultStage = '';
            defaultParameter = 'MaximalForceMean';
            defaultMostRecent = 0;
            defaultRightJustifyResult = 0;
            defaultNumberOfDays = 1;
            defaultDivideIntoEpochs = 0;
            defaultDaysPerEpoch = 5;
            defaultStartDay = 1;
            
            p = inputParser;
            p.CaseSensitive = false;
            
            addOptional(p, 'Stage', defaultStage);
            addOptional(p, 'Parameter', defaultParameter);
            addOptional(p, 'NumberOfDays', defaultNumberOfDays, @isnumeric);
            addOptional(p, 'FromMostRecent', defaultMostRecent, @isnumeric);
            addOptional(p, 'RightJustifyResult', defaultRightJustifyResult, @isnumeric);
            addOptional(p, 'DivideIntoEpochs', defaultDivideIntoEpochs, @isnumeric);
            addOptional(p, 'DaysPerEpoch', defaultDaysPerEpoch, @isnumeric);
            addOptional(p, 'StartDay', defaultStartDay, @isnumeric);
            parse(p, varargin{:});
            
            stage = p.Results.Stage;
            num_days = p.Results.NumberOfDays;
            from_most_recent = p.Results.FromMostRecent;
            right_justify_result = p.Results.RightJustifyResult;
            use_epochs = p.Results.DivideIntoEpochs;
            days_per_epoch = p.Results.DaysPerEpoch;
            parameter = p.Results.Parameter;
            start_day = p.Results.StartDay;
            
            %Fail if the user specified a parameter that this function
            %cannot do.
            if (any(strcmpi(parameter, {'Stage', 'ThresholdType', 'Trials'})))
                disp('You have specified a parameter that this function cannot analyze. Sorry.');
                data = NaN;
                return;
            elseif (~isempty(strfind(lower(parameter), 'psd')))
                disp('This function is not currently equipped to analyze PSD data. Sorry.');
                data = NaN;
                return;
            end
            
            %Define how many datapoints we expect to get
            if (use_epochs)
                num_data_points = ceil(num_days / days_per_epoch);
            else
                num_data_points = num_days;
            end
            data = nan(1, num_data_points);
            
            %If the user specified a stage, let's grab the subset of days
            %that are that stage
            if (~isempty(stage))
                logical_indices = strcmpi(stage, {obj.Days.Stage});
                days = obj.Days(logical_indices);
            else
                days = obj.Days;
            end
            
            %Offset by the start day
            days = days(start_day:end);
            
            %If we have days to work with, let's keep going.
            if (~isempty(days))
                %We are already guaranteed that daycodes are in sorted
                %order, so no sorting needs to be done.
                
                %Check to see how many days we have available to us
                actual_num_days = min(num_days, length(days));
                start_day = 1;
                end_day = actual_num_days;
                if (from_most_recent)
                    end_day = length(days);
                    start_day = end_day - actual_num_days + 1;
                end
                
                %Let's do some bound checking
                if (start_day < 1)
                    start_day = 1;
                elseif (start_day > length(days))
                    start_day = length(days);
                end
                
                if (end_day < 1)
                    end_day = 1;
                elseif (end_day > length(days))
                    end_day = length(days);
                end
                
                if (end_day < start_day)
                    end_day = start_day;
                end
                
                %Okay, bounds checking is done. Now let's grab the data.
                raw_data = [days(start_day:end_day).(parameter)];
                
                %Divide the data into epochs if required
                if (use_epochs)
                    total_datapoints = length(data);
                    i = 1;
                    for epoch_index = 1:total_datapoints
                        epoch_start = i;
                        epoch_end = min(i + days_per_epoch - 1, length(raw_data));
                        data(epoch_index) = nanmean(raw_data(epoch_start:epoch_end));
                        i = i + days_per_epoch;
                    end
                    
                    if (right_justify_result)
                        count_empty_space = length(find(isnan(data)));
                        last_filled_space = length(data) - count_empty_space;
                        start_index = length(data) - last_filled_space + 1;
                        end_index = length(data);
                        data(start_index:end_index) = data(1:last_filled_space);
                        data(1:last_filled_space) = NaN;
                    end
                else
                    %In the case that we aren't using epochs, just transfer
                    %the data right over.
                    if (right_justify_result)
                        start_index = length(data) - length(raw_data) + 1;
                        end_index = length(data);
                        data(start_index:end_index) = raw_data;
                    else
                        data(1:length(raw_data)) = raw_data;
                    end
                end
            end
        end
        
        function data = RetrieveDistribution(obj, varargin)
            %Enumeration of distribution types.
            DIST_PDF = 0;
            DIST_CDF = 1;
            DIST_PSD_FROM_INDIVIDUAL_PULLS = 2;
            DIST_PSD_FROM_WHOLE_TRIALS = 3;
            DIST_PSD_FROM_CUSTOM = 4;
            DIST_PSD_FROM_CUSTOM_NORMALIZED = 5;
            
            DISTRIBUTION_TYPE_STRINGS = {'pdf', 'cdf', 'psd', 'trialpsd', 'custompsd', 'custompsdn'};
            
            %Parse inputs to the function
            p = inputParser;
            p.CaseSensitive = false;
            defaultStage = '';
            defaultParameter = 'MaximalForce';
            defaultStartDay = 1;
            defaultNumberOfDays = 1;
            defaultGrabMostRecent = 0;
            defaultUseCustomBins = 0;
            defaultBins = 0:20:400;
            defaultPSDsFromMinutes = [];
            defaultPSDsFromPullDurations = [];
            defaultDistributionType = DIST_PDF;
            addOptional(p, 'Stage', defaultStage);
            addOptional(p, 'StartDay', defaultStartDay, @isnumeric);
            addOptional(p, 'NumberOfDays', defaultNumberOfDays, @isnumeric);
            addOptional(p, 'FromMostRecent', defaultGrabMostRecent, @isnumeric);
            addOptional(p, 'Parameter', defaultParameter);
            addOptional(p, 'UseCustomBins', defaultUseCustomBins, @isnumeric);
            addOptional(p, 'Bins', defaultBins);
            addOptional(p, 'SelectMinutes', defaultPSDsFromMinutes);
            addOptional(p, 'SelectPullDurations', defaultPSDsFromPullDurations);
            addOptional(p, 'DistributionType', defaultDistributionType);
            parse(p, varargin{:});
            
            stage = p.Results.Stage;
            start_day = p.Results.StartDay;
            num_days = p.Results.NumberOfDays;
            from_most_recent = p.Results.FromMostRecent;
            parameter = p.Results.Parameter;
            use_custom_bins = p.Results.UseCustomBins;
            bins = p.Results.Bins;
            from_minutes = p.Results.SelectMinutes;
            from_durations = p.Results.SelectPullDurations;
            
            %Determine the type of distribution to be returned to the user.
            temporary_dist_type = p.Results.DistributionType;
            distribution_type = defaultDistributionType;
            if (isnumeric(temporary_dist_type))
                %Assume the user knows what he/she is doing. Set the
                %distribution type accordingly.
                distribution_type = temporary_dist_type;
            elseif (ischar(temporary_dist_type))
                %Find the index of the distribution the user specified in
                %our list of distribution strings.
                index_of_string = find(strcmpi(temporary_dist_type, DISTRIBUTION_TYPE_STRINGS), 1, 'first');
                
                %If we found the distribution in our list...
                if (~isempty(index_of_string))
                    %Convert the index to our enumerated type at the top of
                    %this function.
                    distribution_type = index_of_string - 1;
                end
            end
            
            %Check to see if the user wants us to return a PSD, and which
            %kind of PSD.
            do_psd = (distribution_type == DIST_PSD_FROM_INDIVIDUAL_PULLS || ...
                distribution_type == DIST_PSD_FROM_WHOLE_TRIALS || ...
                distribution_type == DIST_PSD_FROM_CUSTOM);
            use_pulls_for_psd = (distribution_type == DIST_PSD_FROM_INDIVIDUAL_PULLS);
            use_custom_psd = (distribution_type == DIST_PSD_FROM_CUSTOM);
            use_custom_psd_normalized = (distribution_type == DIST_PSD_FROM_CUSTOM_NORMALIZED);
            
            %If the user specified a stage, let's grab the subset of days
            %that are that stage
            if (~isempty(stage))
                logical_indices = strcmpi(stage, {obj.Days.Stage});
                days = obj.Days(logical_indices);
            else
                days = obj.Days;
            end
            
            %Offset by the start day
            days = days(start_day:end);
            
            %We are already guaranteed that daycodes are in sorted
            %order, so no sorting needs to be done.

            %Check to see how many days we have available to us
            actual_num_days = min(num_days, length(days));
            start_day = 1;
            end_day = actual_num_days;
            if (from_most_recent)
                end_day = length(days);
                start_day = end_day - actual_num_days + 1;
            end

            %Let's do some bound checking
            if (start_day < 1)
                start_day = 1;
            elseif (start_day > length(days))
                start_day = length(days);
            end

            if (end_day < 1)
                end_day = 1;
            elseif (end_day > length(days))
                end_day = length(days);
            end

            if (end_day < start_day)
                end_day = start_day;
            end

            if (~isempty(days))
                days = days(start_day:end_day);
            end
            
            data = [];
            if (~isempty(days))
                if (do_psd)
                    %If the user wants to get the PSDs instead of a PDF/CDF
                    psd_data = [];
                    for d = days
                        if (isempty(from_minutes) && isempty(from_durations))
                            %If the user elected not to specify any
                            %specific minutes or pull durations, then we
                            %should use the pre-calculated values that we
                            %already have.  Go ahead and grab them.
                            if (use_custom_psd)
                                if (~isempty(d.CustomPSDMean))
                                    try
                                        if (size(d.CustomPSDMean, 2) == 26)
                                            psd_data = [psd_data; d.CustomPSDMean];
                                        end
                                    catch e
                                        e
                                    end
                                end
                            elseif (use_custom_psd_normalized)
                                if (~isempty(d.CustomPSDMeanNormalized))
                                    psd_data = [psd_data; d.CustomPSDMeanNormalized];
                                end
                            elseif (use_pulls_for_psd)
                                if (~isempty(d.PullPSDFineMean))
                                    psd_data = [psd_data; d.PullPSDFineMean];
                                end
                            else
                                if (~isempty(d.TrialPSDFineMean))
                                    psd_data = [psd_data; d.TrialPSDFineMean];
                                end
                            end
                        else
                            %If the user either did not select which
                            %minutes or which pull durations to analyze,
                            %then we should retrieve PSDs for all minutes
                            %and all pull durations.
                            if (isempty(from_minutes))
                                from_minutes = [0 Inf];
                            end
                            if (isempty(from_durations))
                                from_durations = [0 Inf];
                            end
                            
                            %Retrieve the PSDs
                            custom = use_custom_psd_normalized || use_custom_psd;
                            k = d.RetrievePSDs('ReturnMeanPSD', 1, 'TakeMeanOfPulls', use_pulls_for_psd, 'FromMinutes', from_minutes, ...
                                'PullDurationLowerBound', from_durations(1), 'PullDurationUpperBound', from_durations(2), ...
                                'ReturnCustomPSD', custom, 'NormalizeCustomPSDByAUC', use_custom_psd_normalized);
                            psd_data = [psd_data; k];
                        end
                    end
                    
                    %Take the mean PSD of all the gathered days.
                    data = nanmean(psd_data, 1);
                else
                    %Iterate over each day that we are looking at
                    for d = days
                        %Iterate over each trial from that day
                        this_day_data = [d.Trials.(parameter)];
                        data = [data this_day_data];
                    end

                    %Create the raw PDF of the data
                    if (use_custom_bins)
                        raw_pdf = histc(data, bins);
                    else
                        [raw_pdf, bins] = hist(data);
                    end

                    %Normalize the PDF based on how much data there is. The
                    %normalized PDF is in units of % trials on the y-axis.
                    normalized_pdf = 100 * (raw_pdf / length(data));

                    %If the user actually wants a CDF, let's create it.
                    if (distribution_type == DIST_CDF)
                        normalized_cdf = zeros(1, length(normalized_pdf));
                        for i = 1:length(normalized_cdf)
                            normalized_cdf(i) = sum(normalized_pdf(1:i));
                        end

                        data = normalized_cdf;
                    else
                        data = normalized_pdf;
                    end
                end 
            end
            
        end

    end
    
end



















