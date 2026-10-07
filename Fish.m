1;   % Indique à Octave que c'est un script (et non un fichier de fonction)
more off;

% ======================================================================
%  FISH EAT GETTING BIG - version corrigée pour Octave
% ======================================================================

function key_handler(figure_handle, key_event)
    if isstruct(key_event) && isfield(key_event, "Key")
        setappdata(figure_handle, "last_key", lower(key_event.Key));
    endif
endfunction


function key = wait_for_key(figure_handle, valid_keys)
    key = "";
    setappdata(figure_handle, "last_key", "");
    while isempty(key) && ishandle(figure_handle)
        drawnow;
        pause(0.05);
        if ~ishandle(figure_handle)
            break;
        endif
        candidate = getappdata(figure_handle, "last_key");
        if ischar(candidate) && ~isempty(candidate) && any(strcmp(candidate, valid_keys))
            key = candidate;
        endif
    endwhile
    if ~ishandle(figure_handle)
        key = "escape";
    endif
endfunction


function [body_x, body_y, tail_x, tail_y, eye_x, eye_y] = fish_shape(x, y, fish_size, direction)
    angle_vector = linspace(0, 2*pi, 24);
    body_x = x + fish_size * cos(angle_vector);
    body_y = y + 0.6 * fish_size * sin(angle_vector);
    tail_x = x - direction * [0.8 1.8 1.8] * fish_size;
    tail_y = y + [0 0.7 -0.7] * fish_size;
    eye_x  = x + direction * 0.55 * fish_size;
    eye_y  = y + 0.2 * fish_size;
endfunction


function [x, y, fish_size, direction, speed] = spawn_enemy(player_size, speed_factor, ...
        world_width, world_height, player_x, player_y, initial_placement)
    if rand < 0.65
        fish_size = player_size * (0.45 + 0.45 * rand);
    else
        fish_size = player_size * (1.15 + 0.90 * rand);
    endif
    fish_size = min(max(fish_size, 0.8), 14);
    direction = 2 * (rand > 0.5) - 1;
    speed     = speed_factor * (0.25 + 0.50 * rand);
    y         = 7 + (world_height - 11) * rand;
    if initial_placement
        x = world_width * rand;
        while hypot(x - player_x, y - player_y) < 25
            x = world_width * rand;
            y = 7 + (world_height - 11) * rand;
        endwhile
    else
        if direction == 1
            x = -3 * fish_size;
        else
            x = world_width + 3 * fish_size;
        endif
    endif
endfunction


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


function save_best_score(file_name, best_score)
    file_id = fopen(file_name, "w");
    if file_id ~= -1
        fprintf(file_id, "%d\n", best_score);
        fclose(file_id);
    endif
endfunction


function draw_sea_background(axes_handle)
    cla(axes_handle);
    set(axes_handle, "XLim", [0 100], "YLim", [0 60], ...
        "XLimMode", "manual", "YLimMode", "manual");
    patch("XData", [0 100 100 0], "YData", [0 0 5 5], "FaceColor", [0.93 0.85 0.55], ...
          "EdgeColor", "none", "Parent", axes_handle);
    seaweed_positions = [8 27 62 88];
    for k = 1:numel(seaweed_positions)
        seaweed_y = linspace(4, 14 + 3 * k, 25);
        seaweed_x = seaweed_positions(k) + 1.5 * sin(linspace(0, 3 * pi, 25));
        line("XData", seaweed_x, "YData", seaweed_y, "Color", [0.1 0.55 0.25], ...
             "LineWidth", 3, "Parent", axes_handle);
    endfor
endfunction


function screen_handles = show_screen(axes_handle, text_lines, panel_color)
    panel = patch("XData", [10 90 90 10], "YData", [6 6 54 54], "FaceColor", panel_color, ...
                  "EdgeColor", [1 1 1], "LineWidth", 2, "Parent", axes_handle);
    message = text(50, 30, text_lines, "HorizontalAlignment", "center", ...
                   "VerticalAlignment", "middle", "FontSize", 14, ...
                   "Color", [1 1 1], "Parent", axes_handle);
    screen_handles = [panel, message];
    drawnow;
