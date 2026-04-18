function trial_tbl = auth_build_verification_trials(auth_rows, template_order, opts)
% AUTH_BUILD_VERIFICATION_TRIALS
% Expand Score_k results into claim-based verification trials.

if nargin < 3 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'include_attack') || isempty(opts.include_attack)
    opts.include_attack = false;
end

trial_rows = repmat(empty_trial_row_local(), 0, 1);

for i = 1:numel(auth_rows)
    row = auth_rows(i);
    if ~opts.include_attack && isfield(row, 'attack_applied') && logical(row.attack_applied)
        continue;
    end

    score_vec = reshape(resolve_vector_local(row, 'score_vector'), 1, []);
    dist_vec = reshape(resolve_vector_local(row, 'distance_vector'), 1, []);
    rmse_vec = reshape(resolve_vector_local(row, 'rmse_vector'), 1, []);
    dtw_vec = reshape(resolve_vector_local(row, 'dtw_vector'), 1, []);
    phi_vec = reshape(resolve_vector_local(row, 'phi_vector'), 1, []);
    n_vec = min([numel(template_order), numel(score_vec), numel(dist_vec), numel(rmse_vec), numel(dtw_vec), numel(phi_vec)]);
    if n_vec <= 0
        continue;
    end

    true_label = string(resolve_field_local(row, 'true_label', ""));
    predicted_label = string(resolve_field_local(row, 'predicted_label', ""));
    case_id = string(resolve_field_local(row, 'case_id', "case_" + string(i)));
    attack_mode = string(resolve_field_local(row, 'attack_mode', "none"));
    attack_applied = logical(resolve_field_local(row, 'attack_applied', false));
    scenario_mode = string(resolve_field_local(row, 'scenario_mode', "open_field"));
    scenario_applied = logical(resolve_field_local(row, 'scenario_applied', false));
    top_score = fallback_local(resolve_field_local(row, 'top_score', NaN), NaN);
    score_margin = fallback_local(resolve_field_local(row, 'score_margin', NaN), NaN);

    base_count = numel(trial_rows);
    trial_rows(base_count + n_vec) = empty_trial_row_local();
    for j = 1:n_vec
        claim_label = string(template_order{j});
        trial_rows(base_count + j).case_id = case_id;
        trial_rows(base_count + j).true_label = true_label;
        trial_rows(base_count + j).claim_label = claim_label;
        trial_rows(base_count + j).predicted_label = predicted_label;
        trial_rows(base_count + j).scenario_applied = scenario_applied;
        trial_rows(base_count + j).scenario_mode = scenario_mode;
        trial_rows(base_count + j).attack_applied = attack_applied;
        trial_rows(base_count + j).attack_mode = attack_mode;
        trial_rows(base_count + j).is_genuine = (true_label == claim_label);
        trial_rows(base_count + j).predicted_matches_claim = (predicted_label == claim_label);
        trial_rows(base_count + j).claim_score = score_vec(j);
        trial_rows(base_count + j).claim_distance = dist_vec(j);
        trial_rows(base_count + j).claim_rmse = rmse_vec(j);
        trial_rows(base_count + j).claim_dtw = dtw_vec(j);
        trial_rows(base_count + j).claim_phi = phi_vec(j);
        trial_rows(base_count + j).top_score = top_score;
        trial_rows(base_count + j).score_margin = score_margin;
    end
end

if isempty(trial_rows)
    trial_tbl = struct2table(trial_rows);
    return;
end

trial_tbl = struct2table(trial_rows);
end

function row = empty_trial_row_local()
row = struct( ...
    'case_id', "", ...
    'true_label', "", ...
    'claim_label', "", ...
    'predicted_label', "", ...
    'scenario_applied', false, ...
    'scenario_mode', "", ...
    'attack_applied', false, ...
    'attack_mode', "", ...
    'is_genuine', false, ...
    'predicted_matches_claim', false, ...
    'claim_score', NaN, ...
    'claim_distance', NaN, ...
    'claim_rmse', NaN, ...
    'claim_dtw', NaN, ...
    'claim_phi', NaN, ...
    'top_score', NaN, ...
    'score_margin', NaN);
end

function val = resolve_vector_local(row, field_name)
if isfield(row, field_name)
    val = row.(field_name);
else
    val = [];
end
end

function val = resolve_field_local(row, field_name, default_val)
if isfield(row, field_name)
    val = row.(field_name);
else
    val = default_val;
end
end

function out = fallback_local(val, default_val)
if nargin < 2
    default_val = NaN;
end
if isempty(val) || ~isfinite(val)
    out = default_val;
else
    out = val;
end
end
