function score = auth_compute_template_scores(distance_bundle, auth_cfg)
% AUTH_COMPUTE_TEMPLATE_SCORES
% Convert template distances into normalized Score_k values.

if nargin < 2 || isempty(auth_cfg)
    auth_cfg = struct();
end
if ~isfield(auth_cfg, 'temperature') || isempty(auth_cfg.temperature)
    auth_cfg.temperature = 0.16;
end

d = distance_bundle.distance(:);
score = struct();
score.template_order = distance_bundle.template_order;
score.distance = d;
score.temperature = auth_cfg.temperature;
score.values = zeros(size(d));
score.logits = -d / max(auth_cfg.temperature, 1e-6);
score.entropy = NaN;

finite_mask = isfinite(d);
if ~any(finite_mask)
    return;
end

logits = score.logits;
logits(~finite_mask) = -inf;
shift = max(logits(finite_mask));
weights = exp(logits - shift);
weights(~finite_mask) = 0;
z = sum(weights, 'omitnan');
if ~isfinite(z) || z <= 0
    return;
end

score.values = weights / z;
valid_scores = score.values(score.values > 0);
if isempty(valid_scores)
    score.entropy = 0;
else
    score.entropy = -sum(valid_scores .* log(valid_scores));
end
end
