%==========================================================================
% ABYSS FEAST
%==========================================================================
% CONTEXT
%   Small "eat or be eaten" game, inspired by .io fish games. Written for TechnEx TP1 Coding.
%
% GOAL OF THE GAME
%   Cross 5 underwater levels. In each level, eat smaller fish to grow,
%   wait for the boss to arrive, grow even bigger than the boss and eat it.
%
% GAME COMPONENTS (objects shown on the screen)
%   - Player fish (orange): body, stripe, fins, eye, swimming tail
%   - Special fish : lime green
%   - Enemy fish of 6 species: reef fish, puffer, eel, needlefish, shark,
%     angler. Colour tells the danger:
%         green  = smaller than you (you can eat it)
%         red    = bigger than you (it can eat you)
%         yellow = same size (you only bump into each other)
%   - One BOSS per level (Giant Puffer, Barracuda, Moray Boss, Anglerfish
%     King, Megalodon). The boss chases you and charges (red dashed line
%     = warning). When you are bigger than the boss, it turns green and
%     flees: catch it to win the level.
%   - Golden pearls : collectible bonus objects that gives extra points
%   - Hearts : restores one lost life
%   - Shield : protects player one time
%   - Progression bar : % of growth before boss appearance
%   - 5 decors with background effects: Sunny Reef, Kelp Forest, Sunken Ship, Magma Trench, The Abyss
%   - Effects: bubbles, plankton, tiny fish schools, moving seaweed,
%     moving crabs, sparkles and "+points" text, red flash when hit, screen
%     shake for boss events, blinking while protected, banners,
%     golden flash when bonus mission completed
%   - HUD: lives (small fish icons), level, score, best score
%   - Title menu (big title, PLAY and SETTINGS buttons) and a SETTINGS panel
%     (goal, how to play, sound on/off), also reachable in game (gear icon)
%   - Message panels: level cleared, game over, final win
%
% VARIABLES (properties of the objects)
%   - player_x, player_y, player_size, player_dir_x, velocity, lives, score
%   - enemy_x, enemy_y, enemy_size, enemy_dir, enemy_speed, enemy_species
%   - boss_x, boss_y, boss_dir, boss_mode, boss_timer, boss_size
%   - bubble_x, bubble_y, sil_x, sil_y (background fish), level, best_score
%
% MAIN LOOP (during one trial = one level)
%   1. Read the last key pressed (changes the swimming direction)
%   2. Move the player (speed decreases slightly when the fish grows)
%   3. Move every enemy fish; respawn them when they leave the screen
%   4. Boss: arrives when the player is big enough, then chases, warns,
%      dashes (or flees when the player is bigger than the boss)
%   5. Collisions: eat (grow + points), get eaten (lose a life, short
%      protection) or bump (same size)
%   6. Update the decor, effects, graphics and the HUD
%   7. End of the level: boss eaten = win, no life left = lose
%
% ACROSS TRIALS
%   - Win  : next level (new decor, new fish species, faster, harder boss)
%   - Lose : same level again, with new random fish (never identical)
%   - Size, lives and fish are reset at each level; the score is kept
%   - After level 5 the game restarts from level 1 (new game)
%   - The best score is saved in the text file abyss_best_score.txt
%
% RULES
%   - Eat a fish smaller than you: you grow and earn points
%   - Touch a bigger fish or a dangerous boss: you lose 1 life (4 lives,
%     3 in level 5) and your fish shrinks by 5 percent
%   - Red fish show teeth, an angry brow and red eyes, and
%     they HUNT you when you are close. Bosses are darker, have a red aura,
%     fangs, red eyes, shake before a charge, and chain several charges.
%   - BOSS arrives at a given size when progression bar is full;
%     eat it once you are bigger than it
%   - SPECIAL FISH appear from time to time (harmless, glowing): 
%     eat it to wipe out the red fish around you
%   - BONUS MISSION : optional objective in each level
%     that gives extra points when completed
%   - BONUSES :
%      Golden pearl gives extra point
%      Heart gives one life back
%      Shield protects from one red fish bite
%
% WAYS TO MOVE
%   - Arrow keys or Z Q S D (AZERTY) or W A S D (QWERTY): swimming direction
%   - SPACE : stop swimming      - ESC : quit      - R : replay/next level
%   - P or gear icon : settings      - M : sound on/off (mouse clicks work too)
%
% SOURCES (AI / sound / image / word list)
%   - No external image, sound or word list: all graphics are drawn by
%     the code, and the sounds are small tones computed by the code.
%     Code structure written with Claude.ai (Anthropic)
%   - Music: files abyss_music.wav (game) and abyss_boss.wav (boss)
%     MUST BE PLACED IN THE SAME FOLDER as this file (no file = no music)
%
% VERSIONS
%   - Octave version : 11.3.0
%   - Code version   : 9
%
% AUTHORS AND CONTRIBUTION
%   - SIGHIERI Manon : base game, difficulty level adjustment, game and boss music, comments
%   - ECHEVERRIA COBO Paula : graphics and background effects, difficulty level adjustment, main and in-game menu, progression bar, special fish addition, combo system, bonuses and bonus mission
%   - PETERFALVI Jeanne : levels, species and bosses addition, difficulty level adjustment, minor bug fix, background music, header
%
% DATE (format: dd/mm/yyyy)
%   - 08/10/2026
%==========================================================================
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
% FUNCTION: glossy highlight on the back of a fish (a smaller ellipse
%   placed in the upper part of the body, drawn semi-transparent)
%--------------------------------------------------------------------------
function [shine_x, shine_y] = fish_shine(body_x, body_y, x, y)
    shine_x = x + 0.55 * (body_x - x);
    shine_y = y + 0.42 * (max(body_y) - y) + 0.34 * (body_y - y);
endfunction

%--------------------------------------------------------------------------
% FUNCTION: draw a starfish (decor, does not move)
%--------------------------------------------------------------------------
function draw_starfish(axes_handle, center_x, center_y, radius, star_color)
    star_angle  = linspace(0, 2*pi, 11);
    star_angle  = star_angle(1:10) + pi / 2;
    star_radius = radius * [1 0.45 1 0.45 1 0.45 1 0.45 1 0.45];
    patch("XData", center_x + star_radius .* cos(star_angle), ...
          "YData", center_y + star_radius .* sin(star_angle), ...
          "FaceColor", star_color, "EdgeColor", 0.55 * star_color, "LineWidth", 1, ...
          "Parent", axes_handle);
    line("XData", center_x, "YData", center_y, "LineStyle", "none", "Marker", "o", ...
         "MarkerSize", 3, "MarkerFaceColor", min(1.2 * star_color, 1), ...
         "Color", 0.55 * star_color, "Parent", axes_handle);
endfunction

%--------------------------------------------------------------------------
% FUNCTION: draw a glowing jellyfish (decor of the deepest level)
%--------------------------------------------------------------------------
function draw_jellyfish(axes_handle, center_x, center_y, radius, jelly_color)
    dome_angle = linspace(0, pi, 24);
    for t = -3:3
        tentacle_x = center_x + 0.30 * radius * t + 0.25 * radius * sin(t + [0 1.5 3 4.5 6]);
        tentacle_y = center_y - radius * [0 0.5 1.0 1.5 2.0];
        line("XData", tentacle_x, "YData", tentacle_y, "Color", jelly_color, ...
             "LineWidth", 1.5, "Parent", axes_handle);
    endfor
    patch("XData", center_x + radius * cos(dome_angle), ...
          "YData", center_y + 0.8 * radius * sin(dome_angle), ...
          "FaceColor", jelly_color, "FaceAlpha", 0.55, ...
          "EdgeColor", min(1.3 * jelly_color, 1), "LineWidth", 1.5, "Parent", axes_handle);
    patch("XData", center_x + 0.6 * radius * cos(dome_angle), ...
          "YData", center_y + 0.1 * radius + 0.5 * radius * sin(dome_angle), ...
          "FaceColor", [1 1 1], "FaceAlpha", 0.25, "EdgeColor", "none", "Parent", axes_handle);
endfunction

%--------------------------------------------------------------------------
% FUNCTION: test if the player overlaps another fish (ellipse approximation)
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
% Function: shape of a small crab walking on the sea floor (decor)
%   Inputs : position (x, y), size of the crab and a phase (the phase moves
%            the claws and the legs, so the crab looks alive)
%   Outputs: the shell (body), the two claws and the legs as coordinates
%            (a NaN cuts a line in several pieces, so one line draws many legs)
%--------------------------------------------------------------------------
function [body_x, body_y, claw_x, claw_y, leg_x, leg_y] = crab_shape(x, y, crab_size, phase)
    dome_angle = linspace(0, pi, 16);
    body_x = x + 1.2 * crab_size * cos(dome_angle);
    body_y = y + 0.8 * crab_size * sin(dome_angle);
    snap = 0.25 * sin(phase);                      % the claws open and close
    % Two raised arms (NaN separates the two lines)
    claw_x = x + crab_size * [-1.1 -1.5 -1.7 NaN 1.1 1.5 1.7];
    claw_y = y + crab_size * [0.5 1.0 + snap 1.5 + snap NaN 0.5 1.0 + snap 1.5 + snap];
    % Four little legs
    leg_wiggle = 0.15 * sin(2 * phase);
    leg_x = x + crab_size * [-1.0 -1.5 NaN -0.7 -1.1 NaN 0.7 1.1 NaN 1.0 1.5];
    leg_y = y + crab_size * [0.1 -0.4 + leg_wiggle NaN 0 -0.5 - leg_wiggle NaN 0 -0.5 + leg_wiggle NaN 0.1 -0.4 - leg_wiggle];
endfunction

