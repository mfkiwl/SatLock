function [manifest_tbl, out_dir] = export_paper_figures_data_driven(user_cfg)
% EXPORT_PAPER_FIGURES_DATA_DRIVEN
% Export paper-ready figures for the single-method trajectory reconstruction
% workflow, using the existing Data-Driven results as the primary source.
%
% Usage:
%   export_paper_figures_data_driven();
%   export_paper_figures_data_driven(struct('source_mat', '...research_plot_suite.mat'));

if nargin < 1 || isempty(user_cfg)
    user_cfg = struct();
end

repo_dir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
ensure_project_paths_local(repo_dir);

cfg = default_cfg(repo_dir);
source_cfg = struct();
requested_source_mat = '';
if isstruct(user_cfg) && isfield(user_cfg, 'source_mat')
    requested_source_mat = user_cfg.source_mat;
end
source_mat = resolve_source_mat(requested_source_mat, repo_dir);
if ~isempty(source_mat) && exist(source_mat, 'file') == 2
    tmp = load(source_mat);
    if isfield(tmp, 'cfg') && isstruct(tmp.cfg)
        source_cfg = tmp.cfg;
    end
end
cfg = absorb_source_cfg(cfg, source_cfg);
cfg = merge_cfg(cfg, user_cfg);

rng(cfg.random_seed, 'twister');

[out_dir, work_dir, cache_dir] = prepare_output_dirs(source_mat, cfg);
source_cache_path = fullfile(work_dir, cfg.source_cache_name);

if ~isempty(source_mat) && exist(source_mat, 'file') == 2
    src = load(source_mat);
    if ~isfield(src, 'src') && ~isfield(src, 'cases')
        error('export_paper_figures_data_driven:MissingCases', ...
            'The source MAT file does not contain valid case results.');
    end
elseif cfg.reuse_cache && exist(source_cache_path, 'file') == 2
    tmp = load(source_cache_path, 'src');
    src = tmp.src;
else
    src = build_data_driven_source(cfg);
end

src = normalize_loaded_source(src);
method_cases = extract_data_driven_cases(src);
template_order = determine_template_order_local(src, method_cases, cfg);
auth_res = extract_or_build_auth_results(src, method_cases, template_order, cfg);
metric_bar_tbl = build_classified_metric_table(auth_res, false);
metric_dtw_tbl = build_classified_metric_table(auth_res, true);
metric_cdf_tbl = build_cdf_metric_table(auth_res, cfg);
auth_perf = struct();

if isempty(source_mat)
    save(source_cache_path, 'src', '-v7.3');
end

manifest = cell(0, 3);

[obs_base, nav_data] = deal([]);
if cfg.security.enable || cfg.height.enable || cfg.sensing.enable || cfg.auth_perf.enable || cfg.export_multi_gallery
    [obs_base, nav_data] = load_raw_inputs(cfg);
end

rmse_bar_path = fullfile(out_dir, 'rmse_mte_bar.png');
plot_rmse_mte_bar(metric_bar_tbl, method_cases, template_order, rmse_bar_path, cfg);
manifest(end + 1, :) = {'rmse_mte_bar', 'rmse_mte_bar.png', rmse_bar_path}; %#ok<AGROW>

dtw_box_path = fullfile(out_dir, 'dtw_boxplot.png');
plot_dtw_box(metric_dtw_tbl, method_cases, template_order, dtw_box_path, cfg);
manifest(end + 1, :) = {'dtw_boxplot', 'dtw_boxplot.png', dtw_box_path}; %#ok<AGROW>

cdf_path = fullfile(out_dir, 'cdf_rmse_mte.png');
plot_error_cdf(metric_cdf_tbl, cdf_path, cfg);
manifest(end + 1, :) = {'cdf_rmse_mte', 'cdf_rmse_mte.png', cdf_path}; %#ok<AGROW>

gallery_path = fullfile(out_dir, 'traj_gallery_data_driven.png');
plot_single_method_gallery(method_cases, template_order, gallery_path, cfg);
manifest(end + 1, :) = {'traj_gallery_data_driven', 'traj_gallery_data_driven.png', gallery_path}; %#ok<AGROW>

if cfg.auth_perf.enable
    auth_perf_cache_path = fullfile(cache_dir, cfg.auth_perf.cache_name);
    auth_perf = load_or_build_auth_perf_dataset(auth_perf_cache_path, obs_base, nav_data, template_order, cfg);

    auth_roc_path = fullfile(out_dir, 'authentication_roc.png');
    plot_authentication_roc(auth_perf, auth_roc_path, cfg);
    manifest(end + 1, :) = {'authentication_roc', 'authentication_roc.png', auth_roc_path}; %#ok<AGROW>

    auth_metric_bar_path = fullfile(out_dir, 'authentication_metrics_bar.png');
    plot_authentication_metric_bar(auth_perf, auth_metric_bar_path, cfg);
    manifest(end + 1, :) = {'authentication_metrics_bar', 'authentication_metrics_bar.png', auth_metric_bar_path}; %#ok<AGROW>

    auth_csv_path = fullfile(out_dir, 'authentication_roc_points.csv');
    writetable(auth_perf.roc_table, auth_csv_path);
    manifest(end + 1, :) = {'authentication_roc_points', 'authentication_roc_points.csv', auth_csv_path}; %#ok<AGROW>

    auth_metric_csv_path = fullfile(out_dir, 'authentication_metrics_summary.csv');
    writetable(auth_perf.metric_table, auth_metric_csv_path);
    manifest(end + 1, :) = {'authentication_metrics_summary', 'authentication_metrics_summary.csv', auth_metric_csv_path}; %#ok<AGROW>
end

if cfg.security.enable
    sec_cache_path = fullfile(cache_dir, cfg.security.cache_name);
    sec_data = load_or_build_security_dataset(sec_cache_path, obs_base, nav_data, template_order, cfg);

    attack_box_path = fullfile(out_dir, 'attack_defense_boxplot.png');
    plot_attack_defense_boxplot(sec_data, attack_box_path, cfg);
    manifest(end + 1, :) = {'attack_defense_boxplot', 'attack_defense_boxplot.png', attack_box_path}; %#ok<AGROW>

    attack_rate_path = fullfile(out_dir, 'attack_defense_rates.png');
    plot_attack_defense_rate_bar(sec_data, auth_perf, attack_rate_path, cfg);
    manifest(end + 1, :) = {'attack_defense_rates', 'attack_defense_rates.png', attack_rate_path}; %#ok<AGROW>

    pca_path = fullfile(out_dir, 'feature_space_pca.png');
    plot_pca_embedding(sec_data, pca_path, cfg);
    manifest(end + 1, :) = {'feature_space_pca', 'feature_space_pca.png', pca_path}; %#ok<AGROW>

    tsne_path = fullfile(out_dir, 'feature_space_tsne.png');
    plot_tsne_embedding(sec_data, tsne_path, cfg);
    manifest(end + 1, :) = {'feature_space_tsne', 'feature_space_tsne.png', tsne_path}; %#ok<AGROW>

    conf_path = fullfile(out_dir, 'confusion_matrix.png');
    plot_confusion_matrix(auth_res, template_order, conf_path, cfg);
    manifest(end + 1, :) = {'confusion_matrix', 'confusion_matrix.png', conf_path}; %#ok<AGROW>

    dk_conf_path = fullfile(out_dir, 'dk_confusion_matrix.png');
    plot_template_metric_matrix(auth_res, template_order, 'distance_vector', dk_conf_path, cfg, ...
        struct('colorbar_label', 'Average D_k', 'decimals', 2, 'high_is_better', false));
    manifest(end + 1, :) = {'dk_confusion_matrix', 'dk_confusion_matrix.png', dk_conf_path}; %#ok<AGROW>

    rmse_conf_path = fullfile(out_dir, 'rmse_confusion_matrix.png');
    plot_template_metric_matrix(auth_res, template_order, 'rmse_vector', rmse_conf_path, cfg, ...
        struct('colorbar_label', 'Average normalized RMSE', 'decimals', 2, 'high_is_better', false));
    manifest(end + 1, :) = {'rmse_confusion_matrix', 'rmse_confusion_matrix.png', rmse_conf_path}; %#ok<AGROW>

    dtw_conf_path = fullfile(out_dir, 'dtw_confusion_matrix.png');
    plot_template_metric_matrix(auth_res, template_order, 'dtw_vector', dtw_conf_path, cfg, ...
        struct('colorbar_label', 'Average normalized DTW', 'decimals', 2, 'high_is_better', false));
    manifest(end + 1, :) = {'dtw_confusion_matrix', 'dtw_confusion_matrix.png', dtw_conf_path}; %#ok<AGROW>
end

if cfg.height.enable
    height_cache_path = fullfile(cache_dir, cfg.height.cache_name);
    height_tbl = load_or_build_height_sensitivity(height_cache_path, obs_base, nav_data, template_order, cfg);

    height_path = fullfile(out_dir, 'height_sensitivity_dual_axis.png');
    plot_height_sensitivity(height_tbl, height_path, cfg);
    manifest(end + 1, :) = {'height_sensitivity_dual_axis', 'height_sensitivity_dual_axis.png', height_path}; %#ok<AGROW>
end

if cfg.sensing.enable
    sensing_cache_path = fullfile(cache_dir, cfg.sensing.cache_name);
    sensing_data = load_or_build_sensing_scope(sensing_cache_path, obs_base, nav_data, cfg);

    sensing_scope_path = fullfile(out_dir, 'sensing_scope_30cm.png');
    plot_sensing_scope_snapshot(sensing_data.scope_snapshot, sensing_scope_path, cfg);
    manifest(end + 1, :) = {'sensing_scope_30cm', 'sensing_scope_30cm.png', sensing_scope_path}; %#ok<AGROW>

    grid_curve_path = fullfile(out_dir, 'grid_avg_affected_satellites_vs_height.png');
    plot_grid_average_satellite_curve(sensing_data.height_curve, grid_curve_path, cfg);
    manifest(end + 1, :) = {'grid_avg_affected_satellites_vs_height', 'grid_avg_affected_satellites_vs_height.png', grid_curve_path}; %#ok<AGROW>
end

if cfg.export_multi_gallery
    extra_manifest = export_multi_algorithm_galleries(src.cases, template_order, out_dir, cfg);
    manifest = [manifest; extra_manifest]; %#ok<AGROW>
end

manifest_tbl = cell2table(manifest, 'VariableNames', {'figure_id', 'file_name', 'full_path'});
writetable(manifest_tbl, fullfile(out_dir, 'paper_figure_manifest.csv'));
save(fullfile(work_dir, 'paper_figure_manifest.mat'), 'manifest_tbl', 'source_mat', 'cfg');

fprintf('\nPaper figures exported to:\n%s\n', out_dir);
disp(manifest_tbl(:, 1:2));
end

function cfg = default_cfg(repo_dir)
cfg = struct();
cfg.source_mat = '';
cfg.source_cache_name = 'data_driven_source_cache_v3.mat';
cfg.obs_filepath = fullfile(repo_dir, 'data', '1_8', 'A_1_8_1.obs');
cfg.nav_filepath = fullfile(repo_dir, 'data', '1_8', '2026_1_8.nav');
cfg.figure_root = '';
cfg.show_figures = false;
cfg.save_resolution = 380;
cfg.random_seed = 20260321;
cfg.reuse_cache = true;
cfg.export_multi_gallery = false;
cfg.template_order = {};

cfg.span_cfg = struct();
cfg.span_cfg.max_span_x = 0.50;
cfg.span_cfg.max_span_y = 0.50;

cfg.inject_cfg = struct();
cfg.inject_cfg.enable = true;
cfg.inject_cfg.real_case_label = "";

cfg.attack_cfg = struct();
cfg.attack_cfg.enable = false;
cfg.attack_cfg.mode = "none";
cfg.attack_cfg.target = "observation";
cfg.attack_cfg.window_start_ratio = 0.25;
cfg.attack_cfg.window_end_ratio = 0.85;
cfg.attack_cfg.baseline_noise_sigma = 0.03;
cfg.attack_cfg.sdr_drop_db = 8.5;
cfg.attack_cfg.ghost_drop_db = 9.0;
cfg.attack_cfg.random_seed = cfg.random_seed + 77;

cfg.sim_cfg = struct();
cfg.sim_cfg.enable = true;
cfg.sim_cfg.plot = false;
cfg.sim_cfg.max_span_x = cfg.span_cfg.max_span_x;
cfg.sim_cfg.max_span_y = cfg.span_cfg.max_span_y;
cfg.sim_cfg.gesture_height = 0.30;
cfg.sim_cfg.baseline_db = 45;
cfg.sim_cfg.drop_depth_db = 15;
cfg.sim_cfg.noise_sigma = 0.02;

cfg.data_cfg = struct();
cfg.data_cfg.debug = struct('verbose', false, 'plot', false);
cfg.data_cfg.model = struct('max_hand_radius', 0.40);
cfg.data_cfg.grid = struct('x_min', -0.35, 'x_max', 0.35, 'y_min', -0.35, 'y_max', 0.35, 'step', 0.015);
cfg.data_cfg.track = struct( ...
    'lambda_smooth', 12.0, ...
    'final_smooth_pts', 2, ...
    'max_jump_m', 0.18, ...
    'use_active_interpolation', true, ...
    'use_process_window_output', true, ...
    'output_pad_frames', 14, ...
    'use_draw_mask_output', false, ...
    'use_draw_energy_gate', false, ...
    'enforce_piecewise_linear', true, ...
    'polyline_min_segments', 1, ...
    'polyline_rdp_eps', 0.022, ...
    'polyline_corner_angle_deg', 26, ...
    'polyline_max_fit_err', 0.19, ...
    'polyline_len_ratio_min', 0.60, ...
    'polyline_len_ratio_max', 1.25, ...
    'template_snap_enable', false, ...
    'endpoint_lock_enable', true, ...
    'endpoint_lock_blend', 0.72, ...
    'endpoint_lock_len_pts', 10, ...
    'axis_regularize_enable', true, ...
    'axis_regularize_min_major_span', 0.16, ...
    'axis_regularize_max_minor_span', 0.08, ...
    'axis_regularize_min_aspect', 3.2, ...
    'axis_regularize_monotonicity_min', 0.78, ...
    'axis_regularize_path_ratio_max', 1.85, ...
    'axis_regularize_max_turns', 2, ...
    'axis_regularize_target_span', 0.42, ...
    'axis_regularize_max_span', 0.50, ...
    'axis_regularize_blend', 0.82, ...
    'axis_regularize_minor_keep', 0.15);

cfg.auth_cfg = struct();
cfg.auth_cfg.template_order = {};
cfg.auth_cfg.compare_points = 160;
cfg.auth_cfg.temperature = 0.16;
cfg.auth_cfg.weights = struct('alpha_dtw', 2.5, 'beta_rmse', 0.30, 'gamma_shape', 0.20);

cfg.auth_perf = struct();
cfg.auth_perf.enable = true;
cfg.auth_perf.cache_name = 'auth_performance_cache_v4.mat';
cfg.auth_perf.template_names = {};
cfg.auth_perf.samples_per_template = 24;
cfg.auth_perf.threshold_count = 401;
cfg.auth_perf.require_predicted_match = false;
cfg.auth_perf.metric_threshold_mode = 'eer';
cfg.auth_perf.noise_sigma_values = [0.018 0.022 0.026];
cfg.auth_perf.drop_depth_values = [13.5 15.0 16.5];

cfg.sample_metrics = struct();
cfg.sample_metrics.enable = true;
cfg.sample_metrics.cache_name = 'sample_metrics_cache_v3.mat';
cfg.sample_metrics.template_names = {};
cfg.sample_metrics.samples_per_template = 20;

cfg.dtw_box = struct('min_chunks', 6, 'max_chunks', 10, 'chunk_resample_n', 24);
cfg.cdf = struct('window_points', 12, 'step_points', 4, 'best_sample_count', 120, 'smooth_grid_n', 320);

cfg.security = struct();
cfg.security.enable = true;
cfg.security.cache_name = 'security_dataset_cache_v7.mat';
cfg.security.template_names = {};
cfg.security.repetitions_per_mode = 2;
cfg.security.samples_per_case = 6;
cfg.security.tsne_perplexity = 18;
cfg.security.height_jitter_cm = 4;
cfg.security.noise_sigma_values = [0.018 0.022 0.026];
cfg.security.drop_depth_values = [13.5 15.0 16.5];

cfg.height = struct();
cfg.height.enable = true;
cfg.height.cache_name = 'height_sensitivity_cache_v2.mat';
cfg.height.template_names = {'A', 'C', 'M', 'Star', 'Rectangle'};
cfg.height.heights_cm = 10:5:50;
cfg.height.repetitions = 1;
cfg.height.affected_threshold = 2.0;
cfg.height.recommended_height_cm = 30;

cfg.sensing = struct();
cfg.sensing.enable = true;
cfg.sensing.cache_name = 'sensing_scope_cache_v4.mat';
cfg.sensing.plane_height_cm = 30;
cfg.sensing.height_grid_cm = 10:5:50;
cfg.sensing.min_elevation_deg = 0;
cfg.sensing.sensing_radius_m = 0.50 / 3;
cfg.sensing.interaction_span_m = 0.50;
cfg.sensing.max_proj_radius_m = 5.0;
cfg.sensing.grid_step_m = 0.05;
cfg.sensing.analysis_half_span_m = 0.25;
cfg.sensing.best_epoch_scan_limit = 100;

cfg.style = build_style();
end

function style = build_style()
style = struct();
style.font_name = 'Times New Roman';
style.font_size = 10.5;
style.small_font_size = 8.5;
style.axis_line_width = 1.0;
style.line_width = 1.9;
style.marker_size = 6.5;
style.scatter_size = 42;
style.grid_color = [0.80 0.80 0.80];
style.grid_alpha = 0.28;
style.rmse_color = [0.19 0.40 0.67];
style.mte_color = [0.70 0.46 0.24];
style.gt_color = [0.30 0.49 0.68];
style.rec_color = [0.66 0.31 0.32];
style.box_color = [0.23 0.66 0.88];
style.attack_colors = containers.Map( ...
    {'Legitimate', 'Replay', 'SDR Spoof', 'Ghost/Injection'}, ...
    {[0.10 0.35 0.78], [0.84 0.50 0.18], [0.25 0.56 0.33], [0.72 0.24 0.26]});
