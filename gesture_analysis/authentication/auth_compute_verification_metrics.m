function metrics = auth_compute_verification_metrics(trial_tbl, threshold, opts)
% AUTH_COMPUTE_VERIFICATION_METRICS
% Compute verification metrics at a fixed threshold.

if nargin < 3 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'require_predicted_match') || isempty(opts.require_predicted_match)
    opts.require_predicted_match = false;
end

metrics = struct( ...
    'threshold', threshold, ...
    'tp', 0, ...
    'tn', 0, ...
    'fp', 0, ...
    'fn', 0, ...
    'tpr', NaN, ...
    'tnr', NaN, ...
    'fpr', NaN, ...
    'fnr', NaN, ...
    'accuracy', NaN, ...
    'balanced_accuracy', NaN, ...
    'f1_score', NaN, ...
    'precision', NaN, ...
    'recall', NaN, ...
    'n_genuine', 0, ...
    'n_impostor', 0);

if isempty(trial_tbl) || height(trial_tbl) == 0 || ~isfinite(threshold)
    return;
end

valid = isfinite(trial_tbl.claim_score);
trial_tbl = trial_tbl(valid, :);
if isempty(trial_tbl)
    return;
end

accept = (trial_tbl.claim_score >= threshold);
if opts.require_predicted_match
    accept = accept & logical(trial_tbl.predicted_matches_claim);
end

genuine = logical(trial_tbl.is_genuine);
impostor = ~genuine;

metrics.n_genuine = sum(genuine);
metrics.n_impostor = sum(impostor);
metrics.tp = sum(accept & genuine);
metrics.fn = sum(~accept & genuine);
metrics.fp = sum(accept & impostor);
metrics.tn = sum(~accept & impostor);

metrics.tpr = safe_ratio_local(metrics.tp, metrics.tp + metrics.fn);
metrics.tnr = safe_ratio_local(metrics.tn, metrics.tn + metrics.fp);
metrics.fpr = safe_ratio_local(metrics.fp, metrics.fp + metrics.tn);
metrics.fnr = safe_ratio_local(metrics.fn, metrics.fn + metrics.tp);
metrics.accuracy = safe_ratio_local(metrics.tp + metrics.tn, height(trial_tbl));
metrics.balanced_accuracy = mean([metrics.tpr, metrics.tnr], 'omitnan');
metrics.precision = safe_ratio_local(metrics.tp, metrics.tp + metrics.fp);
metrics.recall = metrics.tpr;
metrics.f1_score = safe_ratio_local(2 * metrics.precision * metrics.recall, metrics.precision + metrics.recall);
end

function v = safe_ratio_local(a, b)
if ~isfinite(a) || ~isfinite(b) || b <= 0
    v = NaN;
else
    v = a / b;
end
end
