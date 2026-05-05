%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 02_alternativa_escenario_simple.m
%
%% Regla operativa:
%% - Variables en 100*log(nivel): usar multiplicadores.
%   Ejemplo:
%      L_WTI_alt = L_WTI_base + 100*log(wti_mult)
%
%% - Variables en nivel, tasas, brechas o inflación: usar aditivos.
%   Ejemplo:
%      VIX_alt = VIX_base + vix_add
%
%% Punto clave:
%% - Multiplicador = 1  => no se impone la variable en ese período.
% - Aditivo = 0        => no se impone la variable en ese período.
%% - Si pones un shock solo en 2026Q3, solo se exogeniza 2026Q3.
% - Los períodos siguientes quedan endógenos y los resuelve el modelo.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

close all;
clear all;
clc;

%% ============================================================
%% 0. Configuración principal
%% ============================================================

baselineFile = 'fcast_ipom_exact.csv';
outputFile   = 'fcast_alt_escenario.csv';

startfcast_alt = qq(2026,1);
endfcast       = qq(2027,4);

bufferPeriods  = 8;
fcastrange     = startfcast_alt:(endfcast + bufferPeriods);

altRange       = startfcast_alt:endfcast;
nAlt           = length(altRange);

Plotrng        = qq(2025,1):endfcast;
Tablerng       = qq(2025,1):endfcast;
ObsRng         = qq(2025,1):qq(2025,4);
AltRng         = altRange;

altname        = 'Alternative Scenario';
country        = 'Chile';
exchange       = 'CHL/USA';

reportName     = 'AlternativeScenario_Short';
runReport      = true;

fprintf('\n============================================================\n');
fprintf('Escenario alternativo\n');
fprintf('Rango alternativo: %s a %s\n', ...
    local_dat2char(startfcast_alt), local_dat2char(endfcast));
fprintf('============================================================\n\n');


%% ============================================================
%% 1. Cargar modelo y baseline IPOM exacto
% ============================================================

[m,p,mss] = readmodel_alternativo(false);

if exist(baselineFile,'file') ~= 2
    error('No existe %s. Primero corre 01_identificar_shocks_ipom.m', baselineFile);
end

h = dbload(baselineFile);

% Copia de trabajo. Mantiene todos los shocks y juicios del baseline.
d = h;


%% ============================================================
%% 2. BLOQUE DE MANIPULACIÓN DEL ESCENARIO
% ============================================================
%   one_path  para multiplicadores neutros.
%   zero_path para aditivos neutros.
% Para shock puntual:
%   pcu_mult_path = local_set_path(pcu_mult_path, altRange, qq(2026,3), 1.10);
% Para shock de varios trimestres:
%   vix_add_path = local_set_path(vix_add_path, altRange, qq(2026,2):qq(2026,4), [5 3 1]);
% Si una variable queda en 1 o 0 en todos los períodos, NO se exogeniza.

one_path  = ones(1, nAlt);
zero_path = zeros(1, nAlt);

% ------------------------------------------------------------
%% 2.1 Multiplicadores: variables en 100*log(nivel)
% ------------------------------------------------------------

wti_mult_path      = one_path;   % L_WTI
pcu_mult_path      = one_path;   % L_PCU
lz_mult_path       = one_path;   % L_Z

lcpi_mult_path     = one_path;   % L_CPI
lcpixfe_mult_path  = one_path;   % L_CPIXFE
lcpif_mult_path    = one_path;   % L_CPIF, si existe
lcpie_mult_path    = one_path;   % L_CPIE, si existe

lgdp_mult_path     = one_path;   % L_GDP, si existe
lgdp_bar_mult_path = one_path;   % L_GDP_BAR, si existe


%% ------------------------------------------------------------
%% 2.2 Aditivos: niveles, tasas, brechas e inflación
%% ------------------------------------------------------------

vix_add_path       = zero_path;  % VIX
ffr_add_path       = zero_path;  % FFR
ust10_add_path     = zero_path;  % UST10
crec_add_path      = zero_path;  % CRECSC

gap_add_path       = zero_path;  % L_GDP_GAP
tpm_add_path       = zero_path;  % TPM
rs_unc_add_path    = zero_path;  % RS_UNC

dla_cpi_add_path    = zero_path; % DLA_CPI
dla_cpixfe_add_path = zero_path; % DLA_CPIXFE
dla_cpires_add_path = zero_path; % DLA_CPIRES