end

function source_mat = resolve_source_mat(source_mat, repo_dir)
if nargin >= 1 && ~isempty(source_mat) && exist(source_mat, 'file') == 2
    return;
end

result_root = fullfile(repo_dir, 'gesture_analysis', 'results');
if ~exist(result_root, 'dir')
    error('export_paper_figures_data_driven:MissingResults', ...
        'The results directory does not exist: %s', result_root);
end

files = dir(fullfile(result_root, '**', 'research_plot_suite.mat'));
if isempty(files)
    source_mat = '';
    return;
end

[~, idx] = max([files.datenum]);
source_mat = fullfile(files(idx).folder, files(idx).name);
end

function cfg = absorb_source_cfg(cfg, source_cfg)
if isempty(source_cfg) || ~isstruct(source_cfg)
    return;
end

copy_keys = {'obs_filepath', 'nav_filepath', 'span_cfg', 'sim_cfg', 'data_cfg', 'inject_cfg', 'attack_cfg', 'auth_cfg'};
for i = 1:numel(copy_keys)
    key = copy_keys{i};
    if isfield(source_cfg, key)
        if isstruct(source_cfg.(key)) && isfield(cfg, key) && isstruct(cfg.(key))
            cfg.(key) = merge_cfg(cfg.(key), source_cfg.(key));
        else
            cfg.(key) = source_cfg.(key);
        end
    end
end

if isfield(cfg, 'sim_cfg')
    cfg.sim_cfg.plot = false;
    cfg.sim_cfg.max_span_x = cfg.span_cfg.max_span_x;
    cfg.sim_cfg.max_span_y = cfg.span_cfg.max_span_y;
end
if isfield(cfg, 'data_cfg') && isfield(cfg.data_cfg, 'debug')
    cfg.data_cfg.debug.verbose = false;
    cfg.data_cfg.debug.plot = false;
end
end

function [out_dir, work_dir, cache_dir] = prepare_output_dirs(source_mat, cfg)
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
base_results_dir = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'gesture_analysis', 'results');
if ~isempty(cfg.figure_root)
    out_dir = fullfile(cfg.figure_root, 'paper_figures_data_driven_output', ['paper_figures_data_driven_', stamp]);
    work_dir = fullfile(cfg.figure_root, 'paper_figures_data_driven_work');
else
    out_dir = fullfile(base_results_dir, 'paper_figures_data_driven_output', ['paper_figures_data_driven_', stamp]);
    work_dir = fullfile(base_results_dir, 'paper_figures_data_driven_work');
end
ensure_dir(out_dir);
ensure_dir(work_dir);
cache_dir = fullfile(work_dir, 'cache');
ensure_dir(cache_dir);
end

function src = normalize_loaded_source(src_in)
if isstruct(src_in) && isfield(src_in, 'src') && isstruct(src_in.src)
    src = src_in.src;
else
    src = src_in;
end
end

function template_order = determine_template_order_local(src, method_cases, cfg)
if isfield(src, 'trajectory') && isstruct(src.trajectory) && ...
        isfield(src.trajectory, 'template_order') && ~isempty(src.trajectory.template_order)
    template_order = resolve_template_order(src.trajectory.template_order, cfg.template_order);
    return;
end
if isfield(cfg, 'auth_cfg') && isfield(cfg.auth_cfg, 'template_order') && ~isempty(cfg.auth_cfg.template_order)
    template_order = resolve_template_order(cfg.auth_cfg.template_order, cfg.template_order);
    return;
end
template_order = resolve_template_order({method_cases.template}, cfg.template_order);
end

function auth_res = extract_or_build_auth_results(src, method_cases, template_order, cfg)
if isfield(src, 'auth') && isstruct(src.auth) && isfield(src.auth, 'rows') && ~isempty(src.auth.rows)
    auth_res = src.auth;
    return;
end
auth_cfg = cfg.auth_cfg;
auth_cfg.template_order = template_order;
auth_res = auth_build_results(method_cases, cfg.span_cfg, auth_cfg);
end

function src = build_data_driven_source(cfg)
[~, src] = build_gesture_test_source(cfg);
end

function method_cases = extract_data_driven_cases(src)
if isfield(src, 'trajectory') && isstruct(src.trajectory) && isfield(src.trajectory, 'gallery_cases')
    gallery_cases = src.trajectory.gallery_cases;
    n = numel(gallery_cases);
    method_cases = repmat(struct( ...
        'case_id', "", ...
        'template', '', ...
        'true_label', "", ...
        't_grid', [], ...
        'gt_x', [], ...
        'gt_y', [], ...
        'gt_pen', [], ...
        'num_visible_sats', NaN, ...
        'plot_x', [], ...
        'plot_y', [], ...
        'full_x', [], ...
        'full_y', [], ...
        'metrics', struct(), ...
        'conf', [], ...
        'status', ""), n, 1);

    for i = 1:n
        gc = gallery_cases(i);
        method_cases(i).case_id = string(gc.case_id);
        if strlength(string(gc.true_label)) > 0
            method_cases(i).template = char(gc.true_label);
        else
            method_cases(i).template = char(string(gc.case_id));
        end
        method_cases(i).true_label = string(gc.true_label);
        method_cases(i).t_grid = gc.t_grid;
        method_cases(i).gt_x = gc.reference_x;
        method_cases(i).gt_y = gc.reference_y;
        method_cases(i).gt_pen = gc.reference_pen;
        method_cases(i).num_visible_sats = gc.num_visible_sats;
        method_cases(i).plot_x = gc.plot_x;
        method_cases(i).plot_y = gc.plot_y;
        method_cases(i).full_x = gc.full_x;
        method_cases(i).full_y = gc.full_y;
        method_cases(i).metrics = gc.metrics;
        method_cases(i).conf = gc.conf;
        method_cases(i).status = gc.status;
    end
    return;
end

cases = src.cases;
n = numel(cases);
method_cases = repmat(struct( ...
    'case_id', "", ...
    'template', '', ...
    'true_label', "", ...
    't_grid', [], ...
    'gt_x', [], ...
    'gt_y', [], ...
    'gt_pen', [], ...
    'num_visible_sats', NaN, ...
    'plot_x', [], ...
    'plot_y', [], ...
    'full_x', [], ...
    'full_y', [], ...
    'metrics', struct(), ...
    'conf', [], ...
    'status', ""), n, 1);

for i = 1:n
    dd = cases(i).data_driven;
    method_cases(i).case_id = "legacy_case_" + string(i);
    method_cases(i).template = char(cases(i).template);
    method_cases(i).true_label = string(cases(i).template);
    method_cases(i).t_grid = cases(i).t_grid;
    method_cases(i).gt_x = cases(i).gt_x;
    method_cases(i).gt_y = cases(i).gt_y;
    method_cases(i).gt_pen = cases(i).gt_pen;
    method_cases(i).num_visible_sats = cases(i).num_visible_sats;
    method_cases(i).plot_x = dd.plot_x;
    method_cases(i).plot_y = dd.plot_y;
    method_cases(i).full_x = dd.full_x;
    method_cases(i).full_y = dd.full_y;
    method_cases(i).metrics = dd.metrics;
    method_cases(i).conf = dd.conf;
    method_cases(i).status = dd.status;
end
end

function [obs_base, nav_data] = load_raw_inputs(cfg)
obs_base = parse_rinex_obs(cfg.obs_filepath);
nav_data = parse_rinex_nav_multi_gnss(cfg.nav_filepath);
end

function metric_tbl = build_classified_metric_table(auth_res, expand_dtw)
if nargin < 2
    expand_dtw = false;
end

rows = empty_sample_metric_table();
for i = 1:numel(auth_res.rows)
    row = auth_res.rows(i);
    template_name = string(row.predicted_label);
    if strlength(template_name) == 0
        continue;
    end
    met = row.predicted_metrics;
    if ~isstruct(met) || ~isfinite(fallback(met.rmse_m, NaN))
        continue;
    end

    if expand_dtw
        tmp_case = struct('metrics', met);
        vals = local_dtw_distribution(tmp_case, struct('min_chunks', 6, 'max_chunks', 10, 'chunk_resample_n', 24));
        vals = vals(isfinite(vals));
        if isempty(vals)
            vals = met.dtw_m;
        end
        new_rows = table( ...
            repmat(template_name, numel(vals), 1), ...
            (1:numel(vals)).', ...
            nan(numel(vals), 1), ...
            nan(numel(vals), 1), ...
            vals(:), ...
            repmat(fallback(met.coverage, 0), numel(vals), 1), ...
            repmat(template_name, numel(vals), 1), ...
            repmat({met.aligned_est_x(:)}, numel(vals), 1), ...
            repmat({met.aligned_est_y(:)}, numel(vals), 1), ...
            repmat({met.aligned_gt_x(:)}, numel(vals), 1), ...
            repmat({met.aligned_gt_y(:)}, numel(vals), 1), ...
            'VariableNames', {'template', 'sample_id', 'rmse_m', 'mte_m', 'dtw_m', 'coverage', ...
            'predicted_template', 'aligned_est_x', 'aligned_est_y', 'aligned_gt_x', 'aligned_gt_y'});
    else
        new_rows = table( ...
            template_name, ...
            i, ...
            met.rmse_m, ...
            met.mte_m, ...
            met.dtw_m, ...
            fallback(met.coverage, 0), ...
            template_name, ...
            {met.aligned_est_x(:)}, ...
            {met.aligned_est_y(:)}, ...
            {met.aligned_gt_x(:)}, ...
            {met.aligned_gt_y(:)}, ...
            'VariableNames', {'template', 'sample_id', 'rmse_m', 'mte_m', 'dtw_m', 'coverage', ...
            'predicted_template', 'aligned_est_x', 'aligned_est_y', 'aligned_gt_x', 'aligned_gt_y'});
    end

    rows = [rows; new_rows]; %#ok<AGROW>
end

metric_tbl = rows;
end

function metric_tbl = build_cdf_metric_table(auth_res, cfg)
rows = table(nan(0, 1), nan(0, 1), 'VariableNames', {'rmse_m', 'mte_m'});
for i = 1:numel(auth_res.rows)
    row = auth_res.rows(i);
    met = row.predicted_metrics;
    if ~isstruct(met) || isempty(met.point_errors_m)
        continue;
    end
    [rmse_blocks, mte_blocks] = blockwise_error_metrics(met.point_errors_m, cfg.cdf.window_points, cfg.cdf.step_points);
    rmse_blocks = rmse_blocks(isfinite(rmse_blocks));
    mte_blocks = mte_blocks(isfinite(mte_blocks));
    n = min(numel(rmse_blocks), numel(mte_blocks));
    if n <= 0
        continue;
    end
    new_rows = table(rmse_blocks(1:n), mte_blocks(1:n), 'VariableNames', {'rmse_m', 'mte_m'});
    rows = [rows; new_rows]; %#ok<AGROW>
end

if isempty(rows)
    fallback_rows = table(nan(0, 1), nan(0, 1), 'VariableNames', {'rmse_m', 'mte_m'});
    for i = 1:numel(auth_res.rows)
        met = auth_res.rows(i).predicted_metrics;
        if ~isstruct(met) || ~isfinite(fallback(met.rmse_m, NaN))
            continue;
        end
        fallback_rows = [fallback_rows; table(met.rmse_m, met.mte_m, 'VariableNames', {'rmse_m', 'mte_m'})]; %#ok<AGROW>
    end
    rows = fallback_rows;
end

metric_tbl = rows;
end

function sample_tbl = load_or_build_sample_metrics(cache_path, obs_base, nav_data, template_order, cfg)
template_names = cfg.sample_metrics.template_names;
if isempty(template_names)
    template_names = template_order;
end

if cfg.reuse_cache && exist(cache_path, 'file') == 2
    tmp = load(cache_path, 'sample_tbl');
    if isfield(tmp, 'sample_tbl')
        sample_tbl = tmp.sample_tbl;
    else
        sample_tbl = empty_sample_metric_table();
    end
else
    sample_tbl = empty_sample_metric_table();
end

sample_tbl = refresh_sample_metric_derivatives(sample_tbl, template_order, cfg);

for t_idx = 1:numel(template_names)
    template_name = template_names{t_idx};
    for rep = 1:cfg.sample_metrics.samples_per_template
        if ~isempty(sample_tbl) && any(string(sample_tbl.template) == string(template_name) & sample_tbl.sample_id == rep)
            continue;
        end
        sim_cfg_local = security_sim_cfg(cfg.sim_cfg, cfg.security, t_idx, rep);
        obs_sim = simulate_template_local(obs_base, nav_data, template_name, sim_cfg_local);
        [~, step1_res, obs_waveform, step1_res_shaped] = run_preprocess_pipeline(obs_sim);
        t_grid = resolve_t_grid_local(step1_res, step1_res_shaped);
        [gt_x, gt_y, gt_pen] = build_ground_truth_local(template_name, numel(t_grid), cfg.span_cfg);
        alg_case = run_data_driven_case(obs_waveform, nav_data, step1_res_shaped, t_grid, gt_x, gt_y, gt_pen, template_name, cfg.data_cfg);
        [pred_label, ~, ~, ~] = predict_template_from_trace( ...
            alg_case.metrics.aligned_est_x, alg_case.metrics.aligned_est_y, template_name, template_order, cfg.span_cfg);
        dtw_recomputed = recompute_sample_dtw(alg_case.metrics);

        new_row = table(string(template_name), rep, alg_case.metrics.rmse_m, alg_case.metrics.mte_m, ...
            dtw_recomputed, alg_case.metrics.coverage, string(pred_label), ...
            {alg_case.metrics.aligned_est_x(:)}, {alg_case.metrics.aligned_est_y(:)}, ...
            {alg_case.metrics.aligned_gt_x(:)}, {alg_case.metrics.aligned_gt_y(:)}, ...
            'VariableNames', {'template', 'sample_id', 'rmse_m', 'mte_m', 'dtw_m', 'coverage', ...
            'predicted_template', 'aligned_est_x', 'aligned_est_y', 'aligned_gt_x', 'aligned_gt_y'});
        sample_tbl = [sample_tbl; new_row]; %#ok<AGROW>
        save(cache_path, 'sample_tbl');
    end
end

save(cache_path, 'sample_tbl');
end

function auth_perf = load_or_build_auth_perf_dataset(cache_path, obs_base, nav_data, template_order, cfg)
template_names = cfg.auth_perf.template_names;
if isempty(template_names)
    template_names = template_order;
end

if cfg.reuse_cache && exist(cache_path, 'file') == 2
    tmp = load(cache_path, 'auth_perf');
    if isfield(tmp, 'auth_perf')
        auth_perf = tmp.auth_perf;
        if isfield(auth_perf, 'trial_tbl') && istable(auth_perf.trial_tbl) && ...
                isfield(auth_perf, 'roc') && isstruct(auth_perf.roc)
            return;
        end
    end
end

gallery_cases = repmat(empty_auth_perf_case_local(), 0, 1);
case_counter = 0;
for t_idx = 1:numel(template_names)
    template_name = template_names{t_idx};
    for rep = 1:cfg.auth_perf.samples_per_template
        sim_cfg_local = auth_perf_sim_cfg(cfg.sim_cfg, cfg.auth_perf, t_idx, rep);
        obs_sim = simulate_template_local(obs_base, nav_data, template_name, sim_cfg_local);
        [~, step1_res, obs_waveform, step1_res_shaped] = run_preprocess_pipeline(obs_sim);
        t_grid = resolve_t_grid_local(step1_res, step1_res_shaped);
        [gt_x, gt_y, gt_pen] = build_ground_truth_local(template_name, numel(t_grid), cfg.span_cfg);
        alg_case = run_data_driven_case(obs_waveform, nav_data, step1_res_shaped, t_grid, gt_x, gt_y, gt_pen, template_name, cfg.data_cfg);

        case_counter = case_counter + 1;
        alg_case.case_id = string(sprintf('%s_auth_%02d', char(string(template_name)), rep));
        alg_case.true_label = string(template_name);
        alg_case.reference_label = string(template_name);
        alg_case.reference_x = gt_x;
        alg_case.reference_y = gt_y;
        alg_case.reference_pen = gt_pen;
        alg_case.source_mode = "simulated";
        alg_case.attack_applied = false;
        alg_case.attack_mode = "none";
        alg_case.attack_notes = "";
        if isfield(step1_res_shaped, 'valid_sats')
            alg_case.num_visible_sats = numel(step1_res_shaped.valid_sats);
        else
            alg_case.num_visible_sats = NaN;
        end

        gallery_cases(case_counter, 1) = ensure_auth_perf_case_local(alg_case); %#ok<AGROW>
    end
end

auth_res = auth_build_results(gallery_cases, cfg.span_cfg, cfg.auth_cfg);
trial_tbl = auth_build_verification_trials(auth_res.rows, template_order, struct('include_attack', false));
roc_res = auth_compute_verification_roc(trial_tbl, struct( ...
    'threshold_count', cfg.auth_perf.threshold_count, ...
    'require_predicted_match', cfg.auth_perf.require_predicted_match));
metric_tau = resolve_auth_metric_threshold_local(roc_res, cfg.auth_perf);
metric_res = auth_compute_verification_metrics(trial_tbl, metric_tau, struct( ...
    'require_predicted_match', cfg.auth_perf.require_predicted_match));

roc_table = table(roc_res.thresholds(:), roc_res.fpr(:), roc_res.tpr(:), roc_res.fnr(:), ...
    'VariableNames', {'threshold', 'fpr', 'tpr', 'fnr'});
metric_table = table( ...
    string(cfg.auth_perf.metric_threshold_mode), metric_tau, ...
    metric_res.accuracy, metric_res.balanced_accuracy, metric_res.f1_score, ...
    metric_res.precision, metric_res.recall, metric_res.tpr, metric_res.tnr, ...
    metric_res.fpr, metric_res.fnr, metric_res.tp, metric_res.fp, metric_res.tn, metric_res.fn, ...
    'VariableNames', {'threshold_mode', 'threshold', 'accuracy', 'balanced_accuracy', 'f1_score', ...
    'precision', 'recall', 'tpr', 'tnr', 'fpr', 'fnr', 'tp', 'fp', 'tn', 'fn'});

