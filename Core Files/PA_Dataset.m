classdef PA_Dataset
    %PA_DATASET encompasses an entire dataset and its capabilities.
    
    properties
        Rats
        DataFiles
    end
    
    methods
        %Constructor
        function obj = PA_Dataset(rat_list, groups, stage_list, data_path, varargin)
            %Handle optional parameters
            p = inputParser;
            p.CaseSensitive = false;
            
            defaultStageTransforms = [];
            defaultIsSustainedPull = 0;
            defaultTrashHeavyData = 1;
            defaultOnlyAnalyzeBasicData = 0;
            defaultVerboseOutput = 0;
            defaultCreatePullObjects = 1;
            defaultDoPowerAnalysis = 1;
            defaultLoadDatesAfter = [];
            defaultTrashDaysWithLessThanNTrials = 10;
            addOptional(p, 'StageTransforms', defaultStageTransforms);
            addOptional(p, 'IsSustainedPull', defaultIsSustainedPull, @isnumeric);
            addOptional(p, 'TrashHeavyData', defaultTrashHeavyData, @isnumeric);
            addOptional(p, 'OnlyAnalyzeBasicData', defaultOnlyAnalyzeBasicData, @isnumeric);
            addOptional(p, 'VerboseOutput', defaultVerboseOutput, @isnumeric);
            addOptional(p, 'CreatePullObjects', defaultCreatePullObjects, @isnumeric);
            addOptional(p, 'DoPowerAnalysis', defaultDoPowerAnalysis, @isnumeric);
            addOptional(p, 'LoadDatesAfter', defaultLoadDatesAfter);
            addOptional(p, 'TrashDaysWithLessThanNTrials', defaultTrashDaysWithLessThanNTrials, @isnumeric);
            parse(p, varargin{:});
            stage_transforms = p.Results.StageTransforms;
            is_sustained_pull = p.Results.IsSustainedPull;
            trash_heavy_data = p.Results.TrashHeavyData;
            only_analyze_basic_data = p.Results.OnlyAnalyzeBasicData;
            verbose_output = p.Results.VerboseOutput;
            create_pull_objects = p.Results.CreatePullObjects;
            do_power_analysis = p.Results.DoPowerAnalysis;
            load_dates_after = p.Results.LoadDatesAfter;
            trial_count_trash = p.Results.TrashDaysWithLessThanNTrials;
            
            %Load in all of the rats.
            rats = [];
            for r = 1:length(rat_list)
                disp(['Loading ' rat_list{r} '...']);
                
                if (~isempty(load_dates_after))
                    lda = load_dates_after(r);
                else
                    lda = [];
                end
                
                data = TBI_ReadRawData(rat_list(r), groups(r), stage_list, data_path, verbose_output, ...
                    'LoadDatesAfter', lda);
                data2 = MotoTrak_ReadRawData(rat_list(r), groups(r), stage_list, data_path, verbose_output, 'LoadDatesAfter', lda);
                if (isempty(data) && ~isempty(data2))
                    data = data2;
                else
                    if (~isempty(data) && ~isempty(data2))
                        data.session = [data.session data2.session];
                    end
                end
                
                if (length(data) > 1)
                    for i = 2:length(data)
                        data(1).session = [data(1).session data(i).session];
                    end
                    data(2:end) = [];
                end
                
                disp('Analyzing data...');
                if (~isempty(data))
                    new_rat = PA_Rat(rat_list{r}, groups(r), data.session, 'IsSustainedPull', is_sustained_pull, 'StageShortening', 1, ...
                        'StageTransforms', stage_transforms, 'TrashHeavyDataWithinPullsAndTrials', trash_heavy_data, 'OnlyAnalyzeBasicData', only_analyze_basic_data, ...
                        'CreatePullObjects', create_pull_objects, 'DoPowerAnalysis', do_power_analysis, ...
                        'TrashDaysWithLessThanNTrials', trial_count_trash);
                    rats = [rats new_rat];
                end
            end
            
            %Assign the rats to the dataset.
            obj.Rats = rats;
        end
        
        %Methods
        function PlotData (obj, varargin)
            %Handle optional parameters
            p = inputParser;
            p.CaseSensitive = false;
            defaultParameter = 'MaximalForceMean';
            addOptional(p, 'Parameter', defaultParameter);
            parse(p, varargin{:});
            parameter = p.Results.Parameter;
            
            %Grab the data
            data = [];
            for r = 1:length(obj.Rats)
               pre = obj.Rats(r).RetrieveData('Stage', 'pre', 'Parameter', parameter, 'NumberOfDays', 10, 'FromMostRecent', 1, 'DivideIntoEpochs', 1, ...
                   'DaysPerEpoch', 5, 'RightJustifyResult', 1);
               post = obj.Rats(r).RetrieveData('Stage', 'post', 'Parameter', parameter, 'NumberOfDays', 30, 'FromMostRecent', 0, 'DivideIntoEpochs', 1, ...
                   'DaysPerEpoch', 5);
               rat_data = [pre post];
               data = [data; rat_data];
            end
            
            %Take the mean and find the CI
            mean_data = nanmean(data, 1);
            sem_data = simple_ci(data);
            
            errorbar(1:length(mean_data), mean_data, sem_data, sem_data);
        end
    end
    
end