d4lcpi_add_path     = zero_path; % D4L_CPI, si existe shock
d4lcpixfe_add_path  = zero_path; % D4L_CPIXFE, si existe shock
d4lcpi_tar_add_path = zero_path; % D4L_CPI_TAR


% ------------------------------------------------------------
%% 2.3 Ejemplo de escenario: editar aquí
% ------------------------------------------------------------
% Esta es la única parte que normalmente deberías tocar.
% Este ejemplo reproduce tu lógica 
% Para apagar un bloque, coméntalo o déjalo en one_path/zero_path.

wti_mult_path = local_set_path( ...
    wti_mult_path, altRange, ...
    qq(2027,1):qq(2027,4), ...
    [0.97 0.94 0.90 0.85] ...
);

pcu_mult_path = local_set_path(pcu_mult_path, altRange, qq(2026,3), 1.15);

vix_add_path = local_set_path( ...
    vix_add_path, altRange, ...
    qq(2026,3):qq(2027,4), ...
    [-0.50 -1.00 -2.00 -2.00 -1.50 -1.00] ...
);

lz_mult_path = local_set_path( ...
    lz_mult_path, altRange, ...
    qq(2026,3):qq(2027,4), ...
    [0.997 0.995 0.997 0.999 1.000 1.000] ...
);


% Ejemplos alternativos:
%
% Shock puntual al cobre en 2026Q3:
% pcu_mult_path = one_path;
% pcu_mult_path = local_set_path(pcu_mult_path, altRange, qq(2026,3), 1.10);
%
% Shock puntual al gap en 2026Q2:
% gap_add_path = zero_path;
% gap_add_path = local_set_path(gap_add_path, altRange, qq(2026,2), -0.50);
%
% Shock de TPM en tres trimestres:
% tpm_add_path = zero_path;
% tpm_add_path = local_set_path(tpm_add_path, altRange, qq(2026,2):qq(2026,4), [-0.25 -0.25 -0.25]);


%% ============================================================
%% 3. Catálogo de variables del escenario
%% ============================================================
%
% Formato:
%   variable, shock, tipo, path
%
% tipo = 'mult' para variables en 100*log(.)
% tipo = 'add'  para variables en niveles/tasas/brechas/inflación

catalog = cell(0,4);

% Multiplicadores
catalog = local_add_to_catalog(catalog, 'L_WTI',     'SHK_L_WTI',     'mult', wti_mult_path);
catalog = local_add_to_catalog(catalog, 'L_PCU',     'SHK_L_PCU',     'mult', pcu_mult_path);
catalog = local_add_to_catalog(catalog, 'L_Z',       'SHK_L_Z',       'mult', lz_mult_path);

catalog = local_add_to_catalog(catalog, 'L_CPI',     'SHK_L_CPI',     'mult', lcpi_mult_path);
catalog = local_add_to_catalog(catalog, 'L_CPIXFE',  'SHK_L_CPIXFE',  'mult', lcpixfe_mult_path);
catalog = local_add_to_catalog(catalog, 'L_CPIF',    'SHK_L_CPIF',    'mult', lcpif_mult_path);
catalog = local_add_to_catalog(catalog, 'L_CPIE',    'SHK_L_CPIE',    'mult', lcpie_mult_path);

catalog = local_add_to_catalog(catalog, 'L_GDP',     'SHK_L_GDP',     'mult', lgdp_mult_path);
catalog = local_add_to_catalog(catalog, 'L_GDP_BAR', 'SHK_L_GDP_BAR', 'mult', lgdp_bar_mult_path);

% Aditivos externos/financieros
catalog = local_add_to_catalog(catalog, 'VIX',       'SHK_VIX',       'add', vix_add_path);
catalog = local_add_to_catalog(catalog, 'FFR',       'SHK_FFR',       'add', ffr_add_path);
catalog = local_add_to_catalog(catalog, 'UST10',     'SHK_UST10',     'add', ust10_add_path);
catalog = local_add_to_catalog(catalog, 'CRECSC',    'SHK_CRECSC',    'add', crec_add_path);

% Aditivos domésticos
catalog = local_add_to_catalog(catalog, 'L_GDP_GAP', 'SHK_L_GDP_GAP', 'add', gap_add_path);
catalog = local_add_to_catalog(catalog, 'TPM',       'SHK_TPM',       'add', tpm_add_path);
catalog = local_add_to_catalog(catalog, 'RS_UNC',    'SHK_RS_UNC',    'add', rs_unc_add_path);

