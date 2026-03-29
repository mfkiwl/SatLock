function attacked = layer_attack_simulation(parsed, injected, cfg)
% LAYER_ATTACK_SIMULATION
% Optional attack simulation layer inserted between template injection and
% trajectory recovery. When disabled, the cases pass through unchanged.

attack_cfg = cfg.attack_cfg;
cases_in = injected.cases;
n_case = numel(cases_in);
if n_case > 0
    cases_out = repmat(augment_attack_case_local(cases_in(1)), n_case, 1);
else
    cases_out = cases_in;
end

summary_rows = repmat(struct( ...
    'case_id', "", ...
    'true_label', "", ...
    'attack_applied', false, ...
    'attack_mode', "", ...
    'source_mode', "", ...
    'notes', ""), n_case, 1);

mode_name = canonical_attack_mode_local(attack_cfg);
attack_on = logical(get_cfg_local(attack_cfg, 'enable', false)) && mode_name ~= "none";

for i = 1:n_case
    case_in = cases_in(i);
    case_out = augment_attack_case_local(case_in);
    case_out.attack_applied = attack_on;
    case_out.attack_mode = mode_name;
    case_out.attack_target = "observation";
    case_out.attack_notes = "Attack disabled";

    if attack_on
        switch char(mode_name)
            case 'replay'
                case_out.obs_case = simulate_replay_attack_local(case_in.obs_case, attack_cfg, i);
                case_out.attack_notes = "Replay attack: injected gesture perturbation removed from the observation stream.";
            case 'sdr_spoof'
                case_out.obs_case = simulate_sdr_spoof_attack_local(case_in.obs_case, attack_cfg, i);
                case_out.attack_notes = "SDR spoofing attack: multiple channels forged from one/few ground-point source waveforms.";
            case 'ghost_injection'
                case_out.obs_case = simulate_ghost_injection_attack_local(case_in.obs_case, attack_cfg, i);
                case_out.attack_notes = "Ghost/injection attack: software-layer fake observation perturbations inconsistent across satellites.";
            otherwise
                case_out.obs_case = case_in.obs_case;
                case_out.attack_applied = false;
                case_out.attack_mode = "none";
                case_out.attack_notes = "Unknown attack mode, passed through unchanged.";
        end
    end

    cases_out(i) = case_out;
    summary_rows(i).case_id = string(case_out.case_id);
    summary_rows(i).true_label = string(case_out.true_label);
    summary_rows(i).attack_applied = logical(case_out.attack_applied);
    summary_rows(i).attack_mode = string(case_out.attack_mode);
    summary_rows(i).source_mode = string(case_out.source_mode);
    summary_rows(i).notes = string(case_out.attack_notes);
end

attacked = struct();
attacked.enable = attack_on;
attacked.mode = mode_name;
attacked.template_order = injected.template_order;
attacked.cases = cases_out;
attacked.summary_tbl = struct2table(summary_rows);
end

function obs_out = simulate_replay_attack_local(obs_case, attack_cfg, seed_offset)
obs_out = flatten_attack_window_to_baseline_local(obs_case, attack_cfg, seed_offset);
end

function obs_out = simulate_sdr_spoof_attack_local(obs_case, attack_cfg, seed_offset)
obs_out = flatten_attack_window_to_baseline_local(obs_case, attack_cfg, seed_offset);
n_epoch = numel(obs_out);
win_mask = build_attack_window_mask_local(n_epoch, attack_cfg);
wave = build_common_spoof_waveform_local(n_epoch, win_mask);
sat_ids = collect_satellite_ids_local(obs_out);
rng(get_cfg_local(attack_cfg, 'random_seed', 20260326) + 100 * seed_offset, 'twister');