endfunction


function [outcome, final_score] = play_round(figure_handle, axes_handle, level, best_score)
    world_width     = 100;
    world_height    = 60;
    start_size      = 2;
    win_size        = 10;
    growth_ratio    = 0.30;
    initial_lives   = 3;
    base_speed      = 1.2;
    frame_pause     = 0.03;
    size_tolerance  = 1.05;
    enemy_count     = 7 + level;
    speed_factor    = 1 + 0.15 * (level - 1);

    player_x     = world_width / 2;
    player_y     = world_height / 2;
    player_size  = start_size;
    player_dir_x = 1;
    velocity     = [0 0];
    lives        = initial_lives;
    score        = 0;
    invulnerable_frames = 0;
    frame_count  = 0;
    outcome      = "playing";
    final_score  = 0;

    draw_sea_background(axes_handle);
    bubble_x = world_width * rand(1, 15);
    bubble_y = world_height * rand(1, 15);
    bubble_handle = line("XData", bubble_x, "YData", bubble_y, "LineStyle", "none", ...
                         "Marker", "o", "MarkerSize", 4, "Color", [1 1 1], ...
                         "Parent", axes_handle);

    [bx, by, tx, ty, ex, ey] = fish_shape(player_x, player_y, player_size, player_dir_x);
    player_tail = patch("XData", tx, "YData", ty, "FaceColor", [1 0.45 0.05], ...
                        "EdgeColor", [0.4 0.2 0], "Parent", axes_handle);
    player_body = patch("XData", bx, "YData", by, "FaceColor", [1 0.65 0.1], ...
                        "EdgeColor", [0.4 0.2 0], "LineWidth", 1.5, "Parent", axes_handle);
    player_eye  = line("XData", ex, "YData", ey, "LineStyle", "none", "Marker", "o", ...
                       "MarkerSize", 4, "MarkerFaceColor", "k", "Color", "k", ...
                       "Parent", axes_handle);

    enemy_x     = zeros(1, enemy_count);
    enemy_y     = zeros(1, enemy_count);
    enemy_size  = zeros(1, enemy_count);
    enemy_dir   = zeros(1, enemy_count);
    enemy_speed = zeros(1, enemy_count);
    enemy_body  = zeros(1, enemy_count);
    enemy_tail  = zeros(1, enemy_count);
    enemy_eye   = zeros(1, enemy_count);
    for i = 1:enemy_count
        [enemy_x(i), enemy_y(i), enemy_size(i), enemy_dir(i), enemy_speed(i)] = ...
            spawn_enemy(player_size, speed_factor, world_width, world_height, ...
                        player_x, player_y, true);
        [bx, by, tx, ty, ex, ey] = fish_shape(enemy_x(i), enemy_y(i), enemy_size(i), enemy_dir(i));
        enemy_tail(i) = patch("XData", tx, "YData", ty, "FaceColor", [0.5 0.5 0.5], ...
                              "EdgeColor", [0.2 0.2 0.2], "Parent", axes_handle);
        enemy_body(i) = patch("XData", bx, "YData", by, "FaceColor", [0.5 0.5 0.5], ...
                              "EdgeColor", [0.2 0.2 0.2], "Parent", axes_handle);
        enemy_eye(i)  = line("XData", ex, "YData", ey, "LineStyle", "none", "Marker", "o", ...
                             "MarkerSize", 3, "MarkerFaceColor", "k", "Color", "k", ...
                             "Parent", axes_handle);
    endfor

    hud_text = text(2, 58.5, "", "Parent", axes_handle, "FontSize", 12, ...
                    "FontWeight", "bold", "Color", [1 1 1], ...
                    "VerticalAlignment", "top");
    patch("XData", [70 98 98 70], "YData", [55 55 58 58], "FaceColor", [0.2 0.3 0.4], ...
          "EdgeColor", [1 1 1], "Parent", axes_handle);
    progress_bar = patch("XData", [70 70 70 70], "YData", [55 55 58 58], ...
                         "FaceColor", [1 0.8 0.1], "EdgeColor", "none", "Parent", axes_handle);

    setappdata(figure_handle, "last_key", "");

    while strcmp(outcome, "playing")
        if ~ishandle(figure_handle)
            outcome = "quit";
            final_score = score;
            return;
        endif
        frame_count = frame_count + 1;

        key = getappdata(figure_handle, "last_key");
        setappdata(figure_handle, "last_key", "");
        if ~ischar(key)
            key = "";
        endif
        switch key
            case {"leftarrow", "left", "q", "a"}
                velocity = [-1 0];
            case {"rightarrow", "right", "d"}
                velocity = [1 0];
            case {"uparrow", "up", "z", "w"}
                velocity = [0 1];
            case {"downarrow", "down", "s"}
                velocity = [0 -1];
            case "space"
                velocity = [0 0];
            case "escape"
                outcome = "quit";
        endswitch

        player_speed = base_speed / (1 + 0.04 * player_size);
        player_x = player_x + velocity(1) * player_speed;
        player_y = player_y + velocity(2) * player_speed;
        player_x = min(max(player_x, 0), world_width);
        player_y = min(max(player_y, 6), world_height - 6);
        if velocity(1) ~= 0
            player_dir_x = velocity(1);
        endif
        if invulnerable_frames > 0
            invulnerable_frames = invulnerable_frames - 1;
        endif

        for i = 1:enemy_count
            enemy_x(i) = enemy_x(i) + enemy_dir(i) * enemy_speed(i);
            enemy_y(i) = enemy_y(i) + 0.12 * sin(0.1 * frame_count + i);
            left_screen = (enemy_dir(i) == 1  && enemy_x(i) > world_width + 4 * enemy_size(i)) || ...
                          (enemy_dir(i) == -1 && enemy_x(i) < -4 * enemy_size(i));
            if left_screen
                [enemy_x(i), enemy_y(i), enemy_size(i), enemy_dir(i), enemy_speed(i)] = ...
                    spawn_enemy(player_size, speed_factor, world_width, world_height, ...
                                player_x, player_y, false);
            endif
            size_sum = player_size + enemy_size(i);
            dx = (player_x - enemy_x(i)) / size_sum;
            dy = (player_y - enemy_y(i)) / (0.6 * size_sum);
            if dx^2 + dy^2 < 0.5
                if player_size > enemy_size(i) * size_tolerance
                    score = score + round(10 * enemy_size(i));
                    player_size = player_size + growth_ratio * enemy_size(i);
                    [enemy_x(i), enemy_y(i), enemy_size(i), enemy_dir(i), enemy_speed(i)] = ...
                        spawn_enemy(player_size, speed_factor, world_width, world_height, ...
                                    player_x, player_y, false);
                elseif enemy_size(i) > player_size * size_tolerance
                    if invulnerable_frames == 0
                        lives = lives - 1;
                        invulnerable_frames = 50;
                        player_x = world_width / 2;
                        player_y = world_height / 2;
                        velocity = [0 0];
                    endif
                else
                    player_x = player_x - 2 * sign(enemy_x(i) - player_x);
                endif
            endif
        endfor

        bubble_y = bubble_y + 0.3;
        bubble_y(bubble_y > world_height) = 0;

        [bx, by, tx, ty, ex, ey] = fish_shape(player_x, player_y, player_size, player_dir_x);
        set(player_body, "XData", bx, "YData", by);
        set(player_tail, "XData", tx, "YData", ty);
        set(player_eye, "XData", ex, "YData", ey);

        if invulnerable_frames > 0 && mod(frame_count, 6) < 3
            visible_state = "off";
        else
            visible_state = "on";
        endif
        set([player_body, player_tail, player_eye], "Visible", visible_state);

        for i = 1:enemy_count
            [bx, by, tx, ty, ex, ey] = fish_shape(enemy_x(i), enemy_y(i), enemy_size(i), enemy_dir(i));
            if player_size > enemy_size(i) * size_tolerance
                fish_color = [0.30 0.80 0.40];
            elseif enemy_size(i) > player_size * size_tolerance
                fish_color = [0.90 0.25 0.20];
            else
                fish_color = [0.95 0.90 0.30];
            endif
            set(enemy_body(i), "XData", bx, "YData", by, "FaceColor", fish_color);
            set(enemy_tail(i), "XData", tx, "YData", ty, "FaceColor", 0.8 * fish_color);
            set(enemy_eye(i), "XData", ex, "YData", ey);
        endfor

        set(bubble_handle, "YData", bubble_y);
        progress_ratio = min(player_size / win_size, 1);
        bar_end = 70 + 28 * progress_ratio;
        set(progress_bar, "XData", [70 bar_end bar_end 70]);
        set(hud_text, "String", sprintf("Level %d   Score %d   Lives %d   Best %d", ...
                                        level, score, lives, max(best_score, score)));
        drawnow;
        pause(frame_pause);

        if strcmp(outcome, "quit")
            break;
        endif
        if player_size >= win_size
            outcome = "win";
            score = score + 100 * lives;
        elseif lives <= 0
            outcome = "lose";
        endif
    endwhile
    final_score = score;