catalog = local_add_to_catalog(catalog, 'DLA_CPI',     'SHK_DLA_CPI',     'add', dla_cpi_add_path);
catalog = local_add_to_catalog(catalog, 'DLA_CPIXFE',  'SHK_DLA_CPIXFE',  'add', dla_cpixfe_add_path);
catalog = local_add_to_catalog(catalog, 'DLA_CPIRES',  'SHK_DLA_CPIRES',  'add', dla_cpires_add_path);

catalog = local_add_to_catalog(catalog, 'D4L_CPI',     'SHK_D4L_CPI',     'add', d4lcpi_add_path);
catalog = local_add_to_catalog(catalog, 'D4L_CPIXFE',  'SHK_D4L_CPIXFE',  'add', d4lcpixfe_add_path);
catalog = local_add_to_catalog(catalog, 'D4L_CPI_TAR', 'SHK_D4L_CPI_TAR', 'add', d4lcpi_tar_add_path);


%% ============================================================
%% 4. Aplicar escenario y construir plan
%% ============================================================

[d, planItems] = local_apply_scenario(h, d, catalog, altRange);

% Mantener CPI_US_2020 del baseline si existe
if isfield(h,'CPI_US_2020')
    d.CPI_US_2020(altRange) = h.CPI_US_2020(altRange);
end

simplan = local_build_plan(m, fcastrange, planItems);


%% ============================================================
%% 5. Simular escenario alternativo
%% ============================================================

fprintf('\nSimulando escenario alternativo...\n');

s_alt = simulate(m, d, fcastrange, ...
    'plan',       simplan, ...
    'method',     'selective', ...
    'nonlinPer',  30, ...
    'anticipate', false);

d_alt = dbextend(d, s_alt);


%% ============================================================
%% 6. Variables derivadas
%% ============================================================

h     = local_add_derived_variables(h);
d_alt = local_add_derived_variables(d_alt);


%% ============================================================
%% 7. Guardar resultado
%% ============================================================

dbsave(d_alt, outputFile);

fprintf('\nEscenario alternativo guardado en:\n');
fprintf(' - %s\n', outputFile);


%% ============================================================
%% 8. Diagnóstico
%% ============================================================

diagVars = { ...
    'D4L_CPI', ...
    'D4L_CPIXFE', ...
    'DLA_CPI', ...
    'DLA_CPIXFE', ...
    'DLA_CPIRES', ...
    'L_CPI', ...
    'L_CPIXFE', ...
    'L_GDP_GAP', ...
    'L_GDP', ...
    'L_GDP_BAR', ...
    'TPM', ...
    'RS_UNC', ...
    'L_WTI', ...
    'L_PCU', ...
    'L_Z', ...
    'VIX', ...
    'FFR', ...
    'UST10', ...
    'CRECSC' ...
};

local_print_diagnostics(h, d_alt, altRange, diagVars);


%% ============================================================
%% 9. Reporte
%% ============================================================

if runReport
    local_make_report( ...
        h, d_alt, planItems, ...
        country, altname, exchange, reportName, ...
        Plotrng, Tablerng, ObsRng, AltRng ...
    );
end

fprintf('\nDone: escenario alternativo.\n');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% FUNCIONES LOCALES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function catalog = local_add_to_catalog(catalog, varName, shockName, typeName, path)
    catalog(end+1,:) = {varName, shockName, typeName, reshape(path, [], 1)};
end


function path = local_set_path(path, fullRange, dates, values)

    path  = reshape(path, 1, []);
    dates = reshape(dates, 1, []);

    if isscalar(values)
        values = repmat(values, 1, numel(dates));
    else
        values = reshape(values, 1, []);
    end

    if numel(values) ~= numel(dates)
        error('local_set_path: largo de values debe coincidir con largo de dates.');
    end

    for k = 1:numel(dates)
        idx = find(fullRange == dates(k), 1);

        if isempty(idx)
            error('local_set_path: la fecha %s no está dentro de altRange.', local_dat2char(dates(k)));
        end

        path(idx) = values(k);
    end
end


function out = local_take_path(path, n)

    path = reshape(path, [], 1);

    if isempty(path)
        error('local_take_path: path vacío.');
    end

    if length(path) >= n
        out = path(1:n);
    else
        out = [path; repmat(path(end), n - length(path), 1)];
    end
end


