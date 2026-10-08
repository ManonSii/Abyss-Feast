1;   % Run the script

%--------------------------------------------------------------------------
%Function to detect the last key pressed by the player
%--------------------------------------------------------------------------
function key_handler(figure_handle, key_event)
    % Save the pressed key for the game
    if isfield(key_event, "Key")
        setappdata(figure_handle, "last_key", lower(key_event.Key));
    endif
endfunction

%--------------------------------------------------------------------------
% Wait until one of the valide key is pressed
%--------------------------------------------------------------------------
function key = wait_for_key(figure_handle, valid_keys)
    key = "";
    setappdata(figure_handle, "last_key", "");
    % Loop until a valid key is found or the window is closed
    while isempty(key) && ishandle(figure_handle)
        pause(0.05);
        update_music(figure_handle);               % keep the music looping
        candidate = getappdata(figure_handle, "last_key");
        if ismember(candidate, valid_keys)
            key = candidate;
        endif
    endwhile
    % A closed window is treated as a request to quit
    if ~ishandle(figure_handle)
        key = "escape";
    endif
endfunction

%--------------------------------------------------------------------------
% Functions to handle mouse clicks
%--------------------------------------------------------------------------
function register_zone(figure_handle, left, right, bottom, top, click_key, owner_handle)
    zones = getappdata(figure_handle, "click_zones"); % Get the existing click zones
    if isempty(zones)     % Create the list if it does not exist
        zones = cell(0, 6);
    endif
    % Remove zones whose buttons no longer exist
    keep = false(1, size(zones, 1));
    for k = 1:size(zones, 1)
        keep(k) = ishandle(zones{k, 6});
    endfor
    zones = zones(keep, :); % Add the new click zone
    zones(end + 1, :) = {left, right, bottom, top, click_key, owner_handle};
    setappdata(figure_handle, "click_zones", zones);
endfunction

function click_handler(figure_handle, mouse_event)  % Get the click zones and the main axes
    zones = getappdata(figure_handle, "click_zones");
    axes_handle = getappdata(figure_handle, "main_axes");
    if isempty(zones) || isempty(axes_handle) || ~ishandle(axes_handle)  % Stop if the zones or axes are not available
        return;
    endif
    point = get(axes_handle, "CurrentPoint"); % Get the mouse position
    x = point(1, 1);
    y = point(1, 2);
    % Check which button was clicked
    for k = size(zones, 1):-1:1
        if ishandle(zones{k, 6}) && x >= zones{k, 1} && x <= zones{k, 2} && ...
           y >= zones{k, 3} && y <= zones{k, 4}
            setappdata(figure_handle, "last_key", zones{k, 5}); % Save the button action
            return;
        endif
    endfor
endfunction

%--------------------------------------------------------------------------
% Functions for background music
%   abyss_music.wav = normal music      abyss_boss.wav = music when a boss arrives
%--------------------------------------------------------------------------
% Create a music player from a wav file
function player = make_music_player(music_file)
    player = [];
    try
        if exist(music_file, "file") == 2
            [wave, fs] = audioread(music_file);
            wave = mean(wave, 2);                  % Convert to mono
            player = audioplayer(wave, fs);
        endif
    catch
        player = [];                               % No music if the file cannot be read
    end_try_catch
endfunction

% Play the music of the current mode ("normal" or "boss"), loop it, stop it if muted
function update_music(figure_handle)
    if ~ishandle(figure_handle)
        return;
    endif
    if ~isequal(getappdata(figure_handle, "sound_ok"), 1)
        return;
    endif
    normal_player = getappdata(figure_handle, "music_normal");
    boss_player   = getappdata(figure_handle, "music_boss");
    if strcmp(getappdata(figure_handle, "music_mode"), "boss") && ~isempty(boss_player)
        wanted = boss_player;
        other  = normal_player;
    else
        wanted = normal_player;
        other  = boss_player;
    endif
    try
        if ~isempty(other) && isplaying(other)
            stop(other);                           % the other music stops
        endif
        if ~isempty(wanted)
            if isequal(getappdata(figure_handle, "sound_on"), 1)
                if ~isplaying(wanted)
                    play(wanted);                  % (re)start = loop
                endif
            elseif isplaying(wanted)
                stop(wanted);
            endif
        endif
    catch
        setappdata(figure_handle, "sound_ok", 0);
    end_try_catch
endfunction

%--------------------------------------------------------------------------
% Function: table for the 6 fish species
% Stores the size and shape settings for each fish
%--------------------------------------------------------------------------
function species_table = get_species_table()
    species_table = [1.00 0.60 1.00 0.70 1.00 0.95 1.00 0;     % 1 reef fish
                     0.85 0.85 0.50 0.45 1.15 1.05 1.00 0;     % 2 puffer
                     1.50 0.25 0.90 0.35 0.50 0.45 1.00 0;     % 3 eel
                     1.30 0.28 0.90 0.50 0.55 0.50 0.60 1;     % 4 needlefish
                     1.50 0.50 0.90 0.90 1.50 0.80 0.50 0;     % 5 shark
                     0.95 0.85 0.50 0.55 1.15 1.05 1.00 2];    % 6 angler
endfunction

%--------------------------------------------------------------------------
% Function: create the shape of one fish
%--------------------------------------------------------------------------
function [body_x, body_y, fins_x, fins_y, stripe_x, stripe_y, eye_x, eye_y] = ...
        fish_shape(x, y, fish_size, direction, wiggle, species)
    % Species 1 (reef fish) is the default, used by the player
    if nargin < 6
        species = 1;
    endif
    species_table = get_species_table();
    len         = species_table(species, 1);
    hgt         = species_table(species, 2);
    tail_len    = species_table(species, 3);
    tail_h      = species_table(species, 4);
    dorsal_tip  = species_table(species, 5);
    ventral_tip = species_table(species, 6);
    notch       = species_table(species, 7);
    accessory   = species_table(species, 8);

    % Ellipse body
    angle_vector = linspace(0, 2*pi, 28);
    body_x = x + fish_size * len * cos(angle_vector);
    body_y = y + fish_size * hgt * sin(angle_vector);

    % Tail (can be forked), top fin and bottom fin (relative coordinates)
    tail_tip_x = -(0.8 * len + tail_len);
    tail_x = [-0.7 * len; tail_tip_x; -(0.8 * len + tail_len * notch); tail_tip_x; -0.7 * len];
    tail_y = [0.1 * tail_h; tail_h; 0; -tail_h; -0.1 * tail_h];
    dorsal_x = [-0.4 * len; -0.55 * len; 0.2 * len; 0.2 * len; 0.2 * len];
    dorsal_y = [0.85 * hgt; dorsal_tip; 0.9 * hgt; 0.9 * hgt; 0.9 * hgt];
    ventral_x = [-0.1 * len; -0.3 * len; 0.25 * len; 0.25 * len; 0.25 * len];
    ventral_y = [-0.85 * hgt; -ventral_tip; -0.85 * hgt; -0.85 * hgt; -0.85 * hgt];

    switch accessory
        case 1
            acc_x = [0.9 * len; len + 0.9; 0.9 * len; 0.9 * len; 0.9 * len];
            acc_y = [0.08; 0; -0.08; -0.08; -0.08];
        case 2
            acc_x = [0.4 * len; 1.1 * len; 0.55 * len; 0.55 * len; 0.55 * len];
            acc_y = [0.8 * hgt; hgt + 0.9; 0.85 * hgt; 0.85 * hgt; 0.85 * hgt];
        otherwise
            acc_x = zeros(5, 1);
            acc_y = zeros(5, 1);
    endswitch

    fins_x = x + direction * fish_size * [tail_x, dorsal_x, ventral_x, acc_x];
    fins_y = y + fish_size * [tail_y, dorsal_y, ventral_y, acc_y];
    % The tail moves up and down to look like swimming
    fins_y(2:4, 1) = fins_y(2:4, 1) + fish_size * wiggle;

    % Draw the dark band on the fish
    u_start = 0.05;
    u_end   = 0.30;
    stripe_x = x + direction * fish_size * len * [u_start u_end u_end u_start];
    stripe_y = y + fish_size * hgt * [sqrt(1 - u_start^2) sqrt(1 - u_end^2) ...
                                      -sqrt(1 - u_end^2) -sqrt(1 - u_start^2)];

    % Eye near the mouth
    eye_x = x + direction * 0.55 * len * fish_size;
    eye_y = y + 0.33 * hgt * fish_size;
endfunction

%--------------------------------------------------------------------------
% Function: draw teeth and angry eyebrows
%--------------------------------------------------------------------------
function [teeth_x, teeth_y, brow_x, brow_y] = fish_menace(x, y, fish_size, direction, species)
    species_table = get_species_table();
    len = species_table(species, 1);
    hgt = species_table(species, 2);
    % Draw teeth
    teeth_u = [0.97 0.90 0.84 0.78 0.72 0.66 0.60 0.54];
    teeth_v = [-0.02 -0.34 -0.10 -0.40 -0.14 -0.42 -0.16 -0.32];
    teeth_x = x + direction * fish_size * len * teeth_u;
    teeth_y = y + fish_size * hgt * teeth_v;
    % Draw the angry eyebrows
    brow_x = x + direction * fish_size * len * [0.34 0.80];
    brow_y = y + fish_size * hgt * [0.66 0.40];
endfunction

%--------------------------------------------------------------------------
% Function: check if the player touches another fish
%--------------------------------------------------------------------------
function hit = fish_overlap(player_x, player_y, player_size, fish_x, fish_y, fish_size, fish_species)
    species_table = get_species_table();
    half_length_sum = player_size * 1.0 + fish_size * species_table(fish_species, 1);
    half_height_sum = player_size * 0.6 + fish_size * species_table(fish_species, 2);
    dx = (player_x - fish_x) / half_length_sum;
    dy = (player_y - fish_y) / half_height_sum;
    hit = (dx^2 + dy^2 < 0.5);                         % Check if the fish are close enough
endfunction