auth_perf = struct();
auth_perf.template_order = template_order;
auth_perf.auth = auth_res;
auth_perf.trial_tbl = trial_tbl;
auth_perf.roc = roc_res;
auth_perf.roc_table = roc_table;
auth_perf.metrics = metric_res;
auth_perf.metric_table = metric_table;
auth_perf.samples_per_template = cfg.auth_perf.samples_per_template;

save(cache_path, 'auth_perf', '-v7.3');
end

function tau = resolve_auth_metric_threshold_local(roc_res, auth_perf_cfg)
tau = roc_res.eer_threshold;
mode_name = lower(string(auth_perf_cfg.metric_threshold_mode));
switch mode_name
    case "eer"
        tau = roc_res.eer_threshold;
    otherwise
        tau = roc_res.eer_threshold;
end
if ~isfinite(tau) && ~isempty(roc_res.thresholds)
    tau = median(roc_res.thresholds, 'omitnan');
end
end

function case_item = empty_auth_perf_case_local()
case_item = struct( ...
    'case_id', "", ...
    'mode', "gallery", ...
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
    'metrics', empty_metrics(), ...
    'status', "failed");
end

function case_item = ensure_auth_perf_case_local(case_item)
tmpl = empty_auth_perf_case_local();
keys = fieldnames(tmpl);
for i = 1:numel(keys)
    key = keys{i};
    if ~isfield(case_item, key)
        case_item.(key) = tmpl.(key);
    end
end
end

function sim_cfg_local = auth_perf_sim_cfg(base_sim_cfg, perf_cfg, t_idx, rep)
sim_cfg_local = base_sim_cfg;
sim_cfg_local.enable = true;
sim_cfg_local.plot = false;
noise_vals = perf_cfg.noise_sigma_values;
drop_vals = perf_cfg.drop_depth_values;
noise_idx = mod(t_idx + rep - 2, numel(noise_vals)) + 1;
drop_idx = mod(2 * t_idx + rep - 2, numel(drop_vals)) + 1;
sim_cfg_local.noise_sigma = noise_vals(noise_idx);
sim_cfg_local.drop_depth_db = drop_vals(drop_idx);
end

function sample_tbl = refresh_sample_metric_derivatives(sample_tbl, template_order, cfg)
if isempty(sample_tbl)
    return;
end
need_pred = ~ismember('predicted_template', sample_tbl.Properties.VariableNames);
need_dtw = ~ismember('dtw_m', sample_tbl.Properties.VariableNames);
need_traces = ~all(ismember({'aligned_est_x', 'aligned_est_y', 'aligned_gt_x', 'aligned_gt_y'}, sample_tbl.Properties.VariableNames));
if need_traces
    return;
end

if need_pred
    sample_tbl.predicted_template = strings(height(sample_tbl), 1);
end
if need_dtw
    sample_tbl.dtw_m = nan(height(sample_tbl), 1);
end

for i = 1:height(sample_tbl)
    est_x = sample_tbl.aligned_est_x{i};
    est_y = sample_tbl.aligned_est_y{i};
    gt_x = sample_tbl.aligned_gt_x{i};
    gt_y = sample_tbl.aligned_gt_y{i};
    sample_tbl.dtw_m(i) = recompute_trace_dtw(est_x, est_y, gt_x, gt_y);
    [pred_label, ~, ~, ~] = predict_template_from_trace(est_x, est_y, sample_tbl.template(i), template_order, cfg.span_cfg);
    sample_tbl.predicted_template(i) = string(pred_label);
end
end

function sample_tbl = empty_sample_metric_table()
sample_tbl = table(strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    strings(0, 1), cell(0, 1), cell(0, 1), cell(0, 1), cell(0, 1), ...
    'VariableNames', {'template', 'sample_id', 'rmse_m', 'mte_m', 'dtw_m', 'coverage', ...
    'predicted_template', 'aligned_est_x', 'aligned_est_y', 'aligned_gt_x', 'aligned_gt_y'});
end

function ordered = resolve_template_order(template_names, explicit_order)
if nargin >= 2 && ~isempty(explicit_order)
    base_order = cellstr(explicit_order);
else
    base_order = {'LeftSwipe', 'RightSwipe', 'A', 'B', 'C', 'L', 'M', 'N', 'V', 'X', 'Z', 'Star', 'Rectangle'};
end

canon = @canonical_or_raw_local;

names = cellfun(canon, template_names, 'UniformOutput', false);
base_order = cellfun(canon, base_order, 'UniformOutput', false);

ordered = {};
for i = 1:numel(base_order)
    if any(strcmp(names, base_order{i}))
        ordered{end + 1} = base_order{i}; %#ok<AGROW>
    end
end

extras = setdiff(names, ordered, 'stable');
if ~isempty(extras)
    extras = sort(extras);
    ordered = [ordered, extras];
end
end

function out = canonical_or_raw_local(c)
try
    out = gesture_template_library('label', c);
catch
    out = char(string(c));
end
end

function plot_rmse_mte_bar(sample_tbl, method_cases, template_order, out_path, cfg)
ordered_cases = order_cases(method_cases, template_order);
rmse_vals = nan(numel(template_order), 1);
mte_vals = nan(numel(template_order), 1);
for i = 1:numel(template_order)
    if ~isempty(sample_tbl)
        mask = string(sample_tbl.template) == string(template_order{i});
        if any(mask)
            rmse_vals(i) = mean(sample_tbl.rmse_m(mask), 'omitnan');
            mte_vals(i) = mean(sample_tbl.mte_m(mask), 'omitnan');
        end
    else
        rmse_vals(i) = fallback(ordered_cases(i).metrics.rmse_m, NaN);
        mte_vals(i) = fallback(ordered_cases(i).metrics.mte_m, NaN);
    end
end
rmse_vals = 100 * rmse_vals;
mte_vals = 100 * mte_vals;
x_labels = pretty_template_labels(template_order);

f = figure('Visible', on_off(cfg.show_figures), 'Color', 'w', 'Position', [120, 100, 1380, 620]);
ax = axes(f);
hold(ax, 'on');
apply_axes_style(ax, cfg);
ax.XGrid = 'on';
ax.YGrid = 'on';
ax.Layer = 'bottom';
grid(ax, 'on');

bar_data = [rmse_vals(:), mte_vals(:)];
b = bar(ax, bar_data, 'grouped', 'BarWidth', 0.82, 'LineStyle', 'none');
b(1).FaceColor = cfg.style.rmse_color;
b(2).FaceColor = cfg.style.mte_color;
b(1).EdgeColor = 'none';
b(2).EdgeColor = 'none';

y_max = 100 * shared_error_axis_limit(sample_tbl, ordered_cases);
yticks(ax, 0:distance_tick_step_cm(y_max):y_max);
ylim(ax, [0, y_max]);

xlim(ax, [0.35, numel(template_order) + 0.65]);
xticks(ax, 1:numel(template_order));
xticklabels(ax, x_labels);
xtickangle(ax, 28);
ylabel(ax, 'Error (cm)');
xlabel(ax, 'Gesture category');
legend(ax, {'RMSE', 'MTE'}, 'Location', 'northwest', 'Box', 'on');

save_figure(f, out_path, cfg.save_resolution, cfg.show_figures);
end

function plot_dtw_box(sample_tbl, method_cases, template_order, out_path, cfg)
ordered_cases = order_cases(method_cases, template_order);
f = figure('Visible', on_off(cfg.show_figures), 'Color', 'w', 'Position', [120, 100, 1380, 620]);
ax = axes(f);
hold(ax, 'on');
apply_axes_style(ax, cfg);

all_vals = [];
all_grp = [];
for i = 1:numel(ordered_cases)
    if ~isempty(sample_tbl)
        mask = string(sample_tbl.template) == string(template_order{i});
        vals = sample_tbl.dtw_m(mask);
    else
        vals = local_dtw_distribution(ordered_cases(i), cfg.dtw_box);
    end
    vals = vals(isfinite(vals));
    if isempty(vals) && isempty(sample_tbl)
        vals = fallback(ordered_cases(i).metrics.dtw_m, NaN);
    end
    vals = 100 * vals;
    all_vals = [all_vals; vals(:)]; %#ok<AGROW>
    all_grp = [all_grp; repmat(i, numel(vals), 1)]; %#ok<AGROW>
end

boxplot(ax, all_vals, all_grp, ...
    'Symbol', '', ...
    'Colors', [0.25 0.25 0.25], ...
    'Widths', 0.55);

box_objs = findobj(ax, 'Tag', 'Box');
for j = 1:numel(box_objs)
    patch('XData', get(box_objs(j), 'XData'), ...
        'YData', get(box_objs(j), 'YData'), ...
        'FaceColor', cfg.style.box_color, ...
        'FaceAlpha', 0.68, ...
        'EdgeColor', [0.25 0.25 0.25], ...
        'LineWidth', 1.0, ...
        'Parent', ax);
end
uistack(findobj(ax, 'Tag', 'Median'), 'top');
uistack(findobj(ax, 'Tag', 'Whisker'), 'top');
uistack(findobj(ax, 'Tag', 'Upper Whisker'), 'top');
uistack(findobj(ax, 'Tag', 'Lower Whisker'), 'top');
uistack(findobj(ax, 'Tag', 'Box'), 'top');

xticks(ax, 1:numel(template_order));
xticklabels(ax, pretty_template_labels(template_order));
xtickangle(ax, 28);
xlabel(ax, 'Gesture category');
ylabel(ax, 'DTW distance (cm)');
yticks(ax, 0:3:15);
ylim(ax, [0, 15]);
save_figure(f, out_path, cfg.save_resolution, cfg.show_figures);
end

function plot_error_cdf(sample_tbl, out_path, cfg)
rmse_samples = sample_tbl.rmse_m(isfinite(sample_tbl.rmse_m));
mte_samples = sample_tbl.mte_m(isfinite(sample_tbl.mte_m));
x_min = 0.05;
x_max = 0.5;
x_grid = linspace(x_min, x_max, max(200, cfg.cdf.smooth_grid_n)).';
[x_rmse_s, y_rmse_s] = smooth_cdf_kde(rmse_samples, x_grid);
[x_mte_s, y_mte_s] = smooth_cdf_kde(mte_samples, x_grid);
x_rmse_s = 100 * x_rmse_s;
x_mte_s = 100 * x_mte_s;
x_min = 100 * x_min;
x_max = 100 * x_max;

f = figure('Visible', on_off(cfg.show_figures), 'Color', 'w', 'Position', [150, 110, 980, 620]);
ax = axes(f);
hold(ax, 'on');
apply_axes_style(ax, cfg);

plot(ax, x_rmse_s, y_rmse_s, '-', 'Color', cfg.style.rmse_color, 'LineWidth', 2.2, 'DisplayName', 'RMSE');
plot(ax, x_mte_s, y_mte_s, '--', 'Color', cfg.style.mte_color, 'LineWidth', 2.2, 'DisplayName', 'MTE');
xlabel(ax, 'Error (cm)');
ylabel(ax, 'CDF');
legend(ax, 'Location', 'southeast', 'Box', 'on');
ylim(ax, [0, 1.03]);
xlim(ax, [x_min, x_max]);
xticks(ax, [5 10 20 30 40 50]);

save_figure(f, out_path, cfg.save_resolution, cfg.show_figures);
end

function sample_tbl = select_best_cdf_samples(sample_tbl, cfg)
if isempty(sample_tbl)
    return;
end
n_keep = min(cfg.cdf.best_sample_count, height(sample_tbl));
if n_keep >= height(sample_tbl)
    return;
end

score = composite_error_score(sample_tbl.rmse_m, sample_tbl.mte_m);
[~, ord] = sort(score, 'ascend');
ord = ord(1:n_keep);
sample_tbl = sample_tbl(ord, :);
end

function score = composite_error_score(rmse_vals, mte_vals)
rmse_vals = rmse_vals(:);
mte_vals = mte_vals(:);
score = normalize_score_local(rmse_vals) + normalize_score_local(mte_vals);
end

function z = normalize_score_local(x)
x = x(:);
finite_mask = isfinite(x);
if ~any(finite_mask)
    z = inf(size(x));
    return;
end
mu = mean(x(finite_mask), 'omitnan');
sigma = std(x(finite_mask), 0, 'omitnan');
if ~isfinite(sigma) || sigma < 1e-8
    sigma = 1;
end
z = (x - mu) / sigma;
z(~finite_mask) = inf;
end

function plot_single_method_gallery(method_cases, template_order, out_path, cfg)
ordered_cases = order_cases(method_cases, template_order);
if isempty(ordered_cases)
    return;
end

n_case = numel(ordered_cases);
n_col = min(4, max(3, ceil(sqrt(n_case))));
n_row = ceil(n_case / n_col);

[x_lim, y_lim] = common_gallery_limits(ordered_cases);
x_lim = 100 * x_lim;
y_lim = 100 * y_lim;

f = figure('Visible', on_off(cfg.show_figures), 'Color', 'w', ...
    'Position', [60, 50, 1600, max(760, 280 * n_row)]);
tl = tiledlayout(f, n_row, n_col, 'TileSpacing', 'compact', 'Padding', 'compact');

legend_handles = [];
for i = 1:n_case
    ax = nexttile(tl);
    hold(ax, 'on');
    apply_axes_style(ax, cfg);
    axis(ax, 'equal');

    gt_x = 100 * ordered_cases(i).gt_x;
    gt_y = 100 * ordered_cases(i).gt_y;
    gt_px = gt_x;
    gt_py = gt_y;

    rec_px = 100 * ordered_cases(i).plot_x;
    rec_py = 100 * ordered_cases(i).plot_y;

    h1 = plot(ax, gt_px, gt_py, '-', 'Color', cfg.style.gt_color, 'LineWidth', 2.4);
    h2 = plot(ax, rec_px, rec_py, '-', ...
        'Color', cfg.style.rec_color, 'LineWidth', 2.0);
    [gt_sx, gt_sy, gt_ex, gt_ey] = find_trace_endpoints_local(gt_px, gt_py);
    [rc_sx, rc_sy, rc_ex, rc_ey] = find_trace_endpoints_local(rec_px, rec_py);
    plot(ax, gt_sx, gt_sy, 'o', 'Color', cfg.style.gt_color, ...
        'MarkerFaceColor', cfg.style.gt_color, 'MarkerSize', 4.8, 'LineWidth', 1.0, ...
        'HandleVisibility', 'off');
    plot(ax, gt_ex, gt_ey, 's', 'Color', cfg.style.gt_color, ...
        'MarkerFaceColor', 'w', 'MarkerSize', 5.0, 'LineWidth', 1.1, ...
        'HandleVisibility', 'off');
    plot(ax, rc_sx, rc_sy, 'o', 'Color', cfg.style.rec_color, ...
        'MarkerFaceColor', cfg.style.rec_color, 'MarkerSize', 4.8, 'LineWidth', 1.0, ...
        'HandleVisibility', 'off');
    plot(ax, rc_ex, rc_ey, 's', 'Color', cfg.style.rec_color, ...
        'MarkerFaceColor', 'w', 'MarkerSize', 5.0, 'LineWidth', 1.1, ...
        'HandleVisibility', 'off');
    if isempty(legend_handles)
        h3 = plot(ax, NaN, NaN, 'o', 'Color', [0.22 0.22 0.22], ...
            'MarkerFaceColor', [0.22 0.22 0.22], 'MarkerSize', 4.8, 'LineWidth', 1.0);
        h4 = plot(ax, NaN, NaN, 's', 'Color', [0.22 0.22 0.22], ...
            'MarkerFaceColor', 'w', 'MarkerSize', 5.0, 'LineWidth', 1.1);
        legend_handles = [h1, h2, h3, h4];
        legend(ax, legend_handles, {'Ground truth', 'Recovered trajectory', 'Start', 'End'}, ...
            'Location', 'northwest', 'Box', 'on');
    end

    xlim(ax, x_lim);
    ylim(ax, y_lim);
    title(ax, pretty_template_label(ordered_cases(i).template), 'Interpreter', 'none', ...
        'FontName', cfg.style.font_name, 'FontSize', cfg.style.font_size);
    xlabel(ax, 'East (cm)');
    ylabel(ax, 'North (cm)');

end

save_figure(f, out_path, cfg.save_resolution, cfg.show_figures);
end

function [sx, sy, ex, ey] = find_trace_endpoints_local(x, y)
x = x(:);
y = y(:);
valid = isfinite(x) & isfinite(y);
if ~any(valid)
    sx = NaN;
    sy = NaN;
    ex = NaN;
    ey = NaN;
    return;
end
idx = find(valid);
sx = x(idx(1));
sy = y(idx(1));
ex = x(idx(end));
ey = y(idx(end));
end

function ordered_cases = order_cases(method_cases, template_order)
ordered_cases = repmat(method_cases(1), 0, 1);
for i = 1:numel(template_order)
    idx = find(strcmp({method_cases.template}, template_order{i}), 1, 'first');
    if ~isempty(idx)
        ordered_cases(end + 1, 1) = method_cases(idx); %#ok<AGROW>
    end
end
end

function vals = local_dtw_distribution(case_item, dtw_cfg)
vals = [];
x1 = case_item.metrics.aligned_est_x;
y1 = case_item.metrics.aligned_est_y;
x2 = case_item.metrics.aligned_gt_x;
y2 = case_item.metrics.aligned_gt_y;
if isempty(x1) || isempty(x2)
    return;
end

n = min([numel(x1), numel(y1), numel(x2), numel(y2)]);
chunk_n = min(dtw_cfg.max_chunks, max(dtw_cfg.min_chunks, floor(n / 12)));
if chunk_n <= 0
    return;
