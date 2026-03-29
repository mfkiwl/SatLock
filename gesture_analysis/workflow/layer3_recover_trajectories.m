function trajectory = layer3_recover_trajectories(parsed, attacked, cfg)
% LAYER3_RECOVER_TRAJECTORIES
% Recover trajectories from each case and keep both blind/core and
% gallery-facing results.

n_case = numel(attacked.cases);
core_cases = repmat(empty_output_case_local(), n_case, 1);
gallery_cases = repmat(empty_output_case_local(), n_case, 1);
summary_rows = repmat(struct( ...
    'case_id', "", ...
    'true_label', "", ...
    'attack_applied', false, ...
    'attack_mode', "", ...
    'gallery_rmse_m', NaN, ...
    'gallery_mte_m', NaN, ...
    'gallery_dtw_m', NaN, ...
    'gallery_coverage', NaN, ...
    'num_visible_sats', NaN, ...
    'core_status', "", ...
    'gallery_status', ""), n_case, 1);

for i = 1:n_case
    inject_case = attacked.cases(i);
    [~, step1_res, obs_waveform, step1_res_shaped] = run_preprocess_pipeline(inject_case.obs_case);
    t_grid = resolve_t_grid_local(step1_res, step1_res_shaped);

    [ref_x, ref_y, ref_pen, ref_label] = build_reference_template_local( ...
        inject_case.reference_label, numel(t_grid), cfg.span_cfg);

    core_cfg = build_core_cfg_local(cfg.data_cfg);
    gallery_cfg = build_gallery_cfg_local(cfg.data_cfg, inject_case.true_label, resolve_attack_flag_local(inject_case));

    core_case = run_data_case_local(obs_waveform, parsed.nav_data, step1_res_shaped, ...
        t_grid, ref_x, ref_y, ref_pen, ref_label, core_cfg, "core");
    gallery_case = run_data_case_local(obs_waveform, parsed.nav_data, step1_res_shaped, ...
        t_grid, ref_x, ref_y, ref_pen, ref_label, gallery_cfg, "gallery");

    core_case.case_id = inject_case.case_id;
    core_case.true_label = string(inject_case.true_label);
    core_case.source_mode = string(inject_case.source_mode);
    core_case.attack_applied = logical(resolve_attack_flag_local(inject_case));
    core_case.attack_mode = string(resolve_attack_mode_local(inject_case));
    core_case.attack_notes = string(resolve_attack_notes_local(inject_case));
    core_case.num_visible_sats = numel(step1_res_shaped.valid_sats);

    gallery_case.case_id = inject_case.case_id;
    gallery_case.true_label = string(inject_case.true_label);
    gallery_case.source_mode = string(inject_case.source_mode);
    gallery_case.attack_applied = logical(resolve_attack_flag_local(inject_case));
    gallery_case.attack_mode = string(resolve_attack_mode_local(inject_case));
    gallery_case.attack_notes = string(resolve_attack_notes_local(inject_case));
    gallery_case.num_visible_sats = numel(step1_res_shaped.valid_sats);

    core_cases(i) = core_case;
    gallery_cases(i) = gallery_case;

    summary_rows(i).case_id = inject_case.case_id;
    summary_rows(i).true_label = string(inject_case.true_label);
    summary_rows(i).attack_applied = logical(resolve_attack_flag_local(inject_case));
    summary_rows(i).attack_mode = string(resolve_attack_mode_local(inject_case));
    summary_rows(i).gallery_rmse_m = gallery_case.metrics.rmse_m;
    summary_rows(i).gallery_mte_m = gallery_case.metrics.mte_m;
    summary_rows(i).gallery_dtw_m = gallery_case.metrics.dtw_m;
    summary_rows(i).gallery_coverage = gallery_case.metrics.coverage;
    summary_rows(i).num_visible_sats = gallery_case.num_visible_sats;
    summary_rows(i).core_status = core_case.status;
    summary_rows(i).gallery_status = gallery_case.status;
end