%--------------------------------------------------------------------------
% Function: create a new enemy fish (species, size and speed)
%--------------------------------------------------------------------------
function [x, y, fish_size, direction, speed, species] = spawn_enemy(player_size, ...
        speed_factor, small_probability, allowed_species, world_width, world_height, ...
        player_x, player_y, initial_placement)
    % Choose a random fish species
    species = allowed_species(randi(numel(allowed_species)));
    species_speed = [1.0 0.7 1.2 1.5 1.0 0.6];                   % speed of each species
    % Create a smaller or bigger fish
    if rand < small_probability
        fish_size = player_size * (0.45 + 0.45 * rand);          % smaller fish
    else
        fish_size = player_size * (1.15 + 0.90 * rand);          % bigger fish
    endif
    fish_size = min(max(fish_size, 0.8), 14);                    % keep a good size
    direction = 2 * (rand > 0.5) - 1;                            % -1 = left, +1 = right (direction)
    speed     = speed_factor * species_speed(species) * (0.25 + 0.50 * rand);
    speed     = min(speed, 1.4);                                 % limit the speed
    y         = 7 + (world_height - 18) * rand;                  % random height
    if initial_placement
        % At the start of a round, keep fish away from the player
        x = world_width * rand;
        while hypot(x - player_x, y - player_y) < 28
            x = world_width * rand;
            y = 7 + (world_height - 18) * rand;
        endwhile
    else
        % Later, fish enter the screen from the side
        if direction == 1
            x = -4 * fish_size;
        else
            x = world_width + 4 * fish_size;
        endif
        % Too close to the player (player at the edge): enter from the other side
        if hypot(x - player_x, y - player_y) < 8 + 5 * fish_size
            direction = -direction;
            if direction == 1
                x = -4 * fish_size;
            else
                x = world_width + 4 * fish_size;
            endif
        endif
    endif
endfunction

%--------------------------------------------------------------------------
% Function: load the best score from a file
%--------------------------------------------------------------------------
function best_score = load_best_score(file_name)
    best_score = 0;
    file_id = fopen(file_name, "r");
    if file_id ~= -1
        value = fscanf(file_id, "%d", 1);
        if ~isempty(value)
            best_score = value;
        endif
        fclose(file_id);
    endif
endfunction

%--------------------------------------------------------------------------
% Function: save the best score in a text file
%--------------------------------------------------------------------------
function save_best_score(file_name, best_score)
    file_id = fopen(file_name, "w");
    if file_id ~= -1
        fprintf(file_id, "%d\n", best_score);
        fclose(file_id);
    endif
endfunction

%--------------------------------------------------------------------------
% Function: animate the seaweed
%--------------------------------------------------------------------------
function update_seaweed(seaweed_handles, seaweed_base_x, seaweed_top_y, frame_count)
    for k = 1:numel(seaweed_handles)
        seaweed_y = linspace(3.5, seaweed_top_y(k), 20);
        height_ratio = (seaweed_y - 3.5) / (seaweed_top_y(k) - 3.5);
        seaweed_x = seaweed_base_x(k) + 2.0 * height_ratio ...
                    .* sin(0.12 * frame_count + 3 * height_ratio + k);
        set(seaweed_handles(k), "XData", seaweed_x, "YData", seaweed_y);
    endfor
endfunction

%--------------------------------------------------------------------------
% Function: draw the background for each level
%--------------------------------------------------------------------------
function [seaweed_handles, seaweed_base_x, seaweed_top_y, theme] = draw_sea_background(axes_handle, level)
    cla(axes_handle);

    % Colours and plants of each level
    switch level
        case 1      % Sunny Reef
            deep_color = [0.02 0.30 0.50];  surface_color = [0.35 0.85 0.95];
            ray_alpha = 0.10;  sand_color = [0.95 0.88 0.60];  sand_edge = [0.80 0.70 0.40];
            rock_color = [0.45 0.47 0.52];  plant_color = [0.05 0.55 0.20];
            seaweed_base_x = [6 22 30 58 66 90];
            seaweed_top_y  = [16 20 14 22 15 19];
            theme.sil_color = [0.10 0.45 0.65];  theme.bubble_color = [1 1 1];
        case 2      % Kelp Forest
            deep_color = [0.02 0.18 0.18];  surface_color = [0.30 0.65 0.50];
            ray_alpha = 0.12;  sand_color = [0.55 0.50 0.30];  sand_edge = [0.40 0.35 0.20];
            rock_color = [0.35 0.40 0.30];  plant_color = [0.15 0.45 0.10];
            seaweed_base_x = [4 14 24 34 46 58 70 82 94];
            seaweed_top_y  = [30 38 26 40 32 36 28 34 30];
            theme.sil_color = [0.08 0.30 0.30];  theme.bubble_color = [0.9 1 0.9];
        case 3      % Sunken Ship
            deep_color = [0.02 0.07 0.20];  surface_color = [0.18 0.42 0.65];
            ray_alpha = 0.08;  sand_color = [0.50 0.50 0.48];  sand_edge = [0.30 0.30 0.30];
            rock_color = [0.30 0.33 0.38];  plant_color = [0.10 0.40 0.35];
            seaweed_base_x = [6 18 30 40];
            seaweed_top_y  = [14 18 12 16];
            theme.sil_color = [0.05 0.18 0.35];  theme.bubble_color = [0.9 0.95 1];
        case 4      % Magma Trench
            deep_color = [0.45 0.10 0.02];  surface_color = [0.08 0.05 0.15];
            ray_alpha = 0;     sand_color = [0.22 0.12 0.10];  sand_edge = [0.60 0.20 0.05];
            rock_color = [0.12 0.07 0.06];  plant_color = [0.85 0.30 0.10];
            seaweed_base_x = [6 16 26 36 46 54];
            seaweed_top_y  = [10 14 9 12 11 13];
            theme.sil_color = [0.28 0.08 0.08];  theme.bubble_color = [1 0.7 0.3];
        otherwise   % The Abyss
            deep_color = [0.00 0.00 0.03];  surface_color = [0.02 0.05 0.14];
            ray_alpha = 0;     sand_color = [0.06 0.06 0.10];  sand_edge = [0.15 0.15 0.30];
            rock_color = [0.10 0.10 0.18];  plant_color = [0.10 0.80 0.80];
            seaweed_base_x = [8 22 36 50 64 78 92];
            seaweed_top_y  = [15 22 12 25 14 20 17];
            theme.sil_color = [0.05 0.12 0.22];  theme.bubble_color = [0.5 0.9 1];
    endswitch

    % Draw the water background
    band_count = 24;
    for band = 1:band_count
        mix = (band - 1) / (band_count - 1);
        band_color = deep_color + mix * (surface_color - deep_color);
        y_low  = 60 * (band - 1) / band_count;
        y_high = 60 * band / band_count;
        patch("XData", [0 100 100 0], "YData", [y_low y_low y_high y_high], ...
              "FaceColor", band_color, "EdgeColor", "none", "Parent", axes_handle);
    endfor

    % Light rays coming from the surface
    if ray_alpha > 0
        ray_start_x = [12 38 64 86];
        for k = 1:numel(ray_start_x)
            patch("XData", [ray_start_x(k) ray_start_x(k)+8 ray_start_x(k)+23 ray_start_x(k)+12], ...
                  "YData", [60 60 5 5], "FaceColor", [1 1 1], "FaceAlpha", ray_alpha, ...
                  "EdgeColor", "none", "Parent", axes_handle);
        endfor
    endif

    % Special decor of each level
    switch level
        case 3      % Shipwreck
            patch("XData", [44 52 90 98], "YData", [13 4 4 13], "FaceColor", [0.22 0.14 0.10], ...
                  "EdgeColor", [0.10 0.07 0.05], "LineWidth", 2, "Parent", axes_handle);
            patch("XData", [60 60 80 80], "YData", [13 20 20 13], "FaceColor", [0.28 0.18 0.12], ...
                  "EdgeColor", [0.10 0.07 0.05], "LineWidth", 2, "Parent", axes_handle);
            line("XData", [70 70], "YData", [20 38], "Color", [0.20 0.12 0.08], ...
                 "LineWidth", 4, "Parent", axes_handle);
            patch("XData", [70 70 82], "YData", [37 24 26], "FaceColor", [0.60 0.58 0.50], ...
                  "EdgeColor", [0.30 0.30 0.25], "Parent", axes_handle);
            line("XData", [52 60 86], "YData", [9 9 9], "LineStyle", "none", "Marker", "o", ...
                 "MarkerSize", 6, "MarkerFaceColor", [0.95 0.80 0.35], "Color", [0.1 0.07 0.05], ...
                 "Parent", axes_handle);
        case 4      % Volcano with lava
            patch("XData", [0 100 100 0], "YData", [0 0 16 16], "FaceColor", [1 0.4 0.05], ...
                  "FaceAlpha", 0.18, "EdgeColor", "none", "Parent", axes_handle);
            patch("XData", [58 76 80 84 102], "YData", [3 23 21 23 3], "FaceColor", [0.18 0.09 0.08], ...
                  "EdgeColor", [0.05 0.03 0.03], "LineWidth", 2, "Parent", axes_handle);
            patch("XData", [76 80 84], "YData", [23 21 23], "FaceColor", [1 0.55 0.1], ...
                  "EdgeColor", "none", "Parent", axes_handle);
            line("XData", [80 78 74], "YData", [21 14 6], "Color", [1 0.45 0.05], ...
                 "LineWidth", 3, "Parent", axes_handle);
            line("XData", [81 84 90], "YData", [21 13 5], "Color", [1 0.45 0.05], ...
                 "LineWidth", 3, "Parent", axes_handle);
        case 5      % Bioluminescent lights
            line("XData", 100 * rand(1, 30), "YData", 8 + 46 * rand(1, 30), "LineStyle", "none", ...
                 "Marker", "o", "MarkerSize", 2, "MarkerFaceColor", [0.4 0.9 1], ...
                 "Color", [0.4 0.9 1], "Parent", axes_handle);
            line("XData", 100 * rand(1, 8), "YData", 8 + 46 * rand(1, 8), "LineStyle", "none", ...
                 "Marker", "o", "MarkerSize", 6, "MarkerFaceColor", [0.8 0.3 1], ...
                 "Color", [0.8 0.3 1], "Parent", axes_handle);
    endswitch

    % Draw the sand at the bottom
    dune_x = linspace(0, 100, 80);
    dune_y = 3.5 + 1.2 * sin(dune_x / 7) + 0.6 * sin(dune_x / 3);
    patch("XData", [dune_x 100 0], "YData", [dune_y 0 0], "FaceColor", sand_color, ...
          "EdgeColor", sand_edge, "Parent", axes_handle);

    % Draw the rocks
    rock_angle = linspace(0, pi, 20);
    rock_centers = [18 47 78];
    rock_widths  = [4 6 3.5];
    rock_heights = [2.5 3.5 2];
    for k = 1:numel(rock_centers)
        patch("XData", rock_centers(k) + rock_widths(k) * cos(rock_angle), ...
              "YData", 3 + rock_heights(k) * sin(rock_angle), "FaceColor", rock_color, ...
              "EdgeColor", 0.5 * rock_color, "Parent", axes_handle);
    endfor

    % Add coral in the Sunny Reef
    if level == 1
        line("XData", [38 38 36 38 40], "YData", [4 8 11 8 11], "Color", [0.95 0.40 0.55], ...
             "LineWidth", 4, "Parent", axes_handle);
        line("XData", [72 72 70 72 74], "YData", [4 7 10 7 10], "Color", [1.00 0.55 0.25], ...
             "LineWidth", 4, "Parent", axes_handle);
        line("XData", [95 95 93], "YData", [4 8 10], "Color", [0.95 0.40 0.55], ...
             "LineWidth", 4, "Parent", axes_handle);
    endif

    % Add the plants
    seaweed_handles = zeros(1, numel(seaweed_base_x));
    for k = 1:numel(seaweed_base_x)
        plant_shade = min(plant_color * (0.8 + 0.1 * mod(k, 3)), 1);
        seaweed_handles(k) = line("XData", seaweed_base_x(k) * ones(1, 20), ...
                                  "YData", linspace(3.5, seaweed_top_y(k), 20), ...
                                  "Color", plant_shade, "LineWidth", 3 + (level == 2), ...
                                  "Parent", axes_handle);
    endfor
    update_seaweed(seaweed_handles, seaweed_base_x, seaweed_top_y, 0);
