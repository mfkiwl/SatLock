function [source_mat_path, src] = build_gesture_test_source(user_cfg)
% BUILD_GESTURE_TEST_SOURCE
% Build the layered workflow source bundle used by gesture_test and
% downstream scientific graphing.

if nargin < 1 || isempty(user_cfg)
    user_cfg = struct();
end

repo_dir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
ensure_project_paths_local(repo_dir);

cfg = default_cfg(repo_dir);
cfg = merge_cfg_local(cfg, user_cfg);

rng(cfg.random_seed, 'twister');

parsed = layer1_parse_raw_data(cfg);
injected = layer2_inject_templates(parsed, cfg);
attack = layer_attack_simulation(parsed, injected, cfg);
trajectory = layer3_recover_trajectories(parsed, attack, cfg);
auth = layer4_authenticate_gestures(trajectory, cfg);

src = struct();
src.parsed = strip_parsed_local(parsed);
src.injected = strip_injected_local(injected);
src.attack = strip_attack_local(attack);
src.trajectory = trajectory;
src.auth = auth;
src.summary_tbl = auth.summary_tbl;
src.cfg = cfg;
src.cases = build_legacy_cases_local(trajectory);
src.out_dir = '';
src.workflow = struct( ...
    'layer1', "parse_raw_data", ...
    'layer2', "inject_template_data", ...
    'attack_layer', "simulate_attack", ...
    'layer3', "recover_trajectories", ...
    'layer4', "authenticate_gestures", ...
    'created_at', string(datetime('now')));

[work_dir, source_mat_path] = prepare_source_output_path(repo_dir);
summary_tbl = auth.summary_tbl;
out_dir = '';
writetable(summary_tbl, fullfile(work_dir, 'gesture_test_source_summary.csv'));
save(source_mat_path, 'src', 'trajectory', 'auth', 'summary_tbl', 'cfg', 'out_dir', '-v7.3');
end

function cfg = default_cfg(repo_dir)
cfg = struct();
cfg.obs_filepath = fullfile(repo_dir, 'data', '1_8', 'A_1_8_1.obs');
cfg.nav_filepath = fullfile(repo_dir, 'data', '1_8', '2026_1_8.nav');
cfg.random_seed = 20260321;
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
end

function [work_dir, source_mat_path] = prepare_source_output_path(repo_dir)
stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
work_dir = fullfile(repo_dir, 'gesture_analysis', 'results', 'gesture_test_work');
if ~exist(work_dir, 'dir')
    mkdir(work_dir);
end
source_mat_path = fullfile(work_dir, ['gesture_test_source_', stamp, '.mat']);
end

function parsed = strip_parsed_local(parsed_in)
parsed = rmfield(parsed_in, intersect(fieldnames(parsed_in), {'obs_base', 'nav_data'}));
end

function injected = strip_injected_local(injected_in)
injected = injected_in;
if ~isfield(injected, 'cases')
    return;
end
for i = 1:numel(injected.cases)
    if isfield(injected.cases(i), 'obs_case')
        injected.cases(i).obs_case = [];
    end
end
end

function attack = strip_attack_local(attack_in)
attack = attack_in;
if ~isfield(attack, 'cases')
    return;
end
for i = 1:numel(attack.cases)
    if isfield(attack.cases(i), 'obs_case')
        attack.cases(i).obs_case = [];
    end
end
end

function cases = build_legacy_cases_local(trajectory)
n = numel(trajectory.gallery_cases);
cases = repmat(struct( ...
    'template', '', ...
    't_grid', [], ...
    'gt_x', [], ...
    'gt_y', [], ...
    'gt_pen', [], ...
    'num_visible_sats', NaN, ...
    'core_blind', struct(), ...
    'data_driven', struct()), n, 1);

for i = 1:n
    gallery_case = trajectory.gallery_cases(i);
    core_case = trajectory.core_cases(i);
    cases(i).template = char(gallery_case.true_label);
    cases(i).t_grid = gallery_case.t_grid;
    cases(i).gt_x = gallery_case.reference_x;
    cases(i).gt_y = gallery_case.reference_y;
    cases(i).gt_pen = gallery_case.reference_pen;
    cases(i).num_visible_sats = gallery_case.num_visible_sats;
    cases(i).core_blind = core_case;
    cases(i).data_driven = gallery_case;
end
end

function dst = merge_cfg_local(dst, src)
keys = fieldnames(src);
for i = 1:numel(keys)
    key = keys{i};
    if isstruct(src.(key))
        if ~isfield(dst, key) || ~isstruct(dst.(key))
            dst.(key) = src.(key);
        else
            dst.(key) = merge_cfg_local(dst.(key), src.(key));
        end
    else
        dst.(key) = src.(key);
    end
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