for s = 1:numel(sat_ids)
    sid = sat_ids{s};
    field_names = collect_snr_fields_local(obs_out, sid);
    sat_scale = max(0.75, 1.0 + 0.06 * randn());
    for f = 1:numel(field_names)
        fname = field_names{f};
        series = read_snr_series_local(obs_out, sid, fname);
        valid_mask = isfinite(series);
        if ~any(valid_mask & win_mask)
            continue;
        end
        baseline = median(series(valid_mask & ~win_mask), 'omitnan');
        if ~isfinite(baseline)
            baseline = median(series(valid_mask), 'omitnan');
        end
        if ~isfinite(baseline)
            baseline = 45;
        end
        mod_series = series;
        idx = find(valid_mask & win_mask);
        amp = get_cfg_local(attack_cfg, 'sdr_drop_db', 8.5) * sat_scale;
        mod_series(idx) = baseline - amp * wave(idx) + 0.04 * randn(numel(idx), 1);
        mod_series = clamp_snr_local(mod_series);
        obs_out = write_snr_series_local(obs_out, sid, fname, mod_series);
    end
end
end

function obs_out = simulate_ghost_injection_attack_local(obs_case, attack_cfg, seed_offset)
obs_out = flatten_attack_window_to_baseline_local(obs_case, attack_cfg, seed_offset);
n_epoch = numel(obs_out);
win_mask = build_attack_window_mask_local(n_epoch, attack_cfg);
sat_ids = collect_satellite_ids_local(obs_out);
rng(get_cfg_local(attack_cfg, 'random_seed', 20260326) + 200 * seed_offset, 'twister');

basis_bank = build_ghost_waveform_bank_local(n_epoch, win_mask);
if isempty(basis_bank)
    return;
end

for s = 1:numel(sat_ids)
    sid = sat_ids{s};
    field_names = collect_snr_fields_local(obs_out, sid);
    basis_idx = 1 + mod(sum(double(char(sid))) + seed_offset, numel(basis_bank));
    wave = basis_bank{basis_idx};
    sat_scale = max(0.60, 0.85 + 0.18 * randn());
    for f = 1:numel(field_names)
        fname = field_names{f};
        series = read_snr_series_local(obs_out, sid, fname);
        valid_mask = isfinite(series);
        if ~any(valid_mask & win_mask)
            continue;
        end
        baseline = median(series(valid_mask & ~win_mask), 'omitnan');
        if ~isfinite(baseline)
            baseline = median(series(valid_mask), 'omitnan');
        end
        if ~isfinite(baseline)
            baseline = 45;
        end
        mod_series = series;
        idx = find(valid_mask & win_mask);
        amp = get_cfg_local(attack_cfg, 'ghost_drop_db', 9.0) * sat_scale;
        mod_series(idx) = baseline - amp * wave(idx) + 0.06 * randn(numel(idx), 1);
        mod_series = clamp_snr_local(mod_series);
        obs_out = write_snr_series_local(obs_out, sid, fname, mod_series);
    end
end
end

function obs_out = flatten_attack_window_to_baseline_local(obs_in, attack_cfg, seed_offset)
obs_out = obs_in;
n_epoch = numel(obs_out);
win_mask = build_attack_window_mask_local(n_epoch, attack_cfg);
sat_ids = collect_satellite_ids_local(obs_out);
rng(get_cfg_local(attack_cfg, 'random_seed', 20260326) + seed_offset, 'twister');

for s = 1:numel(sat_ids)
    sid = sat_ids{s};
    field_names = collect_snr_fields_local(obs_out, sid);
    for f = 1:numel(field_names)
        fname = field_names{f};
        series = read_snr_series_local(obs_out, sid, fname);
        valid_mask = isfinite(series);
        if ~any(valid_mask & win_mask)
            continue;
        end
        baseline = median(series(valid_mask & ~win_mask), 'omitnan');
        if ~isfinite(baseline)
            baseline = median(series(valid_mask), 'omitnan');
        end
        if ~isfinite(baseline)
            baseline = 45;
        end
        local_sigma = std(series(valid_mask & ~win_mask), 0, 'omitnan');
        if ~isfinite(local_sigma) || local_sigma < 0.015
            local_sigma = get_cfg_local(attack_cfg, 'baseline_noise_sigma', 0.03);
        end
        idx = find(valid_mask & win_mask);
        series(idx) = baseline + 0.20 * local_sigma * randn(numel(idx), 1);
        series = clamp_snr_local(series);
        obs_out = write_snr_series_local(obs_out, sid, fname, series);
    end