endfunction

%--------------------------------------------------------------------------
% Function: show a message screen (title, rules, win, game over)
%--------------------------------------------------------------------------
function screen_handles = show_screen(axes_handle, title_text, text_lines, panel_color)
    % Draw the shadow, panel and text
    shadow = patch("XData", [12 92 92 12], "YData", [4 4 52 52], "FaceColor", [0 0 0], ...
                   "EdgeColor", "none", "Parent", axes_handle);
    panel = patch("XData", [10 90 90 10], "YData", [6 6 54 54], "FaceColor", panel_color, ...
                  "EdgeColor", [1 1 1], "LineWidth", 2, "Parent", axes_handle);
    title_shadow = text(50.4, 46.6, title_text, "HorizontalAlignment", "center", ...
                        "VerticalAlignment", "middle", "FontUnits", "normalized", ...
                        "FontSize", 0.07, "FontWeight", "bold", "Color", [0 0 0], ...
                        "Parent", axes_handle);
    title_main = text(50, 47, title_text, "HorizontalAlignment", "center", ...
                      "VerticalAlignment", "middle", "FontUnits", "normalized", ...
                      "FontSize", 0.07, "FontWeight", "bold", "Color", [1 0.85 0.2], ...
                      "Parent", axes_handle);
    message = text(50, 26, text_lines, "HorizontalAlignment", "center", ...
                   "VerticalAlignment", "middle", "FontUnits", "normalized", ...
                   "FontSize", 0.032, "Color", [1 1 1], "Parent", axes_handle);
    screen_handles = [shadow, panel, title_shadow, title_main, message];
endfunction

%--------------------------------------------------------------------------
% Function: keep round shapes looking correct
%--------------------------------------------------------------------------
function ratio = x_scale_ratio(axes_handle)
    ratio = 1;
    try
        figure_of_axes = ancestor(axes_handle, "figure");
        position = get(figure_of_axes, "Position");
        ratio = (position(4) / 60) / (position(3) / 100);
    catch
        ratio = 1;
    end_try_catch
endfunction

%--------------------------------------------------------------------------
% Function: create the shape of a gear (settings)
%--------------------------------------------------------------------------
function [gear_x, gear_y] = gear_shape(center_x, center_y, radius, x_ratio)
    tooth_count = 8;
    inner_radius = 0.72 * radius;
    step = 2 * pi / tooth_count;
    gear_x = [];
    gear_y = [];
    for k = 0:tooth_count - 1
        tooth_angle = k * step;
        angles = tooth_angle + step * [-0.30 -0.18 0.18 0.30];
        radii = [inner_radius radius radius inner_radius];
        gear_x = [gear_x, center_x + x_ratio * radii .* cos(angles)];
        gear_y = [gear_y, center_y + radii .* sin(angles)];
    endfor
endfunction

%--------------------------------------------------------------------------
% Function: draw a gear icon
%--------------------------------------------------------------------------
function gear_handles = draw_gear(axes_handle, center_x, center_y, radius, gear_color, hole_color)
    x_ratio = x_scale_ratio(axes_handle);
    [gear_x, gear_y] = gear_shape(center_x, center_y, radius, x_ratio);
    angle_vector = linspace(0, 2*pi, 24);
    gear_body = patch("XData", gear_x, "YData", gear_y, "FaceColor", gear_color, ...
                      "EdgeColor", [0.1 0.1 0.1], "LineWidth", 1, "Parent", axes_handle);
    gear_hole = patch("XData", center_x + 0.38 * radius * x_ratio * cos(angle_vector), ...
                      "YData", center_y + 0.38 * radius * sin(angle_vector), ...
                      "FaceColor", hole_color, "EdgeColor", [0.1 0.1 0.1], "Parent", axes_handle);
    gear_handles = [gear_body, gear_hole];
endfunction

%--------------------------------------------------------------------------
% Function: draw a fish that does not move (decoration of the title menu)
%--------------------------------------------------------------------------
function fish_handles = draw_static_fish(axes_handle, x, y, fish_size, direction, species, body_color, scary)
    [bx, by, fx, fy, sx, sy, ex, ey] = fish_shape(x, y, fish_size, direction, 0.15, species);
    fins   = patch("XData", fx, "YData", fy, "FaceColor", 0.7 * body_color, ...
                   "EdgeColor", 0.3 * body_color, "HitTest", "off", "Parent", axes_handle);
    body   = patch("XData", bx, "YData", by, "FaceColor", body_color, ...
                   "EdgeColor", 0.3 * body_color, "LineWidth", 1.5, "HitTest", "off", ...
                   "Parent", axes_handle);
    stripe = patch("XData", sx, "YData", sy, "FaceColor", 0.75 * body_color, ...
                   "EdgeColor", "none", "HitTest", "off", "Parent", axes_handle);
    if scary
        eye_color = [1 0.1 0.1];
    else
        eye_color = [1 1 1];
    endif
    eye = line("XData", ex, "YData", ey, "LineStyle", "none", "Marker", "o", "MarkerSize", 7, ...
               "MarkerFaceColor", eye_color, "Color", [0 0 0], "HitTest", "off", "Parent", axes_handle);
    fish_handles = [fins, body, stripe, eye];
    if scary
        [teeth_x, teeth_y, brow_x, brow_y] = fish_menace(x, y, fish_size, direction, species);
        teeth = line("XData", teeth_x, "YData", teeth_y, "Color", [1 1 1], "LineWidth", 2, ...
                     "HitTest", "off", "Parent", axes_handle);
        brow  = line("XData", brow_x, "YData", brow_y, "Color", [0.1 0 0], "LineWidth", 3, ...
                     "HitTest", "off", "Parent", axes_handle);
        fish_handles = [fish_handles, teeth, brow];
    endif
endfunction

%--------------------------------------------------------------------------
% function: play a short sound effect
%--------------------------------------------------------------------------
function play_sfx(figure_handle, kind)
    if ~isequal(getappdata(figure_handle, "sound_on"), 1) || ...
       ~isequal(getappdata(figure_handle, "sound_ok"), 1)
        return;
    endif
    fs = 8000;
    switch kind
        case "eat"          % Sound when a fish is eaten
            t = (0:round(0.10 * fs)) / fs;
            wave = 0.35 * sin(2*pi*(500*t + 3500*t.^2)) .* (1 - t / 0.10);
        case "hit"          % Sound when the player is hit
            t = (0:round(0.30 * fs)) / fs;
            wave = 0.40 * sign(sin(2*pi*(180*t - 250*t.^2))) .* (1 - t / 0.30);
        case "boss"         % Sound when the boss appears
            t = (0:round(0.70 * fs)) / fs;
            wave = 0.50 * sin(2*pi*(60*t + 20*t.^2)) .* (0.6 + 0.4*sin(2*pi*16*t)) ...
                   .* (1 - 0.4 * t / 0.70);
        case "win"          % Sound when the player wins
            notes = [523 659 784 1047];
            wave = [];
            t = (0:round(0.12 * fs)) / fs;
            for k = 1:numel(notes)
                wave = [wave, 0.35 * sin(2*pi*notes(k)*t) .* (1 - 0.6 * t / 0.12)];
            endfor
        case "lose"         % Sound when the player loses
            notes = [392 330 262 196];
            wave = [];
            t = (0:round(0.15 * fs)) / fs;
            for k = 1:numel(notes)
                wave = [wave, 0.35 * sin(2*pi*notes(k)*t) .* (1 - 0.6 * t / 0.15)];
            endfor
        case "click" % Sound when a button is clicked
            t = (0:round(0.04 * fs)) / fs;
            wave = 0.30 * sin(2*pi*900*t) .* (1 - t / 0.04);
        otherwise
            return;
    endswitch
    try
        sfx_player = audioplayer(wave, fs);
        play(sfx_player);
        setappdata(figure_handle, "sfx_player", sfx_player);
    catch
        setappdata(figure_handle, "sound_ok", 0);
    end_try_catch
endfunction

%--------------------------------------------------------------------------
% Function: create a clickable button
%--------------------------------------------------------------------------
function button_handles = make_button(figure_handle, axes_handle, center_x, center_y, ...
        button_width, button_height, label, base_color, click_key, font_size)
    left   = center_x - button_width / 2;
    right  = center_x + button_width / 2;
    bottom = center_y - button_height / 2;
    top    = center_y + button_height / 2;
    shadow = patch("XData", [left right right left] + 0.6, "YData", [bottom bottom top top] - 0.9, ...
                   "FaceColor", [0 0 0], "FaceAlpha", 0.45, "EdgeColor", "none", ...
                   "HitTest", "off", "Parent", axes_handle);
    body   = patch("XData", [left right right left], "YData", [bottom bottom top top], ...
                   "FaceColor", base_color, "EdgeColor", [1 1 1], "LineWidth", 2.5, ...
                   "ButtonDownFcn", @(src, evt) setappdata(figure_handle, "last_key", click_key), ...
                   "Parent", axes_handle);
    shine  = patch("XData", [left + 0.6, right - 0.6, right - 0.6, left + 0.6], ...
                   "YData", [center_y + 0.2, center_y + 0.2, top - 0.5, top - 0.5], ...
                   "FaceColor", [1 1 1], "FaceAlpha", 0.18, "EdgeColor", "none", ...
                   "HitTest", "off", "Parent", axes_handle);
    label_handle = text(center_x, center_y, label, "HorizontalAlignment", "center", ...
                        "VerticalAlignment", "middle", "FontUnits", "normalized", ...
                        "FontSize", font_size, "FontWeight", "bold", "Color", [1 1 1], ...
                        "HitTest", "off", "Parent", axes_handle);
    register_zone(figure_handle, left, right, bottom, top, click_key, body);
    button_handles = [shadow, body, shine, label_handle];
