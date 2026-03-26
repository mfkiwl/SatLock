function cls = auth_classify_gesture(score_bundle, true_label)
% AUTH_CLASSIFY_GESTURE
% Select the predicted gesture label from Score_k values.

if nargin < 2
    true_label = "";
end

cls = struct();
cls.template_order = score_bundle.template_order;
cls.predicted_label = "";
cls.predicted_index = NaN;
cls.top_score = NaN;
cls.second_score = NaN;
cls.score_margin = NaN;
cls.true_label_score = NaN;
cls.predicted_distance = NaN;
cls.true_label_distance = NaN;

scores = score_bundle.values(:);
if isempty(scores) || ~any(isfinite(scores))
    return;
end

[sorted_scores, idx] = sort(scores, 'descend');
cls.predicted_index = idx(1);
cls.predicted_label = string(score_bundle.template_order{idx(1)});
cls.top_score = sorted_scores(1);
if numel(sorted_scores) >= 2
    cls.second_score = sorted_scores(2);
    cls.score_margin = sorted_scores(1) - sorted_scores(2);
else
    cls.second_score = 0;
    cls.score_margin = sorted_scores(1);
end

if isfield(score_bundle, 'distance') && numel(score_bundle.distance) >= idx(1)
    cls.predicted_distance = score_bundle.distance(idx(1));
end

if strlength(string(true_label)) > 0
    true_idx = find(strcmp(score_bundle.template_order, char(string(true_label))), 1, 'first');
    if ~isempty(true_idx)
        cls.true_label_score = scores(true_idx);
        if isfield(score_bundle, 'distance') && numel(score_bundle.distance) >= true_idx
            cls.true_label_distance = score_bundle.distance(true_idx);
        end
    end
end
end
