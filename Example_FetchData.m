function data = Example_FetchData( )

	%% This code is only an example, and it will not work if you do not have the actual data files to load in.
	%% If you have MotoTrak, replace the following lines with the animal id's and groups from your own experiments, 
	%% and then then run this code.

    %% First, specify the animal id's that you would like to load the data for
    rat_list = { 'KAMP61', 'KAMP69', 'KAMP65', 'KAMP70', 'KAMP62', ...
        'KAMP67', 'KAMP72', 'KAMP73', 'KAMP76', 'KAMP75', ...
        'KAMP86', 'KAMP95', 'KAMP85', 'KAMP82', 'KAMP97', ...
        'KAMP90', 'KAMP71', 'KAMP78', 'KAMP96', 'KAMP102'};
	
	% Next, specify a "group id" - basically just indicates which experimental group each animal is in
    vns_list = [1 5 3 4 5 ...
        4 2 5 2 5 ...
        1 5 1 3 5 ...
        6 6 6 6 6];
		
	% Specify which stages we would like to load
    stage_list = {'KTrain', 'KPost', 'KTherapy', 'KTherapyStim'};
    
	% Specify the root path where all of the data can be found for each animal
    data_path = 'Z:\Navid_Behavior_Data\';
    
	%Display a start time (indicating when the process of loading the data begins)
    disp(datestr(now));

	%Load the data itself
    data = PA_Dataset(rat_list, vns_list, stage_list, data_path, 'IsSustainedPull', 0, 'OnlyAnalyzeBasicData', 0, ...
        'CreatePullObjects', 0, 'DoPowerAnalysis', 0, 'TrashDaysWithLessThanNTrials', 10);

	%Display an end time
    disp(datestr(now));

end