endfunction

%--------------------------------------------------------------------------
% Function: draw the title menu
%--------------------------------------------------------------------------
function menu_handles = draw_title_menu(figure_handle, axes_handle)
    menu_handles = [];
    x_ratio = x_scale_ratio(axes_handle);

    % Draw the dark background, bubbles and fish
    menu_handles(end + 1) = patch("XData", [0 100 100 0], "YData", [38.5 38.5 60 60], ...
                                  "FaceColor", [0 0.05 0.15], "FaceAlpha", 0.35, "EdgeColor", "none", ...
                                  "HitTest", "off", "Parent", axes_handle);
    menu_handles(end + 1) = line("XData", 100 * rand(1, 14), "YData", 4 + 52 * rand(1, 14), ...
                                 "LineStyle", "none", "Marker", "o", "MarkerSize", 5, ...
                                 "Color", [1 1 1], "HitTest", "off", "Parent", axes_handle);
    shark_handles = draw_static_fish(axes_handle, 15, 22.5, 4.2, 1, 5, [0.75 0.05 0.08], true);
    fish_handles  = draw_static_fish(axes_handle, 85, 22.5, 3.0, 1, 1, [1 0.65 0.1], false);
    menu_handles = [menu_handles, shark_handles, fish_handles];

    % Draw the game title
    title_lines  = {"A B Y S S", "F E A S T"};
    title_y      = [53.8, 45.4];
    title_colors = {[0.75 0.95 1.0], [1.0 0.75 0.15]};
    for k = 1:2
        % Add the shadow and outline
        menu_handles(end + 1) = text(50.9, title_y(k) - 1.0, title_lines{k}, ...
            "HorizontalAlignment", "center", "VerticalAlignment", "middle", ...
            "FontUnits", "normalized", "FontSize", 0.17, "FontWeight", "bold", ...
            "Color", [0 0.03 0.1], "HitTest", "off", "Parent", axes_handle);
        for a = 0:7
            menu_handles(end + 1) = text(50 + 0.55 * cos(a * pi / 4), title_y(k) + 0.45 * sin(a * pi / 4), ...
                title_lines{k}, "HorizontalAlignment", "center", "VerticalAlignment", "middle", ...
                "FontUnits", "normalized", "FontSize", 0.17, "FontWeight", "bold", ...
                "Color", [0.02 0.12 0.25], "HitTest", "off", "Parent", axes_handle);
        endfor
        menu_handles(end + 1) = text(50, title_y(k), title_lines{k}, ...
            "HorizontalAlignment", "center", "VerticalAlignment", "middle", ...
            "FontUnits", "normalized", "FontSize", 0.17, "FontWeight", "bold", ...
            "Color", title_colors{k}, "HitTest", "off", "Parent", axes_handle);
    endfor
    menu_handles(end + 1) = text(50, 36.8, "EAT  OR  BE  EATEN", "HorizontalAlignment", "center", ...
        "VerticalAlignment", "middle", "FontUnits", "normalized", "FontSize", 0.036, ...
        "FontWeight", "bold", "Color", [0.8 0.95 1], "HitTest", "off", "Parent", axes_handle);

    % Create the PLAY and SETTINGS buttons
    play_button = make_button(figure_handle, axes_handle, 50, 28.5, 40, 8.5, "PLAY", ...
                              [0.12 0.60 0.30], "click_play", 0.07);
    triangle = patch("XData", 37 + x_ratio * [-1.6 -1.6 1.8], "YData", 28.5 + [-2.2 2.2 0], ...
                     "FaceColor", [1 1 1], "EdgeColor", "none", "HitTest", "off", "Parent", axes_handle);
    settings_button = make_button(figure_handle, axes_handle, 50, 17.5, 40, 8.5, "SETTINGS", ...
                                  [0.15 0.40 0.70], "click_settings", 0.055);
    gear_handles = draw_gear(axes_handle, 36.5, 17.5, 2.6, [1 1 1], [0.15 0.40 0.70]);
    set(gear_handles, "HitTest", "off");
    menu_handles = [menu_handles, play_button, triangle, settings_button, gear_handles];

    % Show the keyboard controls
    menu_handles(end + 1) = patch("XData", [0 100 100 0], "YData", [4 4 10 10], "FaceColor", [0 0.05 0.15], ...
                                  "FaceAlpha", 0.35, "EdgeColor", "none", "HitTest", "off", ...
                                  "Parent", axes_handle);
    menu_handles(end + 1) = text(50, 7, "CLICK PLAY (or ENTER)     S = settings     M = sound on/off     ESC = quit", ...
        "HorizontalAlignment", "center", "VerticalAlignment", "middle", "FontUnits", "normalized", ...
        "FontSize", 0.028, "Color", [0.85 0.95 1], "HitTest", "off", "Parent", axes_handle);
endfunction

%--------------------------------------------------------------------------
% Function: show the settings panel
%--------------------------------------------------------------------------
function show_settings(figure_handle, axes_handle)
    items = [];
    % Draw the dark background and settings panel
    items(end + 1) = patch("XData", [0 100 100 0], "YData", [0 0 60 60], "FaceColor", [0 0 0], ...
                           "FaceAlpha", 0.65, "EdgeColor", "none", "Parent", axes_handle);
    items(end + 1) = patch("XData", [6 94 94 6], "YData", [3 3 57 57], "FaceColor", [0.04 0.18 0.32], ...
                           "EdgeColor", [1 1 1], "LineWidth", 2.5, "Parent", axes_handle);
    items(end + 1) = text(52.4, 50.8, "SETTINGS", "HorizontalAlignment", "center", ...
                          "VerticalAlignment", "middle", "FontUnits", "normalized", "FontSize", 0.075, ...
                          "FontWeight", "bold", "Color", [0 0 0], "Parent", axes_handle);
    items(end + 1) = text(52, 51.5, "SETTINGS", "HorizontalAlignment", "center", ...
                          "VerticalAlignment", "middle", "FontUnits", "normalized", "FontSize", 0.075, ...
                          "FontWeight", "bold", "Color", [1 0.85 0.2], "Parent", axes_handle);
    items = [items, draw_gear(axes_handle, 31, 51.5, 2.8, [1 0.85 0.2], [0.04 0.18 0.32])];

    % Show the game instructions
    rows = { 45.4, "THE GOAL", 1;
             42.0, "Cross 5 levels. In each one, eat smaller fish to grow,", 0;
             39.1, "then beat the BOSS: get bigger than it and EAT it!", 0;
             34.4, "HOW TO PLAY", 1;
             31.0, "Swim: arrow keys  or  Z Q S D  /  W A S D", 0;
             28.1, "Green = edible    Yellow = same size    Red = DANGER", 0;
             25.2, "Red fish hunt you and bite: you lose a life and shrink", 0;
             22.3, "Red dashed line = the boss is about to charge!", 0;
             19.4, "SPACE = stop   P = settings   M = sound/music on-off   ESC = quit", 0 };
    for r = 1:size(rows, 1)
        if rows{r, 3}
            text_color = [1 0.85 0.2];
            text_size = 0.04;
            text_weight = "bold";
        else
            text_color = [1 1 1];
            text_size = 0.03;
            text_weight = "normal";
        endif
        items(end + 1) = text(11, rows{r, 1}, rows{r, 2}, "HorizontalAlignment", "left", ...
                              "VerticalAlignment", "middle", "FontUnits", "normalized", ...
                              "FontSize", text_size, "FontWeight", text_weight, "Color", text_color, ...
                              "Parent", axes_handle);
    endfor

    % Create the sound and BACK buttons
    sound_button = make_button(figure_handle, axes_handle, 30, 10.5, 34, 7.5, "SOUND: ON", ...
                               [0.12 0.60 0.30], "click_sound", 0.045);
    back_button  = make_button(figure_handle, axes_handle, 70, 10.5, 34, 7.5, "BACK", ...
                               [0.15 0.40 0.70], "click_back", 0.05);
    items = [items, sound_button, back_button];

    done = false;
    while ~done && ishandle(figure_handle)
        if isequal(getappdata(figure_handle, "sound_on"), 1)
            set(sound_button(4), "String", "SOUND: ON");
            set(sound_button(2), "FaceColor", [0.12 0.60 0.30]);
        else
            set(sound_button(4), "String", "SOUND: MUTED");
            set(sound_button(2), "FaceColor", [0.55 0.20 0.20]);
        endif
        key = wait_for_key(figure_handle, {"click_sound", "m", "click_back", "escape", ...
                                           "return", "space", "b", "p"});
        if any(strcmp(key, {"click_sound", "m"})) % Turn the sound on or off
            if isequal(getappdata(figure_handle, "sound_on"), 1)
                setappdata(figure_handle, "sound_on", 0);
            else
                setappdata(figure_handle, "sound_on", 1);
                play_sfx(figure_handle, "click");
            endif
        else
            done = true;
        endif
    endwhile
    if ishandle(figure_handle) % Remove the settings panel
        delete(items(ishandle(items)));
    endif
endfunction

