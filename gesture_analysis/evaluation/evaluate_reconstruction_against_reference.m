function met = evaluate_reconstruction_against_reference(full_x, full_y, ref_x, ref_y, ref_pen, max_shift)
% EVALUATE_RECONSTRUCTION_AGAINST_REFERENCE
% Evaluate a recovered trajectory against a reference template trajectory.

if nargin < 6 || isempty(max_shift)
    max_shift = 75;
end

met = empty_metrics_local();
if isempty(ref_x) || isempty(ref_y) || isempty(ref_pen)
    return;
end

idx_ref = find(ref_pen & isfinite(ref_x) & isfinite(ref_y));
if isempty(idx_ref)
    return;
end

valid_est = find(isfinite(full_x) & isfinite(full_y));
if isempty(valid_est)
    return;
end

N = numel(ref_x);
met.coverage = nnz(isfinite(full_x(idx_ref)) & isfinite(full_y(idx_ref))) / numel(idx_ref);
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
    idx_est = idx_ref + sh;
    keep = idx_est >= 1 & idx_est <= N;
    if nnz(keep) < max(8, round(0.2 * numel(idx_ref)))
        continue;
    end
    r_idx = idx_ref(keep);
    e_idx = idx_est(keep);
    err = hypot(est_x(e_idx) - ref_x(r_idx), est_y(e_idx) - ref_y(r_idx));
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

r_idx = idx_ref(best_keep);
e_idx = r_idx + best_shift;
err = hypot(est_x(e_idx) - ref_x(r_idx), est_y(e_idx) - ref_y(r_idx));
met.rmse_m = sqrt(mean(err .^ 2));
met.mte_m = mean(err);
met.dtw_m = compute_dtw_local([est_x(e_idx), est_y(e_idx)], [ref_x(r_idx), ref_y(r_idx)], 120);
met.start_err_m = err(1);
met.end_err_m = err(end);
met.point_errors_m = err;
met.aligned_est_x = est_x(e_idx);
met.aligned_est_y = est_y(e_idx);
met.aligned_gt_x = ref_x(r_idx);
met.aligned_gt_y = ref_y(r_idx);
met.path_length_m = polyline_length_local(met.aligned_est_x, met.aligned_est_y);
met.x_span_m = span_of_local(met.aligned_est_x);
met.y_span_m = span_of_local(met.aligned_est_y);
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

function d = compute_dtw_local(a, b, n_resample)
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