endfunction




%
best_score_file = "fish_best_score.txt";
level           = 1;
best_score      = load_best_score(best_score_file);
keep_playing    = true;

close all;
try
    graphics_toolkit("qt");
catch
    try
        graphics_toolkit("fltk");
    catch
    end_try_catch
end_try_catch

figure_handle = figure("Name", "Fish Eat Getting Big", "NumberTitle", "off", ...
                       "Color", [0.05 0.2 0.35], "Resize", "on", ...
                       "KeyPressFcn", @key_handler);
axes_handle = axes("Parent", figure_handle, "Position", [0 0 1 1], ...
                   "XLim", [0 100], "YLim", [0 60], ...
                   "XLimMode", "manual", "YLimMode", "manual", ...
                   "XTick", [], "YTick", [], "Color", [0.45 0.75 0.95], ...
                   "Box", "on", "NextPlot", "add");

draw_sea_background(axes_handle);
rules_text = {"FISH", "", ...
              "Goal: eat smaller fish to grow up to size 10.", ...
              "Green fish: you can eat them.   Red fish: they can eat you!", ...
              "Yellow fish: same size, you just bump.", ...
              "You have 3 lives. Each new level adds faster fish.", "", ...
              "Move: arrow keys or Z Q S D / W A S D (SPACE = stop)", ...
              "ESC = quit", "", "Press SPACE to start"};