%--------------------------------------------------------------------------
% Play one level
%--------------------------------------------------------------------------
function [outcome, final_score] = play_round(figure_handle, axes_handle, level, best_score, start_score)
    % Set the settings for each level
    level_names       = {"Sunny Reef", "Kelp Forest", "Sunken Ship", "Magma Trench", "The Abyss"};
    boss_names        = {"Giant Puffer", "Barracuda", "Moray Boss", "Anglerfish King", "Megalodon"};
    boss_species_list = [2 4 3 6 5];               % species used for each boss
    boss_size_list    = [8.0 9.0 10.0 11.0 12.0];    % size of each boss
    boss_trigger_list = [5.5 6.0 6.5 7.0 7.5];     % player size that calls the boss
    boss_speed_list   = [0.55 0.64 0.72 0.80 0.86];% boss speed
    telegraph_list    = [30 27 24 21 18];          % warning time before an attack
    dash_wait_list    = [120 105 92 80 70];       % Time between attacks
    small_prob_list   = [0.70 0.65 0.60 0.55 0.50];% Chance of small fish
    species_lists     = {[1 1 2], [1 2 4], [1 3 4 2], [1 3 4 6], [1 2 3 4 5]};
    combo_list        = [0 1 1 2 2];               % Number of extra attacks
    lives_list        = [4 4 4 4 3];               % lives at each level
    hunt_radius_list  = [18 20 22 24 26];          % distance at which red fish hunt you
    hunt_boost_list   = [0.70 0.75 0.80 0.85 0.90];     % speed multiplier of hunting fish

    % --- Constants of the game ---
    world_width     = 100;                         % width of the sea
    world_height    = 60;                          % height of the sea
    start_size      = 2;                           % size of the player at the start
    growth_ratio    = 0.25;                        % Fish growth rate
    initial_lives   = lives_list(level);                           % number of lives
    base_speed      = 1.2;                         % player speed
    frame_pause     = 0.02;                        % pause between frames (seconds)
    size_tolerance  = 1.05;                        % size difference allowed
    enemy_count     = 7 + level;                   % more fish at each level
    speed_factor    = 1 + 0.15 * (level - 1);      % faster fish at each level
    level_count     = numel(level_names);

    % --- Settings of the current level and of its boss ---
    boss_species    = boss_species_list(level);
    boss_size       = boss_size_list(level);
    boss_trigger    = boss_trigger_list(level);
    boss_speed      = boss_speed_list(level);
    telegraph_frames = telegraph_list(level);
    dash_wait       = dash_wait_list(level);
    small_probability = small_prob_list(level);
    allowed_species = species_lists{level};
    boss_win_size   = boss_size * size_tolerance;  % size needed to eat the boss
    boss_combo_max  = combo_list(level);
    hunt_radius     = hunt_radius_list(level);
    hunt_boost      = hunt_boost_list(level);

    % --- Variables of the player ---
    player_x     = world_width / 2;
    player_y     = world_height / 2;
    player_size  = start_size;
    player_dir_x = 1;                              % +1 = looks right, -1 = looks left
    velocity     = [0 0];                          % current swimming direction
    lives        = initial_lives;
    score        = start_score;
    displayed_score = start_score;                 % score shown on the screen (counts up)
    invulnerable_frames = 0;                       % frames without danger after a hit
    frame_count  = 0;
    outcome      = "playing";
    final_score  = start_score;

    % --- Variables of the boss ---
    boss_active  = false;                          % true once the boss has arrived
    boss_defeated = false;
    boss_was_edible = false;
    boss_x = 0;  boss_y = 0;  boss_dir = 1;
    boss_mode    = "chase";                        % boss movement mode
    boss_timer   = dash_wait;
    dash_vector  = [1 0];
    boss_combo   = 0;                              % Number of attacks left

    % --- Variables of the effects ---
    burst_age     = 0;                             % Sparkle effect
    burst_x       = 0;
    burst_y       = 0;
    burst_angles  = linspace(0, 2*pi, 9)(1:8);     % Sparkle directions
    hit_flash_frames = 0;                          % Red flash duration
    shake_frames  = 0;                             % Screen shake duration
    banner_frames = 100;                           % time the banner stay visible

    % Draw the background first
    [seaweed_handles, seaweed_base_x, seaweed_top_y, theme] = draw_sea_background(axes_handle, level);

    % Dark silhouettes of fish swimming slowly far in the background
    sil_count   = 3;
    sil_species = [1 5 1];
    sil_x       = world_width * rand(1, sil_count);
    sil_y       = 18 + 25 * rand(1, sil_count);
    sil_size    = 3 + 3 * rand(1, sil_count);
    sil_dir     = [1 -1 1];
    sil_speed   = 0.08 + 0.10 * rand(1, sil_count);
    sil_body    = zeros(1, sil_count);
    sil_fins    = zeros(1, sil_count);
    for i = 1:sil_count
        [bx, by, fx, fy] = fish_shape(sil_x(i), sil_y(i), sil_size(i), sil_dir(i), 0, sil_species(i));
        sil_fins(i) = patch("XData", fx, "YData", fy, "FaceColor", theme.sil_color, ...
                            "EdgeColor", "none", "Parent", axes_handle);
        sil_body(i) = patch("XData", bx, "YData", by, "FaceColor", theme.sil_color, ...
                            "EdgeColor", "none", "Parent", axes_handle);
    endfor

    % Bubbles: 10 small and 5 big ones
    bubble_x = world_width * rand(1, 15);
    bubble_y = world_height * rand(1, 15);
    bubble_rise = [0.25 * ones(1, 10), 0.40 * ones(1, 5)];
    bubble_small = line("XData", bubble_x(1:10), "YData", bubble_y(1:10), "LineStyle", "none", ...
                        "Marker", "o", "MarkerSize", 3, "Color", theme.bubble_color, ...
                        "Parent", axes_handle);
    bubble_big = line("XData", bubble_x(11:15), "YData", bubble_y(11:15), "LineStyle", "none", ...
                      "Marker", "o", "MarkerSize", 7, "Color", theme.bubble_color, ...
                      "Parent", axes_handle);

    % Darken the background when the boss appears on the screen
    boss_dark = patch("XData", [0 100 100 0], "YData", [0 0 60 60], "FaceColor", [0 0 0], ...
                      "FaceAlpha", 0.22, "EdgeColor", "none", "Visible", "off", ...
                      "Parent", axes_handle);

    % Player graphics
    [bx, by, fx, fy, sx, sy, ex, ey] = fish_shape(player_x, player_y, player_size, player_dir_x, 0);
    player_fins   = patch("XData", fx, "YData", fy, "FaceColor", [0.85 0.35 0.05], ...
                          "EdgeColor", [0.4 0.2 0], "Parent", axes_handle);
    player_body   = patch("XData", bx, "YData", by, "FaceColor", [1 0.65 0.1], ...
                          "EdgeColor", [0.4 0.2 0], "LineWidth", 1.5, "Parent", axes_handle);
    player_stripe = patch("XData", sx, "YData", sy, "FaceColor", [0.90 0.40 0.05], ...
                          "EdgeColor", "none", "Parent", axes_handle);
    player_eye    = line("XData", ex, "YData", ey, "LineStyle", "none", "Marker", "o", ...
                         "MarkerSize", 6, "MarkerFaceColor", [1 1 1], "Color", [0 0 0], ...
                         "Parent", axes_handle);

    % Enemy variables and graphics (one entry per fish)
    enemy_x       = zeros(1, enemy_count);
    enemy_y       = zeros(1, enemy_count);
    enemy_size    = zeros(1, enemy_count);
    enemy_dir     = zeros(1, enemy_count);
    enemy_speed   = zeros(1, enemy_count);
    enemy_species = zeros(1, enemy_count);
    enemy_body    = zeros(1, enemy_count);
    enemy_fins    = zeros(1, enemy_count);
    enemy_stripe  = zeros(1, enemy_count);
    enemy_eye     = zeros(1, enemy_count);
    enemy_teeth   = zeros(1, enemy_count);
    enemy_brow    = zeros(1, enemy_count);
    for i = 1:enemy_count
        [enemy_x(i), enemy_y(i), enemy_size(i), enemy_dir(i), enemy_speed(i), enemy_species(i)] = ...
            spawn_enemy(player_size, speed_factor, small_probability, allowed_species, ...
                        world_width, world_height, player_x, player_y, true);
        [bx, by, fx, fy, sx, sy, ex, ey] = fish_shape(enemy_x(i), enemy_y(i), enemy_size(i), ...
                                                      enemy_dir(i), 0, enemy_species(i));
        enemy_fins(i)   = patch("XData", fx, "YData", fy, "FaceColor", [0.5 0.5 0.5], ...
                                "EdgeColor", [0.15 0.15 0.15], "Parent", axes_handle);
        enemy_body(i)   = patch("XData", bx, "YData", by, "FaceColor", [0.5 0.5 0.5], ...
                                "EdgeColor", [0.15 0.15 0.15], "Parent", axes_handle);
        enemy_stripe(i) = patch("XData", sx, "YData", sy, "FaceColor", [0.4 0.4 0.4], ...
                                "EdgeColor", "none", "Parent", axes_handle);
        enemy_eye(i)    = line("XData", ex, "YData", ey, "LineStyle", "none", "Marker", "o", ...
                               "MarkerSize", 4, "MarkerFaceColor", [1 1 1], "Color", [0 0 0], ...
                               "Parent", axes_handle);
        [tx, ty, brx, bry] = fish_menace(enemy_x(i), enemy_y(i), enemy_size(i), enemy_dir(i), ...
                                         enemy_species(i));
        enemy_teeth(i)  = line("XData", tx, "YData", ty, "Color", [1 1 1], "LineWidth", 1.5, ...
                               "Visible", "off", "Parent", axes_handle);
        enemy_brow(i)   = line("XData", brx, "YData", bry, "Color", [0.1 0 0], "LineWidth", 2.5, ...
                               "Visible", "off", "Parent", axes_handle);
    endfor

    % Boss graphics (hidden until the boss arrives)
    [bx, by, fx, fy, sx, sy, ex, ey] = fish_shape(0, 0, boss_size, 1, 0, boss_species);
    [tx, ty, brx, bry] = fish_menace(0, 0, boss_size, 1, boss_species);
    boss_aura   = patch("XData", 1.3 * bx, "YData", 1.3 * by, "FaceColor", [1 0 0], ...
                        "FaceAlpha", 0.2, "EdgeColor", "none", "Visible", "off", "Parent", axes_handle);
    boss_aim    = line("XData", [0 0], "YData", [0 0], "Color", [1 0.2 0.2], "LineStyle", "--", ...
                       "LineWidth", 2, "Visible", "off", "Parent", axes_handle);
    boss_fins   = patch("XData", fx, "YData", fy, "FaceColor", [0.4 0.07 0.14], ...
                        "EdgeColor", [0.1 0 0], "LineWidth", 2, "Visible", "off", "Parent", axes_handle);
    boss_body   = patch("XData", bx, "YData", by, "FaceColor", [0.55 0.10 0.20], ...
                        "EdgeColor", [0.1 0 0], "LineWidth", 2.5, "Visible", "off", "Parent", axes_handle);
    boss_stripe = patch("XData", sx, "YData", sy, "FaceColor", [0.4 0.07 0.14], ...
                        "EdgeColor", "none", "Visible", "off", "Parent", axes_handle);
    boss_eye    = line("XData", ex, "YData", ey, "LineStyle", "none", "Marker", "o", ...
                       "MarkerSize", 13, "MarkerFaceColor", [1 0 0], "Color", [0 0 0], ...
                       "Visible", "off", "Parent", axes_handle);
    boss_glow   = line("XData", 0, "YData", 0, "LineStyle", "none", "Marker", "o", ...
                       "MarkerSize", 11, "MarkerFaceColor", [1 1 0.5], "Color", [1 0.8 0.2], ...
                       "Visible", "off", "Parent", axes_handle);
    boss_teeth  = line("XData", tx, "YData", ty, "Color", [1 1 1], "LineWidth", 3.5, ...
                       "Visible", "off", "Parent", axes_handle);
    boss_brow   = line("XData", brx, "YData", bry, "Color", [0 0 0], "LineWidth", 5, ...
                       "Visible", "off", "Parent", axes_handle);
    boss_warning = text(0, 0, "!", "HorizontalAlignment", "center", "FontUnits", "normalized", ...
                        "FontSize", 0.12, "FontWeight", "bold", "Color", [1 0.1 0.1], ...
                        "Visible", "off", "Parent", axes_handle);

    % Effects: sparkles, floating points and banner
    burst_handle = line("XData", zeros(1, 8), "YData", zeros(1, 8), "LineStyle", "none", ...
                        "Marker", ".", "MarkerSize", 14, "Color", [1 0.95 0.4], ...
                        "Visible", "off", "Parent", axes_handle);
    popup_text = text(0, 0, "", "HorizontalAlignment", "center", "FontUnits", "normalized", ...
                      "FontSize", 0.045, "FontWeight", "bold", "Color", [1 1 0.4], ...
                      "Parent", axes_handle);
    banner_text = text(50, 38, sprintf("LEVEL %d - %s", level, level_names{level}), ...
                       "HorizontalAlignment", "center", "FontUnits", "normalized", ...
                       "FontSize", 0.06, "FontWeight", "bold", "Color", [1 0.9 0.3], ...
                       "Parent", axes_handle);

    % HUD top left: level, score, then the lives just below
    %      HUD top right: best score and the settings icon (gear)
    patch("XData", [0 38 38 0], "YData", [46.5 46.5 60 60], "FaceColor", [0 0.05 0.15], ...
          "FaceAlpha", 0.55, "EdgeColor", "none", "Parent", axes_handle);
    patch("XData", [62 100 100 62], "YData", [54 54 60 60], "FaceColor", [0 0.05 0.15], ...
          "FaceAlpha", 0.55, "EdgeColor", "none", "Parent", axes_handle);
    text(2, 57.6, sprintf("LEVEL %d/%d - %s", level, level_count, level_names{level}), ...
         "Parent", axes_handle, "FontUnits", "normalized", "FontSize", 0.032, "FontWeight", "bold", ...
         "Color", [1 0.9 0.3], "VerticalAlignment", "middle");
    score_hud = text(2, 53.2, "", "Parent", axes_handle, "FontUnits", "normalized", ...
                     "FontSize", 0.05, "FontWeight", "bold", "Color", [1 1 1], ...
                     "VerticalAlignment", "middle");
    life_body = zeros(1, initial_lives);
    life_fins = zeros(1, initial_lives);
    for k = 1:initial_lives
        [bx, by, fx, fy] = fish_shape(4 + 7 * (k - 1), 49.2, 1.3, 1, 0);
        life_fins(k) = patch("XData", fx, "YData", fy, "FaceColor", [0.85 0.35 0.05], ...
                             "EdgeColor", "none", "Parent", axes_handle);
        life_body(k) = patch("XData", bx, "YData", by, "FaceColor", [1 0.65 0.1], ...
                             "EdgeColor", [0.4 0.2 0], "Parent", axes_handle);
    endfor
    best_hud = text(64, 57, "", "Parent", axes_handle, "FontUnits", "normalized", ...
                    "FontSize", 0.03, "FontWeight", "bold", "Color", [1 0.9 0.5], ...
                    "VerticalAlignment", "middle");
    % Settings icon (gear on a small button): click it or press P
    gear_button = patch("XData", [91 98 98 91], "YData", [54.3 54.3 59.7 59.7], "FaceColor", [0.10 0.22 0.38], ...
          "FaceAlpha", 0.9, "EdgeColor", [1 1 1], "LineWidth", 1.5, ...
          "ButtonDownFcn", @(src, evt) setappdata(figure_handle, "last_key", "click_settings"), ...
          "Parent", axes_handle);
    register_zone(figure_handle, 89, 100, 52, 60, "click_settings", gear_button);
    gear_icon = draw_gear(axes_handle, 94.5, 57, 2.1, [0.9 0.92 0.95], [0.10 0.22 0.38]);
    set(gear_icon, "HitTest", "off");

    % Red flash over the whole screen when the player is hit (hidden at the start)
    hit_flash = patch("XData", [0 100 100 0], "YData", [0 0 60 60], "FaceColor", [1 0 0], ...
                      "FaceAlpha", 0.30, "EdgeColor", "none", "Visible", "off", ...
                      "Parent", axes_handle);

    setappdata(figure_handle, "last_key", "");
    setappdata(figure_handle, "music_mode", "normal");     % normal music at the start of a level

    % --- Main loop of the level ---
    while strcmp(outcome, "playing")
        % Stop at once if the window was closed
        if ~ishandle(figure_handle)
            outcome = "quit";
            final_score = score;
            return;
        endif
        frame_count = frame_count + 1;
        player_hit = false;                        % set to true by any dangerous contact

        % 1. Read the keyboard (the fish keeps swimming in the chosen direction)
        key = getappdata(figure_handle, "last_key");
        setappdata(figure_handle, "last_key", "");
        open_settings = false;
        switch key
            case {"leftarrow", "q", "a"}
                velocity = [-1 0];
            case {"rightarrow", "d"}
                velocity = [1 0];
            case {"uparrow", "z", "w"}
                velocity = [0 1];
            case {"downarrow", "s"}
                velocity = [0 -1];
            case "space"
                velocity = [0 0];
            case {"p", "click_settings"}
                open_settings = true;
            case "m"
                if isequal(getappdata(figure_handle, "sound_on"), 1)
                    setappdata(figure_handle, "sound_on", 0);
                else
                    setappdata(figure_handle, "sound_on", 1);
                endif
            case "escape"
                outcome = "quit";
        endswitch
        if open_settings
            % The game is paused while the settings panel is open
            show_settings(figure_handle, axes_handle);
            if ~ishandle(figure_handle)
                outcome = "quit";
                final_score = score;
                return;
            endif
            setappdata(figure_handle, "last_key", "");
        endif

        % 2. Move the player (bigger fish are a little slower), stay inside the sea
        player_speed = base_speed / (1 + 0.04 * player_size);
        player_x = player_x + velocity(1) * player_speed;
        player_y = player_y + velocity(2) * player_speed;
        player_x = min(max(player_x, 0), world_width);
        player_y = min(max(player_y, 6), world_height - 8);
        if velocity(1) ~= 0
            player_dir_x = velocity(1);
        endif
        if invulnerable_frames > 0
            invulnerable_frames = invulnerable_frames - 1;
        endif

        % 3. Move enemies, test collisions
        if boss_active
            current_small_probability = max(small_probability, 0.75);   % Help the player grow when the boss is active
        else
            current_small_probability = small_probability;
        endif
        for i = 1:enemy_count
            enemy_is_big = enemy_size(i) > player_size * size_tolerance;
            enemy_distance = hypot(player_x - enemy_x(i), player_y - enemy_y(i));
            if enemy_is_big && enemy_distance < hunt_radius && invulnerable_frames == 0
                % Dangerous fish nearby: it turns towards the player and hunts him
                if abs(player_x - enemy_x(i)) > 1
                    enemy_dir(i) = sign(player_x - enemy_x(i));
                endif
                chase_speed = min(enemy_speed(i) * hunt_boost, 1.7);
                enemy_x(i) = enemy_x(i) + enemy_dir(i) * chase_speed;
                y_step = min(max(player_y - enemy_y(i), -0.6 * chase_speed), 0.6 * chase_speed);
                enemy_y(i) = min(max(enemy_y(i) + y_step, 7), world_height - 10);
            else
                enemy_x(i) = enemy_x(i) + enemy_dir(i) * enemy_speed(i);
                enemy_y(i) = enemy_y(i) + 0.12 * sin(0.1 * frame_count + i);
            endif
            % Respawn a fish that left the screen
            left_screen = (enemy_dir(i) == 1  && enemy_x(i) > world_width + 5 * enemy_size(i)) || ...
                          (enemy_dir(i) == -1 && enemy_x(i) < -5 * enemy_size(i));
            if left_screen
                [enemy_x(i), enemy_y(i), enemy_size(i), enemy_dir(i), enemy_speed(i), enemy_species(i)] = ...
                    spawn_enemy(player_size, speed_factor, current_small_probability, allowed_species, ...
                                world_width, world_height, player_x, player_y, false);
            endif
            % Check for a collision
            if fish_overlap(player_x, player_y, player_size, enemy_x(i), enemy_y(i), ...
                            enemy_size(i), enemy_species(i))
                if player_size > enemy_size(i) * size_tolerance
                    % The player eats the fish and grow
                    points = round(10 * enemy_size(i));
                    play_sfx(figure_handle, "eat");
                    score = score + points;
                    player_size = player_size + growth_ratio * enemy_size(i);
                    burst_x = enemy_x(i);
                    burst_y = enemy_y(i);
                    burst_age = 1;
                    set(popup_text, "String", sprintf("+%d", points), "Position", [burst_x, burst_y + 2]);
                    [enemy_x(i), enemy_y(i), enemy_size(i), enemy_dir(i), enemy_speed(i), enemy_species(i)] = ...
                        spawn_enemy(player_size, speed_factor, current_small_probability, allowed_species, ...
                                    world_width, world_height, player_x, player_y, false);
                elseif enemy_size(i) > player_size * size_tolerance
                    player_hit = true;
                else
                    % Same size: the two fish push each other away
                    player_x = player_x - 2 * sign(enemy_x(i) - player_x);
                endif
            endif
        endfor

        % 4. Boss: arrival, behaviour and collision
        if ~boss_active && ~boss_defeated && player_size >= boss_trigger
            % The boss enters from the side opposite to the player
            boss_active = true;
            if player_x < world_width / 2
                boss_x = world_width + 3 * boss_size;
                boss_dir = -1;
            else
                boss_x = -3 * boss_size;
                boss_dir = 1;
            endif
            boss_y = world_height / 2 - 3;
            boss_mode = "chase";
            boss_timer = dash_wait;
            banner_frames = 140;
            set(banner_text, "String", sprintf("!! %s !!", upper(boss_names{level})), "Color", [1 0.15 0.15]);
            shake_frames = 45;
            hit_flash_frames = 10;
            set(boss_dark, "Visible", "on");
            play_sfx(figure_handle, "boss");
            setappdata(figure_handle, "music_mode", "boss");   % boss music
            set([boss_fins, boss_body, boss_stripe, boss_eye], "Visible", "on");
            if boss_species == 6
                set(boss_glow, "Visible", "on");
            endif
        endif
        boss_edible = boss_active && (player_size > boss_win_size);
        if boss_edible && ~boss_was_edible
            boss_was_edible = true;
            banner_frames = 100;
            set(banner_text, "String", "NOW EAT THE BOSS!", "Color", [0.4 1 0.5]);
            set([boss_aim, boss_warning], "Visible", "off");
            set(boss_dark, "Visible", "off");
        endif
        if boss_active && ~boss_defeated && ~boss_edible && boss_was_edible
            % The player is smaller, so the boss is dangerous again
            boss_was_edible = false;
            banner_frames = 100;
            set(banner_text, "String", "THE BOSS IS BACK!", "Color", [1 0.2 0.2]);
            set(boss_dark, "Visible", "on");
        endif
        if boss_active
            to_player = [player_x - boss_x, player_y - boss_y];
            distance_to_player = max(norm(to_player), 0.001);
            boss_step = [0 0];
            % The boss gets angry (20 percent faster) when the player is close to beating it
            boss_rage = player_size >= 0.85 * boss_win_size;
            boss_speed_now = boss_speed * (1 + 0.2 * boss_rage);
            if boss_edible
                % The boss is smaller than the player: it runs away
                boss_mode = "flee";
                away_vector = -to_player / distance_to_player;
                center_pull = [world_width / 2 - boss_x, world_height / 2 - boss_y];
                center_pull = center_pull / max(norm(center_pull), 1);
                flee_vector = away_vector + 0.35 * center_pull;
                boss_step = 0.75 * boss_speed * flee_vector / max(norm(flee_vector), 0.001);
            else
                switch boss_mode
                    case "chase"
                        boss_step = boss_speed_now * to_player / distance_to_player;
                        boss_timer = boss_timer - 1;
                        if boss_timer <= 0
                            % Lock the direction of the charge and show the warning
                            boss_mode = "telegraph";
                            boss_timer = telegraph_frames;
                            % The boss aims where the player is going to be, not where he is
                            aim_point = [player_x, player_y] + velocity * player_speed * 0.5 * telegraph_frames;
                            aim_point(1) = min(max(aim_point(1), 0), world_width);
                            aim_point(2) = min(max(aim_point(2), 6), world_height - 8);
                            aim_vector = aim_point - [boss_x, boss_y];
                            dash_vector = aim_vector / max(norm(aim_vector), 0.001);
                            boss_combo = boss_combo_max;
                        endif
                    case "telegraph"
                        boss_timer = boss_timer - 1;
                        if boss_timer <= 0
                            boss_mode = "dash";
                            boss_timer = 16;
                            shake_frames = 6;
                        endif
                    case "dash"
                        boss_step = 2.8 * boss_speed_now * dash_vector;
                        boss_timer = boss_timer - 1;
                        if boss_timer <= 0
                            if boss_combo > 0
                                % Prepare the next attack
                                boss_combo = boss_combo - 1;
                                boss_mode = "telegraph";
                                boss_timer = max(8, round(telegraph_frames / 2));
                                dash_vector = to_player / distance_to_player;
                            else
                                boss_mode = "chase";
                                boss_timer = dash_wait + randi(30);
                            endif
                        endif
                    otherwise
                        boss_mode = "chase";
                endswitch
            endif
            boss_x = min(max(boss_x + boss_step(1), 0), world_width);
            boss_y = min(max(boss_y + boss_step(2), 7), world_height - 10);
            if abs(boss_step(1)) > 0.01
                boss_dir = sign(boss_step(1));
            endif
            % Collision with the boss
            if fish_overlap(player_x, player_y, player_size, boss_x, boss_y, boss_size, boss_species)
                if boss_edible
                    % The boss is eaten: the level is won
                    boss_defeated = true;
                    score = score + 500 * level;
                    burst_x = boss_x;
                    burst_y = boss_y;
                    burst_age = 1;
                    set(popup_text, "String", sprintf("+%d", 500 * level), "Position", [boss_x, boss_y + 3]);
                    shake_frames = 15;
                else
                    player_hit = true;
                endif
            endif
        endif

        % The player loses a life if touched by a dangerous fish
        if player_hit && invulnerable_frames == 0
            lives = lives - 1;
            play_sfx(figure_handle, "hit");
            invulnerable_frames = 60;
            player_size = max(start_size, player_size * 0.95);   % being eaten makes you smaller
            hit_flash_frames = 6;
            shake_frames = max(shake_frames, 8);
            player_x = world_width / 2;
            player_y = world_height / 2;
            velocity = [0 0];
        endif

        % 5. Move bubbles, plants and background fish
        bubble_y = bubble_y + bubble_rise;
        bubble_x = bubble_x + 0.05 * sin(0.2 * frame_count + (1:15));
        bubble_y(bubble_y > world_height) = 0;
        update_seaweed(seaweed_handles, seaweed_base_x, seaweed_top_y, frame_count);
        for i = 1:sil_count
            sil_x(i) = sil_x(i) + sil_dir(i) * sil_speed(i);
            if sil_dir(i) == 1 && sil_x(i) > world_width + 15
                sil_x(i) = -15;
            elseif sil_dir(i) == -1 && sil_x(i) < -15
                sil_x(i) = world_width + 15;
            endif
            [bx, by, fx, fy] = fish_shape(sil_x(i), sil_y(i), sil_size(i), sil_dir(i), ...
                                          0.2 * sin(0.2 * frame_count + i), sil_species(i));
            set(sil_body(i), "XData", bx, "YData", by);
            set(sil_fins(i), "XData", fx, "YData", fy);
        endfor

        % 6. Update the graphics of the player (tail swims faster when moving)
        if any(velocity ~= 0)
            player_wiggle = 0.25 * sin(0.7 * frame_count);
        else
            player_wiggle = 0.08 * sin(0.2 * frame_count);
        endif
        [bx, by, fx, fy, sx, sy, ex, ey] = fish_shape(player_x, player_y, player_size, ...
                                                      player_dir_x, player_wiggle);
        set(player_body, "XData", bx, "YData", by);
        set(player_fins, "XData", fx, "YData", fy);
        set(player_stripe, "XData", sx, "YData", sy);
        set(player_eye, "XData", ex, "YData", ey, "MarkerSize", max(5, min(10, 2 + player_size)));
        % Blink while the player is protected
        if invulnerable_frames > 0 && mod(frame_count, 6) < 3
            visible_state = "off";
        else
            visible_state = "on";
        endif
        set([player_body, player_fins, player_stripe, player_eye], "Visible", visible_state);

        % Update the graphics of the enemies
        for i = 1:enemy_count
            [bx, by, fx, fy, sx, sy, ex, ey] = fish_shape(enemy_x(i), enemy_y(i), enemy_size(i), ...
                enemy_dir(i), 0.25 * sin(0.5 * frame_count + i), enemy_species(i));
            % Colour of the fish can be green, yellow or red
            is_edible    = player_size > enemy_size(i) * size_tolerance;
            is_dangerous = enemy_size(i) > player_size * size_tolerance;
            if is_edible
                fish_color = [0.30 0.80 0.40];             % green: edible
            elseif is_dangerous
                fish_color = [0.75 0.05 0.08];             % dark red: dangerous
            else
                fish_color = [0.95 0.90 0.30];             % yellow: same size
            endif
            if is_dangerous
                body_edge = [1 0.25 0.2];                  % glowing red outline
                body_edge_width = 1.8;
            else
                body_edge = [0.15 0.15 0.15];
                body_edge_width = 0.5;
            endif
            set(enemy_body(i), "XData", bx, "YData", by, "FaceColor", fish_color, ...
                "EdgeColor", body_edge, "LineWidth", body_edge_width);
            set(enemy_fins(i), "XData", fx, "YData", fy, "FaceColor", 0.7 * fish_color);
            set(enemy_stripe(i), "XData", sx, "YData", sy, "FaceColor", 0.75 * fish_color);
            if is_dangerous
                % Scary face: red eye, angry brow and teeth
                [tx, ty, brx, bry] = fish_menace(enemy_x(i), enemy_y(i), enemy_size(i), ...
                                                 enemy_dir(i), enemy_species(i));
                set(enemy_teeth(i), "XData", tx, "YData", ty, "Visible", "on");
                set(enemy_brow(i), "XData", brx, "YData", bry, "Visible", "on");
                set(enemy_eye(i), "XData", ex, "YData", ey, "MarkerFaceColor", [1 0.1 0.1], ...
                    "MarkerSize", 6);
            else
                set([enemy_teeth(i), enemy_brow(i)], "Visible", "off");
                set(enemy_eye(i), "XData", ex, "YData", ey, "MarkerFaceColor", [1 1 1], ...
                    "MarkerSize", 4);
            endif
        endfor

        % Update the graphics of the boss
        if boss_active && ~boss_defeated
            if strcmp(boss_mode, "dash")
                boss_wiggle = 0.35 * sin(1.2 * frame_count);
            else
                boss_wiggle = 0.20 * sin(0.4 * frame_count);
            endif
            % The boss trembles with rage just before a charge
            draw_x = boss_x;
            draw_y = boss_y;
            if strcmp(boss_mode, "telegraph")
                boss_jitter = 0.6 * (2 * rand(1, 2) - 1);
                draw_x = draw_x + boss_jitter(1);
                draw_y = draw_y + boss_jitter(2);
            endif
            [bx, by, fx, fy, sx, sy, ex, ey] = fish_shape(draw_x, draw_y, boss_size, boss_dir, ...
                                                          boss_wiggle, boss_species);
            % Colour: red = dangerous, orange flash = warning, green = edible
            boss_edge = [0.1 0 0];
            if boss_edible
                boss_color = [0.35 0.90 0.45];
                boss_edge = [1 0.85 0.2];
            elseif strcmp(boss_mode, "telegraph") && mod(frame_count, 4) < 2
                boss_color = [1 0.55 0.1];
            elseif strcmp(boss_mode, "dash")
                boss_color = [0.95 0.10 0.10];
            else
                boss_color = [0.38 0.03 0.08];
            endif
            set(boss_body, "XData", bx, "YData", by, "FaceColor", boss_color, "EdgeColor", boss_edge);
            set(boss_fins, "XData", fx, "YData", fy, "FaceColor", 0.7 * boss_color);
            set(boss_stripe, "XData", sx, "YData", sy, "FaceColor", 0.75 * boss_color);
            set(boss_eye, "XData", ex, "YData", ey);
            if boss_edible
                % Scared boss: no fangs, no aura, normal eye
                set([boss_teeth, boss_brow, boss_aura], "Visible", "off");
                set(boss_eye, "MarkerFaceColor", [1 1 1], "MarkerSize", 9);
            else
                % Terrifying boss: pulsing red aura, fangs, angry brow, red eye
                aura_alpha = 0.16 + 0.10 * sin(0.3 * frame_count);
                if strcmp(boss_mode, "dash")
                    aura_alpha = 0.45;
                endif
                set(boss_aura, "XData", draw_x + 1.3 * (bx - draw_x), ...
                    "YData", draw_y + 1.3 * (by - draw_y), "FaceAlpha", aura_alpha, "Visible", "on");
                [tx, ty, brx, bry] = fish_menace(draw_x, draw_y, boss_size, boss_dir, boss_species);
                set(boss_teeth, "XData", tx, "YData", ty, "Visible", "on");
                set(boss_brow, "XData", brx, "YData", bry, "Visible", "on");
                set(boss_eye, "MarkerFaceColor", [1 0 0], "MarkerSize", 13);
                set(boss_dark, "FaceAlpha", 0.22 + 0.06 * sin(0.1 * frame_count));
            endif
            if boss_species == 6
                set(boss_glow, "XData", boss_x + boss_dir * boss_size * 1.1 * 0.95, ...
                    "YData", boss_y + boss_size * 1.75);
            endif
            % Warning: red dashed line along the future charge and a "!" above the boss
            if strcmp(boss_mode, "telegraph")
                set(boss_aim, "XData", [boss_x, boss_x + 70 * dash_vector(1)], ...
                    "YData", [boss_y, boss_y + 70 * dash_vector(2)], "LineWidth", 3, "Visible", "on");
                set(boss_warning, "Position", [boss_x, boss_y + boss_size * 1.7], "Visible", "on");
            else
                set([boss_aim, boss_warning], "Visible", "off");
            endif
        elseif boss_defeated
            set([boss_fins, boss_body, boss_stripe, boss_eye, boss_glow, boss_aim, boss_warning, ...
                 boss_teeth, boss_brow, boss_aura, boss_dark], "Visible", "off");
        endif

        % Update the bubbles
        set(bubble_small, "XData", bubble_x(1:10), "YData", bubble_y(1:10));
        set(bubble_big, "XData", bubble_x(11:15), "YData", bubble_y(11:15));

        % Update the sparkles and the floating points
        if burst_age > 0
            burst_radius = 1 + 0.6 * burst_age;
            set(burst_handle, "XData", burst_x + burst_radius * cos(burst_angles), ...
                "YData", burst_y + burst_radius * sin(burst_angles), "Visible", "on");
            popup_position = get(popup_text, "Position");
            set(popup_text, "Position", [popup_position(1), popup_position(2) + 0.35]);
            burst_age = burst_age + 1;
            if burst_age > 14
                burst_age = 0;
                set(burst_handle, "Visible", "off");
                set(popup_text, "String", "");
            endif
        endif

        % Update the banner, the red flash and the screen shake
        if banner_frames > 0
            banner_frames = banner_frames - 1;
            if banner_frames == 0
                set(banner_text, "String", "");
            endif
        endif
        if hit_flash_frames > 0
            set(hit_flash, "Visible", "on");
            hit_flash_frames = hit_flash_frames - 1;
        else
            set(hit_flash, "Visible", "off");
        endif
        if shake_frames > 0
            shake_offset = 1.2 * (2 * rand(1, 2) - 1);
            set(axes_handle, "XLim", [0 world_width] + shake_offset(1), ...
                "YLim", [0 world_height] + shake_offset(2));
            shake_frames = shake_frames - 1;
            if shake_frames == 0
                set(axes_handle, "XLim", [0 world_width], "YLim", [0 world_height]);
            endif
        endif

        % Update the lives display
        for k = 1:initial_lives
            if k <= lives
                set([life_body(k), life_fins(k)], "Visible", "on");
            else
                set([life_body(k), life_fins(k)], "Visible", "off");
            endif
        endfor
        % The displayed score counts up towards the real score
        if displayed_score < score
            displayed_score = min(score, displayed_score + max(1, ceil((score - displayed_score) * 0.2)));
        endif
        set(score_hud, "String", sprintf("SCORE  %d", displayed_score));
        set(best_hud, "String", sprintf("BEST %d", max(best_score, score)));
        update_music(figure_handle);
        drawnow;
        pause(frame_pause);

        % 7. End of the level
        if boss_defeated
            outcome = "win";
            play_sfx(figure_handle, "win");
            score = score + 100 * lives;                   % bonus for remaining lives
        elseif lives <= 0
            outcome = "lose";
            play_sfx(figure_handle, "lose");
        endif
    endwhile
    set(axes_handle, "XLim", [0 world_width], "YLim", [0 world_height]);
    setappdata(figure_handle, "music_mode", "normal");
    final_score = score;
