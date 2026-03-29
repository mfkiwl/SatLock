function auth = auth_build_results(gallery_cases, span_cfg, auth_cfg)
% AUTH_BUILD_RESULTS
% Build Score_k-based authentication results from recovered trajectories.

if nargin < 3 || isempty(auth_cfg)
    auth_cfg = struct();
end
if ~isfield(auth_cfg, 'template_order') || isempty(auth_cfg.template_order)
    auth_cfg.template_order = gesture_template_store('all');
end

template_order = resolve_template_order_local(auth_cfg.template_order);
n_case = numel(gallery_cases);
rows = repmat(empty_auth_row_local(), n_case, 1);
summary_rows = repmat(struct( ...
    'case_id', "", ...
    'true_label', "", ...
    'attack_applied', false, ...
    'attack_mode', "", ...
    'predicted_label', "", ...
    'top_score', NaN, ...
    'score_margin', NaN, ...
    'predicted_distance', NaN, ...
    'true_label_score', NaN, ...
    'true_label_distance', NaN, ...
    'pred_rmse_m', NaN, ...
    'pred_mte_m', NaN, ...
    'pred_dtw_m', NaN, ...
    'true_rmse_m', NaN, ...
    'true_mte_m', NaN, ...
    'true_dtw_m', NaN, ...
    'status', ""), n_case, 1);

for i = 1:n_case
    case_item = gallery_cases(i);
    case_id = resolve_case_id_local(case_item, i);
    true_label = resolve_true_label_local(case_item);

    dist_bundle = auth_compute_template_distances( ...
        case_item.plot_x, case_item.plot_y, template_order, span_cfg, auth_cfg);
    score_bundle = auth_compute_template_scores(dist_bundle, auth_cfg);
    cls = auth_classify_gesture(score_bundle, true_label);

    pred_metrics = evaluate_case_against_label_local(case_item, cls.predicted_label, span_cfg);
    true_metrics = evaluate_case_against_label_local(case_item, true_label, span_cfg);

    rows(i).case_id = case_id;
    rows(i).true_label = true_label;
    rows(i).attack_applied = logical(resolve_attack_flag_local(case_item));
    rows(i).attack_mode = string(resolve_attack_mode_local(case_item));
    rows(i).predicted_label = cls.predicted_label;
    rows(i).template_order = template_order;
    rows(i).score_vector = score_bundle.values(:).';
    rows(i).distance_vector = dist_bundle.distance(:).';
    rows(i).rmse_vector = dist_bundle.rmse(:).';
    rows(i).mte_vector = dist_bundle.mte(:).';
    rows(i).dtw_vector = dist_bundle.dtw(:).';
    rows(i).phi_vector = dist_bundle.phi(:).';
    rows(i).top_score = cls.top_score;
    rows(i).second_score = cls.second_score;
    rows(i).score_margin = cls.score_margin;
    rows(i).true_label_score = cls.true_label_score;
    rows(i).predicted_distance = cls.predicted_distance;
    rows(i).true_label_distance = cls.true_label_distance;
    rows(i).predicted_metrics = pred_metrics;
    rows(i).true_label_metrics = true_metrics;
    rows(i).status = "ok";

    summary_rows(i).case_id = case_id;
    summary_rows(i).true_label = true_label;
    summary_rows(i).attack_applied = logical(resolve_attack_flag_local(case_item));
    summary_rows(i).attack_mode = string(resolve_attack_mode_local(case_item));
    summary_rows(i).predicted_label = cls.predicted_label;
    summary_rows(i).top_score = cls.top_score;
    summary_rows(i).score_margin = cls.score_margin;
    summary_rows(i).predicted_distance = cls.predicted_distance;
    summary_rows(i).true_label_score = cls.true_label_score;
    summary_rows(i).true_label_distance = cls.true_label_distance;
    summary_rows(i).pred_rmse_m = pred_metrics.rmse_m;
    summary_rows(i).pred_mte_m = pred_metrics.mte_m;
    summary_rows(i).pred_dtw_m = pred_metrics.dtw_m;
    summary_rows(i).true_rmse_m = true_metrics.rmse_m;
    summary_rows(i).true_mte_m = true_metrics.mte_m;
    summary_rows(i).true_dtw_m = true_metrics.dtw_m;
    summary_rows(i).status = "ok";
end

auth = struct();
auth.template_order = template_order;
auth.rows = rows;
auth.summary_tbl = struct2table(summary_rows);
end

function metrics = evaluate_case_against_label_local(case_item, label, span_cfg)
metrics = empty_metrics_local();
if strlength(string(label)) == 0 || isempty(case_item.full_x) || isempty(case_item.full_y)
    return;
end
if ~isfield(case_item, 't_grid') || isempty(case_item.t_grid)
    return;
end

[ref_x, ref_y, ref_pen] = gesture_template_store('groundtruth', char(string(label)), numel(case_item.t_grid), span_cfg);
metrics = evaluate_reconstruction_against_reference(case_item.full_x, case_item.full_y, ref_x, ref_y, ref_pen, 75);
end

function row = empty_auth_row_local()
row = struct( ...
    'case_id', "", ...
    'true_label', "", ...
    'attack_applied', false, ...
    'attack_mode', "", ...
    'predicted_label', "", ...
    'template_order', {{}}, ...
    'score_vector', [], ...
    'distance_vector', [], ...
    'rmse_vector', [], ...
    'mte_vector', [], ...
    'dtw_vector', [], ...
    'phi_vector', [], ...
    'top_score', NaN, ...
    'second_score', NaN, ...
    'score_margin', NaN, ...
    'true_label_score', NaN, ...
    'predicted_distance', NaN, ...
    'true_label_distance', NaN, ...
    'predicted_metrics', empty_metrics_local(), ...
    'true_label_metrics', empty_metrics_local(), ...
    'status', "");
end

function label = resolve_true_label_local(case_item)
if isfield(case_item, 'true_label') && strlength(string(case_item.true_label)) > 0
    label = string(case_item.true_label);
elseif isfield(case_item, 'template') && strlength(string(case_item.template)) > 0
    label = string(case_item.template);
else
    label = "";
end
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

function case_id = resolve_case_id_local(case_item, idx)
if isfield(case_item, 'case_id') && strlength(string(case_item.case_id)) > 0
    case_id = string(case_item.case_id);
else
    case_id = "case_" + string(idx);
end
end

function ordered = resolve_template_order_local(template_order)
base_order = {'LeftSwipe', 'RightSwipe', 'A', 'B', 'C', 'L', 'M', 'N', 'V', 'X', 'Z', 'Star', 'Rectangle'};
canon = @(c) gesture_template_store('label', c);
names = cellfun(canon, template_order, 'UniformOutput', false);
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
