function injected = layer2_inject_templates(parsed, cfg)
% LAYER2_INJECT_TEMPLATES
% Build the per-case input set for downstream trajectory recovery.

inject_cfg = cfg.inject_cfg;
template_names = gesture_template_store('all');
template_names = resolve_template_order_local(template_names, cfg.template_order);

cases = repmat(struct( ...
    'case_id', "", ...
    'source_mode', "", ...
    'true_label', "", ...
    'reference_label', "", ...
    'obs_case', [], ...
    'notes', ""), 0, 1);

if inject_cfg.enable
    for i = 1:numel(template_names)
        template_name = template_names{i};
        sim_cfg_local = cfg.sim_cfg;
        sim_cfg_local.enable = true;
        sim_cfg_local.target_letter = template_name;
        sim_cfg_local.plot = false;
        obs_case = generate_ideal_multi_shape(parsed.obs_base, parsed.nav_data, template_name, sim_cfg_local);

        row = cases_template_row_local(i, template_name, obs_case);
        cases(end + 1, 1) = row; %#ok<AGROW>
    end
else
    true_label = string(inject_cfg.real_case_label);
    row = struct( ...
        'case_id', "real_case_1", ...
        'source_mode', "raw", ...
        'true_label', true_label, ...
        'reference_label', true_label, ...
        'obs_case', parsed.obs_base, ...
        'notes', "Injection disabled");
    cases(end + 1, 1) = row; %#ok<AGROW>
end

injected = struct();
injected.enable = inject_cfg.enable;
injected.template_order = template_names;
injected.cases = cases;
end

function row = cases_template_row_local(i, template_name, obs_case)
row = struct( ...
    'case_id', "sim_case_" + string(i), ...
    'source_mode', "simulated", ...
    'true_label', string(template_name), ...
    'reference_label', string(template_name), ...
    'obs_case', obs_case, ...
    'notes', "Template-injected sample");
end

function template_names = resolve_template_order_local(template_names, explicit_order)
if nargin >= 2 && ~isempty(explicit_order)
    base_order = cellstr(explicit_order);
else
base_order = {'LeftSwipe', 'RightSwipe', 'A', 'B', 'C', 'L', 'M', 'N', 'V', 'X', 'Z', 'Star', 'Rectangle'};
end

canon = @(c) gesture_template_store('label', c);
names = cellfun(canon, template_names, 'UniformOutput', false);
base_order = cellfun(canon, base_order, 'UniformOutput', false);

template_names = {};
for i = 1:numel(base_order)
    if any(strcmp(names, base_order{i}))
        template_names{end + 1} = base_order{i}; %#ok<AGROW>
    end
end

extras = setdiff(names, template_names, 'stable');
if ~isempty(extras)
    extras = sort(extras);
    template_names = [template_names, extras];
end
end