endfunction

%==========================================================================
% THE MAIN PROGRAM
%==========================================================================

% Settings of the program
best_score_file = "abyss_best_score.txt";              % file where the best score is saved
level_count     = 5;                                   % number of levels
level           = 1;                                   % current level
total_score     = 0;                                   % score at the start of the current level
best_score      = load_best_score(best_score_file);    % best score of previous sessions
keep_playing    = true;                                % false when the player quits

% Create the game window
close all;
figure_handle = figure("Name", "Abyss Feast", "NumberTitle", "off", ...
                       "Color", [0.05 0.2 0.35], "Resize", "on", ...
                       "KeyPressFcn", @key_handler, ...
                       "WindowButtonDownFcn", @click_handler);
axes_handle = axes("Parent", figure_handle, "Position", [0 0 1 1], "XLim", [0 100], ...
                   "YLim", [0 60], "XTick", [], "YTick", [], "Color", [0.45 0.75 0.95], ...
                   "Box", "on");
hold(axes_handle, "on");
setappdata(figure_handle, "main_axes", axes_handle);   % used by the mouse clicks

% Start the game and turn on the sound
setappdata(figure_handle, "sound_on", 1);
setappdata(figure_handle, "sound_ok", 1);

% The game has background music from .wav files in the same folder.
script_folder = "";
try
    script_folder = fileparts(mfilename("fullpath"));