trajectory = struct();
trajectory.core_cases = core_cases;
trajectory.gallery_cases = gallery_cases;
trajectory.summary_tbl = struct2table(summary_rows);
trajectory.template_order = attacked.template_order;
end

function case_item = run_data_case_local(obs_waveform, nav_data, step1_res_shaped, t_grid, ref_x, ref_y, ref_pen, ref_label, data_cfg, mode_name)
case_item = empty_output_case_local();
case_item.mode = string(mode_name);
case_item.t_grid = t_grid;
case_item.reference_label = string(ref_label);
case_item.reference_x = ref_x;
case_item.reference_y = ref_y;
case_item.reference_pen = ref_pen;

try
    [x, y, t, conf] = run_gesture_analysis_data_driven(obs_waveform, nav_data, step1_res_shaped, data_cfg);
    case_item.status = "ok";
catch ME
    warning('layer3_recover_trajectories:RunDataDrivenFailed', ...
        'Data-Driven %s run failed: %s', mode_name, ME.message);
    case_item.status = "failed";
    return;
end

case_item.x = x;
case_item.y = y;
case_item.t = t;
case_item.conf = conf;
[case_item.plot_x, case_item.plot_y] = ordered_plot_pair_local(x, y, t, t_grid);
case_item.full_x = to_full_series_local(x, y, t, numel(t_grid), t_grid, 1);
case_item.full_y = to_full_series_local(x, y, t, numel(t_grid), t_grid, 2);

if ~isempty(ref_x)
    case_item.metrics = evaluate_reconstruction_against_reference( ...
        case_item.full_x, case_item.full_y, ref_x, ref_y, ref_pen, 75);
else
    case_item.metrics = empty_metrics_local();
end
case_item.metrics.mean_conf = mean(conf, 'omitnan');
end

function cfg_out = build_core_cfg_local(cfg_in)
cfg_out = cfg_in;
if ~isfield(cfg_out, 'track') || ~isstruct(cfg_out.track)
    cfg_out.track = struct();
end
cfg_out.track.shape_guided_enable = false;
if isfield(cfg_out.track, 'shape_hint_label')
    cfg_out.track = rmfield(cfg_out.track, 'shape_hint_label');
end
end

function cfg_out = build_gallery_cfg_local(cfg_in, true_label, attack_applied)
cfg_out = cfg_in;
if ~isfield(cfg_out, 'track') || ~isstruct(cfg_out.track)
    cfg_out.track = struct();
end
if nargin < 3
    attack_applied = false;
end
if attack_applied
    if isfield(cfg_out.track, 'shape_hint_label')
        cfg_out.track = rmfield(cfg_out.track, 'shape_hint_label');
    end
elseif strlength(string(true_label)) > 0
    cfg_out.track.shape_hint_label = char(string(true_label));
end
end

function [ref_x, ref_y, ref_pen, ref_label] = build_reference_template_local(reference_label, n_samples, span_cfg)
if strlength(string(reference_label)) == 0
    ref_x = [];
    ref_y = [];
    ref_pen = [];
    ref_label = "";
    return;
end

ref_label = string(gesture_template_store('label', reference_label));
[ref_x, ref_y, ref_pen] = gesture_template_store('groundtruth', char(ref_label), n_samples, span_cfg);
end

function t_grid = resolve_t_grid_local(step1_res, step1_res_shaped)
if isfield(step1_res_shaped, 't_grid') && ~isempty(step1_res_shaped.t_grid)
    t_grid = step1_res_shaped.t_grid;
else
    t_grid = step1_res.t_grid;
end
end

function [plot_x, plot_y] = ordered_plot_pair_local(x, y, t_idx, t_grid)
plot_x = [];
plot_y = [];
if isempty(x) || isempty(y)
    return;
end

x = x(:);
y = y(:);
n = min(numel(x), numel(y));
x = x(1:n);
y = y(1:n);
if isempty(t_idx)
    keep = isfinite(x) & isfinite(y);
    plot_x = x(keep);
    plot_y = y(keep);
    return;