end
end

function mask = build_attack_window_mask_local(n_epoch, attack_cfg)
start_ratio = get_cfg_local(attack_cfg, 'window_start_ratio', 0.25);
end_ratio = get_cfg_local(attack_cfg, 'window_end_ratio', 0.85);
start_idx = max(1, min(n_epoch, round(start_ratio * n_epoch)));
end_idx = max(start_idx, min(n_epoch, round(end_ratio * n_epoch)));
mask = false(n_epoch, 1);
mask(start_idx:end_idx) = true;
end

function wave = build_common_spoof_waveform_local(n_epoch, win_mask)
wave = zeros(n_epoch, 1);
idx = find(win_mask);
if isempty(idx)
    return;
end
p = linspace(0, 1, numel(idx)).';
wave(idx) = 0.52 * sin(pi * p) .^ 2 + ...
    0.28 * exp(-((p - 0.32) / 0.10) .^ 2) + ...
    0.22 * exp(-((p - 0.71) / 0.13) .^ 2);
wave = min(max(wave, 0), 1);
end

function bank = build_ghost_waveform_bank_local(n_epoch, win_mask)
bank = {};
idx = find(win_mask);
if isempty(idx)
    return;
end
p = linspace(0, 1, numel(idx)).';

w1 = zeros(n_epoch, 1);
w1(idx) = 0.65 * exp(-((p - 0.20) / 0.10) .^ 2) + 0.18 * sin(5.5 * pi * p) .^ 2;

w2 = zeros(n_epoch, 1);
w2(idx) = 0.55 * exp(-((p - 0.52) / 0.12) .^ 2) + 0.24 * exp(-((p - 0.82) / 0.07) .^ 2);

w3 = zeros(n_epoch, 1);
w3(idx) = 0.42 * sin(2.8 * pi * p + 0.5) .^ 2 + 0.26 * exp(-((p - 0.36) / 0.09) .^ 2);

w4 = zeros(n_epoch, 1);
w4(idx) = 0.34 * sin(6.0 * pi * p + 1.1) .^ 2 + 0.30 * exp(-((p - 0.66) / 0.08) .^ 2);

bank = {min(max(w1, 0), 1), min(max(w2, 0), 1), min(max(w3, 0), 1), min(max(w4, 0), 1)};
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
    if isfield(sat_item, 'snr') && isfield(sat_item.snr, field_name) && isfinite(series(i))
        obs_data(i).data.(sat_id).snr.(field_name) = series(i);
    end
end
end

function x = clamp_snr_local(x)
x = min(max(x, 18), 55);
end

function mode_name = canonical_attack_mode_local(attack_cfg)
mode_name = string(get_cfg_local(attack_cfg, 'mode', 'none'));
mode_name = lower(strtrim(mode_name));
switch char(mode_name)
    case {'none', ''}
        mode_name = "none";
    case {'replay', 'replay_attack'}
        mode_name = "replay";
    case {'sdr_spoof', 'sdr', 'spoof'}
        mode_name = "sdr_spoof";
    case {'ghost_injection', 'ghost', 'injection'}
        mode_name = "ghost_injection";
    otherwise
        mode_name = "none";
end
end

function v = get_cfg_local(s, key, default_v)
if isstruct(s) && isfield(s, key)
    v = s.(key);
else
    v = default_v;
end
end

function case_out = augment_attack_case_local(case_in)
case_out = case_in;
if ~isfield(case_out, 'attack_applied')
    case_out.attack_applied = false;
end
if ~isfield(case_out, 'attack_mode')
    case_out.attack_mode = "none";
end
if ~isfield(case_out, 'attack_target')
    case_out.attack_target = "observation";
end
if ~isfield(case_out, 'attack_notes')
    case_out.attack_notes = "";
end
end
