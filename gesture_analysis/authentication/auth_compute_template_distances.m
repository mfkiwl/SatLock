function dist = auth_compute_template_distances(plot_x, plot_y, template_order, span_cfg, auth_cfg)
% AUTH_COMPUTE_TEMPLATE_DISTANCES
% Compute per-template classification distances from a recovered trajectory.

if nargin < 5 || isempty(auth_cfg)
    auth_cfg = struct();
end
if ~isfield(auth_cfg, 'compare_points') || isempty(auth_cfg.compare_points)
    auth_cfg.compare_points = 160;
end
if ~isfield(auth_cfg, 'weights') || ~isstruct(auth_cfg.weights)
    auth_cfg.weights = struct('alpha_dtw', 0.45, 'beta_rmse', 0.35, 'gamma_shape', 0.20);
end

trace_xy = [plot_x(:), plot_y(:)];
trace_xy = trace_xy(all(isfinite(trace_xy), 2), :);

dist = struct();
dist.template_order = template_order;
dist.rmse = inf(numel(template_order), 1);
dist.mte = inf(numel(template_order), 1);
dist.dtw = inf(numel(template_order), 1);
dist.phi = inf(numel(template_order), 1);
dist.distance = inf(numel(template_order), 1);
dist.trace_feature = struct();

if size(trace_xy, 1) < 4
    return;
end

n_cmp = max(60, round(auth_cfg.compare_points));
[xr, yr] = resample_polyline_local(trace_xy(:, 1), trace_xy(:, 2), n_cmp);
trace_xy = normalize_xy_local([xr, yr]);
feat = trace_shape_features_local(trace_xy);
dist.trace_feature = feat;

for i = 1:numel(template_order)
    [tx, ty] = gesture_template_store('trace', template_order{i}, n_cmp, span_cfg);
    tpl_xy = normalize_xy_local([tx(:), ty(:)]);
    [rmse_val, mte_val] = pointwise_error_local(trace_xy, tpl_xy);
    dtw_val = compute_dtw_local(trace_xy, tpl_xy, n_cmp);
    phi_val = template_shape_penalty_local(template_order{i}, feat);

    dist.rmse(i) = rmse_val;
    dist.mte(i) = mte_val;
    dist.dtw(i) = dtw_val;
    dist.phi(i) = phi_val;
    dist.distance(i) = ...
        auth_cfg.weights.alpha_dtw * dtw_val + ...
        auth_cfg.weights.beta_rmse * rmse_val + ...
        auth_cfg.weights.gamma_shape * phi_val;
end
end

function [rmse_val, mte_val] = pointwise_error_local(a, b)
a = a(all(isfinite(a), 2), :);
b = b(all(isfinite(b), 2), :);
n = min(size(a, 1), size(b, 1));
if n < 4
    rmse_val = inf;
    mte_val = inf;
    return;
end

a = a(1:n, :);
b = b(1:n, :);
err = vecnorm(a - b, 2, 2);
rmse_val = sqrt(mean(err .^ 2, 'omitnan'));
mte_val = mean(err, 'omitnan');
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

function xy = normalize_xy_local(xy)
xy = xy(all(isfinite(xy), 2), :);
if isempty(xy)
    return;
end
mu = mean(xy, 1, 'omitnan');
xy = xy - mu;
span = max(max(xy, [], 1) - min(xy, [], 1));
if ~isfinite(span) || span < 1e-6
    span = 1;
end
xy = xy / span;
end

function feat = trace_shape_features_local(trace_xy)
feat = struct('same_x_sign', false, 'x_progress', 0, 'y_progress', 0, ...
    'horizontal_ratio', 1, 'path_ratio', 1, 'corner_count', 0, ...
    'end_gap', 0, 'endpoint_x_min', 0, 'endpoint_x_max', 0);
trace_xy = trace_xy(all(isfinite(trace_xy), 2), :);
if size(trace_xy, 1) < 3
    return;
end