function [d, planItems] = local_apply_scenario(h, d, catalog, altRange)

    tolNeutral = 1e-12;
    nAlt       = length(altRange);

    planItems = struct('var', {}, 'shock', {}, 'dates', {}, 'type', {});

    fprintf('\n============================================================\n');
    fprintf('Aplicando escenario\n');
    fprintf('============================================================\n');

    for i = 1:size(catalog,1)

        v  = catalog{i,1};
        sh = catalog{i,2};
        tp = lower(catalog{i,3});
        pp = local_take_path(catalog{i,4}, nAlt);

        if ~isfield(h, v)
            fprintf('[OMITIDO] %-14s no existe en baseline.\n', v);
            continue
        end

        switch tp
            case 'mult'
                activeIdx = find(abs(pp - 1) > tolNeutral);

            case 'add'
                activeIdx = find(abs(pp) > tolNeutral);

            otherwise
                error('Tipo no reconocido para %s: %s', v, tp);
        end

        if isempty(activeIdx)
            fprintf('[NEUTRO]  %-14s queda endógena.\n', v);
            continue
        end

        if ~(isfield(h, sh) || isfield(d, sh))
            fprintf('[AVISO]   %-14s tiene path activo, pero no encuentro shock %-18s. No se impone.\n', v, sh);
            continue
        end

        activeDates = altRange(activeIdx);
        base_v      = h.(v)(activeDates);

        switch tp
            case 'mult'
                delta = 100 * log(pp(activeIdx));

            case 'add'
                delta = pp(activeIdx);
        end

        delta = reshape(delta, size(base_v));

        d.(v)(activeDates) = base_v + delta;

        planItems(end+1).var   = v;           %#ok<AGROW>
        planItems(end).shock   = sh;
        planItems(end).dates   = activeDates;
        planItems(end).type    = tp;

        fprintf('[ACTIVO]  %-14s con %-18s | %s a %s | n = %d\n', ...
            v, sh, local_dat2char(activeDates(1)), ...
            local_dat2char(activeDates(end)), length(activeDates));
    end
end


function simplan = local_build_plan(m, fcastrange, planItems)

    simplan = plan(m, fcastrange);

    fprintf('\n============================================================\n');
    fprintf('Plan de simulación\n');
    fprintf('============================================================\n');

    if isempty(planItems)
        warning('No hay variables exogenizadas. El escenario será igual al baseline salvo cambios externos ya cargados.');
        return
    end

    for i = 1:numel(planItems)

        v  = planItems(i).var;
        sh = planItems(i).shock;
        rr = planItems(i).dates;

        fprintf('Exogenize %-14s | Endogenize %-18s | %s a %s | n = %d\n', ...
            v, sh, local_dat2char(rr(1)), local_dat2char(rr(end)), length(rr));

        simplan = exogenize(simplan, v,  rr);
        simplan = endogenize(simplan, sh, rr);
    end
end


function local_print_diagnostics(h, d_alt, altRange, diagVars)

    fprintf('\n============================================================\n');
    fprintf('Diferencias Alt - Baseline en rango alternativo\n');
    fprintf('============================================================\n');

    for i = 1:numel(diagVars)

        v = diagVars{i};

        if ~(isfield(h, v) && isfield(d_alt, v))
            continue
        end

        try
            diffv = d_alt.(v)(altRange) - h.(v)(altRange);
            diffv = diffv(~isnan(diffv));

            if isempty(diffv)
                continue
            end

            fprintf('%-14s | mean diff = %+9.4f | max abs diff = %+9.4f\n', ...
                v, mean(diffv), max(abs(diffv)));
        catch
        end
    end
end


function db = local_add_derived_variables(db)

    if isfield(db,'CPI_US_2020')

        if isfield(db,'L_PCU')
            db.L_PCU_NOM = exp(db.L_PCU/100) .* db.CPI_US_2020/100;
        end

        if isfield(db,'L_WTI')
            db.L_WTI_NOM = exp(db.L_WTI/100) .* db.CPI_US_2020/100;
        end

    else

        if isfield(db,'L_PCU')
            db.L_PCU_NOM = exp(db.L_PCU/100);
        end

        if isfield(db,'L_WTI')
            db.L_WTI_NOM = exp(db.L_WTI/100);
        end
    end

    if isfield(db,'L_Z')
        db.L_Z_INDEX = exp(db.L_Z/100);
    end

    if isfield(db,'D4L_CPI') && isfield(db,'D4L_CPIXFE')
        db.D4L_CPI_GAP_XFE = db.D4L_CPI - db.D4L_CPIXFE;
    end
