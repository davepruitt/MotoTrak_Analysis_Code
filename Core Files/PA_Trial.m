classdef PA_Trial
    %PA_TRIAL holds information for a single trial.
    
    properties
        Outcome
        Time
        ElapsedTime
        SessionNumber
        Signal
        SampleRate
        IsMalformedTrial
        HitWindowStart
        HitWindowEnd
        BinSize
        MaximalForce
        TrialPulls
        MaximalHoldTime
        TotalAttempts
        TotalAttemptsAfterHitWindowBegins
        TotalAttemptsWithinHitWindow
        AveragePullSpeed
        MaximalPullSpeed
        FilteredAveragePullSpeed
        FilteredGrandAveragePullSpeed
        AttemptsToHit
        AttemptsToForceThreshold
        AttemptsToHoldThreshold
        TrialPSD
        TrialFreqs
        PSDFine
        TrialPower
        PowerBetween10And25Hz
        PowerBetween1And9Hz
        PercentPowerBetween10And25Hz
        
        ForceThreshold
        HoldDurationThreshold
        TrialThreshold
        
        HitTime
        VNSTime
        
    end
    
    methods
        %Class constructor
        function obj = PA_Trial(trial, varargin)
            %This constructor requires a trial object of the format that
            %comes from ArdyMotorFileRead.
            
            %Handle optional inputs
            p = inputParser;
            
            defaultIsSustainedPull = 0;
            defaultStartTime = 0;
            defaultSessionNumber = 1;
            defaultCustomPSDDuration = 500;
            defaultOnlyAnalyzeBasicData = 0;
            defaultCreatePullObjects = 1;
            defaultDoPowerAnalysis = 1;
            
            addOptional(p, 'IsSustainedPull', defaultIsSustainedPull, @isnumeric);
            addOptional(p, 'SessionStartTime', defaultStartTime, @isnumeric);
            addOptional(p, 'SessionNumber', defaultSessionNumber, @isnumeric);
            addOptional(p, 'CustomPSDDuration', defaultCustomPSDDuration, @isnumeric);
            addOptional(p, 'OnlyAnalyzeBasicData', defaultOnlyAnalyzeBasicData, @isnumeric);
            addOptional(p, 'CreatePullObjects', defaultCreatePullObjects, @isnumeric);
            addOptional(p, 'DoPowerAnalysis', defaultDoPowerAnalysis, @isnumeric);
            
            parse(p, varargin{:});
            
            is_sustained_pull = p.Results.IsSustainedPull;
            session_start_time = p.Results.SessionStartTime;
            session_num = p.Results.SessionNumber;
            custom_psd_duration = p.Results.CustomPSDDuration;
            only_analyze_basic_data = p.Results.OnlyAnalyzeBasicData;
            create_pull_objects = p.Results.CreatePullObjects;
            do_power_analysis = p.Results.DoPowerAnalysis;
            
            %Some variable we will need throughout the constructor
            %trial_duration = 5;
            trial_duration = trial.hitwin + 3; %3 is because there is 1 second before the hit window and 2 seconds after the hit window
            regular_pull_grams_threshold = 120;
            sustained_pull_grams_threshold = 35;
            sustained_pull_hold_threshold = 870;
            minimum_pull_hold_time_threshold = 200;
            
            %Grab the trial signal and save it as a row vector.
            obj.Signal = trial.signal';
            obj.Outcome = trial.outcome;
            obj.Time = datevec(trial.starttime);
            obj.TrialThreshold = trial.thresh;
            obj.HitTime = trial.hittime;
            obj.VNSTime = trial.vnstime;
            
            if (is_sustained_pull)
                %Convert from "centiseconds" to "milliseconds"
                obj.TrialThreshold = obj.TrialThreshold * 10; 
                
                obj.HoldDurationThreshold = obj.TrialThreshold;
                obj.ForceThreshold = 35;
            else
                obj.ForceThreshold = obj.TrialThreshold;
                obj.HoldDurationThreshold = 0;
            end
            
            %Set the elapsed time and the session number
            if (session_start_time == 0)
                obj.ElapsedTime = 0;
            else
                start_time_vec = datevec(session_start_time);
                obj.ElapsedTime = etime(obj.Time, start_time_vec);
            end
            
            obj.SessionNumber = session_num;
            
            %Calculate the sample rate of this trial.
            obj.SampleRate = round(length(trial.signal) / trial_duration);
            
            %Currently we enforce a sample rate of either 500 Hz or 100 Hz.
            %If the trial doesn't meet this requirement, let's flag it.
            obj.IsMalformedTrial = 0;
            if (obj.SampleRate ~= 500 && obj.SampleRate ~= 100)
                obj.IsMalformedTrial = 1;
            end
            
            %Calculate where the hit window is in our trial.
            
            %obj.HitWindowStart = 0.2 * length(trial.signal);
            obj.HitWindowStart = obj.SampleRate;
            %obj.HitWindowEnd = 0.6 * length(trial.signal);
            obj.HitWindowEnd = obj.SampleRate * (trial.hitwin + 1);
            
            obj.BinSize = 1000 / obj.SampleRate;
            
            %Calculate maximal force here since it is super simple.
            obj.MaximalForce = max(obj.Signal(obj.HitWindowStart:obj.HitWindowEnd));
            
            %Initialize total attempts variables
            obj.TotalAttemptsAfterHitWindowBegins = NaN;
            obj.TotalAttemptsWithinHitWindow = NaN;
            
            if (~only_analyze_basic_data)
                
                %Initialize total attempts variables
                obj.TotalAttemptsAfterHitWindowBegins = 0;
                obj.TotalAttemptsWithinHitWindow = 0;
                in_attempt = 0;
                
                if (~isempty(obj.Signal))
                    for i = obj.HitWindowStart:length(obj.Signal)
                        if (obj.Signal(i) >= 35)
                            if (in_attempt == 0)
                                in_attempt = 1;

                                if (i >= obj.HitWindowStart)
                                    obj.TotalAttemptsAfterHitWindowBegins = obj.TotalAttemptsAfterHitWindowBegins + 1;
                                    if (i <= obj.HitWindowEnd)
                                        obj.TotalAttemptsWithinHitWindow = obj.TotalAttemptsWithinHitWindow + 1;
                                    end
                                end
                            end
                        else
                            if (in_attempt == 1)
                                in_attempt = 0;
                            end
                        end
                    end
                end

                %Zero the signal at the force threshold
                sustained_signal = obj.Signal - sustained_pull_grams_threshold;

                %Make everything above the hit threshold a 1, and
                %everything below the hit threshold a 0.
                sustained_signal(sustained_signal > 0) = 1;
                sustained_signal(sustained_signal <= 0) = 0;

                %Find the starting index and ending index of all
                %pulls in the trial.
                is=find(diff([0 sustained_signal])==1);
                ie=find(diff([sustained_signal 0])==-1);

                %Find the length of all pulls in the trial.
                lgt = ie-is+1;

                %Find the length of the longest pull in the trial.
                longest_pull_length = max(lgt);
                if (isempty(longest_pull_length))
                    longest_pull_length = 0;
                end

                %Separate each individual pull in the trial and create objects
                %for each of them.
                pulls = [];
                attempts_to_hold_threshold = 0;
                hold_hit_attempt_found = 0;
                attempts_to_force_threshold = 0;
                force_hit_attempt_found = 0;

                for p = 1:length(lgt)
                    pull_duration_in_ms = lgt(p) * obj.BinSize;
                    this_pull_signal = obj.Signal(is(p):ie(p));

                    if (~force_hit_attempt_found)
                        attempts_to_force_threshold = attempts_to_force_threshold + 1;
                        if (max(this_pull_signal) >= regular_pull_grams_threshold)
                            force_hit_attempt_found = 1;
                        end
                    end

                    if (~hold_hit_attempt_found && is_sustained_pull)
                        attempts_to_hold_threshold = attempts_to_hold_threshold + 1;
                        if (pull_duration_in_ms >= sustained_pull_hold_threshold)
                            hold_hit_attempt_found = 1;
                        end
                    end

                    if (pull_duration_in_ms >= minimum_pull_hold_time_threshold)    
                        longest_pull = 0;
                        if (lgt(p) == longest_pull_length)
                            longest_pull = 1;
                        end

                        %Create a new pull object for all pulls that meet the
                        %minimum duration threshold (200ms).
                        if (create_pull_objects)
                            new_pull = PA_Pull(this_pull_signal, obj.SampleRate, longest_pull, ...
                                'CreateCustomPSDWithSignalDuration', custom_psd_duration);
                        else
                            new_pull = [];
                        end

                        %Add the new pull to our list of pulls for this trial.
                        pulls = [pulls new_pull];
                    end
                end

                %Set the trial pulls. Only pulls longer than 200ms in duration
                %are saved!!!!
                obj.TrialPulls = pulls;

                %Set the maximal hold time for this trial.
                obj.MaximalHoldTime = longest_pull_length * obj.BinSize;

                if (~force_hit_attempt_found)
                    attempts_to_force_threshold = NaN;
                end
                if (~hold_hit_attempt_found)
                    attempts_to_hold_threshold = NaN;
                end

                obj.AttemptsToForceThreshold = attempts_to_force_threshold;
                obj.AttemptsToHoldThreshold = attempts_to_hold_threshold;
                if (is_sustained_pull)
                    obj.AttemptsToHit = obj.AttemptsToHoldThreshold;
                else
                    obj.AttemptsToHit = obj.AttemptsToForceThreshold;
                end

                %Define how many attempts there were for this trial.
                %The definition of "attempts" we are using is any time the
                %force exceeded 35 grams (the sustained pull force threshold).
                obj.TotalAttempts = length(lgt);

                %Calculate the average and maximal pull speeds.
                pull_speed = [0 diff(obj.Signal)];
                pull_speed(pull_speed < 0) = 0;
                obj.AveragePullSpeed = mean(pull_speed) / obj.BinSize;
                obj.MaximalPullSpeed = max(pull_speed) / obj.BinSize;

                %Calculate the "filtered" average pull speed.
                %This is defined as the pull speed only during pulling motion,
                %rather than over the entire trial.
                mean_speed_of_each_pull = [];
                all_speeds_of_all_pulls = [];
                for p = 1:length(lgt)
                    this_pull_speed = pull_speed(is(p):ie(p)) / obj.BinSize;
                    this_pull_speed = this_pull_speed(this_pull_speed > 0);
                    mean_speed_of_each_pull = [mean_speed_of_each_pull mean(this_pull_speed)];
                    all_speeds_of_all_pulls = [all_speeds_of_all_pulls this_pull_speed];
                end

                obj.FilteredAveragePullSpeed = mean(all_speeds_of_all_pulls);
                obj.FilteredGrandAveragePullSpeed = mean(mean_speed_of_each_pull);

                if (do_power_analysis)
                    %Calculate the trial PSD
                    [obj.TrialPSD, obj.TrialFreqs] = periodogram(obj.Signal, hamming(length(obj.Signal)), length(obj.Signal), obj.SampleRate);

                    %Calculate the fine PSD
                    f = 1;
                    fine_psd = zeros(1, 50);
                    for start_freq = 1:50
                        sf = min(start_freq, floor(max(obj.TrialFreqs)));
                        ef = min(sf + 1, floor(max(obj.TrialFreqs)));
                        if (sf == ef)
                            fine_psd(f) = 0;
                        else
                            try
                                fine_psd(f) = bandpower(obj.TrialPSD, obj.TrialFreqs, [sf ef], 'psd');
                            catch e
                                e
                            end
                        end
                        f = f + 1;
                    end

                    obj.PSDFine = fine_psd;

                    %Calculate the total trial power
                    max_freq = min(50, floor(max(obj.TrialFreqs)));
                    obj.TrialPower = bandpower(obj.TrialPSD, obj.TrialFreqs, [1 max_freq], 'psd');

                    %Calculate trial postural power
                    obj.PowerBetween10And25Hz = bandpower(obj.TrialPSD, obj.TrialFreqs, [10 25], 'psd');

                    %Calculate the trial lower spectral power
                    obj.PowerBetween1And9Hz = bandpower(obj.TrialPSD, obj.TrialFreqs, [1 9], 'psd');

                    %Calculate the % power in the postural spectrum
                    obj.PercentPowerBetween10And25Hz = obj.PowerBetween10And25Hz / obj.TrialPower;
                end
            
            end
        end
        
        function data = RetrievePullPSDs (obj, varargin)
            
            %Parse inputs to the function
            p = inputParser;
            p.CaseSensitive = false;
            defaultReturnMeanPSD = 0;
            defaultDurationLowerBound = 200;
            defaultDurationUpperBound = Inf;
            defaultRetrieveCoarsePSD = 0;
            addOptional(p, 'ReturnMeanPSD', defaultReturnMeanPSD, @isnumeric);
            addOptional(p, 'DurationLowerBound', defaultDurationLowerBound, @isnumeric);
            addOptional(p, 'DurationUpperBound', defaultDurationUpperBound, @isnumeric);
            addOptional(p, 'ReturnCoarsePSD', defaultRetrieveCoarsePSD, @isnumeric);
            parse(p, varargin{:});
            return_mean = p.Results.ReturnMeanPSD;
            lower_bound = p.Results.DurationLowerBound;
            upper_bound = p.Results.DurationUpperBound;
            use_coarse_psd = p.Results.ReturnCoarsePSD;
            
            %Grab the pulls that meet the criteria
            if (~isempty(obj.TrialPulls))
                pull_durations = [obj.TrialPulls.PullDuration];
                pulls = obj.TrialPulls(pull_durations >= lower_bound & pull_durations <= upper_bound);
                
                %Create a matrix of all the PSDs.
                if (use_coarse_psd)
                    parameter = 'PSDCoarse';
                else
                    parameter = 'PSDFine';
                end
                psds = [];
                for i = 1:length(pulls)
                    indiv_psd = pulls.(parameter);
                    if (size(indiv_psd, 2) > 50)
                        indiv_psd = indiv_psd(1:50);
                    end
                    psds = [psds; indiv_psd];
                end

                %Either return the mean or the full matrix
                if (return_mean)
                    data = nanmean(psds, 1);
                else
                    data = psds;
                end
            else
                data = [];
            end
        end
    end
    
end





























