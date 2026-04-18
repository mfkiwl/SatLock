function scenario = layer_scenario_simulation(parsed, injected, cfg)
% LAYER_SCENARIO_SIMULATION
% Optional scenario simulation layer inserted after template injection.
% It perturbs the observation stream to emulate different surrounding
% environments while keeping the downstream workflow unchanged.

if nargin < 3
    cfg = struct();
end

scenario_cfg = struct();
if isstruct(cfg) && isfield(cfg, 'scenario_cfg') && isstruct(cfg.scenario_cfg)
    scenario_cfg = cfg.scenario_cfg;
end

mode_name = canonical_scenario_mode_local(get_cfg_local(scenario_cfg, 'mode', "open_field"));
scene_on = logical(get_cfg_local(scenario_cfg, 'enable', false)) && mode_name ~= "open_field";

cases_in = injected.cases;
n_case = numel(cases_in);
if n_case > 0
    cases_out = repmat(augment_case_local(cases_in(1)), n_case, 1);
else
    cases_out = cases_in;
end

summary_rows = repmat(struct( ...
    'case_id', "", ...
    'true_label', "", ...
    'scenario_applied', false, ...
    'scenario_mode', "", ...
    'source_mode', "", ...
    'notes', ""), n_case, 1);

for i = 1:n_case
    case_in = cases_in(i);
    case_out = augment_case_local(case_in);
    case_out.scenario_applied = scene_on;
    case_out.scenario_mode = mode_name;
    case_out.scenario_notes = "Open-field baseline";

    if scene_on
        switch char(mode_name)
            case 'near_building'
                case_out.obs_case = simulate_building_scene_local(case_in.obs_case, scenario_cfg, i);
                case_out.scenario_notes = "Near-building scene: directional blockage, multipath, and reduced satellite availability.";
            case 'near_trees'
                case_out.obs_case = simulate_tree_scene_local(case_in.obs_case, scenario_cfg, i);
                case_out.scenario_notes = "Near-trees scene: foliage attenuation, flicker, and random signal instability.";
            otherwise
                case_out.obs_case = case_in.obs_case;
                case_out.scenario_applied = false;
                case_out.scenario_mode = "open_field";
                case_out.scenario_notes = "Unknown scenario mode, passed through unchanged.";
        end
    end

    cases_out(i) = case_out;
    summary_rows(i).case_id = string(case_out.case_id);
    summary_rows(i).true_label = string(case_out.true_label);
    summary_rows(i).scenario_applied = logical(case_out.scenario_applied);
    summary_rows(i).scenario_mode = string(case_out.scenario_mode);
    summary_rows(i).source_mode = string(case_out.source_mode);
    summary_rows(i).notes = string(case_out.scenario_notes);
end

scenario = struct();
scenario.enable = scene_on;
scenario.mode = mode_name;
scenario.template_order = injected.template_order;
scenario.cases = cases_out;
scenario.summary_tbl = struct2table(summary_rows);
scenario.nav_data = parsed.nav_data;
end

function obs_out = simulate_building_scene_local(obs_case, scenario_cfg, seed_offset)
obs_out = obs_case;
n_epoch = numel(obs_out);
sat_ids = collect_satellite_ids_local(obs_out);
if isempty(sat_ids)
    return;
end

rng(get_cfg_local(scenario_cfg, 'random_seed', 20260331) + 101 * seed_offset, 'twister');
blocked_ratio = get_cfg_local(scenario_cfg, 'building_blocked_ratio', 0.40);
atten_db = get_cfg_local(scenario_cfg, 'building_atten_db', 3.1);
blocked_floor = get_cfg_local(scenario_cfg, 'building_blocked_floor_db', 20.2);
nan_prob = get_cfg_local(scenario_cfg, 'building_nan_prob', 0.46);
noise_sigma = get_cfg_local(scenario_cfg, 'building_noise_sigma', 0.31);
mp_amp = get_cfg_local(scenario_cfg, 'building_multipath_amp', 1.58);

blocked_mask = false(numel(sat_ids), 1);
blocked_count = max(1, round(blocked_ratio * numel(sat_ids)));
[~, ord] = sort(cellfun(@hash_satellite_local, sat_ids));
blocked_mask(ord(1:blocked_count)) = true;