dx = diff(trace_xy(:, 1));
dy = diff(trace_xy(:, 2));
seg_len = hypot(dx, dy);
scale = max([max(trace_xy(:, 1)) - min(trace_xy(:, 1)), max(trace_xy(:, 2)) - min(trace_xy(:, 2)), eps]);
start_pt = trace_xy(1, :);
stop_pt = trace_xy(end, :);

feat.same_x_sign = signed_unit_local(start_pt(1)) * signed_unit_local(stop_pt(1)) > 0;
feat.x_progress = (stop_pt(1) - start_pt(1)) / scale;
feat.y_progress = (stop_pt(2) - start_pt(2)) / scale;
feat.horizontal_ratio = (max(trace_xy(:, 2)) - min(trace_xy(:, 2))) / ...
    max(max(trace_xy(:, 1)) - min(trace_xy(:, 1)), eps);
feat.path_ratio = sum(seg_len, 'omitnan') / scale;
feat.corner_count = count_turns_local(trace_xy, 48, 0.01);
feat.end_gap = norm(stop_pt - start_pt) / scale;
feat.endpoint_x_min = min(start_pt(1), stop_pt(1));
feat.endpoint_x_max = max(start_pt(1), stop_pt(1));
end

function pen = template_shape_penalty_local(template_name, feat)
pen = 0;
name = char(string(template_name));
switch name
    case 'A'
        if feat.corner_count < 2
            pen = pen + 0.35;
        end
        if feat.x_progress < 0.08
            pen = pen + 0.30;
        end
        if feat.path_ratio < 1.7
            pen = pen + 0.25;
        end
    case 'RightSwipe'
        if feat.x_progress < 0.22
            pen = pen + 0.90;
        end
        if feat.horizontal_ratio > 0.28
            pen = pen + 0.60;
        end
        if feat.corner_count > 1
            pen = pen + 0.25;
        end
    case 'LeftSwipe'
        if feat.x_progress > -0.22
            pen = pen + 0.90;
        end
        if feat.horizontal_ratio > 0.28
            pen = pen + 0.60;
        end
    case 'C'
        if ~feat.same_x_sign
            pen = pen + 0.80;
        end
        if feat.endpoint_x_min < 0.01
            pen = pen + 0.45;
        end
        if abs(feat.x_progress) > 0.20
            pen = pen + 0.25;
        end
    case 'L'
        if feat.y_progress > -0.18
            pen = pen + 0.45;
        end
        if feat.x_progress < 0.12
            pen = pen + 0.30;
        end
    case 'V'
        if feat.y_progress < 0.18
            pen = pen + 0.45;
        end
        if feat.corner_count < 1
            pen = pen + 0.20;
        end
    case 'X'
        if feat.corner_count < 2
            pen = pen + 0.55;
        end
        if feat.end_gap < 0.20
            pen = pen + 0.35;
        end
    case 'Star'
        if feat.corner_count < 4
            pen = pen + 0.55;
        end
        if feat.path_ratio < 2.4
            pen = pen + 0.30;
        end
    case 'Rectangle'
        if feat.corner_count < 3
            pen = pen + 0.55;
        end
        if feat.end_gap > 0.24
            pen = pen + 0.60;
        end
    case 'M'
        if feat.corner_count < 3
            pen = pen + 0.25;
        end
    case 'N'
        if feat.corner_count < 2
            pen = pen + 0.20;
        end
    case 'Z'
        if feat.corner_count < 2
            pen = pen + 0.20;
        end
end
end

function turn_count = count_turns_local(pts, angle_deg, min_step)
turn_count = 0;
if size(pts, 1) < 3
    return;
end
for i = 2:(size(pts, 1) - 1)
    v1 = pts(i, :) - pts(i - 1, :);
    v2 = pts(i + 1, :) - pts(i, :);
    n1 = norm(v1);
    n2 = norm(v2);
    if n1 < min_step || n2 < min_step
        continue;
    end
    ca = dot(v1, v2) / max(n1 * n2, eps);
    ca = min(max(ca, -1), 1);
    if acosd(ca) >= angle_deg
        turn_count = turn_count + 1;
    end
end
end

function s = signed_unit_local(v)
if v > 1e-6
    s = 1;
elseif v < -1e-6
    s = -1;
else
    s = 0;
end
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
