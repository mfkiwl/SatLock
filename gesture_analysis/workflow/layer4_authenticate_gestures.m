function auth = layer4_authenticate_gestures(trajectory, cfg)
% LAYER4_AUTHENTICATE_GESTURES
% Classify recovered trajectories by comparing them against the template
% library and computing Score_k.

auth_cfg = cfg.auth_cfg;
if ~isfield(auth_cfg, 'template_order') || isempty(auth_cfg.template_order)
    auth_cfg.template_order = trajectory.template_order;
end

auth = auth_build_results(trajectory.gallery_cases, cfg.span_cfg, auth_cfg);
end