catch
end_try_catch
normal_file = fullfile(script_folder, "abyss_music.wav");   % music of the menu and of the game
boss_file   = fullfile(script_folder, "abyss_boss.wav");    % music when a boss is on the screen
music_normal = make_music_player(normal_file);
music_boss   = make_music_player(boss_file);
setappdata(figure_handle, "music_normal", music_normal);
setappdata(figure_handle, "music_boss", music_boss);
setappdata(figure_handle, "music_mode", "normal");
update_music(figure_handle);

draw_sea_background(axes_handle, 1);
menu_handles = draw_title_menu(figure_handle, axes_handle);
in_menu = true;
while in_menu && ishandle(figure_handle)
    key = wait_for_key(figure_handle, {"click_play", "return", "click_settings", ...
                                       "s", "m", "escape"});
    switch key
        case {"click_play", "return"}
            in_menu = false;
        case {"click_settings", "s"}
            show_settings(figure_handle, axes_handle);
        case "m"
            if isequal(getappdata(figure_handle, "sound_on"), 1)
                setappdata(figure_handle, "sound_on", 0);
            else
                setappdata(figure_handle, "sound_on", 1);
            endif
        case "escape"
            keep_playing = false;
            in_menu = false;
    endswitch
endwhile
if ishandle(figure_handle)
    delete(menu_handles(ishandle(menu_handles)));
