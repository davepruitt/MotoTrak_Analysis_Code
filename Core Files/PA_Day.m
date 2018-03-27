classdef PA_Day
    %PA_DAY holds data for a single day.
    
    properties
        DayCode
        Booth
        Stage
        ThresholdType
        Trials
        TotalTrials
		
		TotalTrialsAbove120
		PercentTrialsAbove120
        
        TotalKnobTrialsAbove60
        PercentKnobTrialsAbove60
        
        TotalAttemptsFromTrialsOnlyHitWindow
        TotalAttemptsFromTrials
        
        HitRate
        MaximalForceMean
        MaximalForceMedian
        MaximalForceCI
        MaximalHoldTimeMean
        MaximalHoldTimeMedian
        MaximalHoldTimeCI
        
        TotalAttemptsMean
        AttemptsToHitMean
        AttemptsToForceThresholdMean
        AttemptsToHoldThresholdMean
        
        AveragePullSpeedMean
        MaximalPullSpeedMean
        FilteredAveragePullSpeedMean
        FilteredGrandAveragePullSpeedMean
        
        TrialPowerMean
        TrialPowerBetween10And25HzMean
        TrialPowerBetween1And9HzMean
        TrialPercentPowerBetween10And25HzMean
        
        PullPowerMean
        PullPowerBetween10And25HzMean
        PullPowerBetween1And9HzMean
        PullPercentPowerBetween10And25HzMean
        PullDurationMean
        
        PullPSDFineMean
        PullPSDFineCI
        TrialPSDFineMean
        TrialPSDFineCI
        
        CustomPSDMean
        CustomPSDCI
        CustomPSDMeanNormalized
        CustomPSDCINormalized
        CustomPSDFreqs
        
        TrialThresholdMean
        ForceThresholdMean
        HoldDurationThresholdMean
        
        TrialThresholdPeak
        ForceThresholdPeak
        HoldDurationThresholdPeak
    end
    
    methods
        %Class constructor
        function obj = PA_Day(sessions, varargin)
            %Handle optional parameters
            defaultIsSustainedPull = 0;
            defaultAutoShed = 1;
            defaultForceCriterionForAutoShed = 300;
            defaultOnlyAnalyzeBasicData = 0;
            defaultCreatePullObjects = 1;
            defaultDoPowerAnalysis = 1;
            p = inputParser;
            p.CaseSensitive = false;
            addOptional(p, 'IsSustainedPull', defaultIsSustainedPull, @isnumeric);
            addOptional(p, 'AutomaticallyShedHighForcePulls', defaultAutoShed, @isnumeric);
            addOptional(p, 'ForceCriterionForAutoShed', defaultForceCriterionForAutoShed, @isnumeric);
            addOptional(p, 'OnlyAnalyzeBasicData', defaultOnlyAnalyzeBasicData, @isnumeric);
            addOptional(p, 'CreatePullObjects', defaultCreatePullObjects, @isnumeric);
            addOptional(p, 'DoPowerAnalysis', defaultDoPowerAnalysis, @isnumeric);
            parse(p, varargin{:});
            is_sustained_pull = p.Results.IsSustainedPull;
            auto_shed = p.Results.AutomaticallyShedHighForcePulls;
            auto_shed_force = p.Results.ForceCriterionForAutoShed;
            only_analyze_basic_data = p.Results.OnlyAnalyzeBasicData;
            create_pull_objects = p.Results.CreatePullObjects;
            do_power_analysis = p.Results.DoPowerAnalysis;
            
            %This constructor requires an array of sessions in the format
            %that comes from ArdyMotorFileRead.  All of the sessions should
            %be from the same day.
            
            %Verify that all daycodes are the same, and display a warning
            %if not. Use the first daycode available.
            daycodes = unique([sessions.daycode]);
            if (length(daycodes) > 1)
                disp(['Warning: You have selected sessions from different ' ...
                    'days to be analyzed together into the same day. The daycode ' ...
                    'used will be the first daycode found.']);
            end
            obj.DayCode = daycodes(1);
            
            %Verify that the booth is the same for all sessions from this
            %day. If not, display a warning message. Use the first booth
            %available as the booth number.
            booths = unique([sessions.booth]);
            if (length(booths) > 1)
                disp(['Warning: You have selected sessions from different ' ...
                    'booths. The first booth will be used as the booth number.']);
            end
            obj.Booth = booths(1);
            
            %Verify that the stage is the same for all sessions from this
            %day. If not, display a warning message. Use the first stage
            %available as the stage name.
            stage = unique({sessions.stage});
            if (length(stage) > 1)
                disp(['Warning: You have selected sessions from multiple different stages ' ...
                    'to be analyzed together as one stage. The first stage found ' ...
                    'will be used as the stage name.']);
            end
            obj.Stage = lower(stage{1});
            
            %Verify that all sessions have the same threshold type. Use the
            %first threshold type if not.
            threshold = unique({sessions.threshtype});
            if (length(threshold) > 1)
                disp(['Warning: You have selected sessions that are fundamentally different tasks ' ...
                    'to be analyzed together. The first threshold type found ' ...
                    'will be used as the overall threshold type.']);
            end
            obj.ThresholdType = threshold{1};
            
            %Iterate over every single session
            all_day_trials = [];
            for s = 1:length(sessions)
                %Determine the start time for the session.  This will be
                %used for determining the elapsed time for each trial
                %during the session.
                this_session = sessions(s);
                if (~isempty(this_session.trial))
                    session_start_time = this_session.trial(1).starttime;
                else
                    session_start_time = 0;
                end
                
                this_session_trials = [];
                shed_count = 0;
                
                %Iterate through each trial. Create trial objects for each
                %one, and add them to our list of trials for the day.
                for t = 1:length(this_session.trial)
                    new_trial = PA_Trial(this_session.trial(t), 'IsSustainedPull', is_sustained_pull, 'SessionStartTime', session_start_time, ...
                        'SessionNumber', s, 'OnlyAnalyzeBasicData', only_analyze_basic_data, 'CreatePullObjects', create_pull_objects, ...
                        'DoPowerAnalysis', do_power_analysis);
                    
                    %If the trial's maximal force is more than 300 grams,
                    %automatically get rid of it.
                    shed_trial = 0;
                    if (auto_shed)
                        if (new_trial.MaximalForce >= auto_shed_force)
                            shed_trial = 1;
                            shed_count = shed_count + 1;
                        end
                    end
                    
                    %Add the trial to the list of trials if it was not
                    %shedded.
                    if (~shed_trial)
                        this_session_trials = [this_session_trials new_trial];
                    end
                end
                
                %Determine if we want to completeley shed this session.
                %Current criterion: if at least 50% of the trials were
                %already shedded, let's shed the entire session. It's most
                %likely a useless session.
                shed_session = 0;
                if (~isempty(this_session.trial))
                    shed_percentage = 100 * (shed_count / length(this_session.trial));
                    if (auto_shed && (shed_percentage >= 50))
                        shed_session = 1;
                    end
                end
                
                %Add all of this session's trials to the day's trials if
                %the session is determined to be good.
                if (~shed_session)
                    all_day_trials = [all_day_trials this_session_trials];
                end
            end
            
            %Assign the list of trials to this object.
            obj.Trials = all_day_trials;
            obj.TotalTrials = length(obj.Trials);
            
            %Calculate
            if (~isempty(obj.Trials))
                obj = Calculate(obj, only_analyze_basic_data);
            end
        end
        
        function obj = Calculate(obj, only_analyze_basic_data)
            %Calculate hit rate
            HIT_OUTCOME = 72;
            MISS_OUTCOME = 77;
            all_outcomes = [obj.Trials.Outcome];
            all_real_trials = length(find(all_outcomes == HIT_OUTCOME | all_outcomes == MISS_OUTCOME));
            all_hits = length(find(all_outcomes == HIT_OUTCOME));
            obj.HitRate = (all_hits / all_real_trials) * 100;
            
            %Maximal force
            max_force_vec = [obj.Trials.MaximalForce];
            obj.MaximalForceMean = nanmean(max_force_vec);
            obj.MaximalForceMedian = nanmedian(max_force_vec);
            obj.MaximalForceCI = simple_ci(max_force_vec');
            
			%Trials above 120
			total_trials_above_120 = length(find(max_force_vec > 120));
			obj.TotalTrialsAbove120 = total_trials_above_120;
			obj.PercentTrialsAbove120 = (total_trials_above_120 / all_real_trials) * 100;
            
            %Trials above 60 degrees (for Knob)
            total_trials_above_60_deg = length(find(max_force_vec >= 60));
            obj.TotalKnobTrialsAbove60 = total_trials_above_60_deg;
            obj.PercentKnobTrialsAbove60 = (total_trials_above_60_deg / all_real_trials) * 100;
            
            obj.TotalAttemptsFromTrialsOnlyHitWindow = NaN;
            obj.TotalAttemptsFromTrials = NaN;
			
            if (~only_analyze_basic_data)
                
                %Thresholds
                trial_thresholds = [obj.Trials.TrialThreshold];
                force_thresholds = [obj.Trials.ForceThreshold];
                hold_thresholds = [obj.Trials.HoldDurationThreshold];
                obj.TrialThresholdMean = nanmean(trial_thresholds);
                obj.ForceThresholdMean = nanmean(force_thresholds);
                obj.HoldDurationThresholdMean = nanmean(hold_thresholds);
                obj.TrialThresholdPeak = max(trial_thresholds);
                obj.ForceThresholdPeak = max(force_thresholds);
                obj.HoldDurationThresholdPeak = max(hold_thresholds);
                obj.TotalAttemptsFromTrialsOnlyHitWindow = nansum([obj.Trials.TotalAttemptsWithinHitWindow]);
                obj.TotalAttemptsFromTrials = nansum([obj.Trials.TotalAttemptsAfterHitWindowBegins]);

                %Hold time
                max_hold_time = [obj.Trials.MaximalHoldTime];
                obj.MaximalHoldTimeMean = nanmean(max_hold_time);
                obj.MaximalHoldTimeMedian = nanmedian(max_hold_time);
                obj.MaximalHoldTimeCI = simple_ci(max_hold_time');

                %Attempts
                obj.TotalAttemptsMean = nanmean([obj.Trials.TotalAttempts]);
                obj.AttemptsToHitMean = nanmean([obj.Trials.AttemptsToHit]);
                obj.AttemptsToForceThresholdMean = nanmean([obj.Trials.AttemptsToForceThreshold]);
                obj.AttemptsToHoldThresholdMean = nanmean([obj.Trials.AttemptsToHoldThreshold]);

                %Pull speed
                obj.AveragePullSpeedMean = nanmean([obj.Trials.AveragePullSpeed]);
                obj.MaximalPullSpeedMean = nanmean([obj.Trials.MaximalPullSpeed]);
                obj.FilteredAveragePullSpeedMean = nanmean([obj.Trials.FilteredAveragePullSpeed]);
                obj.FilteredGrandAveragePullSpeedMean = nanmean([obj.Trials.FilteredGrandAveragePullSpeed]);

                %Trial power
                obj.TrialPowerMean = nanmean([obj.Trials.TrialPower]);
                obj.TrialPowerBetween10And25HzMean = nanmean([obj.Trials.PowerBetween10And25Hz]);
                obj.TrialPowerBetween1And9HzMean = nanmean([obj.Trials.PowerBetween1And9Hz]);
                obj.TrialPercentPowerBetween10And25HzMean = nanmean([obj.Trials.PercentPowerBetween10And25Hz]);

                %Pull power
                all_pulls = [];
                for t = 1:length(obj.Trials);
                    all_pulls = [all_pulls obj.Trials(t).TrialPulls];
                end

                if (~isempty(all_pulls))
                    obj.PullPowerMean = nanmean([all_pulls.TotalPower]);
                    obj.PullPowerBetween10And25HzMean = nanmean([all_pulls.PowerBetween10And25Hz]);
                    obj.PullPowerBetween1And9HzMean = nanmean([all_pulls.PowerBetween1And9Hz]);
                    obj.PullPercentPowerBetween10And25HzMean = nanmean([all_pulls.PercentPowerBetween10And25Hz]);

                    %Mean pull duration for all pulls above 200 ms
                    obj.PullDurationMean = nanmean([all_pulls.PullDuration]); 
                else
                    obj.PullPowerMean = 0;
                    obj.PullPowerBetween10And25HzMean = 0;
                    obj.PullPowerBetween1And9HzMean = 0;
                    obj.PullPercentPowerBetween10And25HzMean = 0;
                    obj.PullDurationMean = 0;
                end

                %Calculate mean PSD for all pulls
                all_pulls_psds = [];
                for p = 1:length(all_pulls)
                    all_pulls_psds = [all_pulls_psds; all_pulls(p).PSDFine];
                end
                psd_fine = nanmean(all_pulls_psds, 1);
                if (size(all_pulls_psds, 1) > 1)
                    psd_fine_err = simple_ci(all_pulls_psds);
                else
                    psd_fine_err = NaN;
                end
                obj.PullPSDFineMean = psd_fine;
                obj.PullPSDFineCI = psd_fine_err;

                %Calculate the mean custom PSD for all pulls
                all_pulls_custom_psds = [];
                all_pulls_custom_psds_normalized = [];
                for p = 1:length(all_pulls)
                    this_pull = all_pulls(p);
                    if (~isempty(this_pull.CustomPullPSD))
                        new_psd = this_pull.CustomPullPSD;
                        new_psd_normalized = new_psd ./ this_pull.CustomPullAUC;

                        all_pulls_custom_psds = [all_pulls_custom_psds; new_psd];
                        all_pulls_custom_psds_normalized = [all_pulls_custom_psds_normalized; new_psd_normalized];

                        if (isempty(obj.CustomPSDFreqs))
                            obj.CustomPSDFreqs = this_pull.CustomPullFreqs;
                        end
                    end
                end

                obj.CustomPSDMean = nanmean(all_pulls_custom_psds, 1);
                if (size(all_pulls_custom_psds, 1) > 1)
                    obj.CustomPSDCI = simple_ci(all_pulls_custom_psds);
                else
                    obj.CustomPSDCI = NaN;
                end

                obj.CustomPSDMeanNormalized = nanmean(all_pulls_custom_psds_normalized, 1);
                if (size(all_pulls_custom_psds_normalized, 1) > 1)
                    obj.CustomPSDCINormalized = simple_ci(all_pulls_custom_psds_normalized);
                else
                    obj.CustomPSDCINormalized = NaN;
                end

                %Calculate mean PSD for all trials
                all_trials_psds = [];
                for t = 1:length(obj.Trials)
                    all_trials_psds = [all_trials_psds; obj.Trials(t).PSDFine];
                end
                psd_fine = nanmean(all_trials_psds, 1);
                if (size(all_trials_psds, 1) > 1)
                    psd_fine_err = simple_ci(all_trials_psds);
                else
                    psd_fine_err = NaN;
                end
                obj.TrialPSDFineMean = psd_fine;
                obj.TrialPSDFineCI = psd_fine_err;
            
            end
            
            %Eliminate all data from specific trials to save memory
            %obj.Trials = [];
            
        end
        
        function data = RetrievePSDs (obj, varargin)
                       
            %Parse inputs to the function
            p = inputParser;
            p.CaseSensitive = false;
            defaultReturnMeanPSD = 0;
            defaultDurationLowerBound = 200;
            defaultDurationUpperBound = Inf;
            defaultRetrieveCoarsePSD = 0;
            defaultUseTrialPSD = 0;
            defaultTakeMeanOfPulls = 0;
            defaultNumberOfTrials = length(obj.Trials);
            defaultFromMinutes = [0 Inf];
            defaultUseCustomPSD = 0;
            defaultNormalizeByCustomAUC = 0;
            addOptional(p, 'ReturnMeanPSD', defaultReturnMeanPSD, @isnumeric);
            addOptional(p, 'PullDurationLowerBound', defaultDurationLowerBound, @isnumeric);
            addOptional(p, 'PullDurationUpperBound', defaultDurationUpperBound, @isnumeric);
            addOptional(p, 'PullReturnCoarsePSD', defaultRetrieveCoarsePSD, @isnumeric);
            addOptional(p, 'ReturnTrialPSD', defaultUseTrialPSD, @isnumeric);
            addOptional(p, 'ReturnCustomPSD', defaultUseCustomPSD, @isnumeric);
            addOptional(p, 'NormalizeCustomPSDByAUC', defaultNormalizeByCustomAUC, @isnumeric);
            addOptional(p, 'TakeMeanOfPulls', defaultTakeMeanOfPulls, @isnumeric);
            addOptional(p, 'NumberOfTrials', defaultNumberOfTrials, @isnumeric);
            addOptional(p, 'FromMinutes', defaultFromMinutes); 
            parse(p, varargin{:});
            return_mean = p.Results.ReturnMeanPSD;
            lower_bound = p.Results.PullDurationLowerBound;
            upper_bound = p.Results.PullDurationUpperBound;
            use_coarse_psd = p.Results.PullReturnCoarsePSD;
            use_trial_psd = p.Results.ReturnTrialPSD;
            use_custom_psd = p.Results.ReturnCustomPSD;
            use_pull_mean = p.Results.TakeMeanOfPulls;
            num_trials = p.Results.NumberOfTrials;
            minutes_to_search = p.Results.FromMinutes;
            custom_normalize_by_auc = p.Results.NormalizeCustomPSDByAUC;
            
            if (isempty(minutes_to_search))
                minutes_to_search = [0 Inf];
            elseif (isscalar(minutes_to_search))
                minutes_to_search = [minutes_to_search Inf];
            end
            
            %Grab trials only from the time-period being searched for
            if (minutes_to_search(1) == 0 && isinf(minutes_to_search(2)))
                trials_to_search = obj.Trials;
            else
                time_diffs = [];
                if (~isempty(obj.Trials))
                    for t = 1:length(obj.Trials)
                        this_trial_elapsed_time = obj.Trials(t).ElapsedTime / 60;
                        time_diffs = [time_diffs this_trial_elapsed_time];
                    end
                end
                logical_indices = time_diffs >= minutes_to_search(1) & time_diffs <= minutes_to_search(2);
                trials_to_search = obj.Trials(logical_indices);
            end
            
            %Grab only as many trials as the user wants to search through
            if (length(trials_to_search) > num_trials)
                trials_to_search = trials_to_search(1:num_trials);
            end
            
            %Iterate through trials to get PSDs
            psds = [];
            pull_freqs = [];
            for t = 1:length(trials_to_search)
                if (use_trial_psd)
                    %If the user has requested to use the "trial psd", then
                    %grab that from the trial object. A "trial psd" is
                    %essentially the power spectrum of the ENTIRE trial
                    %(including empty space where no pulling was
                    %happening).
                    psds = [psds; trials_to_search(t).PSDFine];
                elseif (use_custom_psd)
                    %If the user has asked for the custom PSD, return that.
                    %The custom PSD is something that the user can specify
                    %when creating the dataset.  By default, the custom PSD
                    %is the periodogram of the first 500ms of all pulls
                    %that are at least that duration.
                    
                    %All custom PSDs in the dataset SHOULD have the same
                    %frequencies on the x-axis, because it is enforced
                    %that all custom PSDs be of the same length.
                    %Therefore, we will grab the frequencies from the first
                    %one in the list.
                    
                    pulls = trials_to_search(t).TrialPulls;
                    pull_psds = [];
                    for p = pulls
                        if (~isempty(p.CustomPullPSD))
                            %Grab the pull PSD and normalize it if need be
                            new_psd = p.CustomPullPSD;
                            if (custom_normalize_by_auc)
                                new_psd = new_psd ./ p.CustomPullAUC;
                            end
                            
                            %Add the PSD to the list, and the frequency
                            %list if we don't have one yet.
                            pull_psds = [pull_psds; new_psd];
                            if (isempty(pull_freqs))
                                pull_freqs = p.CustomPullFreqs;
                            end
                        end
                    end
                    
                    %Add the custom PSDs from this trial to the list of
                    %PSDs from all trials.
                    if (~isempty(pull_psds))
                        psds = [psds; pull_psds];
                    end
                    
                else
                    %If neither special case is met, then we will simply
                    %ask to retrieve the PSDs from each pull that occurred
                    %during the trial.  These PSDs are transformed to be
                    %from 1 to 50 Hz.
                    pull_psds = trials_to_search(t).RetrievePullPSDs('ReturnMeanPSD', use_pull_mean, 'DurationLowerBound', lower_bound, ...
                        'DurationUpperBound', upper_bound, 'ReturnCoarsePSD', use_coarse_psd);
                    if (~isempty(pull_psds))
                        psds = [psds; pull_psds];
                    end
                end
            end
            
            %Return the PSDs to the caller.
            if (return_mean)
                data = nanmean(psds, 1);
            else
                data = psds;
            end
        end
    end
    
end






