%--------------------------------------------------------------------------
% Function: animate the seaweed
%--------------------------------------------------------------------------
function update_seaweed(seaweed_handles, seaweed_base_x, seaweed_top_y, frame_count)
    % The first half of the handles are the dark outlines, the second half
    % the coloured plants: both halves use the same shape and the same phase
    plant_count = numel(seaweed_handles) / 2;
    for k = 1:numel(seaweed_handles)
        phase_index = mod(k - 1, plant_count) + 1;
        seaweed_y = linspace(3.5, seaweed_top_y(k), 20);
        height_ratio = (seaweed_y - 3.5) / (seaweed_top_y(k) - 3.5);
        seaweed_x = seaweed_base_x(k) + 2.0 * height_ratio ...
                    .* sin(0.12 * frame_count + 3 * height_ratio + phase_index);
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

    % Water: vertical gradient made of horizontal bands
    band_count = 48;
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
        ray_start_x = [12 38 64 86 25 52 76];
        ray_weight  = [1 1 1 1 0.6 0.6 0.6];
        for k = 1:numel(ray_start_x)
            patch("XData", [ray_start_x(k) ray_start_x(k)+8 ray_start_x(k)+23 ray_start_x(k)+12], ...
                  "YData", [60 60 5 5], "FaceColor", [1 1 1], "FaceAlpha", ray_alpha * ray_weight(k), ...
                  "EdgeColor", "none", "Parent", axes_handle);
        endfor
        % Soft glow just under the surface
        patch("XData", [0 100 100 0], "YData", [46 46 60 60], "FaceColor", [1 1 1], ...
              "FaceAlpha", 0.06, "EdgeColor", "none", "Parent", axes_handle);
        patch("XData", [0 100 100 0], "YData", [53 53 60 60], "FaceColor", [1 1 1], ...
              "FaceAlpha", 0.08, "EdgeColor", "none", "Parent", axes_handle);
    endif

    % Far away sea floor hills (darker than the water: they give depth)
    far_x  = linspace(0, 100, 60);
    far_y1 = 11 + 4 * sin(far_x / 9 + 1) + 2 * sin(far_x / 4);
    far_y2 = 7.5 + 3 * sin(far_x / 6 + 4) + 1.5 * sin(far_x / 3 + 2);
    patch("XData", [far_x 100 0], "YData", [far_y1 0 0], "FaceColor", 0.55 * deep_color + 0.03, ...
          "FaceAlpha", 0.60, "EdgeColor", "none", "Parent", axes_handle);
    patch("XData", [far_x 100 0], "YData", [far_y2 0 0], "FaceColor", 0.35 * deep_color + 0.02, ...
          "FaceAlpha", 0.70, "EdgeColor", "none", "Parent", axes_handle);

    % Special decor of each level
    switch level
        case 2      % Kelp Forest: dark kelp far away (static), for depth
            far_kelp_x = [9 19 29 41 52 63 75 88 97];
            far_kelp_h = [26 33 22 35 28 31 24 30 27];
            for k = 1:numel(far_kelp_x)
                far_kelp_y = linspace(4, far_kelp_h(k), 16);
                far_kelp_line_x = far_kelp_x(k) + 1.5 * sin(far_kelp_y / 5 + k);
                line("XData", far_kelp_line_x, "YData", far_kelp_y, "Color", [0.06 0.26 0.18], ...
                     "LineWidth", 8, "Parent", axes_handle);
            endfor
        case 3      % Shipwreck: hull, cabin, mast, torn sail and portholes
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
            % Wooden planks, ropes, flag and moss on the wreck
            line("XData", [46.5 95.5], "YData", [10.5 10.5], "Color", [0.12 0.08 0.06], ...
                 "LineWidth", 1, "Parent", axes_handle);
            line("XData", [49.5 92.5], "YData", [7 7], "Color", [0.12 0.08 0.06], ...
                 "LineWidth", 1, "Parent", axes_handle);
            line("XData", [70 60], "YData", [38 20], "Color", [0.35 0.25 0.18], ...
                 "LineWidth", 1, "Parent", axes_handle);
            line("XData", [70 80], "YData", [38 20], "Color", [0.35 0.25 0.18], ...
                 "LineWidth", 1, "Parent", axes_handle);
            patch("XData", [70 70 77 74], "YData", [38 41.5 40 38.8], "FaceColor", [0.10 0.10 0.12], ...
                  "EdgeColor", [0.3 0.3 0.3], "Parent", axes_handle);
            line("XData", [44.5 49 55 62 70 78 86 93 97], "YData", [12.6 12.9 12.5 13.0 12.6 12.9 12.5 12.8 12.6], ...
                 "LineStyle", "none", "Marker", "o", "MarkerSize", 4, "MarkerFaceColor", [0.15 0.45 0.30], ...
                 "Color", [0.10 0.30 0.20], "Parent", axes_handle);
        case 4      % Volcano with lava, and a red glow at the bottom
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
            % Glow around the crater and floating embers
            glow_angle = linspace(0, 2*pi, 30);
            patch("XData", 80 + 10 * cos(glow_angle), "YData", 24 + 7 * sin(glow_angle), ...
                  "FaceColor", [1 0.5 0.1], "FaceAlpha", 0.12, "EdgeColor", "none", ...
                  "Parent", axes_handle);
            line("XData", 100 * rand(1, 40), "YData", 6 + 44 * rand(1, 40), "LineStyle", "none", ...
                 "Marker", ".", "MarkerSize", 8, "Color", [1 0.6 0.15], "Parent", axes_handle);
        case 5      % Bioluminescent dots (small cyan and big purple lights)
            line("XData", 100 * rand(1, 30), "YData", 8 + 46 * rand(1, 30), "LineStyle", "none", ...
                 "Marker", "o", "MarkerSize", 2, "MarkerFaceColor", [0.4 0.9 1], ...
                 "Color", [0.4 0.9 1], "Parent", axes_handle);
            line("XData", 100 * rand(1, 8), "YData", 8 + 46 * rand(1, 8), "LineStyle", "none", ...
                 "Marker", "o", "MarkerSize", 6, "MarkerFaceColor", [0.8 0.3 1], ...
                 "Color", [0.8 0.3 1], "Parent", axes_handle);
            % Three glowing jellyfish
            draw_jellyfish(axes_handle, 20, 40, 3.5, [0.75 0.35 1.0]);
            draw_jellyfish(axes_handle, 55, 47, 4.0, [0.30 0.90 1.0]);
            draw_jellyfish(axes_handle, 85, 36, 3.0, [1.0 0.45 0.80]);
    endswitch

    % Draw the sand at the bottom
    dune_x = linspace(0, 100, 80);
    dune_y = 3.5 + 1.2 * sin(dune_x / 7) + 0.6 * sin(dune_x / 3);
    patch("XData", [dune_x 100 0], "YData", [dune_y 0 0], "FaceColor", sand_color, ...
          "EdgeColor", sand_edge, "Parent", axes_handle);
    % Darker sand below, ripples and pebbles
    patch("XData", [dune_x 100 0], "YData", [0.55 * dune_y 0 0], "FaceColor", 0.8 * sand_color, ...
          "FaceAlpha", 0.7, "EdgeColor", "none", "Parent", axes_handle);
    line("XData", dune_x, "YData", dune_y - 0.9 + 0.25 * sin(dune_x / 2), "Color", sand_edge, ...
         "LineWidth", 0.5, "Parent", axes_handle);
    line("XData", 100 * rand(1, 24), "YData", 0.8 + 1.4 * rand(1, 24), "LineStyle", "none", ...
         "Marker", "o", "MarkerSize", 2, "MarkerFaceColor", sand_edge, "Color", sand_edge, ...
         "Parent", axes_handle);
    if level == 4
        % Glowing cracks in the ground
        line("XData", [6 12 17 24], "YData", [2.2 1.4 2.0 1.2], "Color", [1 0.5 0.1], ...
             "LineWidth", 2, "Parent", axes_handle);
        line("XData", [40 46 52], "YData", [1.8 1.0 1.9], "Color", [1 0.5 0.1], ...
             "LineWidth", 2, "Parent", axes_handle);
        line("XData", [90 95 99], "YData", [1.5 2.2 1.3], "Color", [1 0.5 0.1], ...
             "LineWidth", 2, "Parent", axes_handle);
    endif

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
    % Light spot on each rock
    for k = 1:numel(rock_centers)
        patch("XData", rock_centers(k) - 0.15 * rock_widths(k) + 0.55 * rock_widths(k) * cos(rock_angle), ...
              "YData", 3 + 0.25 * rock_heights(k) + 0.55 * rock_heights(k) * sin(rock_angle), ...
              "FaceColor", min(1.35 * rock_color + 0.04, 1), "FaceAlpha", 0.55, ...
              "EdgeColor", "none", "Parent", axes_handle);
    endfor

    % Treasure chest on the sand of the Sunken Ship level (decor): a wooden box,
    % a round lid, a golden band with a lock, some coins on the sand and a
    % soft golden light around it
    if level == 3
        chest_x = 10;
        chest_y = 3.8;
        lid_angle = linspace(0, pi, 20);
        patch("XData", chest_x + 5 * cos(lid_angle), "YData", chest_y + 3.5 + 3 * sin(lid_angle), ...
              "FaceColor", [1 0.85 0.3], "FaceAlpha", 0.10, "EdgeColor", "none", "Parent", axes_handle);
        patch("XData", [chest_x - 3, chest_x + 3, chest_x + 3, chest_x - 3], ...
              "YData", [chest_y, chest_y, chest_y + 3, chest_y + 3], "FaceColor", [0.40 0.24 0.10], ...
              "EdgeColor", [0.15 0.08 0.03], "LineWidth", 1.5, "Parent", axes_handle);
        patch("XData", chest_x + 3 * cos(lid_angle), "YData", chest_y + 3 + 1.6 * sin(lid_angle), ...
              "FaceColor", [0.50 0.30 0.12], "EdgeColor", [0.15 0.08 0.03], "LineWidth", 1.5, ...
              "Parent", axes_handle);
        line("XData", [chest_x chest_x], "YData", [chest_y chest_y + 4.6], "Color", [0.90 0.75 0.25], ...
             "LineWidth", 2, "Parent", axes_handle);
        line("XData", chest_x, "YData", chest_y + 2.6, "LineStyle", "none", "Marker", "s", ...
             "MarkerSize", 4, "MarkerFaceColor", [1 0.9 0.4], "Color", [0.4 0.3 0.1], "Parent", axes_handle);
        line("XData", chest_x + [3.8 4.8 -3.9], "YData", chest_y + [0.2 0.1 0.2], "LineStyle", "none", ...
             "Marker", "o", "MarkerSize", 4, "MarkerFaceColor", [1 0.85 0.2], "Color", [0.6 0.45 0.1], ...
             "Parent", axes_handle);
    endif

    % Add coral in the Sunny Reef
    if level == 1
        line("XData", [38 38 36 38 40], "YData", [4 8 11 8 11], "Color", [0.95 0.40 0.55], ...
             "LineWidth", 4, "Parent", axes_handle);
        line("XData", [72 72 70 72 74], "YData", [4 7 10 7 10], "Color", [1.00 0.55 0.25], ...
             "LineWidth", 4, "Parent", axes_handle);
        line("XData", [95 95 93], "YData", [4 8 10], "Color", [0.95 0.40 0.55], ...
             "LineWidth", 4, "Parent", axes_handle);
    endif

    % More decor of the Sunny Reef: starfish and two round corals
    if level == 1
        draw_starfish(axes_handle, 28, 3.2, 1.8, [1.00 0.45 0.35]);
        draw_starfish(axes_handle, 62, 2.6, 1.5, [1.00 0.75 0.20]);
        draw_starfish(axes_handle, 84, 3.0, 1.3, [0.95 0.40 0.60]);
        coral_angle = linspace(0, pi, 20);
        patch("XData", 8 + 3.2 * cos(coral_angle), "YData", 3.4 + 2.4 * sin(coral_angle), ...
              "FaceColor", [0.90 0.45 0.65], "EdgeColor", [0.60 0.25 0.40], "LineWidth", 1.5, ...
              "Parent", axes_handle);
        patch("XData", 88 + 2.6 * cos(coral_angle), "YData", 3.2 + 2.0 * sin(coral_angle), ...
              "FaceColor", [0.55 0.45 0.85], "EdgeColor", [0.35 0.25 0.60], "LineWidth", 1.5, ...
              "Parent", axes_handle);
    endif

    % Plants (animated later by update_seaweed): a dark outline line under
    % each plant (first half of the handles), then the coloured plant (second half)
    plant_count = numel(seaweed_base_x);
    seaweed_handles = zeros(1, 2 * plant_count);
    for k = 1:plant_count
        seaweed_handles(k) = line("XData", seaweed_base_x(k) * ones(1, 20), ...
                                  "YData", linspace(3.5, seaweed_top_y(k), 20), ...
                                  "Color", 0.45 * plant_color, "LineWidth", 6.5 + (level == 2), ...
                                  "Parent", axes_handle);
    endfor
    for k = 1:plant_count
        plant_shade = min(plant_color * (0.8 + 0.1 * mod(k, 3)) + 0.08, 1);
        seaweed_handles(plant_count + k) = line("XData", seaweed_base_x(k) * ones(1, 20), ...
                                  "YData", linspace(3.5, seaweed_top_y(k), 20), ...
                                  "Color", plant_shade, "LineWidth", 3.5 + (level == 2), ...
                                  "Parent", axes_handle);
    endfor
    % Both halves share the same positions (update_seaweed uses these lists)
    seaweed_base_x = [seaweed_base_x seaweed_base_x];
    seaweed_top_y  = [seaweed_top_y seaweed_top_y];
    update_seaweed(seaweed_handles, seaweed_base_x, seaweed_top_y, 0);