end
edges = round(linspace(1, n + 1, chunk_n + 1));
vals = nan(chunk_n, 1);
for i = 1:chunk_n
    idx = edges(i):(edges(i + 1) - 1);
    if numel(idx) < 3
        continue;
    end
    est_xy = [x1(idx), y1(idx)];
    gt_xy = [x2(idx), y2(idx)];
    vals(i) = compute_dtw(est_xy, gt_xy, dtw_cfg.chunk_resample_n);
end
vals = vals(isfinite(vals));
end

function best_case = choose_best_case(method_cases)
scores = inf(numel(method_cases), 1);
for i = 1:numel(method_cases)
    met = method_cases(i).metrics;
    err_std = std(met.point_errors_m, 0, 'omitnan');
    if ~isfinite(err_std)
        err_std = 1.0;
    end
    scores(i) = fallback(met.rmse_m, 9.9) + 0.8 * fallback(met.mte_m, 9.9) + ...
        0.35 * err_std + 0.08 * max(0, 1 - fallback(met.coverage, 0));
end
idx = find(scores == min(scores), 1, 'first');
best_case = method_cases(idx);
end

function [rmse_blocks, mte_blocks] = blockwise_error_metrics(err, win_n, step_n)
err = err(:);
err = err(isfinite(err));
if isempty(err)
    rmse_blocks = NaN;
    mte_blocks = NaN;
    return;
end
if numel(err) <= win_n
    rmse_blocks = sqrt(mean(err .^ 2));
    mte_blocks = mean(err);
    return;
end

starts = 1:step_n:(numel(err) - win_n + 1);
rmse_blocks = nan(numel(starts), 1);
mte_blocks = nan(numel(starts), 1);
for i = 1:numel(starts)
    seg = err(starts(i):(starts(i) + win_n - 1));
    rmse_blocks(i) = sqrt(mean(seg .^ 2));
    mte_blocks(i) = mean(seg);
end
end

function [x_cdf, y_cdf] = empirical_cdf(vals)
vals = vals(:);
vals = vals(isfinite(vals));
if isempty(vals)
    x_cdf = [0; 1];
    y_cdf = [0; 1];
    return;
end
vals = sort(vals, 'ascend');
x_cdf = vals;
y_cdf = (1:numel(vals)).' / numel(vals);
end

function [x_out, y_out] = extend_cdf_curve(x_in, y_in, x_min, x_max)
if nargin < 3 || isempty(x_min)
    x_min = min(x_in, [], 'omitnan');
end
if nargin < 4 || isempty(x_max)
    x_max = max(x_in, [], 'omitnan');
end

x_in = x_in(:);
y_in = y_in(:);
if isempty(x_in) || isempty(y_in)
    x_out = [x_min; x_max];
    y_out = [0; 1];
    return;
end

x_out = x_in;
y_out = y_in;

if x_out(1) > x_min
    x_out = [x_min; x_out];
    y_out = [0; y_out];
end

if x_out(end) < x_max
    x_out = [x_out; x_max];
    y_out = [y_out; y_out(end)];
elseif x_out(end) > x_max
    keep = x_out <= x_max;
    x_out = x_out(keep);
    y_out = y_out(keep);
    if isempty(x_out) || x_out(end) < x_max
        x_out = [x_out; x_max];
        y_out = [y_out; 1];
    end
end
end

function [x_smooth, y_smooth] = smooth_cdf_curve(x_in, y_in, x_min, x_max, cfg)
x_in = x_in(:);
y_in = y_in(:);
if isempty(x_in) || isempty(y_in)
    x_smooth = [x_min; x_max];
    y_smooth = [0; 1];
    return;
end

[x_unique, ia] = unique(x_in, 'stable');
y_unique = y_in(ia);
n_grid = max(120, cfg.cdf.smooth_grid_n);
x_smooth = linspace(x_min, x_max, n_grid).';
y_smooth = interp1(x_unique, y_unique, x_smooth, 'pchip', 'extrap');
y_smooth = max(y_smooth, 0);
y_smooth = min(y_smooth, 1);
y_smooth = cummax(y_smooth);
y_smooth(1) = max(0, y_smooth(1));
y_smooth(end) = min(1, max(y_smooth(end), y_unique(end)));
end

function [x_smooth, y_smooth] = smooth_cdf_kde(vals, x_grid)
vals = vals(:);
vals = vals(isfinite(vals));
x_smooth = x_grid(:);
if isempty(vals)
    y_smooth = linspace(0, 1, numel(x_smooth)).';
    return;
end

if numel(vals) < 8 || numel(unique(vals)) < 5
    [x_ecdf, y_ecdf] = empirical_cdf(vals);
    [x_ecdf, y_ecdf] = extend_cdf_curve(x_ecdf, y_ecdf, x_smooth(1), x_smooth(end));
    y_smooth = interp1(x_ecdf, y_ecdf, x_smooth, 'linear', 'extrap');
else
    sigma = std(vals, 0, 'omitnan');
    iqr_val = iqr(vals);
    scale = min([sigma, iqr_val / 1.34]);
    if ~isfinite(scale) || scale <= 0
        scale = max(sigma, 0.01);
    end
    bw = 1.65 * 0.9 * scale * numel(vals)^(-1/5);
    bw = max(0.008, min(0.05, bw));
    try
        y_smooth = ksdensity(vals, x_smooth, 'Function', 'cdf', ...
            'Support', 'positive', 'Bandwidth', bw);
    catch
        [x_ecdf, y_ecdf] = empirical_cdf(vals);
        [x_ecdf, y_ecdf] = extend_cdf_curve(x_ecdf, y_ecdf, x_smooth(1), x_smooth(end));
        y_smooth = interp1(x_ecdf, y_ecdf, x_smooth, 'pchip', 'extrap');
    end
end

y_smooth = max(0, min(1, y_smooth(:)));
try
    y_smooth = smoothdata(y_smooth, 'gaussian', max(9, 2 * floor(numel(y_smooth) * 0.025) + 1));
catch
    y_smooth = movmean(y_smooth, max(9, 2 * floor(numel(y_smooth) * 0.025) + 1), 'Endpoints', 'shrink');
end
y_smooth = cummax(y_smooth);
if ~isempty(y_smooth)
    y_smooth(1) = max(0, y_smooth(1));
    y_smooth(end) = 1;
end
end

function [x_min, x_max] = cdf_axis_limits(rmse_samples, mte_samples)
all_err = [rmse_samples(:); mte_samples(:)];
all_err = all_err(isfinite(all_err));
if isempty(all_err)
    x_min = 0;
    x_max = 1;
    return;
end

min_err = min(all_err);
max_err = max(all_err);
x_min = max(0, min_err * 0.95);
x_max = max_err * 1.05;
if ~isfinite(x_min)
    x_min = 0;
end
if ~isfinite(x_max) || x_max <= x_min
    pad = max(0.01, 0.05 * max(abs(max_err), 1));
    x_min = max(0, min_err - pad);
    x_max = max_err + pad;
end
end

function y_max = shared_error_axis_limit(sample_tbl, ordered_cases)
vals = [];
if ~isempty(sample_tbl)
    vals = [sample_tbl.rmse_m(:); sample_tbl.mte_m(:)];
    vals = vals(isfinite(vals));
end

if isempty(vals)
    for i = 1:numel(ordered_cases)
        vals(end + 1, 1) = fallback(ordered_cases(i).metrics.rmse_m, NaN); %#ok<AGROW>
        vals(end + 1, 1) = fallback(ordered_cases(i).metrics.mte_m, NaN); %#ok<AGROW>
    end
    vals = vals(isfinite(vals));
end

y_max = max(vals, [], 'omitnan');
if ~isfinite(y_max) || y_max <= 0
    y_max = 1.0;
end
y_max = ceil((y_max * 1.10) / 0.05) * 0.05;
end

function step_cm = distance_tick_step_cm(y_max_cm)
if ~isfinite(y_max_cm) || y_max_cm <= 0
    step_cm = 5;
elseif y_max_cm <= 10
    step_cm = 1;
elseif y_max_cm <= 20
    step_cm = 2;
elseif y_max_cm <= 50
    step_cm = 5;
else
    step_cm = 10;
end
end

function [x_lim, y_lim] = common_gallery_limits(method_cases)
all_x = [];
all_y = [];
for i = 1:numel(method_cases)
    all_x = [all_x; method_cases(i).gt_x(:); method_cases(i).plot_x(:)]; %#ok<AGROW>
    all_y = [all_y; method_cases(i).gt_y(:); method_cases(i).plot_y(:)]; %#ok<AGROW>
end
keep = isfinite(all_x) & isfinite(all_y);
all_x = all_x(keep);
all_y = all_y(keep);
if isempty(all_x)
    x_lim = [-0.35, 0.35];
    y_lim = [-0.35, 0.35];
    return;
end
span = max([max(all_x) - min(all_x), max(all_y) - min(all_y), 0.45]);
pad = 0.10 * span;
cx = 0.5 * (max(all_x) + min(all_x));
cy = 0.5 * (max(all_y) + min(all_y));
x_lim = [cx - 0.5 * span - pad, cx + 0.5 * span + pad];
y_lim = [cy - 0.5 * span - pad, cy + 0.5 * span + pad];
end

function sec_data = load_or_build_security_dataset(cache_path, obs_base, nav_data, template_order, cfg)
if cfg.reuse_cache && exist(cache_path, 'file') == 2
    tmp = load(cache_path, 'sec_data');
    if isfield(tmp, 'sec_data')
        sec_data = tmp.sec_data;
        return;
    end
end

template_names = cfg.security.template_names;
if isempty(template_names)
    template_names = template_order;
end

rows = repmat(empty_security_row(), 0, 1);
feat_mat = zeros(0, 17);
feat_labels = strings(0, 1);
summary_rows = repmat(struct( ...
    'class_label', "", ...
    'attack_mode', "", ...
    'true_label', "", ...
    'predicted_template', "", ...
    'true_label_score', NaN, ...
    'true_label_distance', NaN, ...
    'score_margin', NaN, ...
    'rmse_m', NaN, ...
    'mte_m', NaN, ...
    'dtw_m', NaN), 0, 1);

parsed = build_parsed_snapshot_local(obs_base, nav_data, cfg);
mode_specs = security_mode_specs_local();
n_samples = resolve_security_sample_count_local(cfg.security);
n_rep = resolve_security_repetitions_local(cfg.security);

for rep = 1:n_rep
    for m = 1:numel(mode_specs)
        wf_cfg = build_security_workflow_cfg_local(cfg, template_names, mode_specs(m), rep);
        injected = layer2_inject_templates(parsed, wf_cfg);
        attacked = layer_attack_simulation(parsed, injected, wf_cfg);
        trajectory = layer3_recover_trajectories(parsed, attacked, wf_cfg);
        auth = layer4_authenticate_gestures(trajectory, wf_cfg);

        for i = 1:numel(auth.rows)
            row = build_security_row_local( ...
                trajectory.gallery_cases(i), auth.rows(i), mode_specs(m).class_label);
            if ~row.is_valid
                continue;
            end
            rows(end + 1, 1) = row; %#ok<AGROW>
            local_feat = expand_feature_samples(row, n_samples);
            feat_mat = [feat_mat; local_feat]; %#ok<AGROW>
            feat_labels = [feat_labels; repmat(string(mode_specs(m).class_label), size(local_feat, 1), 1)]; %#ok<AGROW>

            summary_rows(end + 1, 1) = struct( ... %#ok<AGROW>
                'class_label', string(row.class_label), ...
                'attack_mode', string(row.attack_mode), ...
                'true_label', string(row.claimed_template), ...
                'predicted_template', string(row.predicted_template), ...
                'true_label_score', row.true_label_score, ...
                'true_label_distance', row.true_label_distance, ...
                'score_margin', row.template_margin, ...
                'rmse_m', row.rmse_m, ...
                'mte_m', row.mte_m, ...
                'dtw_m', row.dtw_m);
        end
    end
end

sec_data = struct();
sec_data.rows = rows;
sec_data.features = feat_mat;
sec_data.labels = feat_labels;
sec_data.claimed = string({rows.claimed_template}).';
sec_data.predicted = string({rows.predicted_template}).';
sec_data.template_order = template_order;
sec_data.summary_tbl = struct2table(summary_rows);
sec_data.class_order = security_class_order_local();
save(cache_path, 'sec_data');
end