end


function local_make_report(h, d_alt, planItems, country, altname, exchange, reportName, Plotrng, Tablerng, ObsRng, AltRng)

    x = report.new(country);

    sty = struct();
    sty.line.linewidth         = 1.5;
    sty.line.linestyle         = {'-';'--'};
    sty.axes.box               = 'on';
    sty.legend.location        = 'Best';
    sty.axes.yticklabelformat  = '%.1f';


    %% ========================================================
    %% Figura principal
    %% ========================================================

    x.figure([altname ' - Main Indicators'], ...
        'subplot', [3,2], ...
        'style', sty, ...
        'range', Plotrng, ...
        'dateformat', 'YYYY:P');

    local_graph_two(x, 'Policy Rate, % p.a.', ...
        {'Baseline IPOM','Alternative'}, h, d_alt, 'TPM', ObsRng, AltRng);

    local_graph_two(x, 'Output Gap, %', ...
        {'Baseline IPOM','Alternative'}, h, d_alt, 'L_GDP_GAP', ObsRng, AltRng);

    local_graph_two(x, 'Headline Inflation, % YoY', ...
        {'Baseline IPOM','Alternative'}, h, d_alt, 'D4L_CPI', ObsRng, AltRng);

    local_graph_two(x, 'Core Inflation, % YoY', ...
        {'Baseline IPOM','Alternative'}, h, d_alt, 'D4L_CPIXFE', ObsRng, AltRng);

    local_graph_two(x, 'Oil Price, USD per barrel', ...
        {'Baseline IPOM','Alternative'}, h, d_alt, 'L_WTI_NOM', ObsRng, AltRng);

    local_graph_two(x, ['Real Exchange Rate Index - ' exchange], ...
        {'Baseline IPOM','Alternative'}, h, d_alt, 'L_Z_INDEX', ObsRng, AltRng);

    x.pagebreak();


    %% ========================================================
    %% Inflación doméstica
    %% ========================================================

    x.figure([altname ' - Inflation Details'], ...
        'subplot', [2,2], ...
        'style', sty, ...
        'range', Plotrng, ...
        'dateformat', 'YYYY:P');

    if local_has_fields(h, d_alt, {'DLA_CPI','D4L_CPI'})
        x.graph('Headline Inflation, % QoQ annualized and YoY', 'legend', true);
        x.series({'QoQ Base','YoY Base','QoQ Alt','YoY Alt'}, ...
            [h.DLA_CPI, h.D4L_CPI, d_alt.DLA_CPI, d_alt.D4L_CPI]);
        x.highlight('', ObsRng);
        x.highlight('', AltRng);
    end

    if local_has_fields(h, d_alt, {'DLA_CPIXFE','D4L_CPIXFE'})
        x.graph('Core Inflation, % QoQ annualized and YoY', 'legend', true);
        x.series({'QoQ Base','YoY Base','QoQ Alt','YoY Alt'}, ...
            [h.DLA_CPIXFE, h.D4L_CPIXFE, d_alt.DLA_CPIXFE, d_alt.D4L_CPIXFE]);
        x.highlight('', ObsRng);
        x.highlight('', AltRng);
    end

    local_graph_two(x, 'Residual Inflation DLA\_CPIRES, % QoQ annualized', ...
        {'Baseline IPOM','Alternative'}, h, d_alt, 'DLA_CPIRES', ObsRng, AltRng);

    local_graph_two(x, 'Headline-Core Gap, pp YoY', ...
        {'Baseline IPOM','Alternative'}, h, d_alt, 'D4L_CPI_GAP_XFE', ObsRng, AltRng);

    x.pagebreak();


    %% ========================================================
    %% Bloque externo
    %% ========================================================

    x.figure([altname ' - External Block'], ...
        'subplot', [3,2], ...
        'style', sty, ...
        'range', Plotrng, ...
        'dateformat', 'YYYY:P');

    local_graph_two(x, 'Oil Price, USD per barrel', ...
        {'Baseline IPOM','Alternative'}, h, d_alt, 'L_WTI_NOM', ObsRng, AltRng);

    local_graph_two(x, 'Copper Price, USD per lb', ...
        {'Baseline IPOM','Alternative'}, h, d_alt, 'L_PCU_NOM', ObsRng, AltRng);

    local_graph_two(x, 'Foreign Output Growth, %', ...
        {'Baseline IPOM','Alternative'}, h, d_alt, 'CRECSC', ObsRng, AltRng);

    local_graph_two(x, 'Federal Funds Rate, %', ...
        {'Baseline IPOM','Alternative'}, h, d_alt, 'FFR', ObsRng, AltRng);

    local_graph_two(x, 'UST 10Y, %', ...
        {'Baseline IPOM','Alternative'}, h, d_alt, 'UST10', ObsRng, AltRng);

    local_graph_two(x, 'VIX', ...
        {'Baseline IPOM','Alternative'}, h, d_alt, 'VIX', ObsRng, AltRng);

    x.pagebreak();


    %% ========================================================
    %% Shocks efectivamente activados
    %% ========================================================

    if ~isempty(planItems)

        shockNames = unique({planItems.shock}, 'stable');
        nShock     = min(numel(shockNames), 6);

        x.figure([altname ' - Active Shocks'], ...
            'subplot', [ceil(nShock/2), 2], ...
            'style', sty, ...
            'range', AltRng, ...
            'dateformat', 'YYYY:P');

        for i = 1:nShock
            sh = shockNames{i};

            if isfield(h, sh) && isfield(d_alt, sh)
                graphTitle = strrep(sh, '_', '\_');
                x.graph(graphTitle, 'legend', true);
                x.series({'Baseline','Alternative'}, [h.(sh), d_alt.(sh)]);
            end
        end

        x.pagebreak();
    end


    %% ========================================================
    %% Tabla resumen
    %% ========================================================

    TableOptions = {'range', Tablerng, ...
                    'vline', qq(2025,4), ...
                    'decimal', 2, ...
                    'dateformat', 'YYYY:P', ...
                    'long', true, ...
                    'longfoot', '---continued', ...
                    'longfootposition', 'right'};

    x.table([altname ' - Summary Table'], TableOptions{:});

    x.subheading('Inflation');

    local_table_two(x, h, d_alt, 'D4L_CPI',    'Headline CPI YoY', '%');
    local_table_two(x, h, d_alt, 'D4L_CPIXFE', 'Core CPI YoY', '%');
    local_table_two(x, h, d_alt, 'D4L_CPI_GAP_XFE', 'Headline-Core Gap YoY', 'pp');

    x.subheading('Activity and Monetary Policy');

    local_table_two(x, h, d_alt, 'L_GDP_GAP', 'Output Gap', '%');
    local_table_two(x, h, d_alt, 'TPM',       'Policy Rate', '%');

    x.subheading('External Assumptions and Financial Conditions');

    local_table_two(x, h, d_alt, 'L_WTI_NOM', 'Oil Price', 'USD/bbl');
    local_table_two(x, h, d_alt, 'L_PCU_NOM', 'Copper Price', 'USD/lb');
    local_table_two(x, h, d_alt, 'CRECSC',    'Foreign Growth', '%');
    local_table_two(x, h, d_alt, 'FFR',       'FFR', '%');
    local_table_two(x, h, d_alt, 'UST10',     'UST10', '%');
    local_table_two(x, h, d_alt, 'VIX',       'VIX', '');

    x.publish(reportName, 'display', false);

    fprintf('\nReporte generado: %s.pdf\n', reportName);
end


function local_graph_two(x, graphTitle, legendNames, h, d_alt, varName, ObsRng, AltRng)

    if ~(isfield(h, varName) && isfield(d_alt, varName))
        x.graph([graphTitle ' - missing'], 'legend', false);
        return
    end

    x.graph(graphTitle, 'legend', true);
    x.series(legendNames, [h.(varName), d_alt.(varName)]);
    x.highlight('', ObsRng);
    x.highlight('', AltRng);
end


function local_table_two(x, h, d_alt, varName, label, units)

    if ~(isfield(h, varName) && isfield(d_alt, varName))
        return
    end

    x.series([label ' - Baseline'],    h.(varName),     'units', units);
    x.series([label ' - Alternative'], d_alt.(varName), 'units', units);
end


function tf = local_has_fields(h, d_alt, vars)

    tf = true;

    for i = 1:numel(vars)
        v = vars{i};

        if ~(isfield(h, v) && isfield(d_alt, v))
            tf = false;
            return
        end
    end
end


function s = local_dat2char(d)

    s = dat2str(d);

    if iscell(s)
        s = s{1};
    end

    if isstring(s)
        s = char(s);
    end
end