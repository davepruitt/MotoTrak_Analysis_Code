classdef PA_Pull
    %PA_Pull represents a single pull within a trial.
    
    properties
        PullPSD
        PullFreqs
        PSDCoarse
        PSDFine
        TotalPower
        PowerBetween10And25Hz
        PowerBetween1And9Hz
        IsLongestPull
        PullDuration
        SampleRate
        Signal
        PercentPowerBetween10And25Hz
        AreaUnderCurve
        
        CustomPullPSD
        CustomPullFreqs
        CustomPullAUC
    end
    
    methods
        %Class constructor
        function obj = PA_Pull(signal, Fs, longest, varargin)
            %Parse optional inputs
            p = inputParser;
            defaultCustomDuration = 0;
            addOptional(p, 'CreateCustomPSDWithSignalDuration', defaultCustomDuration, @isnumeric);
            parse(p, varargin{:});
            custom_duration = p.Results.CreateCustomPSDWithSignalDuration;
            
            %Set some simple variables
            obj.IsLongestPull = longest;
            obj.SampleRate = Fs;
            obj.Signal = signal;
            
            bin_size = 1000 / obj.SampleRate;
            
            %Calculate pull duration
            obj.PullDuration = 1000 * (obj.SampleRate / length(obj.Signal));
            
            %Calculate the periodogram
            [obj.PullPSD, obj.PullFreqs] = periodogram(signal, hamming(length(signal)), length(signal), Fs);
            
            %Calculate the area under the curve of the signal
            %This should be normalized by the sample rate
            obj.AreaUnderCurve = trapz(obj.Signal) / obj.SampleRate;
            
            %Calculate total power
            max_freq = min(50, floor(max(obj.PullFreqs)));
            obj.TotalPower = bandpower(obj.PullPSD, obj.PullFreqs, [1 max_freq], 'psd');
            
            %Calculate postural power
            obj.PowerBetween10And25Hz = bandpower(obj.PullPSD, obj.PullFreqs, [10 25], 'psd');
            
            %Calculate power in the lower frequency spectrum
            obj.PowerBetween1And9Hz = bandpower(obj.PullPSD, obj.PullFreqs, [1 9], 'psd');
            
            %Calculate the % power that is postural power
            obj.PercentPowerBetween10And25Hz = obj.PowerBetween10And25Hz / obj.TotalPower;
            
            %Calculate the coarse PSD
            f = 1;
            coarse_psd = zeros(1, 10);
            for start_freq = 1:5:50
                sf = min(start_freq, floor(max(obj.PullFreqs)));
                ef = min(sf + 4, floor(max(obj.PullFreqs)));
                if (sf == ef)
                    coarse_psd(f) = 0;
                else
                    coarse_psd(f) = bandpower(obj.PullPSD, obj.PullFreqs, [sf ef], 'psd');
                end
                f = f + 1;
            end
            
            obj.PSDCoarse = coarse_psd;
            
            %Calculate the fine PSD
            f = 1;
            fine_psd = zeros(1, 50);
            for start_freq = 1:50
                sf = min(start_freq, floor(max(obj.PullFreqs)));
                ef = min(sf + 1, floor(max(obj.PullFreqs)));
                if (sf == ef)
                    fine_psd(f) = 0;
                else
                    fine_psd(f) = bandpower(obj.PullPSD, obj.PullFreqs, [sf ef], 'psd');
                end
                f = f + 1;
            end
            
            obj.PSDFine = fine_psd;
            
            %Calculate the custom PSD if the user wants it
            %The minimum custom duration is 200 ms.
            if (custom_duration >= 200)
                samples_needed = custom_duration / bin_size;
                if (length(obj.Signal) >= samples_needed)
                    custom_signal = obj.Signal(1:samples_needed);
                    [obj.CustomPullPSD, obj.CustomPullFreqs] = periodogram(custom_signal, hamming(samples_needed), samples_needed, Fs);
                    
                    obj.CustomPullPSD = obj.CustomPullPSD';
                    obj.CustomPullFreqs = obj.CustomPullFreqs';
                    
                    %Calculate the custom area-under-the-curve
                    %This should also be normalized by sample rate
                    obj.CustomPullAUC = trapz(custom_signal) / obj.SampleRate;
                end
            end
        end
    end
    
end

