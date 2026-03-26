function parsed = layer1_parse_raw_data(cfg)
% LAYER1_PARSE_RAW_DATA
% Parse the raw observation and navigation data used by the workflow.

obs_base = parse_rinex_obs(cfg.obs_filepath);
nav_data = parse_rinex_nav_multi_gnss(cfg.nav_filepath);

all_sat_ids = {};
n_scan = min(numel(obs_base), 100);
for i = 1:n_scan
    if isfield(obs_base(i), 'data') && ~isempty(obs_base(i).data)
        all_sat_ids = [all_sat_ids, fieldnames(obs_base(i).data)']; %#ok<AGROW>
    end
end
all_sat_ids = unique(all_sat_ids);
systems = cellfun(@(s) upper(s(1)), all_sat_ids, 'UniformOutput', false);
systems = unique(systems);

parsed = struct();
parsed.obs_filepath = cfg.obs_filepath;
parsed.nav_filepath = cfg.nav_filepath;
parsed.obs_base = obs_base;
parsed.nav_data = nav_data;
parsed.epoch_count = numel(obs_base);
parsed.systems = systems;
parsed.status = "ok";
end
