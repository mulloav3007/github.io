%**************
% Czech Republic
%**************

close all;
clear all;

%% Load model to take parameters
[m,p,mss] = readmodel_alternativo(false);

%% Load quarterly data
% Command 'dbdload' loads the data from the 'csv' file (save from Excel as
% .csv in the current directory). All the data are now available in the
% database 'd' 
d = dbload('Data.csv');

%% Seasonal adjustment


%% Growth rate qoq, yoy
exceptions = {''};

list = dbnames(d);

for i = 1:length(list)
    if isempty(strmatch(list{i}, exceptions,'exact'))
        if length(list{i})>1
            if strcmp('L_', list{i}(1:2))
                d.(['DLA_' list{i}(3:end)])  = 4*(d.(list{i}) - d.(list{i}){-1});
                d.(['D4L_' list{i}(3:end)]) = d.(list{i}) - d.(list{i}){-4};
            end
        end
    end
end


d.DLA_CPIRES = d.DLA_CPI-d.DLA_CPIXFE;


%% Save the database
% Database is saved in file 'history.csv'
dbsave(d,'history.csv');