endif

% Each level is a new game attempt
while keep_playing && ishandle(figure_handle)
    [outcome, round_score] = play_round(figure_handle, axes_handle, level, best_score, total_score);
    if ~ishandle(figure_handle)
        break;
    endif

    % Save a new best score
    if round_score > best_score
        best_score = round_score;
        save_best_score(best_score_file, best_score);
    endif

    % End of the level: win, final win, lose or quit screen
    if strcmp(outcome, "win") && level < level_count
        total_score = round_score;                     % the score is kept for the next level
        end_text = {sprintf("Boss defeated! Level %d cleared!", level), "", ...
                    sprintf("Score: %d    Best score: %d", round_score, best_score), "", ...
                    sprintf("R = go to level %d (new decor, harder boss)", level + 1), "ESC = quit"};
        end_screen = show_screen(axes_handle, "LEVEL CLEARED!", end_text, [0.1 0.45 0.2]);
        level = level + 1;
    elseif strcmp(outcome, "win")
        end_text = {"You defeated all 5 bosses!", "", ...
                    sprintf("Final score: %d    Best score: %d", round_score, best_score), "", ...
                    "R = start a new game", "ESC = quit"};
        end_screen = show_screen(axes_handle, "KING OF THE ABYSS!", end_text, [0.45 0.35 0.05]);
        level = 1;                                     % new game
        total_score = 0;
    elseif strcmp(outcome, "lose")
        end_text = {sprintf("You were eaten on level %d!", level), "", ...
                    sprintf("Score: %d    Best score: %d", round_score, best_score), "", ...
                    "R = retry this level (new random fish)", "ESC = quit"};
        end_screen = show_screen(axes_handle, "GAME OVER", end_text, [0.55 0.15 0.15]);
    else
        break;                                         % the player pressed ESC during the level
    endif

    key = wait_for_key(figure_handle, {"r", "escape"});
    if strcmp(key, "escape")
        keep_playing = false;
    endif
endwhile

%End of the game: goodbye message, then close the window
if ishandle(figure_handle)
    draw_sea_background(axes_handle, 1);
    bye_screen = show_screen(axes_handle, "THANKS FOR PLAYING", ...
                             {sprintf("Best score: %d", best_score)}, [0.05 0.25 0.45]);
    pause(1.5);
    close(figure_handle);
endif
try
    stop(music_normal);                            % stop the music at the end
    stop(music_boss);
catch
end_try_catch