endfunction

%--------------------------------------------------------------------------
% Function: show a message screen (title, rules, win, game over)
%--------------------------------------------------------------------------
function screen_handles = show_screen(axes_handle, title_text, text_lines, panel_color)
    % Shadow, panel, darker header, golden inner border, title (with shadow) and message
    shadow = patch("XData", [9.5 93.5 93.5 9.5], "YData", [3.5 3.5 53.5 53.5], "FaceColor", [0 0 0], ...
                   "FaceAlpha", 0.6, "EdgeColor", "none", "Parent", axes_handle);
    panel = patch("XData", [8 92 92 8], "YData", [5 5 55 55], "FaceColor", panel_color, ...
                  "EdgeColor", [1 1 1], "LineWidth", 3, "Parent", axes_handle);
    header = patch("XData", [8 92 92 8], "YData", [42 42 55 55], "FaceColor", 0.6 * panel_color, ...
                   "EdgeColor", "none", "Parent", axes_handle);
    border = line("XData", [9.5 90.5 90.5 9.5 9.5], "YData", [6.5 6.5 53.5 53.5 6.5], ...
                  "Color", [1 0.85 0.3], "LineWidth", 1.5, "Parent", axes_handle);
    title_shadow = text(50.4, 47.9, title_text, "HorizontalAlignment", "center", ...
                        "VerticalAlignment", "middle", "FontUnits", "normalized", ...
                        "FontSize", 0.085, "FontWeight", "bold", "Color", [0 0 0], ...
                        "Parent", axes_handle);
    title_main = text(50, 48.5, title_text, "HorizontalAlignment", "center", ...
                      "VerticalAlignment", "middle", "FontUnits", "normalized", ...
                      "FontSize", 0.085, "FontWeight", "bold", "Color", [1 0.85 0.2], ...
                      "Parent", axes_handle);
    message = text(50, 24, text_lines, "HorizontalAlignment", "center", ...
                   "VerticalAlignment", "middle", "FontUnits", "normalized", ...
                   "FontSize", 0.04, "Color", [1 1 1], "Parent", axes_handle);
    screen_handles = [shadow, panel, header, border, title_shadow, title_main, message];
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
        case "power"        % quick rising arpeggio (special fish eaten)
            notes = [659 880 1175 1568];
            wave = [];
            t = (0:round(0.07 * fs)) / fs;
            for k = 1:numel(notes)
                wave = [wave, 0.35 * sin(2*pi*notes(k)*t) .* (1 - 0.5 * t / 0.07)];
            endfor
        case "pearl"        % two bright notes (golden pearl collected)
            notes = [1319 1760];
            wave = [];
            t = (0:round(0.06 * fs)) / fs;
            for k = 1:numel(notes)
                wave = [wave, 0.30 * sin(2*pi*notes(k)*t) .* (1 - 0.5 * t / 0.06)];
            endfor
        case "heart"        % three soft rising notes (a life is given back)
            notes = [523 784 1047];
            wave = [];
            t = (0:round(0.08 * fs)) / fs;
            for k = 1:numel(notes)
                wave = [wave, 0.30 * sin(2*pi*notes(k)*t) .* (1 - 0.4 * t / 0.08)];
            endfor
        case "shield"       % two notes going up (a shield is collected)
            notes = [784 1175];
            wave = [];
            t = (0:round(0.07 * fs)) / fs;
            for k = 1:numel(notes)
                wave = [wave, 0.30 * sin(2*pi*notes(k)*t) .* (1 - 0.4 * t / 0.07)];
            endfor
        case "click"
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
    shadow = patch("XData", [left right right left] + 0.8, "YData", [bottom bottom top top] - 1.1, ...
                   "FaceColor", [0 0 0], "FaceAlpha", 0.5, "EdgeColor", "none", ...
                   "HitTest", "off", "Parent", axes_handle);
    body   = patch("XData", [left right right left], "YData", [bottom bottom top top], ...
                   "FaceColor", base_color, "EdgeColor", [1 1 1], "LineWidth", 3, ...
                   "ButtonDownFcn", @(src, evt) setappdata(figure_handle, "last_key", click_key), ...
                   "Parent", axes_handle);
    % Darker lower part and light upper part give a relief to the button
    base_strip = patch("XData", [left right right left], ...
                       "YData", [bottom bottom bottom + 0.30 * button_height bottom + 0.30 * button_height], ...
                       "FaceColor", [0 0 0], "FaceAlpha", 0.20, "EdgeColor", "none", ...
                       "HitTest", "off", "Parent", axes_handle);
    shine  = patch("XData", [left + 0.8, right - 0.8, right - 0.8, left + 0.8], ...
                   "YData", [center_y + 0.3, center_y + 0.3, top - 0.6, top - 0.6], ...
                   "FaceColor", [1 1 1], "FaceAlpha", 0.22, "EdgeColor", "none", ...
                   "HitTest", "off", "Parent", axes_handle);
    label_shadow = text(center_x + 0.35, center_y - 0.55, label, "HorizontalAlignment", "center", ...
                        "VerticalAlignment", "middle", "FontUnits", "normalized", ...
                        "FontSize", font_size, "FontWeight", "bold", "Color", [0 0 0], ...
                        "HitTest", "off", "Parent", axes_handle);
    label_handle = text(center_x, center_y, label, "HorizontalAlignment", "center", ...
                        "VerticalAlignment", "middle", "FontUnits", "normalized", ...
                        "FontSize", font_size, "FontWeight", "bold", "Color", [1 1 1], ...
                        "HitTest", "off", "Parent", axes_handle);
    register_zone(figure_handle, left, right, bottom, top, click_key, body);
    % Order: [shadow, body, shine, label, lower strip, label shadow]
    button_handles = [shadow, body, shine, label_handle, base_strip, label_shadow];
endfunction

