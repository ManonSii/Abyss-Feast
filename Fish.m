1;

function key_handler(figure_handle, key_event)
    if isfield(key_event, "Key")
        setappdata(figure_handle, "last_key", lower(key_event.Key));
    endif
endfunction

function key = wait_for_key(figure_handle, valid_keys)
    key = "";
    setappdata(figure_handle, "last_key", "");
    while isempty(key) && ishandle(figure_handle)
        pause(0.05);
        candidate = getappdata(figure_handle, "last_key");
        if ismember(candidate, valid_keys)
            key = candidate;
        endif
    endwhile
    if ~ishandle(figure_handle)
        key = "escape";
    endif
endfunction

function [body_x, body_y, fins_x, fins_y, stripe_x, stripe_y, eye_x, eye_y] = ...
        fish_shape(x, y, fish_size, direction, wiggle)
    angle_vector = linspace(0, 2*pi, 28);
    body_x = x + fish_size * cos(angle_vector);
    body_y = y + 0.6 * fish_size * sin(angle_vector);
    fins_unit_x = [-0.8 -0.40 -0.10; -1.8 -0.55 -0.30; -1.8 0.20 0.25];
    fins_unit_y = [ 0.0  0.50 -0.50;  0.7  1.00 -0.95; -0.7 0.55 -0.50];
    fins_x = x + direction * fish_size * fins_unit_x;
    fins_y = y + fish_size * fins_unit_y;
    fins_y(2:3, 1) = fins_y(2:3, 1) + fish_size * wiggle;
    u_start = 0.05;
    u_end   = 0.30;
    stripe_x = x + direction * fish_size * [u_start u_end u_end u_start];
    stripe_y = y + 0.6 * fish_size * [sqrt(1 - u_start^2) sqrt(1 - u_end^2) ...
                                      -sqrt(1 - u_end^2) -sqrt(1 - u_start^2)];
    eye_x = x + direction * 0.55 * fish_size;
    eye_y = y + 0.2 * fish_size;
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
    y         = 7 + (world_height - 18) * rand;
    if initial_placement
        x = world_width * rand;
        while hypot(x - player_x, y - player_y) < 25
            x = world_width * rand;
            y = 7 + (world_height - 18) * rand;
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

function update_seaweed(seaweed_handles, seaweed_base_x, seaweed_top_y, frame_count)
    for k = 1:numel(seaweed_handles)
        seaweed_y = linspace(3.5, seaweed_top_y(k), 20);
        height_ratio = (seaweed_y - 3.5) / (seaweed_top_y(k) - 3.5);
        seaweed_x = seaweed_base_x(k) + 2.0 * height_ratio ...
                    .* sin(0.12 * frame_count + 3 * height_ratio + k);
        set(seaweed_handles(k), "XData", seaweed_x, "YData", seaweed_y);
    endfor
endfunction

function [seaweed_handles, seaweed_base_x, seaweed_top_y] = draw_sea_background(axes_handle)
    cla(axes_handle);

    band_count    = 24;
    deep_color    = [0.02 0.15 0.35];
    surface_color = [0.30 0.72 0.95];
    for band = 1:band_count
        mix = (band - 1) / (band_count - 1);
        band_color = deep_color + mix * (surface_color - deep_color);
        y_low  = 60 * (band - 1) / band_count;
        y_high = 60 * band / band_count;
        patch("XData", [0 100 100 0], "YData", [y_low y_low y_high y_high], ...
              "FaceColor", band_color, "EdgeColor", "none", "Parent", axes_handle);
    endfor

    ray_start_x = [12 38 64 86];
    for k = 1:numel(ray_start_x)
        patch("XData", [ray_start_x(k) ray_start_x(k)+8 ray_start_x(k)+23 ray_start_x(k)+12], ...
              "YData", [60 60 5 5], "FaceColor", [1 1 1], "FaceAlpha", 0.07, ...
              "EdgeColor", "none", "Parent", axes_handle);
    endfor

    dune_x = linspace(0, 100, 80);
    dune_y = 3.5 + 1.2 * sin(dune_x / 7) + 0.6 * sin(dune_x / 3);
    patch("XData", [dune_x 100 0], "YData", [dune_y 0 0], "FaceColor", [0.90 0.80 0.50], ...
          "EdgeColor", [0.75 0.65 0.35], "Parent", axes_handle);

    rock_angle = linspace(0, pi, 20);
    rock_centers = [18 47 78];
    rock_widths  = [4 6 3.5];
    rock_heights = [2.5 3.5 2];
    for k = 1:numel(rock_centers)
        patch("XData", rock_centers(k) + rock_widths(k) * cos(rock_angle), ...
              "YData", 3 + rock_heights(k) * sin(rock_angle), "FaceColor", [0.45 0.47 0.52], ...
              "EdgeColor", [0.25 0.27 0.30], "Parent", axes_handle);
    endfor

    line("XData", [38 38 36 38 40], "YData", [4 8 11 8 11], "Color", [0.95 0.40 0.55], ...
         "LineWidth", 4, "Parent", axes_handle);
    line("XData", [72 72 70 72 74], "YData", [4 7 10 7 10], "Color", [1.00 0.55 0.25], ...
         "LineWidth", 4, "Parent", axes_handle);
    line("XData", [95 95 93], "YData", [4 8 10], "Color", [0.95 0.40 0.55], ...
         "LineWidth", 4, "Parent", axes_handle);

    seaweed_base_x = [6 22 30 58 66 90];
    seaweed_top_y  = [16 20 14 22 15 19];
    seaweed_handles = zeros(1, numel(seaweed_base_x));
    for k = 1:numel(seaweed_base_x)
        seaweed_handles(k) = line("XData", seaweed_base_x(k) * ones(1, 20), ...
                                  "YData", linspace(3.5, seaweed_top_y(k), 20), ...
                                  "Color", [0.05 0.45 + 0.08 * mod(k, 3) 0.20], ...
                                  "LineWidth", 3, "Parent", axes_handle);
    endfor
    update_seaweed(seaweed_handles, seaweed_base_x, seaweed_top_y, 0);
