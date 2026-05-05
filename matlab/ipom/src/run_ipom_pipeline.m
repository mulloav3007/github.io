%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% run_ipom_pipeline.m
%
% Wrapper mínimo para ordenar el flujo IPoM/IRIS desde el repositorio Quarto.
%
% Este archivo NO reemplaza tus scripts originales. Su objetivo es darte un
% punto de entrada estable para ejecutar el bloque Matlab y dejar outputs en:
%   matlab/ipom/outputs/
%
% Flujo sugerido:
%   1. Ajustar paths de IRIS Toolbox si corresponde.
%   2. Ejecutar identificación del baseline IPoM.
%   3. Ejecutar escenarios alternativos.
%   4. Guardar CSV compatibles con scripts/03_build_ipom_outputs.R.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; close all; clc;

thisFile = mfilename('fullpath');
srcDir   = fileparts(thisFile);
ipomDir  = fileparts(srcDir);
repoDir  = fileparts(fileparts(ipomDir));
modelDir = fullfile(ipomDir, 'model');
outDir   = fullfile(ipomDir, 'outputs');

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

addpath(srcDir);
addpath(modelDir);
cd(srcDir);

fprintf('Repositorio: %s\n', repoDir);
fprintf('IPoM dir:    %s\n', ipomDir);
fprintf('Model dir:   %s\n', modelDir);
fprintf('Output dir:  %s\n', outDir);

% -------------------------------------------------------------------------
% 1. IRIS Toolbox
% -------------------------------------------------------------------------
% Si IRIS no está cargado globalmente, descomenta y edita esta línea:
% addpath('C:\ruta\a\iris-toolbox');
% iris.startup;

% -------------------------------------------------------------------------
% 2. Copiar modelo al directorio src durante la ejecución
% -------------------------------------------------------------------------
% Tus scripts originales llaman minimep0.model desde el working directory.
% Para no reescribirlos por completo, copiamos temporalmente el archivo.
copyfile(fullfile(modelDir, 'minimep0.model'), fullfile(srcDir, 'minimep0.model'));

% -------------------------------------------------------------------------
% 3. Ejecutar scripts originales si están preparados para correr localmente
% -------------------------------------------------------------------------
% Estos scripts fueron preservados con sufijo _original.m para evitar
% sobrescribir tu trabajo. Puedes renombrarlos o adaptar las llamadas.
%
% Ejemplo de flujo posible:
% run('identificar_shocks_ipom_original.m');
% run('fcast_alt_ipom_original.m');
%
% Por defecto no se ejecutan automáticamente porque tus scripts originales
% pueden depender de archivos locales y decisiones manuales de escenario.

fprintf('\nWrapper listo. Edita run_ipom_pipeline.m para activar tu flujo exacto.\n');
fprintf('Luego exporta CSV a matlab/ipom/outputs y ejecuta scripts/03_build_ipom_outputs.R.\n');