start_screen = show_screen(axes_handle, rules_text, [0.05 0.25 0.45]);
key = wait_for_key(figure_handle, {"space", "escape"});
if ishandle(figure_handle)
    delete(start_screen);
endif
if strcmp(key, "escape")
    keep_playing = false;
endif

while keep_playing && ishandle(figure_handle)
    [outcome, round_score] = play_round(figure_handle, axes_handle, level, best_score);
    if ~ishandle(figure_handle)
        break;
    endif

    if round_score > best_score
        best_score = round_score;
        save_best_score(best_score_file, best_score);
    endif

    if strcmp(outcome, "win")
        end_text = {sprintf("YOU WIN! Level %d cleared!", level), "", ...
                    sprintf("Score: %d    Best score: %d", round_score, best_score), "", ...
                    "R = next level (faster fish)", "ESC = quit"};
        end_screen = show_screen(axes_handle, end_text, [0.1 0.45 0.2]);
        level = level + 1;
    elseif strcmp(outcome, "lose")
        end_text = {"GAME OVER - you were eaten!", "", ...
                    sprintf("Score: %d    Best score: %d", round_score, best_score), "", ...
                    "R = replay this level (new random fish)", "ESC = quit"};
        end_screen = show_screen(axes_handle, end_text, [0.55 0.15 0.15]);
    else
        break;
    endif

    key = wait_for_key(figure_handle, {"r", "escape"});
    if strcmp(key, "escape")
        keep_playing = false;
    endif
endwhile

if ishandle(figure_handle)
    draw_sea_background(axes_handle);
    bye_screen = show_screen(axes_handle, {"Thanks for playing!", "", ...
                             sprintf("Best score: %d", best_score)}, [0.05 0.25 0.45]);
    pause(1.5);
    close(figure_handle);
endif