endfunction

function screen_handles = show_screen(axes_handle, title_text, text_lines, panel_color)
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

function [outcome, final_score] = play_round(figure_handle, axes_handle, level, best_score)
    world_width     = 100;
    world_height    = 60;
    start_size      = 2;
    win_size        = 10;
    growth_ratio    = 0.30;
    initial_lives   = 3;
    base_speed      = 1.2;
    frame_pause     = 0.02;
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

    burst_age     = 0;
    burst_x       = 0;
    burst_y       = 0;
    burst_angles  = linspace(0, 2*pi, 9)(1:8);
    hit_flash_frames = 0;

    [seaweed_handles, seaweed_base_x, seaweed_top_y] = draw_sea_background(axes_handle);

    sil_count = 3;
    sil_x     = world_width * rand(1, sil_count);
    sil_y     = 18 + 25 * rand(1, sil_count);
    sil_size  = 3 + 3 * rand(1, sil_count);
    sil_dir   = [1 -1 1];
    sil_speed = 0.08 + 0.10 * rand(1, sil_count);
    sil_body  = zeros(1, sil_count);
    sil_fins  = zeros(1, sil_count);
    for i = 1:sil_count
        [bx, by, fx, fy] = fish_shape(sil_x(i), sil_y(i), sil_size(i), sil_dir(i), 0);
        sil_fins(i) = patch("XData", fx, "YData", fy, "FaceColor", [0.08 0.30 0.50], ...
                            "EdgeColor", "none", "Parent", axes_handle);
        sil_body(i) = patch("XData", bx, "YData", by, "FaceColor", [0.08 0.30 0.50], ...
                            "EdgeColor", "none", "Parent", axes_handle);
    endfor

    bubble_x = world_width * rand(1, 15);
    bubble_y = world_height * rand(1, 15);
    bubble_rise = [0.25 * ones(1, 10), 0.40 * ones(1, 5)];
    bubble_small = line("XData", bubble_x(1:10), "YData", bubble_y(1:10), "LineStyle", "none", ...
                        "Marker", "o", "MarkerSize", 3, "Color", [0.9 0.97 1], ...
                        "Parent", axes_handle);
    bubble_big = line("XData", bubble_x(11:15), "YData", bubble_y(11:15), "LineStyle", "none", ...
                      "Marker", "o", "MarkerSize", 7, "Color", [0.9 0.97 1], ...
                      "Parent", axes_handle);

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

    enemy_x      = zeros(1, enemy_count);
    enemy_y      = zeros(1, enemy_count);
    enemy_size   = zeros(1, enemy_count);
    enemy_dir    = zeros(1, enemy_count);
    enemy_speed  = zeros(1, enemy_count);
    enemy_body   = zeros(1, enemy_count);
    enemy_fins   = zeros(1, enemy_count);
    enemy_stripe = zeros(1, enemy_count);
    enemy_eye    = zeros(1, enemy_count);
    for i = 1:enemy_count
        [enemy_x(i), enemy_y(i), enemy_size(i), enemy_dir(i), enemy_speed(i)] = ...
            spawn_enemy(player_size, speed_factor, world_width, world_height, ...
                        player_x, player_y, true);
        [bx, by, fx, fy, sx, sy, ex, ey] = fish_shape(enemy_x(i), enemy_y(i), ...
                                                      enemy_size(i), enemy_dir(i), 0);
        enemy_fins(i)   = patch("XData", fx, "YData", fy, "FaceColor", [0.5 0.5 0.5], ...
                                "EdgeColor", [0.15 0.15 0.15], "Parent", axes_handle);
        enemy_body(i)   = patch("XData", bx, "YData", by, "FaceColor", [0.5 0.5 0.5], ...
                                "EdgeColor", [0.15 0.15 0.15], "Parent", axes_handle);
        enemy_stripe(i) = patch("XData", sx, "YData", sy, "FaceColor", [0.4 0.4 0.4], ...
                                "EdgeColor", "none", "Parent", axes_handle);
        enemy_eye(i)    = line("XData", ex, "YData", ey, "LineStyle", "none", "Marker", "o", ...
                               "MarkerSize", 4, "MarkerFaceColor", [1 1 1], "Color", [0 0 0], ...
                               "Parent", axes_handle);
    endfor

    burst_handle = line("XData", zeros(1, 8), "YData", zeros(1, 8), "LineStyle", "none", ...
                        "Marker", ".", "MarkerSize", 14, "Color", [1 0.95 0.4], ...
                        "Visible", "off", "Parent", axes_handle);
    popup_text = text(0, 0, "", "HorizontalAlignment", "center", "FontUnits", "normalized", ...
                      "FontSize", 0.045, "FontWeight", "bold", "Color", [1 1 0.4], ...
                      "Parent", axes_handle);

    patch("XData", [0 100 100 0], "YData", [54 54 60 60], "FaceColor", [0 0.05 0.15], ...
          "FaceAlpha", 0.6, "EdgeColor", "none", "Parent", axes_handle);
    life_body = zeros(1, initial_lives);
    life_fins = zeros(1, initial_lives);
    for k = 1:initial_lives
        [bx, by, fx, fy] = fish_shape(4 + 7 * (k - 1), 57, 1.2, 1, 0);
        life_fins(k) = patch("XData", fx, "YData", fy, "FaceColor", [0.85 0.35 0.05], ...
                             "EdgeColor", "none", "Parent", axes_handle);
        life_body(k) = patch("XData", bx, "YData", by, "FaceColor", [1 0.65 0.1], ...
                             "EdgeColor", [0.4 0.2 0], "Parent", axes_handle);
    endfor
    hud_text = text(26, 57, "", "Parent", axes_handle, "FontUnits", "normalized", ...
                    "FontSize", 0.032, "FontWeight", "bold", "Color", [1 1 1], ...
                    "VerticalAlignment", "middle");
    text(68, 57, "Size", "Parent", axes_handle, "FontUnits", "normalized", ...
         "FontSize", 0.03, "Color", [1 1 1], "HorizontalAlignment", "right", ...
         "VerticalAlignment", "middle");
    patch("XData", [70 98 98 70], "YData", [55.2 55.2 58.8 58.8], "FaceColor", [0.2 0.3 0.4], ...
          "EdgeColor", [1 1 1], "Parent", axes_handle);
    progress_bar = patch("XData", [70 70 70 70], "YData", [55.2 55.2 58.8 58.8], ...
                         "FaceColor", [1 0.8 0.1], "EdgeColor", "none", "Parent", axes_handle);

    hit_flash = patch("XData", [0 100 100 0], "YData", [0 0 60 60], "FaceColor", [1 0 0], ...
                      "FaceAlpha", 0.30, "EdgeColor", "none", "Visible", "off", ...
                      "Parent", axes_handle);

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
            case "escape"
                outcome = "quit";
        endswitch

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
                    points = round(10 * enemy_size(i));
                    score = score + points;
                    player_size = player_size + growth_ratio * enemy_size(i);
                    burst_x = enemy_x(i);
                    burst_y = enemy_y(i);
                    burst_age = 1;
                    set(popup_text, "String", sprintf("+%d", points), "Position", [burst_x, burst_y + 2]);
                    [enemy_x(i), enemy_y(i), enemy_size(i), enemy_dir(i), enemy_speed(i)] = ...
                        spawn_enemy(player_size, speed_factor, world_width, world_height, ...
                                    player_x, player_y, false);
                elseif enemy_size(i) > player_size * size_tolerance
                    if invulnerable_frames == 0
                        lives = lives - 1;
                        invulnerable_frames = 50;
                        hit_flash_frames = 6;
                        player_x = world_width / 2;
                        player_y = world_height / 2;
                        velocity = [0 0];
                    endif
                else
                    player_x = player_x - 2 * sign(enemy_x(i) - player_x);
                endif
            endif
        endfor

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
                                          0.2 * sin(0.2 * frame_count + i));
            set(sil_body(i), "XData", bx, "YData", by);
            set(sil_fins(i), "XData", fx, "YData", fy);
        endfor

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
        if invulnerable_frames > 0 && mod(frame_count, 6) < 3
            visible_state = "off";
        else
            visible_state = "on";
        endif
        set([player_body, player_fins, player_stripe, player_eye], "Visible", visible_state);

        for i = 1:enemy_count
            [bx, by, fx, fy, sx, sy, ex, ey] = fish_shape(enemy_x(i), enemy_y(i), enemy_size(i), ...
                                                          enemy_dir(i), 0.25 * sin(0.5 * frame_count + i));
            if player_size > enemy_size(i) * size_tolerance
                fish_color = [0.30 0.80 0.40];
            elseif enemy_size(i) > player_size * size_tolerance
                fish_color = [0.90 0.25 0.20];
            else
                fish_color = [0.95 0.90 0.30];
            endif
            set(enemy_body(i), "XData", bx, "YData", by, "FaceColor", fish_color);
            set(enemy_fins(i), "XData", fx, "YData", fy, "FaceColor", 0.7 * fish_color);
            set(enemy_stripe(i), "XData", sx, "YData", sy, "FaceColor", 0.75 * fish_color);
            set(enemy_eye(i), "XData", ex, "YData", ey);
        endfor

        set(bubble_small, "XData", bubble_x(1:10), "YData", bubble_y(1:10));
        set(bubble_big, "XData", bubble_x(11:15), "YData", bubble_y(11:15));

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

        if hit_flash_frames > 0
            set(hit_flash, "Visible", "on");
            hit_flash_frames = hit_flash_frames - 1;
        else
            set(hit_flash, "Visible", "off");
        endif

        for k = 1:initial_lives
            if k <= lives
                set([life_body(k), life_fins(k)], "Visible", "on");
            else
                set([life_body(k), life_fins(k)], "Visible", "off");
            endif
        endfor
        progress_ratio = min(player_size / win_size, 1);
        set(progress_bar, "XData", [70 70 + 28 * progress_ratio 70 + 28 * progress_ratio 70]);
        set(hud_text, "String", sprintf("Lv %d   Score %d   Best %d", level, score, ...
                                        max(best_score, score)));
        drawnow;
        pause(frame_pause);

        if player_size >= win_size
            outcome = "win";
            score = score + 100 * lives;
        elseif lives <= 0
            outcome = "lose";
        endif
    endwhile
    final_score = score;