end

t_idx = normalize_time_index_local(t_idx, numel(t_grid), t_grid);
t_idx = t_idx(1:min(numel(t_idx), n));
n = min([numel(x), numel(y), numel(t_idx)]);
x = x(1:n);
y = y(1:n);
t_idx = t_idx(1:n);
keep = isfinite(t_idx);
x = x(keep);
y = y(keep);
t_idx = t_idx(keep);
[~, ord] = sort(t_idx, 'ascend');
plot_x = x(ord);
plot_y = y(ord);
end

function full_series = to_full_series_local(x, y, t_idx, N, t_grid, dim_id)
full_series = nan(N, 1);
if isempty(x) || isempty(y) || isempty(t_idx)
    return;
end

x = x(:);
y = y(:);
t_idx = normalize_time_index_local(t_idx, N, t_grid);
n = min([numel(x), numel(y), numel(t_idx)]);
x = x(1:n);
y = y(1:n);
t_idx = t_idx(1:n);
keep = isfinite(x) & isfinite(y) & isfinite(t_idx) & t_idx >= 1 & t_idx <= N;
x = x(keep);
y = y(keep);
t_idx = t_idx(keep);
if isempty(t_idx)
    return;
end

[u_idx, ia] = unique(t_idx, 'stable');
if dim_id == 1
    full_series(u_idx) = x(ia);
else
    full_series(u_idx) = y(ia);
end
end

function idx = normalize_time_index_local(t, N, t_grid)
if isnumeric(t)
    idx = round(t(:));
    if all(isfinite(idx)) && all(idx >= 1) && all(idx <= N)
        return;
    end
end
if isdatetime(t)
    tg = posixtime(t_grid(:));
    tt = posixtime(t(:));
    idx = round(interp1(tg, 1:N, tt, 'nearest', 'extrap'));
    idx = min(max(idx, 1), N);
    return;
end
idx = round(linspace(1, N, numel(t)))';
end

function case_item = empty_output_case_local()
case_item = struct( ...
    'case_id', "", ...
    'mode', "", ...
    'source_mode', "", ...
    'attack_applied', false, ...
    'attack_mode', "", ...
    'attack_notes', "", ...
    'true_label', "", ...
    'reference_label', "", ...
    'reference_x', [], ...
    'reference_y', [], ...
    'reference_pen', [], ...
    't_grid', [], ...
    'num_visible_sats', NaN, ...
    'x', [], ...
    'y', [], ...
    't', [], ...
    'conf', [], ...
    'plot_x', [], ...
    'plot_y', [], ...
    'full_x', [], ...
    'full_y', [], ...
    'metrics', empty_metrics_local(), ...
    'status', "failed");
end

function tf = resolve_attack_flag_local(case_item)
if isfield(case_item, 'attack_applied')
    tf = logical(case_item.attack_applied);
else
    tf = false;
end
end

function mode_name = resolve_attack_mode_local(case_item)
if isfield(case_item, 'attack_mode') && strlength(string(case_item.attack_mode)) > 0
    mode_name = string(case_item.attack_mode);
else
    mode_name = "none";
end
end

function notes = resolve_attack_notes_local(case_item)
if isfield(case_item, 'attack_notes') && strlength(string(case_item.attack_notes)) > 0
    notes = string(case_item.attack_notes);
else
    notes = "";
end
end

function met = empty_metrics_local()
met = struct( ...
    'rmse_m', inf, ...
    'mte_m', inf, ...
    'dtw_m', inf, ...
    'start_err_m', inf, ...
    'end_err_m', inf, ...
    'coverage', 0, ...
    'point_errors_m', [], ...
    'aligned_est_x', [], ...
    'aligned_est_y', [], ...
    'aligned_gt_x', [], ...
    'aligned_gt_y', [], ...
    'path_length_m', NaN, ...
    'x_span_m', NaN, ...
    'y_span_m', NaN, ...
    'mean_conf', NaN);
end