t = linspace(0, 1, n_epoch).';
for s = 1:numel(sat_ids)
    sid = sat_ids{s};
    field_names = collect_snr_fields_local(obs_out, sid);
    if isempty(field_names)
        continue;
    end
    phase1 = 2 * pi * rand();
    phase2 = 2 * pi * rand();
    ripple = mp_amp * (0.62 * sin(2 * pi * 1.35 * t + phase1) + ...
        0.38 * sin(2 * pi * 4.80 * t + phase2));
    for f = 1:numel(field_names)
        fname = field_names{f};
        series = read_snr_series_local(obs_out, sid, fname);
        valid_mask = isfinite(series);
        if ~any(valid_mask)
            continue;
        end
        mod_series = series;
        idx = find(valid_mask);
        mod_series(idx) = series(idx) - atten_db + ripple(idx) + noise_sigma * randn(numel(idx), 1);
        if blocked_mask(s)
            drop_mask = rand(numel(idx), 1) < nan_prob;
            keep_idx = idx(~drop_mask);
            drop_idx = idx(drop_mask);
            mod_series(keep_idx) = min(mod_series(keep_idx), blocked_floor + 0.40 * randn(numel(keep_idx), 1));
            mod_series(drop_idx) = NaN;
            mod_series = apply_scene_window_dropout_local(mod_series, idx, 0.18, 0.48, 0.80, blocked_floor);
        end
        mod_series = clamp_scene_snr_local(mod_series);
        obs_out = write_snr_series_local(obs_out, sid, fname, mod_series);
    end
end
end

function obs_out = simulate_tree_scene_local(obs_case, scenario_cfg, seed_offset)
obs_out = obs_case;
n_epoch = numel(obs_out);
sat_ids = collect_satellite_ids_local(obs_out);
if isempty(sat_ids)
    return;
end

rng(get_cfg_local(scenario_cfg, 'random_seed', 20260331) + 211 * seed_offset, 'twister');
atten_db = get_cfg_local(scenario_cfg, 'tree_atten_db', 2.45);
noise_sigma = get_cfg_local(scenario_cfg, 'tree_noise_sigma', 0.38);
flicker_amp = get_cfg_local(scenario_cfg, 'tree_flicker_amp', 1.32);
drop_prob = get_cfg_local(scenario_cfg, 'tree_dropout_prob', 0.17);
partial_nan_ratio = get_cfg_local(scenario_cfg, 'tree_partial_nan_ratio', 0.19);

t = linspace(0, 1, n_epoch).';
for s = 1:numel(sat_ids)
    sid = sat_ids{s};
    field_names = collect_snr_fields_local(obs_out, sid);
    if isempty(field_names)
        continue;
    end
    phase1 = 2 * pi * rand();
    phase2 = 2 * pi * rand();
    envelope = 0.55 + 0.45 * sin(2 * pi * (0.55 + 0.05 * randn()) * t + phase1);
    flicker = flicker_amp * envelope .* sin(2 * pi * 3.20 * t + phase2);
    for f = 1:numel(field_names)
        fname = field_names{f};
        series = read_snr_series_local(obs_out, sid, fname);
        valid_mask = isfinite(series);
        if ~any(valid_mask)
            continue;
        end
        mod_series = series;
        idx = find(valid_mask);
        mod_series(idx) = series(idx) - atten_db + flicker(idx) + noise_sigma * randn(numel(idx), 1);
        burst_mask = rand(numel(idx), 1) < drop_prob;
        if any(burst_mask)
            burst_idx = idx(burst_mask);
            mod_series(burst_idx) = mod_series(burst_idx) - (1.6 + 0.6 * randn(numel(burst_idx), 1));
        end
        if partial_nan_ratio > 0
            nan_mask = rand(numel(idx), 1) < partial_nan_ratio;
            mod_series(idx(nan_mask)) = NaN;
        end
        mod_series = apply_scene_window_dropout_local(mod_series, idx, 0.12, 0.36, 0.52, 26.0);
        mod_series = clamp_scene_snr_local(mod_series);
        obs_out = write_snr_series_local(obs_out, sid, fname, mod_series);
    end