endfunction

best_score_file = "fish_best_score.txt";
level           = 1;
best_score      = load_best_score(best_score_file);
keep_playing    = true;

close all;
figure_handle = figure("Name", "FISH", "NumberTitle", "off", ...
                       "Color", [0.05 0.2 0.35], "Resize", "on", ...
                       "KeyPressFcn", @key_handler);
axes_handle = axes("Parent", figure_handle, "Position", [0 0 1 1], "XLim", [0 100], ...
                   "YLim", [0 60], "XTick", [], "YTick", [], "Color", [0.45 0.75 0.95], ...
                   "Box", "on");
hold(axes_handle, "on");

draw_sea_background(axes_handle);
rules_text = {"Goal: eat smaller fish to grow up to size 10.", ...
              "Green fish: you can eat them.   Red fish: they can eat you!", ...
              "Yellow fish: same size, you just bump.", ...
              "You have 3 lives. Each new level adds faster fish.", "", ...
              "Move: arrow keys or Z Q S D / W A S D (SPACE = stop)", ...
              "ESC = quit", "", "Press SPACE to start"};
start_screen = show_screen(axes_handle, "FISH", rules_text, [0.05 0.25 0.45]);
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
        end_text = {sprintf("Level %d cleared!", level), "", ...
                    sprintf("Score: %d    Best score: %d", round_score, best_score), "", ...
                    "R = next level (faster fish)", "ESC = quit"};
        end_screen = show_screen(axes_handle, "YOU WIN!", end_text, [0.1 0.45 0.2]);
        level = level + 1;
    elseif strcmp(outcome, "lose")
        end_text = {"You were eaten!", "", ...
                    sprintf("Score: %d    Best score: %d", round_score, best_score), "", ...
                    "R = replay this level (new random fish)", "ESC = quit"};
        end_screen = show_screen(axes_handle, "GAME OVER", end_text, [0.55 0.15 0.15]);
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
    bye_screen = show_screen(axes_handle, "THANKS FOR PLAYING", ...
                             {sprintf("Best score: %d", best_score)}, [0.05 0.25 0.45]);
    pause(1.5);
    close(figure_handle);
endif