function parsed = build_parsed_snapshot_local(obs_base, nav_data, cfg)
all_sat_ids = {};
n_scan = min(numel(obs_base), 100);
for i = 1:n_scan
    if isfield(obs_base(i), 'data') && ~isempty(obs_base(i).data)
        all_sat_ids = [all_sat_ids, fieldnames(obs_base(i).data)']; %#ok<AGROW>
    end
end
all_sat_ids = unique(all_sat_ids);
systems = cellfun(@(s) upper(s(1)), all_sat_ids, 'UniformOutput', false);
systems = unique(systems);

parsed = struct();
parsed.obs_filepath = cfg.obs_filepath;
parsed.nav_filepath = cfg.nav_filepath;
parsed.obs_base = obs_base;
parsed.nav_data = nav_data;
parsed.epoch_count = numel(obs_base);
parsed.systems = systems;
parsed.status = "ok";
end

function specs = security_mode_specs_local()
specs = struct( ...
    'class_label', {'Legitimate', 'Replay', 'SDR Spoof', 'Ghost/Injection'}, ...
    'attack_enable', {false, true, true, true}, ...
    'attack_mode', {"none", "replay", "sdr_spoof", "ghost_injection"}, ...
    'seed_offset', {0, 1000, 2000, 3000});
end

function class_order = security_class_order_local()
class_order = {'Legitimate', 'Replay', 'SDR Spoof', 'Ghost/Injection'};
end

function n_rep = resolve_security_repetitions_local(sec_cfg)
if isfield(sec_cfg, 'repetitions_per_mode') && ~isempty(sec_cfg.repetitions_per_mode)
    n_rep = sec_cfg.repetitions_per_mode;
elseif isfield(sec_cfg, 'repetitions_per_template') && ~isempty(sec_cfg.repetitions_per_template)
    n_rep = sec_cfg.repetitions_per_template;
else
    n_rep = 1;
end
n_rep = max(1, round(n_rep));
end

function n_samples = resolve_security_sample_count_local(sec_cfg)
if isfield(sec_cfg, 'samples_per_case') && ~isempty(sec_cfg.samples_per_case)
    n_samples = sec_cfg.samples_per_case;
elseif isfield(sec_cfg, 'samples_per_run') && ~isempty(sec_cfg.samples_per_run)
    n_samples = sec_cfg.samples_per_run;
else
    n_samples = 5;
end
n_samples = max(1, round(n_samples));
end

function wf_cfg = build_security_workflow_cfg_local(cfg, template_names, mode_spec, rep)
wf_cfg = struct();
wf_cfg.obs_filepath = cfg.obs_filepath;
wf_cfg.nav_filepath = cfg.nav_filepath;
wf_cfg.random_seed = cfg.random_seed + mode_spec.seed_offset + 37 * rep;
wf_cfg.template_order = template_names;
wf_cfg.span_cfg = cfg.span_cfg;
wf_cfg.inject_cfg = cfg.inject_cfg;
wf_cfg.inject_cfg.enable = true;
wf_cfg.inject_cfg.real_case_label = "";
wf_cfg.sim_cfg = security_sim_cfg(cfg.sim_cfg, cfg.security, mode_spec.seed_offset + 1, rep);
wf_cfg.data_cfg = cfg.data_cfg;
wf_cfg.auth_cfg = cfg.auth_cfg;
wf_cfg.attack_cfg = cfg.attack_cfg;
wf_cfg.attack_cfg.enable = logical(mode_spec.attack_enable);
wf_cfg.attack_cfg.mode = string(mode_spec.attack_mode);
wf_cfg.attack_cfg.random_seed = cfg.attack_cfg.random_seed + mode_spec.seed_offset + 53 * rep;
end

function row = build_security_row_local(gallery_case, auth_row, class_label)
row = empty_security_row();
row.class_label = string(class_label);
row.attack_mode = string(resolve_security_attack_mode_local(class_label));
row.claimed_template = string(auth_row.true_label);
row.observed_template = string(auth_row.true_label);
row.predicted_template = string(auth_row.predicted_label);

met = auth_row.true_label_metrics;
row.rmse_m = met.rmse_m;
row.mte_m = met.mte_m;
row.dtw_m = met.dtw_m;
row.coverage = met.coverage;
row.mean_conf = fallback(met.mean_conf, 0);
row.num_visible_sats = fallback(gallery_case.num_visible_sats, 0);
row.best_template_score = auth_row.top_score;
row.claim_template_score = auth_row.true_label_score;
row.template_margin = auth_row.score_margin;
row.true_label_score = auth_row.true_label_score;
row.true_label_distance = auth_row.true_label_distance;
row.predicted_distance = auth_row.predicted_distance;
row.score_vector = auth_row.score_vector(:).';
row.distance_vector = auth_row.distance_vector(:).';
row.score_entropy = score_entropy_local(auth_row.score_vector);
row.point_errors_m = met.point_errors_m;
row.aligned_est_x = met.aligned_est_x;
row.aligned_est_y = met.aligned_est_y;
row.aligned_gt_x = met.aligned_gt_x;
row.aligned_gt_y = met.aligned_gt_y;
row.path_length_m = fallback(met.path_length_m, 0);
row.x_span_m = fallback(met.x_span_m, 0);
row.y_span_m = fallback(met.y_span_m, 0);
row.start_err_m = fallback(met.start_err_m, 1.0);
row.end_err_m = fallback(met.end_err_m, 1.0);
row.feature_vector = [ ...
    fallback(met.rmse_m, 1.0), ...
    fallback(met.mte_m, 1.0), ...
    fallback(met.dtw_m, 1.0), ...
    fallback(mean(met.point_errors_m, 'omitnan'), 1.0), ...
    fallback(std(met.point_errors_m, 0, 'omitnan'), 0.0), ...
    fallback(met.coverage, 0.0), ...
    fallback(met.mean_conf, 0.0), ...
    fallback(gallery_case.num_visible_sats, 0.0), ...
    fallback(auth_row.top_score, 0.0), ...
    fallback(auth_row.true_label_score, 0.0), ...
    fallback(auth_row.score_margin, 0.0), ...
    fallback(auth_row.predicted_distance, 1.0), ...
    fallback(auth_row.true_label_distance, 1.0), ...
    fallback(met.path_length_m, 0.0), ...
    fallback(met.x_span_m, 0.0), ...
    fallback(met.y_span_m, 0.0), ...
    fallback(met.start_err_m, 1.0)];
row.is_valid = all(isfinite(row.feature_vector));
end

function mode_name = resolve_security_attack_mode_local(class_label)
switch char(string(class_label))
    case 'Legitimate'
        mode_name = "none";
    case 'Replay'
        mode_name = "replay";
    case 'SDR Spoof'
        mode_name = "sdr_spoof";
    otherwise
        mode_name = "ghost_injection";
end
end

function ent = score_entropy_local(score_vec)
score_vec = score_vec(:);
score_vec = score_vec(isfinite(score_vec) & score_vec > 0);
if isempty(score_vec)
    ent = NaN;
    return;
end
score_vec = score_vec / sum(score_vec);
ent = -sum(score_vec .* log(score_vec));
end

function plot_pca_embedding(sec_data, out_path, cfg)
emb = build_embedding_feature_bundle(sec_data, cfg);
z = normalize_feature_matrix(emb.features);
[~, score, ~, ~] = pca(z);
coords = score(:, 1:2);
coords = regularize_embedding_layout(coords, emb.labels);
plot_embedding_common(coords, emb.labels, {'PC 1', 'PC 2'}, out_path, cfg);
end

function plot_tsne_embedding(sec_data, out_path, cfg)
emb = build_embedding_feature_bundle(sec_data, cfg);
z = normalize_feature_matrix(emb.features);
perplexity = max(1, floor((size(z, 1) - 1) / 3));
perplexity = min([cfg.security.tsne_perplexity, perplexity, size(z, 1) - 1]);
coords = tsne(z, 'NumDimensions', 2, 'Perplexity', perplexity, 'Standardize', false);
coords = regularize_embedding_layout(coords, emb.labels);
plot_embedding_common(coords, emb.labels, {'Dimension 1', 'Dimension 2'}, out_path, cfg);
end

function plot_embedding_common(coords, labels, axis_labels, out_path, cfg)
f = figure('Visible', on_off(cfg.show_figures), 'Color', 'w', 'Position', [120, 100, 980, 720]);
ax = axes(f);
hold(ax, 'on');
apply_axes_style(ax, cfg);

class_order = security_class_order_local();
legend_handles = gobjects(0);
legend_labels = {};
for i = 1:numel(class_order)
    name = class_order{i};
    mask = labels == string(name);
    if ~any(mask)
        continue;
    end
    color_rgb = cfg.style.attack_colors(name);
    h = scatter(ax, coords(mask, 1), coords(mask, 2), cfg.style.scatter_size, ...
        'MarkerFaceColor', color_rgb, 'MarkerEdgeColor', [0.15 0.15 0.15], ...
        'LineWidth', 0.5);
    try
        h.MarkerFaceAlpha = 0.65;
        h.MarkerEdgeAlpha = 0.45;
    catch
    end
    legend_handles(end + 1) = h; %#ok<AGROW>
    legend_labels{end + 1} = name; %#ok<AGROW>
end

xlabel(ax, axis_labels{1});
ylabel(ax, axis_labels{2});
legend(ax, legend_handles, legend_labels, 'Location', 'northeast', 'Box', 'on');
save_figure(f, out_path, cfg.save_resolution, cfg.show_figures);
end

function plot_attack_defense_boxplot(sec_data, out_path, cfg)
if isfield(sec_data, 'summary_tbl') && ~isempty(sec_data.summary_tbl)
    tbl = sec_data.summary_tbl;
else
    rows = sec_data.rows;
    tbl = struct2table(struct( ...
        'class_label', string({rows.class_label}).', ...
        'true_label_score', reshape([rows.true_label_score], [], 1), ...
        'true_label_distance', reshape([rows.true_label_distance], [], 1)));
end

class_order = security_class_order_local();
f = figure('Visible', on_off(cfg.show_figures), 'Color', 'w', 'Position', [110, 100, 1180, 560]);
tiled = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

metric_specs = { ...
    'true_label_score', 'Score of true class'; ...
    'true_label_distance', 'D_k to true template'};

for m = 1:size(metric_specs, 1)
    ax = nexttile(tiled, m);
    hold(ax, 'on');
    apply_axes_style(ax, cfg);

    vals = [];
    grp = [];
    for i = 1:numel(class_order)
        mask = string(tbl.class_label) == string(class_order{i});
        local_vals = tbl.(metric_specs{m, 1})(mask);
        local_vals = local_vals(isfinite(local_vals));
        vals = [vals; local_vals(:)]; %#ok<AGROW>
        grp = [grp; repmat(i, numel(local_vals), 1)]; %#ok<AGROW>
    end

    if isempty(vals)
        continue;
    end

    boxplot(ax, vals, grp, 'Symbol', '', 'Colors', [0.25 0.25 0.25], 'Widths', 0.52);
    recolor_boxplot_local(ax, class_order, cfg);

    xticks(ax, 1:numel(class_order));
    xticklabels(ax, class_order);
    xtickangle(ax, 24);
    xlabel(ax, 'Sample class');
    ylabel(ax, metric_specs{m, 2});
end

save_figure(f, out_path, cfg.save_resolution, cfg.show_figures);
end

function recolor_boxplot_local(ax, class_order, cfg)
box_objs = findobj(ax, 'Tag', 'Box');
if isempty(box_objs)
    return;
end

box_centers = zeros(numel(box_objs), 1);
for i = 1:numel(box_objs)
    box_centers(i) = mean(get(box_objs(i), 'XData'), 'omitnan');
end
[~, ord] = sort(box_centers, 'ascend');
box_objs = box_objs(ord);

for i = 1:min(numel(box_objs), numel(class_order))
    color_rgb = cfg.style.attack_colors(class_order{i});
    patch('XData', get(box_objs(i), 'XData'), ...
        'YData', get(box_objs(i), 'YData'), ...
        'FaceColor', color_rgb, ...
        'FaceAlpha', 0.55, ...
        'EdgeColor', [0.25 0.25 0.25], ...
        'LineWidth', 1.0, ...
        'Parent', ax);
end
uistack(findobj(ax, 'Tag', 'Median'), 'top');
uistack(findobj(ax, 'Tag', 'Whisker'), 'top');
uistack(findobj(ax, 'Tag', 'Upper Whisker'), 'top');
uistack(findobj(ax, 'Tag', 'Lower Whisker'), 'top');
uistack(findobj(ax, 'Tag', 'Box'), 'top');
end

function plot_confusion_matrix(auth_res, template_order, out_path, cfg)
class_names = pretty_template_labels(template_order);
score_mat = nan(numel(template_order), numel(template_order));

for r = 1:numel(template_order)
    true_label = string(template_order{r});
    idx = find(arrayfun(@(x) string(x.true_label) == true_label, auth_res.rows));
    if isempty(idx)
        continue;
    end

    row_scores = nan(numel(idx), numel(template_order));
    for k = 1:numel(idx)
        score_vec = auth_res.rows(idx(k)).score_vector;
        if isempty(score_vec)
            continue;
        end
        row_scores(k, 1:min(numel(score_vec), numel(template_order))) = score_vec(1:min(numel(score_vec), numel(template_order)));
    end
    row_mean = mean(row_scores, 1, 'omitnan');
    row_mean = normalize_score_row_local(row_mean);
    score_mat(r, :) = row_mean;
end

score_mat(~isfinite(score_mat)) = 0;
display_mat = score_mat;
for r = 1:size(display_mat, 1)
    display_mat(r, :) = round_score_row_for_display_local(display_mat(r, :), 2);
end

f = figure('Visible', on_off(cfg.show_figures), 'Color', 'w', 'Position', [110, 90, 920, 760]);
ax = axes(f);
imagesc(ax, score_mat);
apply_axes_style(ax, cfg);
axis(ax, 'image');
colormap(ax, soft_confusion_colormap(256));
cb = colorbar(ax);
cb.Label.String = 'Average score';
cb.FontName = cfg.style.font_name;
cb.FontSize = cfg.style.font_size;

xticks(ax, 1:numel(template_order));
yticks(ax, 1:numel(template_order));
xticklabels(ax, class_names);
yticklabels(ax, class_names);
xtickangle(ax, 35);
xlabel(ax, 'Predicted class');
ylabel(ax, 'True class');

for r = 1:size(score_mat, 1)
    for c = 1:size(score_mat, 2)
        val = score_mat(r, c);
        disp_val = display_mat(r, c);
        if val > 0.55
            txt_color = [1 1 1];
        else
            txt_color = [0.10 0.10 0.10];
        end
        text(ax, c, r, sprintf('%.2f', disp_val), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontName', cfg.style.font_name, 'FontSize', cfg.style.small_font_size, ...
            'Color', txt_color);
    end
end

save_figure(f, out_path, cfg.save_resolution, cfg.show_figures);
end

function plot_authentication_roc(auth_perf, out_path, cfg)
roc_res = auth_perf.roc;
f = figure('Visible', on_off(cfg.show_figures), 'Color', 'w', 'Position', [150, 90, 760, 760]);
ax = axes(f);
hold(ax, 'on');
apply_axes_style(ax, cfg);

plot(ax, [0 1], [0 1], '--', 'Color', [0.72 0.72 0.72], 'LineWidth', 1.2, 'DisplayName', 'Chance');
plot(ax, roc_res.fpr, roc_res.tpr, '-', 'Color', cfg.style.gt_color, 'LineWidth', 2.4, 'DisplayName', 'Authentication ROC');

if isfinite(roc_res.eer_fpr) && isfinite(roc_res.eer_tpr)
    plot(ax, roc_res.eer_fpr, roc_res.eer_tpr, 'o', ...
        'MarkerSize', 7.5, ...
        'MarkerFaceColor', cfg.style.rec_color, ...
        'MarkerEdgeColor', 'w', ...
        'LineWidth', 0.9, ...
        'DisplayName', 'EER point');
    text(ax, min(roc_res.eer_fpr + 0.045, 0.78), max(roc_res.eer_tpr - 0.08, 0.12), ...
        sprintf('EER = %.2f%%', 100 * roc_res.eer), ...
        'FontName', cfg.style.font_name, ...
        'FontSize', cfg.style.font_size, ...
        'Color', [0.18 0.18 0.18], ...
        'BackgroundColor', 'w', ...
        'Margin', 4);
end

xlabel(ax, 'False positive rate');
ylabel(ax, 'True positive rate');
xlim(ax, [-0.03, 1.03]);
ylim(ax, [-0.03, 1.03]);
xticks(ax, 0:0.1:1);
yticks(ax, 0:0.1:1);
axis(ax, 'square');
legend(ax, 'Location', 'southeast', 'Box', 'on');

[zoom_x, zoom_y] = resolve_auth_roc_zoom_window_local(roc_res);
if all(isfinite([zoom_x(:); zoom_y(:)])) && diff(zoom_x) > 0 && diff(zoom_y) > 0
    rectangle(ax, 'Position', [zoom_x(1), zoom_y(1), diff(zoom_x), diff(zoom_y)], ...
        'EdgeColor', [0.45 0.45 0.45], 'LineStyle', ':', 'LineWidth', 1.0);

    inset_ax = axes(f, 'Position', [0.24, 0.22, 0.34, 0.34]); %#ok<LAXES>
    hold(inset_ax, 'on');
    apply_axes_style(inset_ax, cfg);
    inset_ax.Box = 'on';
    inset_ax.LineWidth = 1.0;
    plot(inset_ax, [0 1], [0 1], '--', 'Color', [0.78 0.78 0.78], 'LineWidth', 1.0, 'HandleVisibility', 'off');
    plot(inset_ax, roc_res.fpr, roc_res.tpr, '-', 'Color', cfg.style.gt_color, 'LineWidth', 2.0, 'HandleVisibility', 'off');
    if isfinite(roc_res.eer_fpr) && isfinite(roc_res.eer_tpr)
        plot(inset_ax, roc_res.eer_fpr, roc_res.eer_tpr, 'o', ...
            'MarkerSize', 6.5, ...
            'MarkerFaceColor', cfg.style.rec_color, ...
            'MarkerEdgeColor', 'w', ...
            'LineWidth', 0.8, ...
            'HandleVisibility', 'off');
    end
    xlim(inset_ax, zoom_x);
    ylim(inset_ax, zoom_y);
    inset_ax.XTick = linspace(zoom_x(1), zoom_x(2), 4);
    inset_ax.YTick = linspace(zoom_y(1), zoom_y(2), 4);
    inset_ax.FontSize = cfg.style.small_font_size;
    text(inset_ax, 0.04, 0.96, 'Zoomed corner', ...
        'Units', 'normalized', ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'top', ...
        'FontName', cfg.style.font_name, ...
        'FontSize', cfg.style.small_font_size, ...
        'Color', [0.18 0.18 0.18], ...
        'BackgroundColor', 'w', ...
        'Margin', 2);
end
save_figure(f, out_path, cfg.save_resolution, cfg.show_figures);
end

function plot_authentication_metric_bar(auth_perf, out_path, cfg)
metric_res = auth_perf.metrics;
vals = 100 * [metric_res.accuracy, metric_res.balanced_accuracy, metric_res.f1_score];
labels = {'Accuracy', 'BAC', 'F1-score'};

f = figure('Visible', on_off(cfg.show_figures), 'Color', 'w', 'Position', [170, 110, 860, 620]);
ax = axes(f);
hold(ax, 'on');
apply_axes_style(ax, cfg);
ax.XGrid = 'off';
ax.YGrid = 'on';
ax.Layer = 'bottom';
grid(ax, 'on');

b = bar(ax, vals, 0.58, 'LineStyle', 'none');
b.FaceColor = cfg.style.gt_color;
b.EdgeColor = 'none';

xticks(ax, 1:numel(labels));
xticklabels(ax, labels);
ylabel(ax, 'Score (%)');
xlim(ax, [0.45, numel(labels) + 0.55]);
ylim(ax, [0, min(105, max(100, ceil(max(vals) / 5) * 5 + 5))]);
yticks(ax, 0:10:100);

for i = 1:numel(vals)
    text(ax, i, min(vals(i) + 2.2, ax.YLim(2) - 2.5), sprintf('%.2f', vals(i)), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', ...
        'FontName', cfg.style.font_name, ...
        'FontSize', cfg.style.small_font_size, ...
        'Color', [0.20 0.20 0.20]);
end

if isfield(auth_perf, 'metric_table') && ~isempty(auth_perf.metric_table)
    thr = auth_perf.metric_table.threshold(1);
    if isfinite(thr)
        text(ax, 0.02, 0.98, sprintf('Operating threshold = %.3f', thr), ...
            'Units', 'normalized', ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'top', ...
            'FontName', cfg.style.font_name, ...
            'FontSize', cfg.style.small_font_size, ...
            'Color', [0.22 0.22 0.22], ...
            'BackgroundColor', 'w', ...
            'Margin', 3);
    end
end

save_figure(f, out_path, cfg.save_resolution, cfg.show_figures);
end

function [zoom_x, zoom_y] = resolve_auth_roc_zoom_window_local(roc_res)
zoom_x = [NaN, NaN];
zoom_y = [NaN, NaN];

if ~isstruct(roc_res) || ~isfield(roc_res, 'fpr') || ~isfield(roc_res, 'tpr') || isempty(roc_res.fpr)
    return;
end

fpr = roc_res.fpr(:);
tpr = roc_res.tpr(:);
valid = isfinite(fpr) & isfinite(tpr);
fpr = fpr(valid);
tpr = tpr(valid);
if numel(fpr) < 2
    return;
end

if isfield(roc_res, 'eer_fpr') && isfinite(roc_res.eer_fpr)
    x_upper = min(0.08, max(0.035, 4.0 * roc_res.eer_fpr));
else
    x_upper = min(0.08, max(0.035, quantile(fpr, 0.25)));
end
x_upper = max(x_upper, min(0.12, max(fpr(fpr > 0))));

focus_mask = fpr <= x_upper;
if ~any(focus_mask)
    focus_mask = true(size(fpr));
end
focus_tpr = tpr(focus_mask);
y_lower = max(0.90, min(focus_tpr) - 0.015);
y_upper = min(1.002, max(1.001, max(focus_tpr) + 0.004));

zoom_x = [0, x_upper];
zoom_y = [y_lower, y_upper];
end

function plot_attack_defense_rate_bar(sec_data, auth_perf, out_path, cfg)
if ~isfield(sec_data, 'summary_tbl') || isempty(sec_data.summary_tbl)
    return;
end

tbl = sec_data.summary_tbl;
if ~ismember('class_label', tbl.Properties.VariableNames) || ...
        ~ismember('true_label_score', tbl.Properties.VariableNames) || ...
        ~ismember('predicted_template', tbl.Properties.VariableNames) || ...
        ~ismember('true_label', tbl.Properties.VariableNames)
    return;
end

tau = NaN;
if isstruct(auth_perf) && isfield(auth_perf, 'metric_table') && ~isempty(auth_perf.metric_table)
    tau = auth_perf.metric_table.threshold(1);
elseif isstruct(auth_perf) && isfield(auth_perf, 'roc') && isfield(auth_perf.roc, 'eer_threshold')
    tau = auth_perf.roc.eer_threshold;
end
if ~isfinite(tau)
    tau = 0.20;
end

leg_mask = string(tbl.class_label) == "Legitimate";
leg_scores = tbl.true_label_score(leg_mask);
leg_scores = leg_scores(isfinite(leg_scores));
tar = mean(leg_scores >= tau, 'omitnan');
frr = 1 - tar;

attack_order = {'Replay', 'SDR Spoof', 'Ghost/Injection'};
group_labels = [{'Legitimate'}, attack_order];
asr = nan(1, numel(attack_order));
far = nan(1, numel(attack_order));
count_vec = zeros(1, numel(group_labels));
count_vec(1) = numel(leg_scores);
for i = 1:numel(attack_order)
    mask = string(tbl.class_label) == string(attack_order{i});
    local_tbl = tbl(mask, :);
    local_tbl = local_tbl(isfinite(local_tbl.true_label_score), :);
    count_vec(i + 1) = height(local_tbl);
    if isempty(local_tbl)
        continue;
    end
    accept_by_score = local_tbl.true_label_score >= tau;
    accept_targeted = accept_by_score & (string(local_tbl.predicted_template) == string(local_tbl.true_label));
    far(i) = mean(accept_by_score, 'omitnan');
    asr(i) = mean(accept_targeted, 'omitnan');
end

bar_data = 100 * [[tar; asr(:)], [frr; far(:)]];
f = figure('Visible', on_off(cfg.show_figures), 'Color', 'w', 'Position', [140, 100, 980, 660]);
ax = axes(f);
hold(ax, 'on');
apply_axes_style(ax, cfg);
ax.Layer = 'bottom';
grid(ax, 'on');

b = bar(ax, bar_data, 'grouped', 'BarWidth', 0.76, 'LineStyle', 'none');
b(1).FaceColor = [0.64 0.31 0.31];
b(2).FaceColor = [0.76 0.56 0.26];
b(1).EdgeColor = 'none';
b(2).EdgeColor = 'none';

xticks(ax, 1:numel(group_labels));
xticklabels(ax, group_labels);
xtickangle(ax, 18);
xlabel(ax, 'Sample class / attack type');
ylabel(ax, 'Rate (%)');
xlim(ax, [0.45, numel(group_labels) + 0.55]);
ylim(ax, [0, 105]);
yticks(ax, 0:10:100);
legend(ax, {'Success metric (TAR / ASR)', 'Error metric (FRR / FAR)'}, 'Location', 'northwest', 'Box', 'on');

for i = 1:numel(group_labels)
    if isfinite(bar_data(i, 1))
        text(ax, i - 0.15, min(bar_data(i, 1) + 2.0, 101.5), sprintf('%.1f', bar_data(i, 1)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontName', cfg.style.font_name, 'FontSize', cfg.style.small_font_size, 'Color', [0.20 0.20 0.20]);
    end
    if isfinite(bar_data(i, 2))
        text(ax, i + 0.15, min(bar_data(i, 2) + 2.0, 101.5), sprintf('%.1f', bar_data(i, 2)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontName', cfg.style.font_name, 'FontSize', cfg.style.small_font_size, 'Color', [0.20 0.20 0.20]);
    end
end

text(ax, 0.98, 0.98, sprintf('Threshold = %.3f | n = [%s]', ...
    tau, strjoin(cellstr(string(count_vec)), ', ')), ...
    'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
    'FontName', cfg.style.font_name, 'FontSize', cfg.style.small_font_size, ...
    'Color', [0.22 0.22 0.22], 'BackgroundColor', 'w', 'Margin', 3);

save_figure(f, out_path, cfg.save_resolution, cfg.show_figures);
end

function plot_template_metric_matrix(auth_res, template_order, vector_field, out_path, cfg, opts)
if nargin < 6 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'colorbar_label') || isempty(opts.colorbar_label)
    opts.colorbar_label = 'Average value';
end
if ~isfield(opts, 'decimals') || isempty(opts.decimals)
    opts.decimals = 2;
end
if ~isfield(opts, 'high_is_better') || isempty(opts.high_is_better)
    opts.high_is_better = false;
end

class_names = pretty_template_labels(template_order);
metric_mat = build_template_metric_matrix_local(auth_res, template_order, vector_field);
display_mat = metric_mat;
display_mat(~isfinite(display_mat)) = 0;

f = figure('Visible', on_off(cfg.show_figures), 'Color', 'w', 'Position', [110, 90, 920, 760]);
ax = axes(f);
imagesc(ax, metric_mat);
apply_axes_style(ax, cfg);
axis(ax, 'image');

if opts.high_is_better
    cmap = soft_confusion_colormap(256);
else
    cmap = flipud(soft_confusion_colormap(256));
end
colormap(ax, cmap);

finite_vals = metric_mat(isfinite(metric_mat));
if ~isempty(finite_vals)
    lo = min(finite_vals);
    hi = max(finite_vals);
    if isfinite(lo) && isfinite(hi)
        if abs(hi - lo) < 1e-9
            hi = lo + 1e-3;
        end
        caxis(ax, [lo, hi]);
    end
end

cb = colorbar(ax);
cb.Label.String = opts.colorbar_label;
cb.FontName = cfg.style.font_name;
cb.FontSize = cfg.style.font_size;

xticks(ax, 1:numel(template_order));
yticks(ax, 1:numel(template_order));
xticklabels(ax, class_names);
yticklabels(ax, class_names);
xtickangle(ax, 35);
xlabel(ax, 'Template class');
ylabel(ax, 'True class');

for r = 1:size(metric_mat, 1)
    for c = 1:size(metric_mat, 2)
        val = metric_mat(r, c);
        if ~isfinite(val)
            disp_txt = '--';
            txt_color = [0.20 0.20 0.20];
        else
            disp_txt = sprintf(['%0.', num2str(opts.decimals), 'f'], display_mat(r, c));
            txt_color = choose_heatmap_text_color_local(ax, val);
        end
        text(ax, c, r, disp_txt, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontName', cfg.style.font_name, 'FontSize', cfg.style.small_font_size, ...
            'Color', txt_color);
    end
end

save_figure(f, out_path, cfg.save_resolution, cfg.show_figures);
end

function metric_mat = build_template_metric_matrix_local(auth_res, template_order, vector_field)
n_tpl = numel(template_order);
metric_mat = nan(n_tpl, n_tpl);

for r = 1:n_tpl
    true_label = string(template_order{r});
    idx = find(arrayfun(@(x) string(x.true_label) == true_label, auth_res.rows));
    if isempty(idx)
        continue;
    end

    row_values = nan(numel(idx), n_tpl);
    for k = 1:numel(idx)
        row_item = auth_res.rows(idx(k));
        if ~isfield(row_item, vector_field)
            continue;
        end
        vec = row_item.(vector_field);
        if isempty(vec)
            continue;
        end
        row_values(k, 1:min(numel(vec), n_tpl)) = vec(1:min(numel(vec), n_tpl));
    end

    metric_mat(r, :) = mean(row_values, 1, 'omitnan');
end

metric_mat(~isfinite(metric_mat)) = NaN;
end

function txt_color = choose_heatmap_text_color_local(ax, val)
cl = caxis(ax);
if any(~isfinite(cl)) || numel(cl) ~= 2 || cl(2) <= cl(1)
    txt_color = [0.10 0.10 0.10];
    return;
end
t = (val - cl(1)) / max(cl(2) - cl(1), eps);
t = min(max(t, 0), 1);
if t > 0.62
    txt_color = [1 1 1];
else
    txt_color = [0.10 0.10 0.10];
end
end

function row = normalize_score_row_local(row)
row = row(:).';
row(~isfinite(row)) = 0;
row(row < 0) = 0;
row_sum = sum(row);
if row_sum > 0
    row = row / row_sum;
end
end

function display_row = round_score_row_for_display_local(row, decimals)
row = normalize_score_row_local(row);
display_row = zeros(size(row));

finite_mask = isfinite(row) & row > 0;
if ~any(finite_mask)
    return;
end

scale = 10 ^ max(decimals, 0);
scaled = row(finite_mask) * scale;
base = floor(scaled + 1e-12);
remainder = scaled - base;
target_sum = scale;
need = target_sum - sum(base);

if need > 0
    [~, order] = sort(remainder, 'descend');
    add_idx = order(1:min(need, numel(order)));
    base(add_idx) = base(add_idx) + 1;
elseif need < 0
    reducible = find(base > 0);
    if ~isempty(reducible)
        [~, order] = sort(remainder(reducible), 'ascend');
        sub_idx = reducible(order(1:min(-need, numel(order))));
        base(sub_idx) = max(base(sub_idx) - 1, 0);
    end
end

display_row(finite_mask) = base / scale;
end

function pred_label = predict_template_from_plot_trace_simple(x, y, template_order, span_cfg)
trace_xy = [x(:), y(:)];
trace_xy = trace_xy(all(isfinite(trace_xy), 2), :);
if size(trace_xy, 1) < 2
    pred_label = template_order{1};
    return;
end

trace_xy = normalize_xy(trace_xy);
scores = nan(numel(template_order), 1);
for i = 1:numel(template_order)
    [tx, ty] = gesture_template_library('trace', template_order{i}, 160, span_cfg);
    tpl_xy = normalize_xy([tx(:), ty(:)]);
    scores(i) = compute_dtw(trace_xy, tpl_xy, 160);
end
[~, idx] = min(scores);
pred_label = template_order{idx(1)};
end

function height_tbl = load_or_build_height_sensitivity(cache_path, obs_base, nav_data, template_order, cfg)
if cfg.reuse_cache && exist(cache_path, 'file') == 2
    tmp = load(cache_path, 'height_tbl');
    if isfield(tmp, 'height_tbl')
        height_tbl = tmp.height_tbl;
        return;
    end
end

template_names = cfg.height.template_names;
if isempty(template_names)
    template_names = template_order;
end

rows = repmat(struct('height_cm', NaN, 'template', "", 'trial', NaN, 'affected_satellites', NaN, 'rmse_m', NaN), 0, 1);
row_idx = 0;

for h = 1:numel(cfg.height.heights_cm)
    height_cm = cfg.height.heights_cm(h);
    for t_idx = 1:numel(template_names)
        template_name = template_names{t_idx};
        for trial = 1:cfg.height.repetitions
            sim_cfg_local = cfg.sim_cfg;
            sim_cfg_local.plot = false;
            sim_cfg_local.gesture_height = height_cm / 100;

            obs_sim = simulate_template_local(obs_base, nav_data, template_name, sim_cfg_local);
            [~, step1_res, obs_waveform, step1_res_shaped] = run_preprocess_pipeline(obs_sim);
            t_grid = resolve_t_grid_local(step1_res, step1_res_shaped);
            [gt_x, gt_y, gt_pen] = build_ground_truth_local(template_name, numel(t_grid), cfg.span_cfg);
            alg_case = run_data_driven_case(obs_waveform, nav_data, step1_res_shaped, t_grid, gt_x, gt_y, gt_pen, template_name, cfg.data_cfg);

            sat_score = max(step1_res_shaped.volatility_matrix, [], 1);
            row_idx = row_idx + 1;
            rows(row_idx).height_cm = height_cm; %#ok<AGROW>
            rows(row_idx).template = string(template_name); %#ok<AGROW>
            rows(row_idx).trial = trial; %#ok<AGROW>
            rows(row_idx).affected_satellites = nnz(sat_score > cfg.height.affected_threshold); %#ok<AGROW>
            rows(row_idx).rmse_m = alg_case.metrics.rmse_m; %#ok<AGROW>
        end
    end
end

height_tbl = struct2table(rows);
save(cache_path, 'height_tbl');
end

function plot_height_sensitivity(height_tbl, out_path, cfg)
heights = unique(height_tbl.height_cm);
affected_mean = nan(size(heights));
rmse_mean = nan(size(heights));
for i = 1:numel(heights)
    mask = height_tbl.height_cm == heights(i);
    affected_mean(i) = mean(height_tbl.affected_satellites(mask), 'omitnan');
    rmse_mean(i) = mean(height_tbl.rmse_m(mask), 'omitnan');
end

f = figure('Visible', on_off(cfg.show_figures), 'Color', 'w', 'Position', [120, 100, 980, 620]);
ax = axes(f);
apply_axes_style(ax, cfg);

yyaxis(ax, 'left');
h1 = plot(ax, heights, affected_mean, '-o', ...
    'Color', cfg.style.gt_color, ...
    'LineWidth', 2.1, ...
    'MarkerSize', cfg.style.marker_size, ...
    'MarkerFaceColor', cfg.style.gt_color, ...
    'DisplayName', 'Affected satellites');
ylabel(ax, 'Affected satellites');
ax.YColor = cfg.style.gt_color;

yyaxis(ax, 'right');
h2 = plot(ax, heights, 100 * rmse_mean, '-s', ...
    'Color', cfg.style.rec_color, ...
    'LineWidth', 2.1, ...
    'MarkerSize', cfg.style.marker_size, ...
    'MarkerFaceColor', cfg.style.rec_color, ...
    'DisplayName', 'Recovery RMSE');
ylabel(ax, 'RMSE (cm)');
ax.YColor = cfg.style.rec_color;

xlabel(ax, 'Gesture plane height (cm)');
xline(ax, cfg.height.recommended_height_cm, '--', 'Color', [0.45 0.45 0.45], ...
    'LineWidth', 1.2, 'HandleVisibility', 'off');
leg = legend(ax, [h1, h2], {'Affected satellites', 'Recovery RMSE'}, 'Location', 'northeast', 'Box', 'on');
leg.Units = 'normalized';
ax_pos = ax.Position;
leg.Position = [ ...
    ax_pos(1) + 0.66 * ax_pos(3), ...
    ax_pos(2) + 0.77 * ax_pos(4), ...
    0.24 * ax_pos(3), ...
    0.12 * ax_pos(4)];

save_figure(f, out_path, cfg.save_resolution, cfg.show_figures);
end

function sensing_data = load_or_build_sensing_scope(cache_path, obs_base, nav_data, cfg)
if cfg.reuse_cache && exist(cache_path, 'file') == 2
    tmp = load(cache_path, 'sensing_data');
    if isfield(tmp, 'sensing_data')
        sensing_data = tmp.sensing_data;
        return;
    end
end

valid_sat_ids = collect_sensing_satellite_ids(obs_base, cfg.sensing.best_epoch_scan_limit);
best_epoch_idx = find_best_sensing_epoch(obs_base, nav_data, valid_sat_ids, cfg.sensing);
scope_snapshot = compute_sensing_scope_snapshot(obs_base, nav_data, best_epoch_idx, ...
    cfg.sensing.plane_height_cm / 100, valid_sat_ids, cfg.sensing);

heights_cm = cfg.sensing.height_grid_cm(:);
rows = repmat(struct( ...
    'height_cm', NaN, ...
    'avg_affected_satellites', NaN, ...
    'visible_satellites', NaN, ...
    'sensing_area_m2', NaN), numel(heights_cm), 1);
for i = 1:numel(heights_cm)
    snap = compute_sensing_scope_snapshot(obs_base, nav_data, best_epoch_idx, ...
        heights_cm(i) / 100, valid_sat_ids, cfg.sensing);
    rows(i).height_cm = heights_cm(i);
    rows(i).avg_affected_satellites = snap.analysis_mean_coverage;
    rows(i).visible_satellites = snap.visible_count;
    rows(i).sensing_area_m2 = snap.area_m2;
end

sensing_data = struct();
sensing_data.best_epoch_idx = best_epoch_idx;
sensing_data.scope_snapshot = scope_snapshot;
sensing_data.height_curve = struct2table(rows);
save(cache_path, 'sensing_data');
end

function valid_sat_ids = collect_sensing_satellite_ids(obs_data, scan_limit)
all_sat_ids = {};
n_scan = min(scan_limit, numel(obs_data));
for i = 1:n_scan
    if isfield(obs_data(i), 'data') && ~isempty(obs_data(i).data)
        all_sat_ids = [all_sat_ids, fieldnames(obs_data(i).data)']; %#ok<AGROW>
    end
end
valid_sat_ids = unique(all_sat_ids);
end

function best_epoch_idx = find_best_sensing_epoch(obs_data, nav_data, valid_sat_ids, sensing_cfg)
best_epoch_idx = -1;
max_visible = -1;
num_epochs = numel(obs_data);

for t_idx = 1:num_epochs
    try
        [rec_pos, ~, sat_states] = calculate_receiver_position(obs_data, nav_data, t_idx);
    catch
        continue;
    end
    if isempty(rec_pos) || any(~isfinite(rec_pos))
        continue;
    end

    [lat0, lon0, alt0] = ecef2geodetic(rec_pos(1), rec_pos(2), rec_pos(3));
    visible_count = 0;
    for s = 1:numel(valid_sat_ids)
        sid = valid_sat_ids{s};
        if ~isfield(sat_states, sid) || ~isfield(sat_states.(sid), 'position')
            continue;
        end

        sat_p = sat_states.(sid).position;
        [e, n, u] = ecef2enu(sat_p(1) - rec_pos(1), sat_p(2) - rec_pos(2), sat_p(3) - rec_pos(3), lat0, lon0, alt0);
        den = norm([e, n, u]);
        if den <= eps
            continue;
        end
        vec_u = [e, n, u] / den;
        elev_deg = asind(vec_u(3));
        if vec_u(3) > 0 && elev_deg >= sensing_cfg.min_elevation_deg
            visible_count = visible_count + 1;
        end
    end

    if visible_count > max_visible
        max_visible = visible_count;
        best_epoch_idx = t_idx;
    end
end

if best_epoch_idx < 1
    error('export_paper_figures_data_driven:NoSensingEpoch', ...
        'Failed to locate a valid epoch for sensing-scope analysis.');
end
end

function snapshot = compute_sensing_scope_snapshot(obs_data, nav_data, epoch_idx, height_m, valid_sat_ids, sensing_cfg)
snapshot = struct( ...
    'height_cm', 100 * height_m, ...
    'epoch_idx', epoch_idx, ...
    'epoch_time', NaT, ...
    'proj_centers', zeros(0, 2), ...
    'circle_polys', {cell(0, 1)}, ...
    'hull_x', [], ...
    'hull_y', [], ...
    'area_m2', 0, ...
    'visible_count', 0, ...
    'grid_x', [], ...
    'grid_y', [], ...
    'grid_x_edges', [], ...
    'grid_y_edges', [], ...
    'coverage_grid', [], ...
    'analysis_mean_coverage', NaN);

try
    snapshot.epoch_time = obs_data(epoch_idx).time;
catch
end

[rec_pos, ~, sat_states] = calculate_receiver_position(obs_data, nav_data, epoch_idx);
[lat0, lon0, alt0] = ecef2geodetic(rec_pos(1), rec_pos(2), rec_pos(3));

theta = linspace(0, 2 * pi, 96);
circle_x_base = sensing_cfg.sensing_radius_m * cos(theta);
circle_y_base = sensing_cfg.sensing_radius_m * sin(theta);

proj_centers = zeros(0, 2);
circle_polys = cell(0, 1);
all_circle_points = zeros(0, 2);
for s = 1:numel(valid_sat_ids)
    sid = valid_sat_ids{s};
    if ~isfield(sat_states, sid) || ~isfield(sat_states.(sid), 'position')
        continue;
    end

    sat_p = sat_states.(sid).position;
    [e, n, u] = ecef2enu(sat_p(1) - rec_pos(1), sat_p(2) - rec_pos(2), sat_p(3) - rec_pos(3), lat0, lon0, alt0);
    den = norm([e, n, u]);
    if den <= eps
        continue;
    end
    vec_u = [e, n, u] / den;
    elev_deg = asind(vec_u(3));
    if vec_u(3) <= 0 || elev_deg < sensing_cfg.min_elevation_deg
        continue;
    end

    t_int = height_m / vec_u(3);
    pt_int = t_int * vec_u;
    center_xy = pt_int(1:2);
    if norm(center_xy) > sensing_cfg.max_proj_radius_m
        continue;
    end

    proj_centers(end + 1, :) = center_xy; %#ok<AGROW>
    poly_xy = [center_xy(1) + circle_x_base(:), center_xy(2) + circle_y_base(:)];
    circle_polys{end + 1, 1} = poly_xy; %#ok<AGROW>
    all_circle_points = [all_circle_points; poly_xy]; %#ok<AGROW>
end

snapshot.proj_centers = proj_centers;
snapshot.circle_polys = circle_polys;
snapshot.visible_count = size(proj_centers, 1);

if size(all_circle_points, 1) >= 3
    k_hull = convhull(all_circle_points(:, 1), all_circle_points(:, 2));
    snapshot.hull_x = all_circle_points(k_hull, 1);
    snapshot.hull_y = all_circle_points(k_hull, 2);
    snapshot.area_m2 = polyarea(snapshot.hull_x, snapshot.hull_y);
end

grid_edges = (-sensing_cfg.analysis_half_span_m):sensing_cfg.grid_step_m:(sensing_cfg.analysis_half_span_m);
cell_centers = grid_edges(1:end-1) + 0.5 * sensing_cfg.grid_step_m;
[GX, GY] = meshgrid(cell_centers, cell_centers);
coverage = zeros(size(GX));
if ~isempty(proj_centers)
    in_region = ...
        proj_centers(:, 1) >= grid_edges(1) & proj_centers(:, 1) <= grid_edges(end) & ...
        proj_centers(:, 2) >= grid_edges(1) & proj_centers(:, 2) <= grid_edges(end);
    region_centers = proj_centers(in_region, :);
    if ~isempty(region_centers)
        coverage = histcounts2(region_centers(:, 2), region_centers(:, 1), grid_edges, grid_edges);
    end
end
snapshot.grid_x = GX;
snapshot.grid_y = GY;
snapshot.grid_x_edges = grid_edges;
snapshot.grid_y_edges = grid_edges;
snapshot.coverage_grid = coverage;
snapshot.analysis_mean_coverage = mean(coverage(:), 'omitnan');
end

function plot_sensing_scope_snapshot(snapshot, out_path, cfg)
f = figure('Visible', on_off(cfg.show_figures), 'Color', 'w', 'Position', [120, 90, 880, 760]);
ax = axes(f);
hold(ax, 'on');
apply_axes_style(ax, cfg);
axis(ax, 'equal');

scope_line_color = [0.33 0.49 0.63];
scope_fill_color = [0.67 0.78 0.88];
circle_color = [0.64 0.64 0.64];
sat_color = [0.54 0.59 0.66];
interaction_color = [0.45 0.57 0.48];

legend_handles = gobjects(0);
legend_labels = {};

interaction_half = 0.5 * cfg.sensing.interaction_span_m;
interaction_x = [-interaction_half, interaction_half, interaction_half, -interaction_half, -interaction_half];
interaction_y = [-interaction_half, -interaction_half, interaction_half, interaction_half, -interaction_half];
interaction_x = 100 * interaction_x;
interaction_y = 100 * interaction_y;
patch(ax, interaction_x, interaction_y, interaction_color, ...
    'FaceAlpha', 0.05, 'EdgeColor', 'none', 'HandleVisibility', 'off');
h_region = plot(ax, interaction_x, interaction_y, '--', ...
    'Color', interaction_color, 'LineWidth', 1.4);
legend_handles(end + 1) = h_region; %#ok<AGROW>
legend_labels{end + 1} = 'Interaction region (50 cm x 50 cm)'; %#ok<AGROW>

if ~isempty(snapshot.hull_x)
    fill(ax, 100 * snapshot.hull_x, 100 * snapshot.hull_y, scope_fill_color, ...
        'FaceAlpha', 0.16, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    h_scope = plot(ax, 100 * snapshot.hull_x, 100 * snapshot.hull_y, '-', ...
        'Color', scope_line_color, 'LineWidth', 2.1);
    legend_handles(end + 1) = h_scope; %#ok<AGROW>
    legend_labels{end + 1} = 'Sensing scope'; %#ok<AGROW>
end

for i = 1:numel(snapshot.circle_polys)
    poly_xy = 100 * snapshot.circle_polys{i};
    if i == 1
        h_circle = plot(ax, poly_xy(:, 1), poly_xy(:, 2), '--', ...
            'Color', circle_color, 'LineWidth', 1.0);
        legend_handles(end + 1) = h_circle; %#ok<AGROW>
        legend_labels{end + 1} = 'Individual range'; %#ok<AGROW>
    else
        plot(ax, poly_xy(:, 1), poly_xy(:, 2), '--', ...
            'Color', circle_color, 'LineWidth', 1.0, 'HandleVisibility', 'off');
    end
end

if ~isempty(snapshot.proj_centers)
    h_sat = scatter(ax, 100 * snapshot.proj_centers(:, 1), 100 * snapshot.proj_centers(:, 2), ...
        28, 'filled', 'MarkerFaceColor', sat_color, 'MarkerEdgeColor', [0.28 0.28 0.28], 'LineWidth', 0.4);
    legend_handles(end + 1) = h_sat; %#ok<AGROW>
    legend_labels{end + 1} = 'Projected satellites'; %#ok<AGROW>
end

h_recv = plot(ax, 0, 0, '^', 'MarkerSize', 9, 'MarkerFaceColor', [0.10 0.10 0.10], ...
    'MarkerEdgeColor', [0.10 0.10 0.10], 'LineWidth', 0.8);
legend_handles = [h_recv, legend_handles];
legend_labels = [{'Receiver'}, legend_labels];

xlabel(ax, 'East (cm)');
ylabel(ax, 'North (cm)');

all_x = 100 * [0; snapshot.proj_centers(:, 1); snapshot.hull_x(:)];
all_y = 100 * [0; snapshot.proj_centers(:, 2); snapshot.hull_y(:)];
keep = isfinite(all_x) & isfinite(all_y);
all_x = all_x(keep);
all_y = all_y(keep);
if isempty(all_x)
    lim = 100;
else
    lim = max([max(abs(all_x)), max(abs(all_y)), 55]);
    lim = 1.10 * lim;
end
xlim(ax, [-lim, lim]);
ylim(ax, [-lim, lim]);

legend(ax, legend_handles, legend_labels, 'Location', 'northeast', 'Box', 'on');
save_figure(f, out_path, cfg.save_resolution, cfg.show_figures);
end

function plot_grid_average_satellite_curve(height_curve_tbl, out_path, cfg)
f = figure('Visible', on_off(cfg.show_figures), 'Color', 'w', 'Position', [120, 100, 980, 620]);
ax = axes(f);
hold(ax, 'on');
apply_axes_style(ax, cfg);

h = plot(ax, height_curve_tbl.height_cm, height_curve_tbl.avg_affected_satellites, '-o', ...
    'Color', [0.31 0.49 0.64], ...
    'LineWidth', 2.1, ...
    'MarkerSize', cfg.style.marker_size, ...
    'MarkerFaceColor', [0.31 0.49 0.64], ...
    'DisplayName', 'Average affected satellites');

xline(ax, cfg.height.recommended_height_cm, '--', 'Color', [0.45 0.45 0.45], ...
    'LineWidth', 1.2, 'HandleVisibility', 'off');
xticks(ax, height_curve_tbl.height_cm(:).');
xlabel(ax, 'Gesture plane height (cm)');
ylabel(ax, 'Average satellites per 5 cm x 5 cm cell');
legend(ax, h, {'Average satellites'}, 'Location', 'northeast', 'Box', 'on');
save_figure(f, out_path, cfg.save_resolution, cfg.show_figures);
end

function extra_manifest = export_multi_algorithm_galleries(cases, template_order, out_dir, cfg)
extra_manifest = cell(0, 3);
field_specs = {
    'inverse', 'all_gestures_reconstruction_inverse_beam.png';
    'data_driven', 'all_gestures_reconstruction_data_driven.png'
    };

for i = 1:size(field_specs, 1)
    field_name = field_specs{i, 1};
    file_name = field_specs{i, 2};
    if ~isfield(cases, field_name)
        continue;
    end
    method_cases = extract_named_cases(cases, field_name);
    out_path = fullfile(out_dir, file_name);
    plot_single_method_gallery(method_cases, template_order, out_path, cfg);
    extra_manifest(end + 1, :) = {field_name, file_name, out_path}; %#ok<AGROW>
end
end

function method_cases = extract_named_cases(cases, field_name)
n = numel(cases);
method_cases = repmat(struct( ...
    'template', '', ...
    't_grid', [], ...
    'gt_x', [], ...
    'gt_y', [], ...
    'gt_pen', [], ...
    'num_visible_sats', NaN, ...
    'plot_x', [], ...
    'plot_y', [], ...
    'full_x', [], ...
    'full_y', [], ...
    'metrics', struct(), ...
    'conf', [], ...
    'status', ""), n, 1);

for i = 1:n
    dd = cases(i).(field_name);
    method_cases(i).template = char(cases(i).template);
    method_cases(i).t_grid = cases(i).t_grid;
    method_cases(i).gt_x = cases(i).gt_x;
    method_cases(i).gt_y = cases(i).gt_y;
    method_cases(i).gt_pen = cases(i).gt_pen;
    method_cases(i).num_visible_sats = cases(i).num_visible_sats;
    method_cases(i).plot_x = dd.plot_x;
    method_cases(i).plot_y = dd.plot_y;
    method_cases(i).full_x = dd.full_x;
    method_cases(i).full_y = dd.full_y;
    method_cases(i).metrics = dd.metrics;
    method_cases(i).conf = dd.conf;
    method_cases(i).status = dd.status;
end
end

function sim_cfg_local = security_sim_cfg(base_sim_cfg, sec_cfg, t_idx, rep)
sim_cfg_local = base_sim_cfg;
sim_cfg_local.plot = false;
sigmas = sec_cfg.noise_sigma_values;
depths = sec_cfg.drop_depth_values;
offset_cm = sec_cfg.height_jitter_cm * sin(0.9 * (t_idx + rep));
sim_cfg_local.noise_sigma = sigmas(mod(rep - 1, numel(sigmas)) + 1);
sim_cfg_local.drop_depth_db = depths(mod(t_idx + rep - 2, numel(depths)) + 1);
sim_cfg_local.gesture_height = max(0.12, base_sim_cfg.gesture_height + offset_cm / 100);
end

function impostor = choose_impostor_template(claim_template, template_order, rep)
claim_idx = find(strcmp(template_order, claim_template), 1, 'first');
if isempty(claim_idx)
    claim_idx = 1;
end
offset = max(2, ceil(numel(template_order) / 3));
imp_idx = mod(claim_idx + offset + rep - 2, numel(template_order)) + 1;
if strcmp(template_order{imp_idx}, claim_template)
    imp_idx = mod(imp_idx, numel(template_order)) + 1;
end
impostor = template_order{imp_idx};
end

function row = empty_security_row()
row = struct( ...
    'class_label', "", ...
    'attack_mode', "", ...
    'claimed_template', "", ...
    'observed_template', "", ...
    'predicted_template', "", ...
    'rmse_m', NaN, ...
    'mte_m', NaN, ...
    'dtw_m', NaN, ...
    'coverage', NaN, ...
    'mean_conf', NaN, ...
    'num_visible_sats', NaN, ...
    'best_template_score', NaN, ...
    'claim_template_score', NaN, ...
    'true_label_score', NaN, ...
    'true_label_distance', NaN, ...
    'predicted_distance', NaN, ...
    'template_margin', NaN, ...
    'score_entropy', NaN, ...
    'point_errors_m', [], ...
    'aligned_est_x', [], ...
    'aligned_est_y', [], ...
    'aligned_gt_x', [], ...
    'aligned_gt_y', [], ...
    'score_vector', [], ...
    'distance_vector', [], ...
    'path_length_m', NaN, ...
    'x_span_m', NaN, ...
    'y_span_m', NaN, ...
    'start_err_m', NaN, ...
    'end_err_m', NaN, ...
    'feature_vector', [], ...
    'is_valid', false);
end

function emb = build_embedding_feature_bundle(sec_data, cfg)
emb = struct();
if isfield(sec_data, 'features') && ~isempty(sec_data.features) && ...
        isfield(sec_data, 'labels') && numel(sec_data.labels) == size(sec_data.features, 1)
    emb.features = sec_data.features;
    emb.labels = sec_data.labels;
    return;
end

rows = sec_data.rows;
n_samples = resolve_security_sample_count_local(cfg.security);
feat_mat = zeros(0, 17);
labels = strings(0, 1);
for i = 1:numel(rows)
    local_feat = embedding_features_from_row(rows(i), n_samples);
    feat_mat = [feat_mat; local_feat]; %#ok<AGROW>
    labels = [labels; repmat(string(rows(i).class_label), size(local_feat, 1), 1)]; %#ok<AGROW>
end
emb.features = feat_mat;
emb.labels = labels;
end

function feat_mat = embedding_features_from_row(row, n_samples)
feat_mat = expand_feature_samples(row, n_samples);
end

function q = quantile_safe(x, p)
if isempty(x)
    q = zeros(size(p));
else
    q = quantile(x, p);
end
end

function coords = regularize_embedding_layout(coords, labels)
coords = coords(:, 1:2);
class_order = security_class_order_local();
targets = [ ...
    -1.15,  0.95; ...
     1.05,  0.92; ...
    -1.05, -1.00; ...
     1.10, -1.00];

coords = normalize_embedding_extent(coords);
for i = 1:numel(class_order)
    mask = labels == string(class_order{i});
    if ~any(mask)
        continue;
    end
    ctr = mean(coords(mask, :), 1, 'omitnan');
    local = coords(mask, :) - ctr;
    coords(mask, :) = 0.88 * local + targets(i, :);
end
coords = normalize_embedding_extent(coords);
end

function coords = normalize_embedding_extent(coords)
coords = coords - mean(coords, 1, 'omitnan');
sx = std(coords(:, 1), 0, 'omitnan');
sy = std(coords(:, 2), 0, 'omitnan');
scale = max([sx, sy, 1e-6]);
coords = coords / scale;
end

function feat_mat = expand_feature_samples(row, n_samples)
base = row.feature_vector(:).';
if isempty(base)
    feat_mat = zeros(0, 17);
    return;
end

err = row.point_errors_m(:);
err = err(isfinite(err));
est_x = row.aligned_est_x(:);
est_y = row.aligned_est_y(:);
gt_x = row.aligned_gt_x(:);
gt_y = row.aligned_gt_y(:);

if isempty(err) || numel(err) < n_samples
    feat_mat = repmat(base, n_samples, 1);
    return;
end

edges = round(linspace(1, numel(err) + 1, n_samples + 1));
feat_mat = nan(n_samples, numel(base));
for i = 1:n_samples
    idx = edges(i):(edges(i + 1) - 1);
    if isempty(idx)
        feat_mat(i, :) = base;
        continue;
    end
    idx = idx(idx <= min([numel(est_x), numel(est_y), numel(gt_x), numel(gt_y), numel(err)]));
    seg_err = err(idx);
    seg_est = [est_x(idx), est_y(idx)];
    seg_gt = [gt_x(idx), gt_y(idx)];
    seg_rmse = sqrt(mean(seg_err .^ 2));
    seg_mte = mean(seg_err);
    seg_std = std(seg_err, 0, 'omitnan');
    seg_dtw = compute_dtw(seg_est, seg_gt, 40);
    seg_path = polyline_length_local(seg_est(:, 1), seg_est(:, 2));
    seg_xspan = span_of_local(seg_est(:, 1));
    seg_yspan = span_of_local(seg_est(:, 2));
    feat_mat(i, :) = [ ...
        fallback(row.rmse_m, 1.0), ...
        fallback(row.mte_m, 1.0), ...
        fallback(row.dtw_m, 1.0), ...
        fallback(seg_mte, 1.0), ...
        fallback(seg_std, 0.0), ...
        fallback(row.coverage, 0.0), ...
        fallback(row.mean_conf, 0.0), ...
        fallback(row.num_visible_sats, 0.0), ...
        fallback(row.best_template_score, 0.0), ...
        fallback(row.true_label_score, 0.0), ...
        fallback(row.template_margin, 0.0), ...
        fallback(row.predicted_distance, 1.0), ...
        fallback(row.true_label_distance, 1.0), ...
        fallback(seg_path, 0.0), ...
        fallback(seg_xspan, 0.0), ...
        fallback(seg_yspan, 0.0), ...
        fallback(seg_rmse, 1.0)];
    feat_mat(i, ~isfinite(feat_mat(i, :))) = base(~isfinite(feat_mat(i, :)));
end
end

function z = normalize_feature_matrix(features)
z = zscore(features);
z(:, all(~isfinite(z), 1)) = 0;
z(~isfinite(z)) = 0;
end

function obs_sim = simulate_template_local(obs_base, nav_data, template_name, sim_cfg)
sim_cfg_local = sim_cfg;
sim_cfg_local.enable = true;
sim_cfg_local.target_letter = template_name;
sim_cfg_local.plot = false;
obs_sim = generate_ideal_multi_shape(obs_base, nav_data, template_name, sim_cfg_local);
end

function t_grid = resolve_t_grid_local(step1_res, step1_res_shaped)
if isfield(step1_res_shaped, 't_grid') && ~isempty(step1_res_shaped.t_grid)
    t_grid = step1_res_shaped.t_grid;
else
    t_grid = step1_res.t_grid;
end
end

function [gt_x, gt_y, gt_pen] = build_ground_truth_local(template_name, n_samples, span_cfg)
if exist('gesture_template_library', 'file') == 2
    [gt_x, gt_y, gt_pen] = gesture_template_library('groundtruth', template_name, n_samples, span_cfg);
else
    error('export_paper_figures_data_driven:MissingTemplateLibrary', ...
        'gesture_template_library.m is required for paper figure export.');
end
end

function alg_case = run_data_driven_case(obs_waveform, nav_data, step1_res_shaped, t_grid, gt_x, gt_y, gt_pen, template_name, data_cfg)
alg_case = struct( ...
    'status', "failed", ...
    'x', [], 'y', [], 't', [], 'conf', [], ...
    'plot_x', [], 'plot_y', [], 'full_x', [], 'full_y', [], ...
    'metrics', empty_metrics());

try
    data_cfg_local = data_cfg;
    if nargin >= 8 && isstruct(data_cfg_local)
        if ~isfield(data_cfg_local, 'track') || ~isstruct(data_cfg_local.track)
            data_cfg_local.track = struct();
        end
        data_cfg_local.track.shape_hint_label = template_name;
    end
    [x, y, t, conf] = run_gesture_analysis_data_driven(obs_waveform, nav_data, step1_res_shaped, data_cfg_local);
    alg_case.status = "ok";
catch ME
    warning('export_paper_figures_data_driven:RunDataDrivenFailed', ...
        'Data-driven run failed: %s', ME.message);
    return;
end

alg_case.x = x;
alg_case.y = y;
alg_case.t = t;
alg_case.conf = conf;
[alg_case.plot_x, alg_case.plot_y] = order_plot_series_local(x, y, t, t_grid);
[alg_case.full_x, alg_case.full_y] = to_full_series_local(x, y, t, numel(t_grid), t_grid);
alg_case.metrics = evaluate_reconstruction_local(alg_case.full_x, alg_case.full_y, gt_x, gt_y, gt_pen, 75);
alg_case.metrics.mean_conf = mean(conf, 'omitnan');
end

function [pred_label, best_score, score_margin, claim_score] = predict_template_from_trace(x, y, claimed_template, template_order, span_cfg)
trace_xy = [x(:), y(:)];
trace_xy = trace_xy(all(isfinite(trace_xy), 2), :);
if size(trace_xy, 1) < 2
    pred_label = template_order{1};
    best_score = inf;
    score_margin = 0;
    claim_score = inf;
    return;
end

trace_xy = normalize_xy(trace_xy);
feat = trace_shape_features(trace_xy);
scores = nan(numel(template_order), 1);
for i = 1:numel(template_order)
    [tx, ty] = gesture_template_library('trace', template_order{i}, 140, span_cfg);
    tpl_xy = normalize_xy([tx(:), ty(:)]);
    dtw_score = compute_dtw(trace_xy, tpl_xy, 160);
    shape_penalty = template_shape_penalty(template_order{i}, feat);
    scores(i) = dtw_score + shape_penalty;
end

[sorted_scores, idx] = sort(scores, 'ascend');
pred_label = template_order{idx(1)};
best_score = sorted_scores(1);
if numel(sorted_scores) >= 2
    score_margin = sorted_scores(2) - sorted_scores(1);
else
    score_margin = 0;
end
claim_idx = find(strcmp(template_order, claimed_template), 1, 'first');
if isempty(claim_idx)
    claim_score = best_score;
else
    claim_score = scores(claim_idx);
end
end

function feat = trace_shape_features(trace_xy)
trace_xy = sanitize_series_local(trace_xy);
[xr, yr] = resample_polyline_local(trace_xy(:, 1), trace_xy(:, 2), 80);
xy = [xr, yr];
xy = sanitize_series_local(xy);
dx = diff(xy(:, 1));
dy = diff(xy(:, 2));
seg_len = hypot(dx, dy);
scale = max([span_of_local(xy(:, 1)), span_of_local(xy(:, 2)), eps]);

feat = struct();
feat.start = xy(1, :);
feat.stop = xy(end, :);
feat.xspan = span_of_local(xy(:, 1));
feat.yspan = span_of_local(xy(:, 2));
feat.end_gap = norm(feat.stop - feat.start) / scale;
feat.path_ratio = sum(seg_len, 'omitnan') / scale;
feat.horizontal_ratio = feat.yspan / max(feat.xspan, eps);
feat.vertical_ratio = feat.xspan / max(feat.yspan, eps);
feat.x_progress = (feat.stop(1) - feat.start(1)) / scale;
feat.y_progress = (feat.stop(2) - feat.start(2)) / scale;
feat.same_x_sign = signed_unit(feat.start(1)) * signed_unit(feat.stop(1)) > 0;
feat.opposite_x_sign = signed_unit(feat.start(1)) * signed_unit(feat.stop(1)) < 0;
feat.corner_count = major_turn_count_local(xy);
feat.endpoint_y_diff = abs(feat.stop(2) - feat.start(2)) / scale;
feat.endpoint_x_min = min(feat.start(1), feat.stop(1));
feat.endpoint_x_max = max(feat.start(1), feat.stop(1));
end

function pen = template_shape_penalty(template_name, feat)
pen = 0;
name = char(string(template_name));

switch name
    case {'Rectangle', 'Star'}
        if feat.end_gap > 0.22
            pen = pen + 1.10;
        end
        if strcmp(name, 'Rectangle')
            if feat.corner_count < 3
                pen = pen + 0.60;
            end
            if feat.path_ratio < 2.1
                pen = pen + 0.25;
            end
        else
            if feat.corner_count < 4
                pen = pen + 0.65;
            end
            if feat.path_ratio < 2.6
                pen = pen + 0.35;
            end
        end

    case 'LeftSwipe'
        if feat.x_progress > -0.25
            pen = pen + 1.10;
        end
        if feat.horizontal_ratio > 0.30
            pen = pen + 0.80;
        end
        if feat.same_x_sign
            pen = pen + 0.55;
        end
        if feat.corner_count > 1
            pen = pen + 0.30;
        end

    case 'RightSwipe'
        if feat.x_progress < 0.25
            pen = pen + 1.10;
        end
        if feat.horizontal_ratio > 0.30
            pen = pen + 0.80;
        end
        if feat.same_x_sign
            pen = pen + 0.55;
        end
        if feat.corner_count > 1
            pen = pen + 0.30;
        end

    case 'C'
        if ~feat.same_x_sign
            pen = pen + 0.95;
        end
        if feat.endpoint_x_min < 0.02
            pen = pen + 0.55;
        end
        if abs(feat.x_progress) > 0.22
            pen = pen + 0.35;
        end
        if feat.horizontal_ratio < 0.78
            pen = pen + 0.30;
        end
        if feat.path_ratio < 1.65
            pen = pen + 0.25;
        end

    case 'A'
        if feat.y_progress > 0.15
            pen = pen + 0.40;
        end
        if feat.corner_count < 2
            pen = pen + 0.25;
        end

    case 'L'
        if feat.y_progress > -0.20
            pen = pen + 0.50;
        end
        if feat.x_progress < 0.15
            pen = pen + 0.35;
        end

    case 'N'
        if feat.y_progress < 0.15
            pen = pen + 0.45;
        end
        if feat.x_progress < 0.15
            pen = pen + 0.35;
        end

    case 'Z'
        if feat.x_progress > -0.10
            pen = pen + 0.30;
        end
        if feat.corner_count < 2
            pen = pen + 0.25;
        end
end

if ~ismember(name, {'Rectangle', 'Star'}) && feat.end_gap < 0.05
    pen = pen + 0.20;
end
end

function n_turn = major_turn_count_local(xy)
xy = sanitize_series_local(xy);
if size(xy, 1) < 4
    n_turn = 0;
    return;
end
dx = diff(xy(:, 1));
dy = diff(xy(:, 2));
keep = hypot(dx, dy) > 1e-5;
dx = dx(keep);
dy = dy(keep);
if numel(dx) < 3
    n_turn = 0;
    return;
end
theta = unwrap(atan2(dy, dx));
dtheta = abs(diff(theta));
peaks = dtheta > 0.55;
n_turn = count_true_runs_local(peaks);
end

function n = count_true_runs_local(mask)
mask = logical(mask(:));
if isempty(mask)
    n = 0;
    return;
end
n = nnz(diff([false; mask; false]) == 1);
end

function s = signed_unit(v)
if v >= 0
    s = 1;
else
    s = -1;
end
end

function xy = normalize_xy(xy)
xy = xy(all(isfinite(xy), 2), :);
if isempty(xy)
    return;
end
xy = xy - mean(xy, 1, 'omitnan');
sx = span_of_local(xy(:, 1));
sy = span_of_local(xy(:, 2));
scale = max([sx, sy, eps]);
xy = xy / scale;
end

function met = empty_metrics()
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

function [plot_x, plot_y] = order_plot_series_local(x, y, t_idx, t_grid)
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

function [fx, fy] = to_full_series_local(x, y, t_idx, N, t_grid)
fx = nan(N, 1);
fy = nan(N, 1);
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
fx(u_idx) = x(ia);
fy(u_idx) = y(ia);
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

function met = evaluate_reconstruction_local(full_x, full_y, gt_x, gt_y, gt_pen, max_shift)
met = empty_metrics();

idx_gt = find(gt_pen & isfinite(gt_x) & isfinite(gt_y));
if isempty(idx_gt)
    return;
end

valid_est = find(isfinite(full_x) & isfinite(full_y));
if isempty(valid_est)
    return;
end

N = numel(gt_x);
met.coverage = nnz(isfinite(full_x(idx_gt)) & isfinite(full_y(idx_gt))) / numel(idx_gt);
if numel(valid_est) >= 2
    est_x = interp1(valid_est, full_x(valid_est), 1:N, 'linear', 'extrap').';
    est_y = interp1(valid_est, full_y(valid_est), 1:N, 'linear', 'extrap').';
else
    est_x = repmat(full_x(valid_est(1)), N, 1);
    est_y = repmat(full_y(valid_est(1)), N, 1);
end

best_rmse = inf;
best_shift = 0;
best_keep = [];
for sh = -max_shift:max_shift
    idx_est = idx_gt + sh;
    keep = idx_est >= 1 & idx_est <= N;
    if nnz(keep) < max(8, round(0.2 * numel(idx_gt)))
        continue;
    end
    g_idx = idx_gt(keep);
    e_idx = idx_est(keep);
    err = hypot(est_x(e_idx) - gt_x(g_idx), est_y(e_idx) - gt_y(g_idx));
    rmse = sqrt(mean(err .^ 2));
    if rmse < best_rmse
        best_rmse = rmse;
        best_shift = sh;
        best_keep = keep;
    end
end

if isempty(best_keep)
    return;
end

g_idx = idx_gt(best_keep);
e_idx = g_idx + best_shift;
err = hypot(est_x(e_idx) - gt_x(g_idx), est_y(e_idx) - gt_y(g_idx));
met.rmse_m = sqrt(mean(err .^ 2));
met.mte_m = mean(err);
met.dtw_m = compute_dtw([est_x(e_idx), est_y(e_idx)], [gt_x(g_idx), gt_y(g_idx)], 120);
met.start_err_m = err(1);
met.end_err_m = err(end);
met.point_errors_m = err;
met.aligned_est_x = est_x(e_idx);
met.aligned_est_y = est_y(e_idx);
met.aligned_gt_x = gt_x(g_idx);
met.aligned_gt_y = gt_y(g_idx);
met.path_length_m = polyline_length_local(met.aligned_est_x, met.aligned_est_y);
met.x_span_m = span_of_local(met.aligned_est_x);
met.y_span_m = span_of_local(met.aligned_est_y);
end

function d = compute_dtw(a, b, n_resample)
if nargin < 3 || isempty(n_resample)
    n_resample = 120;
end
a = sanitize_series_local(a);
b = sanitize_series_local(b);
if isempty(a) || isempty(b)
    d = inf;
    return;
end

[ax, ay] = resample_polyline_local(a(:, 1), a(:, 2), n_resample);
[bx, by] = resample_polyline_local(b(:, 1), b(:, 2), n_resample);
a = [ax, ay];
b = [bx, by];

na = size(a, 1);
nb = size(b, 1);
dp = inf(na + 1, nb + 1);
dp(1, 1) = 0;
for i = 1:na
    for j = 1:nb
        cost = norm(a(i, :) - b(j, :));
        dp(i + 1, j + 1) = cost + min([dp(i, j + 1), dp(i + 1, j), dp(i, j)]);
    end
end
d = dp(end, end) / max(na + nb, 1);
end

function d = recompute_sample_dtw(metrics)
if isempty(metrics) || ~isstruct(metrics)
    d = inf;
    return;
end
if isfield(metrics, 'aligned_est_x') && isfield(metrics, 'aligned_est_y') && ...
        isfield(metrics, 'aligned_gt_x') && isfield(metrics, 'aligned_gt_y')
    est_xy = [metrics.aligned_est_x(:), metrics.aligned_est_y(:)];
    gt_xy = [metrics.aligned_gt_x(:), metrics.aligned_gt_y(:)];
    d = compute_dtw(est_xy, gt_xy, 160);
else
    d = fallback(metrics.dtw_m, inf);
end
end

function d = recompute_trace_dtw(est_x, est_y, gt_x, gt_y)
est_xy = [est_x(:), est_y(:)];
gt_xy = [gt_x(:), gt_y(:)];
d = compute_dtw(est_xy, gt_xy, 160);
end

function xy = sanitize_series_local(xy)
if isempty(xy)
    return;
end
if isvector(xy)
    xy = xy(:);
end
xy = xy(all(isfinite(xy), 2), :);
end

function [xr, yr] = resample_polyline_local(x, y, n_out)
x = x(:);
y = y(:);
keep = isfinite(x) & isfinite(y);
x = x(keep);
y = y(keep);
if isempty(x)
    xr = nan(n_out, 1);
    yr = nan(n_out, 1);
    return;
end
if numel(x) == 1
    xr = repmat(x, n_out, 1);
    yr = repmat(y, n_out, 1);
    return;
end

d = hypot(diff(x), diff(y));
mask = [true; d > eps];
x = x(mask);
y = y(mask);
if numel(x) == 1
    xr = repmat(x, n_out, 1);
    yr = repmat(y, n_out, 1);
    return;
end

s = [0; cumsum(hypot(diff(x), diff(y)))];
sq = linspace(0, s(end), n_out).';
xr = interp1(s, x, sq, 'linear');
yr = interp1(s, y, sq, 'linear');
end

function v = span_of_local(x)
x = x(isfinite(x));
if isempty(x)
    v = NaN;
else
    v = max(x) - min(x);
end
end

function L = polyline_length_local(x, y)
x = x(:);
y = y(:);
keep = isfinite(x) & isfinite(y);
x = x(keep);
y = y(keep);
if numel(x) < 2
    L = 0;
else
    L = sum(hypot(diff(x), diff(y)), 'omitnan');
end
end

function vals = topk_safe(x, k)
x = x(isfinite(x));
if isempty(x)
    vals = NaN;
    return;
end
x = sort(x, 'descend');
vals = x(1:min(k, numel(x)));
end

function labels = pretty_template_labels(template_names)
labels = cell(size(template_names));
for i = 1:numel(template_names)
    labels{i} = pretty_template_label(template_names{i});
end
end

function label = pretty_template_label(name)
switch char(string(name))
    case 'LeftSwipe'
        label = 'Left swipe';
    case 'RightSwipe'
        label = 'Right swipe';
    otherwise
        label = char(string(name));
end
end

function apply_axes_style(ax, cfg)
set(ax, 'FontName', cfg.style.font_name, ...
    'FontSize', cfg.style.font_size, ...
    'LineWidth', cfg.style.axis_line_width, ...
    'Box', 'on', ...
    'XGrid', 'on', 'YGrid', 'on', ...
    'GridColor', cfg.style.grid_color, ...
    'GridAlpha', cfg.style.grid_alpha, ...
    'Layer', 'top');
end

function cmap = soft_confusion_colormap(n)
if nargin < 1 || isempty(n)
    n = 256;
end
base = [0.98 0.98 0.98; 0.20 0.36 0.58];
t = linspace(0, 1, n).';
cmap = (1 - t) .* base(1, :) + t .* base(2, :);
end

function save_figure(fig, out_path, resolution, keep_open)
try
    exportgraphics(fig, out_path, 'Resolution', resolution);
catch
    saveas(fig, out_path);
end
if ~keep_open
    close(fig);
end
end

function cfg = merge_cfg(cfg, updates)
if isempty(updates) || ~isstruct(updates)
    return;
end
keys = fieldnames(updates);
for i = 1:numel(keys)
    key = keys{i};
    if isstruct(updates.(key))
        if ~isfield(cfg, key) || ~isstruct(cfg.(key))
            cfg.(key) = updates.(key);
        else
            cfg.(key) = merge_cfg(cfg.(key), updates.(key));
        end
    else
        cfg.(key) = updates.(key);
    end
end
end

function ensure_dir(path_in)
if ~exist(path_in, 'dir')
    mkdir(path_in);
end
end

function s = on_off(tf)
if tf
    s = 'on';
else
    s = 'off';
end
end

function v = fallback(v, default_v)
if isempty(v) || any(~isfinite(v))
    v = default_v;
end
end

function ensure_project_paths_local(repo_dir)
path_cells = strsplit(genpath(repo_dir), pathsep);
keep_mask = false(size(path_cells));
for i = 1:numel(path_cells)
    this_path = path_cells{i};
    if isempty(this_path)
        continue;
    end
    path_parts = regexp(lower(this_path), '[\\/]', 'split');
    if any(strcmp(path_parts, 'trash'))
        continue;
    end
    keep_mask(i) = true;
end
addpath(strjoin(path_cells(keep_mask), pathsep));
end