%--------------------------------------------------------------------------
% Function: draw the title menu
%--------------------------------------------------------------------------
function menu_handles = draw_title_menu(figure_handle, axes_handle)
    menu_handles = [];
    x_ratio = x_scale_ratio(axes_handle);

    % Dark band behind the title (with a golden line under it) and bubbles
    menu_handles(end + 1) = patch("XData", [0 100 100 0], "YData", [35.5 35.5 60 60], ...
                                  "FaceColor", [0 0.05 0.15], "FaceAlpha", 0.45, "EdgeColor", "none", ...
                                  "HitTest", "off", "Parent", axes_handle);
    menu_handles(end + 1) = line("XData", [0 100], "YData", [35.5 35.5], "Color", [1 0.8 0.25], ...
                                 "LineWidth", 2.5, "HitTest", "off", "Parent", axes_handle);
    menu_handles(end + 1) = line("XData", 100 * rand(1, 14), "YData", 4 + 52 * rand(1, 14), ...
                                 "LineStyle", "none", "Marker", "o", "MarkerSize", 5, ...
                                 "Color", [1 1 1], "HitTest", "off", "Parent", axes_handle);

    % A shark chasing a small fish (beside PLAY), and two small fish below
    shark_handles = draw_static_fish(axes_handle, 13, 27.8, 4.2, 1, 5, [0.75 0.05 0.08], true);
    fish_handles  = draw_static_fish(axes_handle, 87, 27.8, 3.0, 1, 1, [1 0.65 0.1], false);
    small_one     = draw_static_fish(axes_handle, 11, 13.5, 1.8, -1, 2, [0.30 0.80 0.40], false);
    small_two     = draw_static_fish(axes_handle, 89, 13.5, 2.0, 1, 1, [0.95 0.90 0.30], false);
    menu_handles = [menu_handles, shark_handles, fish_handles, small_one, small_two];

    % Big title in capital letters, two lines = the top of the page
    title_lines  = {"A B Y S S", "F E A S T"};
    title_y      = [53.0, 44.4];
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
    menu_handles(end + 1) = text(50.3, 37.7, "EAT  OR  BE  EATEN", "HorizontalAlignment", "center", ...
        "VerticalAlignment", "middle", "FontUnits", "normalized", "FontSize", 0.055, ...
        "FontWeight", "bold", "Color", [0 0.03 0.1], "HitTest", "off", "Parent", axes_handle);
    menu_handles(end + 1) = text(50, 38.2, "EAT  OR  BE  EATEN", "HorizontalAlignment", "center", ...
        "VerticalAlignment", "middle", "FontUnits", "normalized", "FontSize", 0.055, ...
        "FontWeight", "bold", "Color", [0.85 0.97 1], "HitTest", "off", "Parent", axes_handle);

    % Big PLAY button (with a play triangle), then a big SETTINGS button (with a gear)
    play_button = make_button(figure_handle, axes_handle, 50, 27.8, 58, 11.5, "PLAY", ...
                              [0.12 0.60 0.30], "click_play", 0.09);
    triangle = patch("XData", 29 + x_ratio * [-1.8 -1.8 2.0], "YData", 27.8 + [-2.6 2.6 0], ...
                     "FaceColor", [1 1 1], "EdgeColor", "none", "HitTest", "off", "Parent", axes_handle);
    settings_button = make_button(figure_handle, axes_handle, 50, 14.3, 58, 9.5, "SETTINGS", ...
                                  [0.15 0.40 0.70], "click_settings", 0.068);
    gear_handles = draw_gear(axes_handle, 29, 14.3, 3.0, [1 1 1], [0.15 0.40 0.70]);
    set(gear_handles, "HitTest", "off");
    menu_handles = [menu_handles, play_button, triangle, settings_button, gear_handles];

    % Best score of the previous sessions, written between the two buttons.
    % The main program saves it with setappdata before drawing the menu;
    % nothing is written if the player has not scored yet.
    menu_best = getappdata(figure_handle, "menu_best");
    if ~isempty(menu_best) && menu_best > 0
        menu_handles(end + 1) = text(50.25, 20.1, sprintf("BEST SCORE: %d", menu_best), ...
            "HorizontalAlignment", "center", "VerticalAlignment", "middle", "FontUnits", "normalized", ...
            "FontSize", 0.034, "FontWeight", "bold", "Color", [0 0.03 0.1], "HitTest", "off", ...
            "Parent", axes_handle);
        menu_handles(end + 1) = text(50, 20.4, sprintf("BEST SCORE: %d", menu_best), ...
            "HorizontalAlignment", "center", "VerticalAlignment", "middle", "FontUnits", "normalized", ...
            "FontSize", 0.034, "FontWeight", "bold", "Color", [1 0.9 0.4], "HitTest", "off", ...
            "Parent", axes_handle);
    endif

    % Keyboard reminder at the bottom, on two lines
    menu_handles(end + 1) = patch("XData", [0 100 100 0], "YData", [0 0 8.3 8.3], "FaceColor", [0 0.05 0.15], ...
                                  "FaceAlpha", 0.55, "EdgeColor", "none", "HitTest", "off", ...
                                  "Parent", axes_handle);
    menu_handles(end + 1) = text(50, 5.6, "CLICK PLAY  or press ENTER", ...
        "HorizontalAlignment", "center", "VerticalAlignment", "middle", "FontUnits", "normalized", ...
        "FontSize", 0.036, "FontWeight", "bold", "Color", [1 0.9 0.4], "HitTest", "off", ...
        "Parent", axes_handle);
    menu_handles(end + 1) = text(50, 2.5, "S = settings      M = sound on/off      ESC = quit", ...
        "HorizontalAlignment", "center", "VerticalAlignment", "middle", "FontUnits", "normalized", ...
        "FontSize", 0.033, "Color", [0.9 0.97 1], "HitTest", "off", "Parent", axes_handle);
endfunction

