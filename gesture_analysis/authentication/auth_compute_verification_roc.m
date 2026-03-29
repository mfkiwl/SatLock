function roc_res = auth_compute_verification_roc(trial_tbl, opts)
% AUTH_COMPUTE_VERIFICATION_ROC
% Compute ROC and EER from claim-based verification trials.

if nargin < 2 || isempty(opts)
    opts = struct();
end
if ~isfield(opts, 'threshold_count') || isempty(opts.threshold_count)
    opts.threshold_count = 401;
end
if ~isfield(opts, 'require_predicted_match') || isempty(opts.require_predicted_match)
    opts.require_predicted_match = false;
end

roc_res = struct( ...
    'thresholds', [], ...
    'tpr', [], ...
    'fpr', [], ...
    'fnr', [], ...
    'eer', NaN, ...
    'eer_threshold', NaN, ...
    'eer_fpr', NaN, ...
    'eer_tpr', NaN, ...
    'auc', NaN, ...
    'n_genuine', 0, ...
    'n_impostor', 0);

if isempty(trial_tbl) || height(trial_tbl) == 0
    return;
end

valid = isfinite(trial_tbl.claim_score) & isfinite(double(trial_tbl.predicted_matches_claim));
trial_tbl = trial_tbl(valid, :);
if isempty(trial_tbl)
    return;
end

pos_mask = logical(trial_tbl.is_genuine);
neg_mask = ~pos_mask;
roc_res.n_genuine = sum(pos_mask);
roc_res.n_impostor = sum(neg_mask);
if roc_res.n_genuine == 0 || roc_res.n_impostor == 0
    return;
end

scores = trial_tbl.claim_score;
lo = min(scores);
hi = max(scores);
if ~isfinite(lo) || ~isfinite(hi)
    return;
end
if abs(hi - lo) < 1e-12
    hi = lo + 1e-6;
end

thresholds = linspace(hi + 1e-6, lo - 1e-6, max(32, round(opts.threshold_count))).';
accept_mask = false(height(trial_tbl), numel(thresholds));
for i = 1:numel(thresholds)
    tau = thresholds(i);
    local_accept = (trial_tbl.claim_score >= tau);
    if opts.require_predicted_match
        local_accept = local_accept & logical(trial_tbl.predicted_matches_claim);
    end
    accept_mask(:, i) = local_accept;
end

tpr = mean(accept_mask(pos_mask, :), 1, 'omitnan').';
fpr = mean(accept_mask(neg_mask, :), 1, 'omitnan').';
fnr = 1 - tpr;

[fpr_sorted, sort_idx] = sort(fpr, 'ascend');
tpr_sorted = tpr(sort_idx);
fnr_sorted = fnr(sort_idx);
thr_sorted = thresholds(sort_idx);

[fpr_unique, uniq_idx] = unique(fpr_sorted, 'stable');
tpr_unique = tpr_sorted(uniq_idx);
fnr_unique = fnr_sorted(uniq_idx);
thr_unique = thr_sorted(uniq_idx);

roc_res.thresholds = thr_unique;
roc_res.tpr = tpr_unique;
roc_res.fpr = fpr_unique;
roc_res.fnr = fnr_unique;
roc_res.auc = trapz(fpr_unique, tpr_unique);

[~, eer_idx] = min(abs(fpr_unique - fnr_unique));
roc_res.eer = mean([fpr_unique(eer_idx), fnr_unique(eer_idx)]);
roc_res.eer_threshold = thr_unique(eer_idx);
roc_res.eer_fpr = fpr_unique(eer_idx);
roc_res.eer_tpr = tpr_unique(eer_idx);
end
