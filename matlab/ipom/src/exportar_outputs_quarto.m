%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% exportar_outputs_quarto.m
%
% Helper simple para guardar bases IRIS en la carpeta esperada por Quarto.
%
% Uso dentro de Matlab después de simular:
%   exportar_outputs_quarto(h, 'fcast_ipom_exact.csv');
%   exportar_outputs_quarto(d_alt, 'fcast_alt_iran_fin_anticipado.csv');
%
% Luego, desde R:
%   Rscript scripts/03_build_ipom_outputs.R
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function exportar_outputs_quarto(db, fileName)
    if nargin < 2
        error('Debes entregar una base IRIS y un nombre de archivo CSV.');
    end

    thisFile = mfilename('fullpath');
    srcDir   = fileparts(thisFile);
    ipomDir  = fileparts(srcDir);
    outDir   = fullfile(ipomDir, 'outputs');

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    outPath = fullfile(outDir, fileName);
    dbsave(db, outPath);
    fprintf('Output guardado para Quarto: %s\n', outPath);
end