%--------------------------------------------------------------------------
% Function: show the settings panel
%--------------------------------------------------------------------------
function show_settings(figure_handle, axes_handle)
    items = [];
    % Dim everything behind, then the panel (with a shadow) and its header
    items(end + 1) = patch("XData", [0 100 100 0], "YData", [0 0 60 60], "FaceColor", [0 0 0], ...
                           "FaceAlpha", 0.70, "EdgeColor", "none", "Parent", axes_handle);
    items(end + 1) = patch("XData", [7.5 95.5 95.5 7.5], "YData", [1.5 1.5 55.5 55.5], "FaceColor", [0 0 0], ...
                           "FaceAlpha", 0.5, "EdgeColor", "none", "Parent", axes_handle);
    items(end + 1) = patch("XData", [6 94 94 6], "YData", [3 3 57 57], "FaceColor", [0.04 0.18 0.32], ...
                           "EdgeColor", [1 1 1], "LineWidth", 3, "Parent", axes_handle);
    items(end + 1) = patch("XData", [6 94 94 6], "YData", [47.5 47.5 57 57], "FaceColor", [0.07 0.32 0.52], ...
                           "EdgeColor", "none", "Parent", axes_handle);
    items(end + 1) = line("XData", [6 94], "YData", [47.5 47.5], "Color", [1 0.85 0.2], ...
                          "LineWidth", 2.5, "Parent", axes_handle);
    items(end + 1) = text(52.4, 51.7, "SETTINGS", "HorizontalAlignment", "center", ...
                          "VerticalAlignment", "middle", "FontUnits", "normalized", "FontSize", 0.075, ...
                          "FontWeight", "bold", "Color", [0 0 0], "Parent", axes_handle);
    items(end + 1) = text(52, 52.3, "SETTINGS", "HorizontalAlignment", "center", ...
                          "VerticalAlignment", "middle", "FontUnits", "normalized", "FontSize", 0.075, ...
                          "FontWeight", "bold", "Color", [1 0.85 0.2], "Parent", axes_handle);
    items = [items, draw_gear(axes_handle, 30, 52.3, 3.2, [1 0.85 0.2], [0.07 0.32 0.52])];

    % Texts: headings in gold (big), lines in white (big enough to read easily)
    rows = { 43.4, "THE GOAL", 1;
             39.9, "Cross 5 levels: eat smaller fish to grow,", 0;
             36.7, "then get bigger than the BOSS and EAT it!", 0;
             32.6, "HOW TO PLAY", 1;
             29.3, "Swim: arrow keys  or  Z Q S D  /  W A S D", 0;
             23.2, "Red fish hunt you: you lose a life and shrink", 0;
             20.4, "Red dashed line = the boss is about to charge!", 0;
             17.6, "Glowing green fish: eat it to wipe out red fish!", 0;
             14.8, "SPACE stop    P settings    M sound    ESC quit", 0 };
    for r = 1:size(rows, 1)
        if rows{r, 3}
            text_color = [1 0.85 0.2];
            text_size = 0.05;
            text_weight = "bold";
        else
            text_color = [1 1 1];
            text_size = 0.037;
            text_weight = "normal";
        endif
        items(end + 1) = text(12, rows{r, 1}, rows{r, 2}, "HorizontalAlignment", "left", ...
                              "VerticalAlignment", "middle", "FontUnits", "normalized", ...
                              "FontSize", text_size, "FontWeight", text_weight, "Color", text_color, ...
                              "Parent", axes_handle);
    endfor
    % Colour legend: each word has the colour of the fish it describes
    legend_text  = {"Green = edible", "Yellow = same size", "Red = DANGER"};
    legend_x     = [12 38 67];
    legend_color = {[0.45 1 0.55], [1 0.95 0.35], [1 0.40 0.35]};
    for j = 1:3
        items(end + 1) = text(legend_x(j), 26.1, legend_text{j}, "HorizontalAlignment", "left", ...
                              "VerticalAlignment", "middle", "FontUnits", "normalized", ...
                              "FontSize", 0.037, "FontWeight", "bold", "Color", legend_color{j}, ...
                              "Parent", axes_handle);
    endfor

    % Buttons: sound on/off (mute) and BACK
    sound_button = make_button(figure_handle, axes_handle, 30, 8.6, 36, 8, "SOUND: ON", ...
                               [0.12 0.60 0.30], "click_sound", 0.045);
    back_button  = make_button(figure_handle, axes_handle, 70, 8.6, 36, 8, "BACK", ...
                               [0.15 0.40 0.70], "click_back", 0.05);
    items = [items, sound_button, back_button];

    done = false;
    while ~done && ishandle(figure_handle)
        if isequal(getappdata(figure_handle, "sound_on"), 1)
            set(sound_button([4 6]), "String", "SOUND: ON");
            set(sound_button(2), "FaceColor", [0.12 0.60 0.30]);
        else
            set(sound_button([4 6]), "String", "SOUND: MUTED");
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
    min_enemy_count = max(5, ceil(0.6 * enemy_count));   % fewest fish left when the player is big
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
    burst_angles  = linspace(0, 2*pi, 17)(1:16);   % 16 sparkles around a circle
    burst_ring    = repmat([1 0.6], 1, 8);         % two rings: outer and inner sparkles
    hit_flash_frames = 0;                          % frames of red flash after a hit
    shake_frames  = 0;                             % frames of screen shake
    banner_frames = 100;                           % frames the banner stays visible

    % --- Special green fish: eat it to wipe out the red fish around you ---
    special_size    = 2.4;                         % size of the special fish
    special_radius  = 45;                          % red fish closer than this are wiped out
    special_speed   = 0.45;                        % swimming speed of the special fish
    special_active  = false;                       % true while the special fish is in the sea
    special_x       = 0;
    special_y       = 0;
    special_dir     = 1;
    special_timer   = 200 + randi(150);            % frames before the first special fish
    wave_age        = 0;                           % age of the green shock wave (0 = none)
    wave_x          = 0;
    wave_y          = 0;
    wave_angles     = linspace(0, 2*pi, 41);
    clear_flash_frames = 0;                        % frames of green flash when red fish are wiped out

    % --- Extra details: combo, golden pearls, crabs, bubble trail, level tip ---
    % These variables only store the state of the new details. The combo counts
    % the fish eaten quickly one after the other, the pearl is a bonus that
    % appears from time to time, the trail stores the bubbles behind the player
    % and the tip is a short sentence shown at the start of each level.
    combo_count   = 0;                             % fish eaten one after the other
    combo_timer   = 0;                             % frames left to continue the combo
    combo_window  = 90;                            % time allowed between two fish
    best_combo    = 0;
    fish_eaten    = 0;
    pearl_active  = false;                         % true while a golden pearl is in the sea
    pearl_x       = 0;
    pearl_y       = 0;
    pearl_age     = 0;
    pearl_timer   = 150 + randi(150);              % frames before the first pearl
    pearls_found  = 0;
    trail_x       = zeros(1, 0);                   % bubbles left behind the player
    trail_y       = zeros(1, 0);
    trail_age     = zeros(1, 0);
    tip_frames    = 140;                           % frames the level tip stays visible
    level_tips    = {"Eat the GREEN fish to grow - avoid the RED ones!", ...
                     "Barracudas are fast: eat fish in a row for COMBOS!", ...
                     "Catch the golden PEARLS for bonus points!", ...
                     "The heat makes fish aggressive. Watch the red dashed line!", ...
                     "Last level: only the Megalodon stands in your way!"};

    % --- More details: heart, shield, school of tiny fish, plankton, milestones ---
    % Heart: gives back one lost life. It only appears if the player lost a life.
    heart_active  = false;                         % true while a heart is in the sea
    heart_x       = 0;
    heart_y       = 0;
    heart_age     = 0;
    heart_timer   = 300 + randi(200);              % frames before a heart can appear
    heart_t       = linspace(0, 2*pi, 40);         % the shape of the heart (formula of a heart curve)
    heart_shape_x = sin(heart_t) .^ 3;
    heart_shape_y = (13*cos(heart_t) - 5*cos(2*heart_t) - 2*cos(3*heart_t) - cos(4*heart_t)) / 16;
    heart_ratio   = x_scale_ratio(axes_handle);    % keeps the heart looking correct
    % Shield: protects the player from the next bite (or for 600 frames at most)
    shield_active = false;                         % true while a shield bubble is in the sea
    shield_x      = 0;
    shield_y      = 0;
    shield_age    = 0;
    shield_timer  = 450 + randi(300);              % frames before a shield can appear
    shield_frames = 0;                             % frames of protection left on the player
    shield_angle  = linspace(0, 2*pi, 32);         % the ring around the player
    % School of tiny fish and plankton, only for the decor of the background
    school_count  = 12;
    school_dx     = 12 * (rand(1, school_count) - 0.5);   % place of each fish inside the school
    school_dy     = 5 * (rand(1, school_count) - 0.5);
    school_cx     = world_width * rand;            % centre of the school
    school_cy     = 20 + 20 * rand;
    school_dir    = 2 * (rand > 0.5) - 1;
    school_speed  = 0.18;
    plankton_count = 25;
    plankton_x    = world_width * rand(1, plankton_count);
    plankton_y    = 8 + 48 * rand(1, plankton_count);
    % Messages shown once when the player reaches a part of the way to the boss
    milestone_start = false;
    milestone_boss  = false;

    % --- Bonus mission of the level ---
    % Each level gives one small extra objective. It does not change the main
    % rules of the game: the player can ignore it, but completing it gives a
    % bonus score and makes the level feel more alive.
    mission_names = {"Reef Snack", "Kelp Streak", "Treasure Hunter", ...
                     "Heat Survivor", "Abyss Legend"};
    mission_goal  = 3 + level;                     % fish to eat for the mission
    mission_done  = false;                         % true when the mission is completed
    mission_reward = 75 * level;                   % bonus points for the mission
    mission_flash_frames = 0;                      % golden flash after the reward

    % --- Draw the scene: decor first (objects drawn later are on top) ---
    [seaweed_handles, seaweed_base_x, seaweed_top_y, theme] = draw_sea_background(axes_handle, level);

    % Two small crabs walking on the sea floor (decor only, they are harmless).
    % Each crab is made of 4 parts: the legs, the claws, the shell and the eyes.
    % They are drawn after the background, so they walk in front of the sand.
    crab_count  = 2;
    crab_x      = [20 70];
    crab_dir    = [1 -1];
    crab_speed  = [0.10 0.07];
    crab_size   = [0.9 0.7];
    crab_colors = [0.90 0.30 0.20; 0.95 0.45 0.15; 0.70 0.55 0.35; 0.60 0.10 0.05; 0.20 0.85 0.85];
    crab_color  = crab_colors(level, :);
    crab_body   = zeros(1, crab_count);
    crab_claws  = zeros(1, crab_count);
    crab_legs   = zeros(1, crab_count);
    crab_eyes   = zeros(1, crab_count);
    for k = 1:crab_count
        crab_y = 3.6 + 1.2 * sin(crab_x(k) / 7) + 0.6 * sin(crab_x(k) / 3);
        [cbx, cby, ccx, ccy, clx, cly] = crab_shape(crab_x(k), crab_y, crab_size(k), 0);
        crab_legs(k)  = line("XData", clx, "YData", cly, "Color", 0.6 * crab_color, ...
                             "LineWidth", 1.5, "Parent", axes_handle);
        crab_claws(k) = line("XData", ccx, "YData", ccy, "Color", crab_color, ...
                             "LineWidth", 2.5, "Parent", axes_handle);
        crab_body(k)  = patch("XData", cbx, "YData", cby, "FaceColor", crab_color, ...
                              "EdgeColor", 0.5 * crab_color, "Parent", axes_handle);
        crab_eyes(k)  = line("XData", crab_x(k) + crab_size(k) * [-0.4 0.4], ...
                             "YData", crab_y + crab_size(k) * [1.0 1.0], "LineStyle", "none", ...
                             "Marker", "o", "MarkerSize", 3, "MarkerFaceColor", [1 1 1], ...
                             "Color", [0 0 0], "Parent", axes_handle);
    endfor

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

    % A school of tiny fish and some plankton in the background: only dots,
    % drawn behind the real fish. The colour follows the colours of the level.
    school_handle   = line("XData", school_cx + school_dx, "YData", school_cy + school_dy, ...
                           "LineStyle", "none", "Marker", ".", "MarkerSize", 9, ...
                           "Color", min(2 * theme.sil_color + 0.15, 1), "Parent", axes_handle);
    plankton_handle = line("XData", plankton_x, "YData", plankton_y, "LineStyle", "none", ...
                           "Marker", ".", "MarkerSize", 5, "Color", 0.8 * theme.bubble_color, ...
                           "Parent", axes_handle);

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

    % Bubble trail behind the swimming player: one line made only of markers,
    % drawn before the player so the bubbles stay behind the fish
    trail_handle = line("XData", [], "YData", [], "LineStyle", "none", "Marker", "o", ...
                        "MarkerSize", 4, "Color", theme.bubble_color, "Parent", axes_handle);

    % Player graphics
    [bx, by, fx, fy, sx, sy, ex, ey] = fish_shape(player_x, player_y, player_size, player_dir_x, 0);
    player_fins   = patch("XData", fx, "YData", fy, "FaceColor", [0.85 0.35 0.05], ...
                          "EdgeColor", [0.4 0.2 0], "Parent", axes_handle);
    player_body   = patch("XData", bx, "YData", by, "FaceColor", [1 0.65 0.1], ...
                          "EdgeColor", [0.4 0.2 0], "LineWidth", 1.5, "Parent", axes_handle);
    player_stripe = patch("XData", sx, "YData", sy, "FaceColor", [0.90 0.40 0.05], ...
                          "EdgeColor", "none", "Parent", axes_handle);
    [shx, shy]    = fish_shine(bx, by, player_x, player_y);
    player_shine  = patch("XData", shx, "YData", shy, "FaceColor", [1 1 0.9], "FaceAlpha", 0.30, ...
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
    enemy_shine   = zeros(1, enemy_count);
    enemy_teeth   = zeros(1, enemy_count);
    enemy_brow    = zeros(1, enemy_count);
    enemy_on      = true(1, enemy_count);          % false = this fish is hidden (not in the sea now)
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
        [shx, shy]      = fish_shine(bx, by, enemy_x(i), enemy_y(i));
        enemy_shine(i)  = patch("XData", shx, "YData", shy, "FaceColor", [1 1 1], "FaceAlpha", 0.22, ...
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
    [shx, shy]  = fish_shine(bx, by, 0, 0);
    boss_shine  = patch("XData", shx, "YData", shy, "FaceColor", [1 1 1], "FaceAlpha", 0.15, ...
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
    burst_handle = line("XData", zeros(1, 16), "YData", zeros(1, 16), "LineStyle", "none", ...
                        "Marker", ".", "MarkerSize", 18, "Color", [1 0.95 0.4], ...
                        "Visible", "off", "Parent", axes_handle);
    % (each text has a black copy behind it, copied from it at every frame)
    popup_shadow = text(0, 0, "", "HorizontalAlignment", "center", "FontUnits", "normalized", ...
                        "FontSize", 0.055, "FontWeight", "bold", "Color", [0 0 0], ...
                        "Parent", axes_handle);
    popup_text = text(0, 0, "", "HorizontalAlignment", "center", "FontUnits", "normalized", ...
                      "FontSize", 0.055, "FontWeight", "bold", "Color", [1 1 0.4], ...
                      "Parent", axes_handle);
    banner_shadow = text(50.35, 37.45, sprintf("LEVEL %d - %s", level, level_names{level}), ...
                         "HorizontalAlignment", "center", "FontUnits", "normalized", ...
                         "FontSize", 0.07, "FontWeight", "bold", "Color", [0 0 0], ...
                         "Parent", axes_handle);
    banner_text = text(50, 38, sprintf("LEVEL %d - %s", level, level_names{level}), ...
                       "HorizontalAlignment", "center", "FontUnits", "normalized", ...
                       "FontSize", 0.07, "FontWeight", "bold", "Color", [1 0.9 0.3], ...
                       "Parent", axes_handle);

    % HUD top left: level, score, then the lives just below
    %      HUD top right: best score and the settings icon (gear)
    patch("XData", [0 38 38 0], "YData", [46.5 46.5 60 60], "FaceColor", [0 0.05 0.15], ...
          "FaceAlpha", 0.60, "EdgeColor", [0.55 0.80 1], "LineWidth", 1.5, "Parent", axes_handle);
    patch("XData", [62 100 100 62], "YData", [54 54 60 60], "FaceColor", [0 0.05 0.15], ...
          "FaceAlpha", 0.60, "EdgeColor", [0.55 0.80 1], "LineWidth", 1.5, "Parent", axes_handle);
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
    % Combo counter (orange text under the lives) and growth bar (top right).
    % The bar is empty at the start of the level and full when the player is big
    % enough to eat the boss: it shows how far the player is from the goal.
    combo_hud = text(2, 43.8, "", "Parent", axes_handle, "FontUnits", "normalized", ...
                     "FontSize", 0.04, "FontWeight", "bold", "Color", [1 0.7 0.2], ...
                     "VerticalAlignment", "middle");
    % Bonus mission HUD: a small line under the combo counter that shows the
    % optional objective of the level and how close the player is to finishing it.
    mission_hud = text(2, 40.7, "", "Parent", axes_handle, "FontUnits", "normalized", ...
                       "FontSize", 0.031, "FontWeight", "bold", "Color", [0.9 0.95 1], ...
                       "VerticalAlignment", "middle");
    % Big growth bar: it is more visible than the first version. The dark box is
    % the empty bar, the coloured rectangle fills it, the white line marks the
    % current progress and the text writes the percent directly on the bar.
    growth_left   = 58;
    growth_right  = 98;
    growth_bottom = 49.8;
    growth_top    = 53.4;
    patch("XData", [growth_left growth_right growth_right growth_left], ...
          "YData", [growth_bottom growth_bottom growth_top growth_top], ...
          "FaceColor", [0 0.04 0.12], "FaceAlpha", 0.78, ...
          "EdgeColor", [0.55 0.80 1], "LineWidth", 2.2, "Parent", axes_handle);
    growth_fill = patch("XData", [growth_left growth_left growth_left growth_left], ...
                        "YData", [growth_bottom growth_bottom growth_top growth_top], ...
                        "FaceColor", [0.3 0.9 0.4], "EdgeColor", "none", ...
                        "Parent", axes_handle);
    growth_marker = line("XData", [growth_left growth_left], "YData", [growth_bottom growth_top], ...
                         "Color", [1 1 1], "LineWidth", 2.5, "Parent", axes_handle);
    growth_percent = text((growth_left + growth_right) / 2, 51.6, "0%", "Parent", axes_handle, ...
         "HorizontalAlignment", "center", "VerticalAlignment", "middle", ...
         "FontUnits", "normalized", "FontSize", 0.043, "FontWeight", "bold", ...
         "Color", [1 1 1]);
    % Text of the progress bar. It changes during the game to show that this bar
    % is the growth needed before the player can eat the boss and pass the level.
    growth_text = text(growth_left, 48.2, "GROWTH TO BOSS SIZE", "Parent", axes_handle, ...
         "FontUnits", "normalized", "FontSize", 0.027, "FontWeight", "bold", ...
         "Color", [0.85 0.95 1], "VerticalAlignment", "middle");

    % Tip of the level: a short sentence shown a few seconds at the start of the
    % level, just under the level banner (a black copy behind gives a shadow)
    tip_shadow = text(50.3, 33.2, level_tips{level}, "HorizontalAlignment", "center", ...
                      "FontUnits", "normalized", "FontSize", 0.035, "FontWeight", "bold", ...
                      "Color", [0 0 0], "Parent", axes_handle);
    tip_text   = text(50, 33.7, level_tips{level}, "HorizontalAlignment", "center", ...
                      "FontUnits", "normalized", "FontSize", 0.035, "FontWeight", "bold", ...
                      "Color", [1 1 1], "Parent", axes_handle);

    % Golden pearl (hidden until it appears): a white dot with a golden ring
    % around it that grows and shrinks to make it shine
    pearl_glow = line("XData", 0, "YData", 0, "LineStyle", "none", "Marker", "o", ...
                      "MarkerSize", 16, "MarkerFaceColor", "none", "Color", [1 0.9 0.6], ...
                      "LineWidth", 1.5, "Visible", "off", "Parent", axes_handle);
    pearl_dot  = line("XData", 0, "YData", 0, "LineStyle", "none", "Marker", "o", ...
                      "MarkerSize", 9, "MarkerFaceColor", [1 0.97 0.88], "Color", [0.85 0.75 0.55], ...
                      "Visible", "off", "Parent", axes_handle);

    % Heart (hidden until it appears): a pink heart with a ring around it
    heart_patch = patch("XData", zeros(1, 40), "YData", zeros(1, 40), "FaceColor", [1 0.25 0.40], ...
                        "EdgeColor", [1 1 1], "LineWidth", 1.5, "Visible", "off", "Parent", axes_handle);
    heart_glow  = line("XData", 0, "YData", 0, "LineStyle", "none", "Marker", "o", ...
                       "MarkerSize", 22, "MarkerFaceColor", "none", "Color", [1 0.6 0.7], ...
                       "LineWidth", 1.5, "Visible", "off", "Parent", axes_handle);

    % Shield: the bonus is a blue diamond inside a ring, and when it is collected
    % a big transparent blue bubble (shield_ring) surrounds the player
    shield_glow = line("XData", 0, "YData", 0, "LineStyle", "none", "Marker", "o", ...
                       "MarkerSize", 22, "MarkerFaceColor", "none", "Color", [0.5 0.85 1], ...
                       "LineWidth", 2.5, "Visible", "off", "Parent", axes_handle);
    shield_dot  = line("XData", 0, "YData", 0, "LineStyle", "none", "Marker", "d", ...
                       "MarkerSize", 10, "MarkerFaceColor", [0.7 0.95 1], "Color", [0.2 0.5 0.8], ...
                       "Visible", "off", "Parent", axes_handle);
    shield_ring = patch("XData", zeros(1, 32), "YData", zeros(1, 32), "FaceColor", [0.5 0.85 1], ...
                        "FaceAlpha", 0.15, "EdgeColor", [0.6 0.9 1], "LineWidth", 2, ...
                        "Visible", "off", "Parent", axes_handle);

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

    % Golden flash over the whole screen when the bonus mission is completed.
    % It is softer than the red hit flash because it is a reward effect.
    mission_flash = patch("XData", [0 100 100 0], "YData", [0 0 60 60], "FaceColor", [1 0.85 0.20], ...
                          "FaceAlpha", 0.20, "EdgeColor", "none", "Visible", "off", ...
                          "Parent", axes_handle);

    % Special green fish (hidden until it appears), its glow, shock wave and green flash
    [bx, by, fx, fy, sx, sy, ex, ey] = fish_shape(0, 0, special_size, 1, 0, 1);
    special_glow   = line("XData", 0, "YData", 0, "LineStyle", "none", "Marker", "o", ...
                          "MarkerSize", 34, "MarkerFaceColor", "none", "Color", [1 1 0.5], ...
                          "LineWidth", 2, "Visible", "off", "Parent", axes_handle);
    special_fins   = patch("XData", fx, "YData", fy, "FaceColor", [0.10 0.70 0.25], ...
                           "EdgeColor", [0.05 0.35 0.10], "Visible", "off", "Parent", axes_handle);
    special_body   = patch("XData", bx, "YData", by, "FaceColor", [0.30 1.00 0.40], ...
                           "EdgeColor", [1 1 0.5], "LineWidth", 2, "Visible", "off", "Parent", axes_handle);
    special_stripe = patch("XData", sx, "YData", sy, "FaceColor", [1 1 0.4], ...
                           "EdgeColor", "none", "Visible", "off", "Parent", axes_handle);
    [shx, shy]     = fish_shine(bx, by, 0, 0);
    special_shine  = patch("XData", shx, "YData", shy, "FaceColor", [1 1 1], "FaceAlpha", 0.35, ...
                           "EdgeColor", "none", "Visible", "off", "Parent", axes_handle);
    special_eye    = line("XData", ex, "YData", ey, "LineStyle", "none", "Marker", "o", ...
                          "MarkerSize", 6, "MarkerFaceColor", [1 1 1], "Color", [0 0 0], ...
                          "Visible", "off", "Parent", axes_handle);
    special_wave   = line("XData", 0, "YData", 0, "Color", [0.5 1 0.6], "LineWidth", 5, ...
                          "Visible", "off", "Parent", axes_handle);
    clear_flash    = patch("XData", [0 100 100 0], "YData", [0 0 60 60], "FaceColor", [0.3 1 0.4], ...
                           "FaceAlpha", 0.22, "EdgeColor", "none", "Visible", "off", ...
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
        % The bigger the player, the fewer fish in the sea (the last ones are hidden;
        % if the player shrinks after a bite, they come back from the sides)
        size_progress = min(max((player_size - start_size) / (boss_win_size - start_size), 0), 1);
        active_count = enemy_count - floor(size_progress * (enemy_count - min_enemy_count));
        for i = 1:enemy_count
            if i <= active_count && ~enemy_on(i)
                [enemy_x(i), enemy_y(i), enemy_size(i), enemy_dir(i), enemy_speed(i), enemy_species(i)] = ...
                    spawn_enemy(player_size, speed_factor, current_small_probability, allowed_species, ...
                                world_width, world_height, player_x, player_y, false);
                set([enemy_body(i), enemy_fins(i), enemy_stripe(i), enemy_shine(i), enemy_eye(i)], "Visible", "on");
                enemy_on(i) = true;
            elseif i > active_count && enemy_on(i)
                set([enemy_body(i), enemy_fins(i), enemy_stripe(i), enemy_shine(i), enemy_eye(i), ...
                     enemy_teeth(i), enemy_brow(i)], "Visible", "off");
                enemy_on(i) = false;
            endif
        endfor
        for i = 1:active_count
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
                    % Combo: if the last fish was eaten less than 90 frames ago, the combo
                    % continues (+1), otherwise it starts again at 1. Each fish of the
                    % combo gives 5 extra points (maximum 50) and the best combo is saved.
                    if combo_timer > 0
                        combo_count = combo_count + 1;
                    else
                        combo_count = 1;
                    endif
                    combo_timer = combo_window;
                    best_combo  = max(best_combo, combo_count);
                    fish_eaten  = fish_eaten + 1;
                    points = points + 5 * min(combo_count - 1, 10);
                    % Bonus mission: when enough fish have been eaten in this level,
                    % the player gets a reward. This is only an extra challenge, so
                    % it never blocks the normal progress to the boss.
                    if ~mission_done && fish_eaten >= mission_goal
                        mission_done = true;
                        points = points + mission_reward;
                        mission_flash_frames = 12;
                        banner_frames = 90;
                        set(banner_text, "String", sprintf("MISSION COMPLETE: %s!", upper(mission_names{level})), ...
                            "Color", [1 0.85 0.2]);
                    endif
                    play_sfx(figure_handle, "eat");
                    score = score + points;
                    player_size = player_size + growth_ratio * enemy_size(i);
                    burst_x = enemy_x(i);
                    burst_y = enemy_y(i);
                    burst_age = 1;
                    if combo_count >= 2
                        popup_label = sprintf("+%d  COMBO x%d", points, combo_count);
                    else
                        popup_label = sprintf("+%d", points);
                    endif
                    if mission_flash_frames == 12
                        popup_label = sprintf("+%d  MISSION!", points);
                    endif
                    set(popup_text, "String", popup_label, "Position", [burst_x, burst_y + 2]);
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

        % 3b. Special green fish: it appears from time to time and is harmless.
        %     Eating it wipes out all the dangerous (red) fish around the player.
        if ~special_active
            special_timer = special_timer - 1;
            if special_timer <= 0
                special_active = true;
                special_dir = 2 * (rand > 0.5) - 1;
                if special_dir == 1
                    special_x = -4 * special_size;
                else
                    special_x = world_width + 4 * special_size;
                endif
                special_y = 14 + 28 * rand;
                set([special_fins, special_body, special_stripe, special_shine, special_eye, special_glow], ...
                    "Visible", "on");
                if banner_frames == 0
                    banner_frames = 90;
                    set(banner_text, "String", "A SPECIAL GREEN FISH!", "Color", [0.4 1 0.5]);
                endif
            endif
        else
            special_x = special_x + special_dir * special_speed;
            special_y = special_y + 0.10 * sin(0.08 * frame_count);
            if (special_dir == 1 && special_x > world_width + 5 * special_size) || ...
               (special_dir == -1 && special_x < -5 * special_size)
                % It left the screen without being eaten
                special_active = false;
                special_timer = 100 + randi(50);
                set([special_fins, special_body, special_stripe, special_shine, special_eye, special_glow], ...
                    "Visible", "off");
            elseif fish_overlap(player_x, player_y, player_size, special_x, special_y, special_size, 1)
                % The player eats it: wipe out the red fish around
                play_sfx(figure_handle, "power");
                special_active = false;
                special_timer = 200 + randi(150);
                set([special_fins, special_body, special_stripe, special_shine, special_eye, special_glow], ...
                    "Visible", "off");
                wiped_count = 0;
                for i = 1:active_count
                    if enemy_size(i) > player_size * size_tolerance && ...
                       hypot(player_x - enemy_x(i), player_y - enemy_y(i)) < special_radius
                        % The red fish is replaced by a small fish coming from a side
                        [enemy_x(i), enemy_y(i), enemy_size(i), enemy_dir(i), enemy_speed(i), enemy_species(i)] = ...
                            spawn_enemy(player_size, speed_factor, 1, allowed_species, ...
                                        world_width, world_height, player_x, player_y, false);
                        wiped_count = wiped_count + 1;
                    endif
                endfor
                score = score + 50;
                burst_x = special_x;
                burst_y = special_y;
                burst_age = 1;
                set(popup_text, "String", "+50", "Position", [burst_x, burst_y + 2]);
                wave_age = 1;
                wave_x = player_x;
                wave_y = player_y;
                clear_flash_frames = 8;
                shake_frames = max(shake_frames, 10);
                banner_frames = 90;
                if wiped_count > 0
                    set(banner_text, "String", sprintf("%d RED FISH WIPED OUT!", wiped_count), "Color", [0.4 1 0.5]);
                else
                    set(banner_text, "String", "NO RED FISH AROUND!", "Color", [0.4 1 0.5]);
                endif
            endif
        endif

        % 3c. Golden pearl: it appears from time to time at a random place, it is
        %     harmless and gives bonus points (25 x level) if the player touches it.
        %     It blinks at the end and disappears if nobody takes it.
        if ~pearl_active
            pearl_timer = pearl_timer - 1;
            if pearl_timer <= 0
                pearl_active = true;
                pearl_age = 0;
                pearl_x = 8 + 84 * rand;
                pearl_y = 10 + 30 * rand;
                set([pearl_glow, pearl_dot], "Visible", "on");
            endif
        else
            pearl_age = pearl_age + 1;
            pearl_draw_y = pearl_y + 0.5 * sin(0.15 * frame_count);
            set(pearl_glow, "XData", pearl_x, "YData", pearl_draw_y, ...
                "MarkerSize", 16 + 4 * sin(0.3 * frame_count));
            set(pearl_dot, "XData", pearl_x, "YData", pearl_draw_y);
            if hypot(player_x - pearl_x, player_y - pearl_draw_y) < 2 + player_size
                % The player collects the pearl
                pearl_active = false;
                pearl_timer = 250 + randi(200);
                pearls_found = pearls_found + 1;
                score = score + 25 * level;
                play_sfx(figure_handle, "pearl");
                burst_x = pearl_x;
                burst_y = pearl_draw_y;
                burst_age = 1;
                set(popup_text, "String", sprintf("+%d  PEARL", 25 * level), ...
                    "Position", [burst_x, burst_y + 2]);
                set([pearl_glow, pearl_dot], "Visible", "off");
            elseif pearl_age > 350
                % The pearl disappears if nobody takes it
                pearl_active = false;
                pearl_timer = 150 + randi(150);
                set([pearl_glow, pearl_dot], "Visible", "off");
            elseif pearl_age > 280 && mod(pearl_age, 8) < 4
                set([pearl_glow, pearl_dot], "Visible", "off");    % blinks before it disappears
            else
                set([pearl_glow, pearl_dot], "Visible", "on");
            endif
        endif

        % 3d. Heart: the timer only runs while the player has lost a life. When it
        %     ends, a heart appears at a random place. If the player touches it, he
        %     gets one life back (never more than at the start of the level).
        %     The heart pulses, blinks at the end and disappears if nobody takes it.
        if ~heart_active
            if lives < initial_lives
                heart_timer = heart_timer - 1;
            endif
            if heart_timer <= 0 && lives < initial_lives
                heart_active = true;
                heart_age = 0;
                heart_x = 8 + 84 * rand;
                heart_y = 10 + 30 * rand;
                set([heart_patch, heart_glow], "Visible", "on");
            endif
        else
            heart_age = heart_age + 1;
            heart_draw_y = heart_y + 0.5 * sin(0.12 * frame_count);
            heart_pulse = 1 + 0.12 * sin(0.35 * frame_count);
            set(heart_patch, "XData", heart_x + 1.5 * heart_pulse * heart_ratio * heart_shape_x, ...
                "YData", heart_draw_y + 1.5 * heart_pulse * heart_shape_y);
            set(heart_glow, "XData", heart_x, "YData", heart_draw_y);
            if hypot(player_x - heart_x, player_y - heart_draw_y) < 2 + player_size
                % The player takes the heart: one life back
                heart_active = false;
                heart_timer = 500 + randi(300);
                lives = min(lives + 1, initial_lives);
                play_sfx(figure_handle, "heart");
                burst_x = heart_x;
                burst_y = heart_draw_y;
                burst_age = 1;
                set(popup_text, "String", "+1 LIFE", "Position", [burst_x, burst_y + 2]);
                set([heart_patch, heart_glow], "Visible", "off");
            elseif heart_age > 420
                heart_active = false;
                heart_timer = 300 + randi(200);
                set([heart_patch, heart_glow], "Visible", "off");
            elseif heart_age > 350 && mod(heart_age, 8) < 4
                set([heart_patch, heart_glow], "Visible", "off");    % blinks before it disappears
            else
                set([heart_patch, heart_glow], "Visible", "on");
            endif
        endif

        % 3e. Shield bonus: it appears from time to time (not while the player already
        %     has a shield). If the player touches it, he gets a blue shield for
        %     600 frames that absorbs the next bite (see the part where a life is lost).
        if ~shield_active
            shield_timer = shield_timer - 1;
            if shield_timer <= 0 && shield_frames == 0
                shield_active = true;
                shield_age = 0;
                shield_x = 8 + 84 * rand;
                shield_y = 10 + 30 * rand;
                set([shield_glow, shield_dot], "Visible", "on");
            endif
        else
            shield_age = shield_age + 1;
            shield_draw_y = shield_y + 0.5 * sin(0.10 * frame_count);
            set(shield_glow, "XData", shield_x, "YData", shield_draw_y, ...
                "MarkerSize", 22 + 4 * sin(0.3 * frame_count));
            set(shield_dot, "XData", shield_x, "YData", shield_draw_y);
            if hypot(player_x - shield_x, player_y - shield_draw_y) < 2 + player_size
                % The player takes the shield
                shield_active = false;
                shield_timer = 600 + randi(300);
                shield_frames = 600;
                play_sfx(figure_handle, "shield");
                burst_x = shield_x;
                burst_y = shield_draw_y;
                burst_age = 1;
                set(popup_text, "String", "SHIELD!", "Position", [burst_x, burst_y + 2]);
                banner_frames = 70;
                set(banner_text, "String", "SHIELD ON: ONE FREE BITE!", "Color", [0.5 0.85 1]);
                set([shield_glow, shield_dot], "Visible", "off");
            elseif shield_age > 380
                shield_active = false;
                shield_timer = 300 + randi(200);
                set([shield_glow, shield_dot], "Visible", "off");
            elseif shield_age > 310 && mod(shield_age, 8) < 4
                set([shield_glow, shield_dot], "Visible", "off");    % blinks before it disappears
            else
                set([shield_glow, shield_dot], "Visible", "on");
            endif
        endif

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
            set([boss_fins, boss_body, boss_stripe, boss_shine, boss_eye], "Visible", "on");
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

        % If the player has a shield, it absorbs the bite: no life is lost, the shield
        % disappears and the player is protected a short time (45 frames)
        if player_hit && invulnerable_frames == 0 && shield_frames > 0
            shield_frames = 0;
            player_hit = false;
            invulnerable_frames = 45;
            shake_frames = max(shake_frames, 6);
            play_sfx(figure_handle, "click");
            banner_frames = 60;
            set(banner_text, "String", "THE SHIELD ABSORBED THE BITE!", "Color", [0.5 0.85 1]);
        endif

        % The player loses a life if touched by a dangerous fish
        if player_hit && invulnerable_frames == 0
            lives = lives - 1;
            combo_count = 0;                                     % a bite breaks the combo
            combo_timer = 0;
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
        % Move the crabs: they walk on the sand (the height follows the dunes),
        % turn around near the edges, and their claws and legs move
        for k = 1:crab_count
            crab_x(k) = crab_x(k) + crab_dir(k) * crab_speed(k);
            if crab_x(k) < 4 || crab_x(k) > 96
                crab_dir(k) = -crab_dir(k);
            endif
            crab_y = 3.6 + 1.2 * sin(crab_x(k) / 7) + 0.6 * sin(crab_x(k) / 3);
            [cbx, cby, ccx, ccy, clx, cly] = crab_shape(crab_x(k), crab_y, crab_size(k), ...
                                                        0.3 * frame_count + 2 * k);
            set(crab_body(k), "XData", cbx, "YData", cby);
            set(crab_claws(k), "XData", ccx, "YData", ccy);
            set(crab_legs(k), "XData", clx, "YData", cly);
            set(crab_eyes(k), "XData", crab_x(k) + crab_size(k) * [-0.4 0.4], ...
                "YData", crab_y + crab_size(k) * [1.0 1.0]);
        endfor
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

        % Move the school of tiny fish and the plankton (decor only):
        %   - the school crosses the sea slowly and comes back on the other side
        %   - each tiny fish wobbles a little so the school looks alive
        %   - the school moves up or down to stay away from the player
        %   - the plankton drifts to the right and goes up and down very slowly
        school_cx = school_cx + school_dir * school_speed;
        if school_dir == 1 && school_cx > world_width + 12
            school_cx = -12;
        elseif school_dir == -1 && school_cx < -12
            school_cx = world_width + 12;
        endif
        if hypot(player_x - school_cx, player_y - school_cy) < 14
            school_cy = min(max(school_cy + 0.4 * sign(school_cy - player_y + 0.01), 10), world_height - 12);
        endif
        set(school_handle, "XData", school_cx + school_dx + 0.8 * sin(0.15 * frame_count + (1:school_count)), ...
            "YData", school_cy + school_dy + 0.5 * cos(0.20 * frame_count + (1:school_count)));
        plankton_x = plankton_x + 0.03;
        plankton_x(plankton_x > world_width) = 0;
        plankton_y = plankton_y + 0.02 * sin(0.05 * frame_count + (1:plankton_count));
        set(plankton_handle, "XData", plankton_x, "YData", plankton_y);

        % Bubble trail behind the swimming fish:
        %   - while the player moves, a new bubble is created behind him every 3 frames
        %   - all the bubbles rise and move a little left and right
        %   - a bubble is removed after 22 frames
        if any(velocity ~= 0) && mod(frame_count, 3) == 0
            trail_x(end + 1)   = player_x - player_dir_x * 0.9 * player_size + 0.3 * (rand - 0.5);
            trail_y(end + 1)   = player_y + 0.3 * player_size * (rand - 0.5);
            trail_age(end + 1) = 0;
        endif
        trail_y   = trail_y + 0.25;
        trail_x   = trail_x + 0.04 * sin(0.5 * frame_count + trail_age);
        trail_age = trail_age + 1;
        trail_alive = trail_age < 22;
        trail_x   = trail_x(trail_alive);
        trail_y   = trail_y(trail_alive);
        trail_age = trail_age(trail_alive);
        set(trail_handle, "XData", trail_x, "YData", trail_y);

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
        [shx, shy] = fish_shine(bx, by, player_x, player_y);
        set(player_shine, "XData", shx, "YData", shy);
        set(player_eye, "XData", ex, "YData", ey, "MarkerSize", max(5, min(10, 2 + player_size)));
        % Blink while the player is protected
        if invulnerable_frames > 0 && mod(frame_count, 6) < 3
            visible_state = "off";
        else
            visible_state = "on";
        endif
        set([player_body, player_fins, player_stripe, player_shine, player_eye], "Visible", visible_state);

        % Shield bubble around the player: a transparent blue ellipse a little bigger
        % than the fish (it follows the player and his size). It counts down and
        % blinks during its last 90 frames, then it disappears.
        if shield_frames > 0
            shield_frames = shield_frames - 1;
            if shield_frames < 90 && mod(shield_frames, 8) < 4
                set(shield_ring, "Visible", "off");
            else
                set(shield_ring, "XData", player_x - player_dir_x * 0.4 * player_size ...
                                          + (1.9 * player_size + 0.6) * cos(shield_angle), ...
                    "YData", player_y + (1.0 * player_size + 0.7) * sin(shield_angle), "Visible", "on");
            endif
        else
            set(shield_ring, "Visible", "off");
        endif

        % Update the graphics of the enemies (only the ones in the sea)
        for i = 1:active_count
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
            [shx, shy] = fish_shine(bx, by, enemy_x(i), enemy_y(i));
            set(enemy_shine(i), "XData", shx, "YData", shy);
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
            [shx, shy] = fish_shine(bx, by, draw_x, draw_y);
            set(boss_shine, "XData", shx, "YData", shy);
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
                 boss_teeth, boss_brow, boss_aura, boss_dark, boss_shine], "Visible", "off");
        endif

        % Update the special green fish, the green shock wave and the green flash
        if special_active
            [bx, by, fx, fy, sx, sy, ex, ey] = fish_shape(special_x, special_y, special_size, special_dir, ...
                                                          0.25 * sin(0.5 * frame_count), 1);
            set(special_body, "XData", bx, "YData", by);
            set(special_fins, "XData", fx, "YData", fy);
            set(special_stripe, "XData", sx, "YData", sy);
            [shx, shy] = fish_shine(bx, by, special_x, special_y);
            set(special_shine, "XData", shx, "YData", shy);
            set(special_eye, "XData", ex, "YData", ey);
            set(special_glow, "XData", special_x, "YData", special_y, ...
                "MarkerSize", 34 + 6 * sin(0.3 * frame_count));
        endif
        if wave_age > 0
            wave_radius = 3 + 2.6 * wave_age;
            set(special_wave, "XData", wave_x + wave_radius * cos(wave_angles), ...
                "YData", wave_y + 0.6 * wave_radius * sin(wave_angles), "Visible", "on");
            wave_age = wave_age + 1;
            if wave_age > 17
                wave_age = 0;
                set(special_wave, "Visible", "off");
            endif
        endif
        if clear_flash_frames > 0
            set(clear_flash, "Visible", "on");
            clear_flash_frames = clear_flash_frames - 1;
        else
            set(clear_flash, "Visible", "off");
        endif

        % Update the bubbles
        set(bubble_small, "XData", bubble_x(1:10), "YData", bubble_y(1:10));
        set(bubble_big, "XData", bubble_x(11:15), "YData", bubble_y(11:15));

        % Update the sparkles and the floating points
        if burst_age > 0
            burst_radius = 1 + 0.6 * burst_age;
            set(burst_handle, "XData", burst_x + burst_radius * burst_ring .* cos(burst_angles), ...
                "YData", burst_y + burst_radius * burst_ring .* sin(burst_angles), "Visible", "on");
            popup_position = get(popup_text, "Position");
            set(popup_text, "Position", [popup_position(1), popup_position(2) + 0.35]);
            burst_age = burst_age + 1;
            if burst_age > 14
                burst_age = 0;
                set(burst_handle, "Visible", "off");
                set(popup_text, "String", "");
            endif
        endif

        % Black copies behind the floating points and the banner (shadow effect)
        popup_position = get(popup_text, "Position");
        set(popup_shadow, "String", get(popup_text, "String"), ...
            "Position", [popup_position(1) + 0.25, popup_position(2) - 0.45]);
        set(banner_shadow, "String", get(banner_text, "String"));

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
        if mission_flash_frames > 0
            set(mission_flash, "Visible", "on", "FaceAlpha", 0.05 + 0.02 * mission_flash_frames);
            mission_flash_frames = mission_flash_frames - 1;
        else
            set(mission_flash, "Visible", "off");
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

        % Update the combo timer and counter, the growth bar and the level tip:
        %   - the combo ends when the timer reaches 0
        %   - the growth bar is recalculated here with the current player size,
        %     so it moves correctly after eating fish or losing size
        %   - the bar becomes golden when the player can eat the boss
        %   - the tip is erased after a few seconds
        if combo_timer > 0
            combo_timer = combo_timer - 1;
            if combo_timer == 0
                combo_count = 0;
            endif
        endif
        if combo_count >= 2
            set(combo_hud, "String", sprintf("COMBO x%d", combo_count));
        else
            set(combo_hud, "String", "");
        endif
        % Update the bonus mission line. Before the reward, it shows the progress;
        % after the reward, it stays as a small golden success message.
        if mission_done
            set(mission_hud, "String", sprintf("MISSION: %s COMPLETE", upper(mission_names{level})), ...
                "Color", [1 0.85 0.2]);
        else
            set(mission_hud, "String", sprintf("MISSION: eat %d/%d fish", ...
                min(fish_eaten, mission_goal), mission_goal), "Color", [0.9 0.95 1]);
        endif
        size_progress = min(max((player_size - start_size) / (boss_win_size - start_size), 0), 1);
        if size_progress >= 1
            growth_color = [1 0.85 0.2];                     % big enough to eat the boss
        else
            growth_color = [0.3 0.9 0.4];
        endif
        growth_x = growth_left + (growth_right - growth_left) * size_progress;
        set(growth_fill, "XData", [growth_left growth_x growth_x growth_left], ...
            "YData", [growth_bottom growth_bottom growth_top growth_top], ...
            "FaceColor", growth_color);
        set(growth_marker, "XData", [growth_x growth_x], "YData", [growth_bottom growth_top]);
        set(growth_percent, "String", sprintf("%d%%", round(100 * size_progress)));
        if size_progress >= 1
            set(growth_text, "String", "READY: EAT THE BOSS!", "Color", [1 0.85 0.2]);
        else
            set(growth_text, "String", "GROWTH TO BOSS SIZE", "Color", [0.85 0.95 1]);
        endif
        % Milestones: a message when the player is 30 percent of the way to the boss
        % size, and another one when the boss is on the screen and the player is
        % close (80 percent) to being big enough. Each message is shown only once
        % and only when no other banner is on the screen.
        if ~milestone_start && size_progress >= 0.3 && banner_frames == 0
            milestone_start = true;
            banner_frames = 70;
            set(banner_text, "String", "GOOD START! KEEP GROWING", "Color", [1 0.9 0.3]);
        endif
        if ~milestone_boss && boss_active && ~boss_edible && size_progress >= 0.8 && banner_frames == 0
            milestone_boss = true;
            banner_frames = 80;
            set(banner_text, "String", "ALMOST BIG ENOUGH TO EAT THE BOSS!", "Color", [0.4 1 0.5]);
        endif
        if tip_frames > 0
            tip_frames = tip_frames - 1;
            if tip_frames == 0
                set([tip_text, tip_shadow], "String", "");
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
    setappdata(figure_handle, "round_stats", [fish_eaten, best_combo, pearls_found, mission_done]);
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

setappdata(figure_handle, "menu_best", best_score);    % the menu shows the best score
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

    % Small statistics of the round (fish eaten, best combo, pearls found,
    % and bonus mission completed or not).
    % play_round saves them with setappdata, here we read them to show them
    % on the end screens. If the round was quit, there are no statistics.
    round_stats = getappdata(figure_handle, "round_stats");
    if isempty(round_stats)
        round_stats = [0 0 0 0];
    endif
    if numel(round_stats) < 4
        round_stats(4) = 0;
    endif
    if round_stats(4)
        mission_text = "Mission: complete";
    else
        mission_text = "Mission: missed";
    endif
    stats_line = sprintf("Fish eaten: %d    Best combo: x%d    Pearls: %d    %s", ...
                         round_stats(1), round_stats(2), round_stats(3), mission_text);

    % End of the level: win, final win, lose or quit screen
    if strcmp(outcome, "win") && level < level_count
        total_score = round_score;                     % the score is kept for the next level
        end_text = {sprintf("Boss defeated! Level %d cleared!", level), "", ...
                    sprintf("Score: %d    Best score: %d", round_score, best_score), stats_line, "", ...
                    sprintf("R = go to level %d (new decor, harder boss)", level + 1), "ESC = quit"};
        end_screen = show_screen(axes_handle, "LEVEL CLEARED!", end_text, [0.1 0.45 0.2]);
        level = level + 1;
    elseif strcmp(outcome, "win")
        end_text = {"You defeated all 5 bosses!", "", ...
                    sprintf("Final score: %d    Best score: %d", round_score, best_score), stats_line, "", ...
                    "R = start a new game", "ESC = quit"};
        end_screen = show_screen(axes_handle, "KING OF THE ABYSS!", end_text, [0.45 0.35 0.05]);
        level = 1;                                     % new game
        total_score = 0;
    elseif strcmp(outcome, "lose")
        end_text = {sprintf("You were eaten on level %d!", level), "", ...
                    sprintf("Score: %d    Best score: %d", round_score, best_score), stats_line, "", ...
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