end
end

function series = apply_scene_window_dropout_local(series, valid_idx, start_ratio, mid_ratio, width_ratio, floor_db)
if isempty(valid_idx)
    return;
end
n = numel(series);
ctr1 = max(1, min(n, round(start_ratio * n)));
ctr2 = max(1, min(n, round(mid_ratio * n)));
half_w = max(1, round(width_ratio * 0.08 * n));
w1 = max(1, ctr1 - half_w):min(n, ctr1 + half_w);
w2 = max(1, ctr2 - half_w):min(n, ctr2 + half_w);
for win = {w1, w2}
    idx = intersect(valid_idx, win{1});
    if isempty(idx)
        continue;
    end
    series(idx) = min(series(idx), floor_db + 0.25 * randn(numel(idx), 1));
end
end

function x = clamp_scene_snr_local(x)
finite_mask = isfinite(x);
x(finite_mask) = min(max(x(finite_mask), 16), 55);
end

function sat_ids = collect_satellite_ids_local(obs_data)
sat_ids = {};
for i = 1:numel(obs_data)
    if ~isfield(obs_data(i), 'data') || isempty(obs_data(i).data)
        continue;
    end
    sat_ids = [sat_ids, fieldnames(obs_data(i).data)']; %#ok<AGROW>
end
sat_ids = unique(sat_ids, 'stable');
end

function field_names = collect_snr_fields_local(obs_data, sat_id)
field_names = {};
for i = 1:numel(obs_data)
    if ~isfield(obs_data(i), 'data') || isempty(obs_data(i).data) || ~isfield(obs_data(i).data, sat_id)
        continue;
    end
    sat_item = obs_data(i).data.(sat_id);
    if isfield(sat_item, 'snr') && ~isempty(sat_item.snr)
        field_names = fieldnames(sat_item.snr);
        return;
    end
end
end

function series = read_snr_series_local(obs_data, sat_id, field_name)
series = nan(numel(obs_data), 1);
for i = 1:numel(obs_data)
    if ~isfield(obs_data(i), 'data') || isempty(obs_data(i).data) || ~isfield(obs_data(i).data, sat_id)
        continue;
    end
    sat_item = obs_data(i).data.(sat_id);
    if isfield(sat_item, 'snr') && isfield(sat_item.snr, field_name)
        series(i) = sat_item.snr.(field_name);
    end
end
end

function obs_data = write_snr_series_local(obs_data, sat_id, field_name, series)
for i = 1:numel(obs_data)
    if ~isfield(obs_data(i), 'data') || isempty(obs_data(i).data) || ~isfield(obs_data(i).data, sat_id)
        continue;
    end
    sat_item = obs_data(i).data.(sat_id);
    if isfield(sat_item, 'snr') && isfield(sat_item.snr, field_name)
        obs_data(i).data.(sat_id).snr.(field_name) = series(i);
    end
end
end

function mode_name = canonical_scenario_mode_local(mode_name)
mode_name = lower(strtrim(string(mode_name)));
switch char(mode_name)
    case {'', 'none', 'open', 'open_field'}
        mode_name = "open_field";
    case {'near_building', 'building', 'urban_building'}
        mode_name = "near_building";
    case {'near_trees', 'trees', 'tree'}
        mode_name = "near_trees";
    otherwise
        mode_name = "open_field";
end
end

function case_out = augment_case_local(case_in)
case_out = case_in;
if ~isfield(case_out, 'scenario_applied')
    case_out.scenario_applied = false;
end
if ~isfield(case_out, 'scenario_mode')
    case_out.scenario_mode = "open_field";
end
if ~isfield(case_out, 'scenario_notes')
    case_out.scenario_notes = "";
end
end

function v = get_cfg_local(s, key, default_v)
if isstruct(s) && isfield(s, key)
    v = s.(key);
else
    v = default_v;
end
end

function h = hash_satellite_local(sat_id)
s = double(char(string(sat_id)));
if isempty(s)
    h = 0;
else
    h = sum((1:numel(s)) .* s);
end
end
