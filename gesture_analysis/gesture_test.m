% =========================================================================
% gesture_test.m
% Refactored scientific-figure workflow:
%   1) parse raw data
%   2) inject template data
%   3) run Data-Driven trajectory recovery
%   4) authenticate gestures via Score_k on the recovered trajectories
%   5) export paper-ready figures from the layered results
%
% Notes:
%   - Data-Driven recognition is the only trajectory result used downstream.
%   - No non-paper plots are exported from this entry script.
%   - The trash folder is intentionally excluded from the MATLAB path.
% =========================================================================
clear;
clc;
close all;

repo_dir = fileparts(fileparts(mfilename('fullpath')));
repo_paths = strsplit(genpath(repo_dir), pathsep);
keep_mask = false(size(repo_paths));
for i = 1:numel(repo_paths)
    this_path = repo_paths{i};
    if isempty(this_path)
        continue;
    end
    path_parts = regexp(lower(this_path), '[\\/]', 'split');
    if any(strcmp(path_parts, 'trash'))
        continue;
    end
    keep_mask(i) = true;
end
addpath(strjoin(repo_paths(keep_mask), pathsep));

%% ================= [Workflow Config] =================
workflow_cfg = struct();
workflow_cfg.obs_filepath = fullfile(repo_dir, 'data', '1_8', 'A_1_8_1.obs');
workflow_cfg.nav_filepath = fullfile(repo_dir, 'data', '1_8', '2026_1_8.nav');
workflow_cfg.span_cfg = struct('max_span_x', 0.50, 'max_span_y', 0.50);

%% ================= [Layer 1-3] Build Data-Driven Source =================
fprintf('\n[gesture_test] Building Data-Driven trajectory source...\n');
[trajectory_source_mat, trajectory_source] = build_gesture_test_source(workflow_cfg);
trajectory_cases = trajectory_source.trajectory.gallery_cases; %#ok<NASGU>
trajectory_summary = trajectory_source.trajectory.summary_tbl; %#ok<NASGU>
auth_summary = trajectory_source.auth.summary_tbl; %#ok<NASGU>

%% ================= [Layer 4] Export Scientific Figures =================
fprintf('[gesture_test] Exporting paper figures from Data-Driven results...\n');
paper_cfg = struct();
paper_cfg.source_mat = trajectory_source_mat;
paper_cfg.show_figures = false;
paper_cfg.reuse_cache = false;
[paper_manifest, paper_figure_dir] = export_paper_figures_data_driven(paper_cfg); %#ok<NASGU>

fprintf('\n[gesture_test] Scientific figures exported successfully.\n');
fprintf('  Source MAT : %s\n', trajectory_source_mat);
fprintf('  Figure dir : %s\n', paper_figure_dir);
