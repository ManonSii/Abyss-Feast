# Tamagochi-Game
1; % marks this file as a script (functions are defined before the main code)
%% ======================================================================
% HEADER
% Name of program : tamagotchi_VF.m
% Authors         : <Name 1> (main loop), <Name 2> (functions) ...  <- TO FILL
% Date            : 01/10/2026 (format dd/mm/yyyy)
% Octave version  : <your version, e.g. 9.2.0>   Code version: 1.0
% Sources         : no external AI/sound/image/word list used (only basic
%                   Octave graphics). <-- UPDATE if you use something else
%
% CONTEXT : small virtual pet game (Tamagotchi) made for the Octave course.
% GOAL    : keep your pet alive until it is 90 seconds old.
%
% GAME COMPONENTS (on screen):
%   - the pet (a coloured circle with eyes, face changes with its mood)
%   - 4 bars : hunger, happiness, energy, hygiene (0 to 100)
%   - a text line with age + short help of the keys
%
% VARIABLES (struct "pet"):
%   hunger, happiness, energy, hygiene : 0-100 (position/size of the bars)
%   age      : seconds survived     sleeping : true/false
%   body_color : random RGB colour of the pet (changes at each replay)
%
% MAIN LOOP (one trial = one game): every second the 4 values decrease.
%   The player acts with the keyboard to refill them.
% ACROSS TRIALS: pet is reset with random start values, screen cleared,
%   the result is saved in tamagotchi_scores.txt.
%
% RULES / WAYS TO MOVE (keys):
%   f = feed      (+25 hunger, -5 hygiene; too much food makes pet sad)
%   p = play      (+20 happiness, -10 energy, -5 hunger; needs energy)
%   s = sleep/wake (asleep: energy goes up, hunger goes down slower)
%   c = clean     (+40 hygiene)
%   q = quit the program
% WIN  : age reaches 90 s.  (GREAT win if mean of the bars > 60)
% LOSE : one bar reaches 0 (pet is dead).
% ======================================================================

%% ---------------------------- FUNCTIONS -------------------------------

function on_key_press(~, event)
  % Callback: store the last key pressed by the player
  global last_key
  last_key = event.Key;
endfunction

function pet = init_pet()
  % Create a pet with random start values (so each replay is different)
  pet.hunger     = 50 + randi(30);   % random between 51 and 80
  pet.happiness  = 50 + randi(30);
  pet.energy     = 50 + randi(30);
  pet.hygiene    = 50 + randi(30);
  pet.age        = 0;                % seconds survived
  pet.sleeping   = false;            % is the pet asleep?
  pet.body_color = rand(1, 3) * 0.7 + 0.3;  % random but not too dark
endfunction

function pet = apply_action(pet, key)
  % Change the pet's values according to the key pressed by the player
  switch key
    case 'f'                                   % feed
      pet.hunger  = pet.hunger + 25;
      pet.hygiene = pet.hygiene - 5;
      if pet.hunger > 100                      % hazard: overfeeding
        pet.hunger    = 100;
        pet.happiness = pet.happiness - 10;
      endif
    case 'p'                                   % play
      if pet.energy > 10 && !pet.sleeping      % too tired -> refuses
        pet.happiness = min(100, pet.happiness + 20);
        pet.energy    = pet.energy - 10;
        pet.hunger    = pet.hunger - 5;
      endif
    case 's'                                   % sleep / wake up
      pet.sleeping = !pet.sleeping;
    case 'c'                                   % clean
      pet.hygiene = min(100, pet.hygiene + 40);
  endswitch
endfunction

function pet = update_pet(pet)
  % Called once per second: natural decrease of the values
  pet.age = pet.age + 1;
  if pet.sleeping
    pet.energy    = min(100, pet.energy + 6);  % rests
    pet.hunger    = pet.hunger - 1;
    pet.happiness = pet.happiness - 0.5;
    pet.hygiene   = pet.hygiene - 0.5;
  else
    pet.energy    = pet.energy - 1;
    pet.hunger    = pet.hunger - 2;
    pet.happiness = pet.happiness - 1.5;
    pet.hygiene   = pet.hygiene - 1;
  endif
endfunction

function draw_screen(pet, message)
  % Redraw everything: pet, bars and texts (axes use 0-100 coordinates,
  % so the figure can be resized freely)
  cla;
  hold on;
  names  = {'Hunger', 'Happiness', 'Energy', 'Hygiene'};
  values = [pet.hunger, pet.happiness, pet.energy, pet.hygiene];
  for i = 1:4                                  % one bar per need
    y = 95 - 8 * i;
    bar_color = [1 - values(i)/100, values(i)/100, 0.2];  % red -> green
    rectangle('Position', [20 y 60 4], 'FaceColor', [0.9 0.9 0.9]);
    rectangle('Position', [20 y max(values(i), 0.1) * 0.6 4], ...
              'FaceColor', bar_color);
    text(2, y + 2, names{i});
  endfor
  % the pet: body (circle) + eyes + mouth depending on mood
  rectangle('Position', [35 25 30 30], 'Curvature', [1 1], ...
            'FaceColor', pet.body_color);
  mood = mean(values);
  if pet.sleeping                              % eyes closed
    plot([42 46], [43 43], 'k', 'LineWidth', 2);
    plot([54 58], [43 43], 'k', 'LineWidth', 2);
  else                                         % eyes open
    plot([44 56], [43 43], 'ko', 'MarkerFaceColor', 'k');
  endif
  if mood > 50
    plot([43 50 57], [35 31 35], 'k', 'LineWidth', 2);   % smile
  else
    plot([43 50 57], [31 35 31], 'k', 'LineWidth', 2);   % sad
  endif
  text(2, 12, sprintf('Age: %d / 90 s', pet.age));
  text(2, 6, 'f=feed  p=play  s=sleep  c=clean  q=quit');
  text(50, 62, message, 'HorizontalAlignment', 'center');
  axis([0 100 0 100]);
  axis off;
  hold off;
  drawnow;
endfunction

function outcome = play_one_game()
  % One trial: returns 'win', 'great', 'lose' or 'quit'
  global last_key
  pet = init_pet();                            % start values (random)
  last_key = '';
  outcome = '';
  timer = tic;                                 % real-time clock
  last_tick = 0;
  draw_screen(pet, 'Take care of your pet!');
  while isempty(outcome)
    if !ishandle(gcf)                          % window closed
      outcome = 'quit';
      break;
    endif
    if !isempty(last_key)                      % a key was pressed
      if strcmp(last_key, 'q')
        outcome = 'quit';
        break;
      endif
      pet = apply_action(pet, last_key);
      last_key = '';
    endif
    elapsed = toc(timer);                      % speed does not depend on PC
    if elapsed - last_tick >= 1                % one tick per second
      last_tick = last_tick + 1;
      pet = update_pet(pet);
    endif
    pet.hunger    = min(100, pet.hunger);      % keep values in [0, 100]
    pet.happiness = min(100, pet.happiness);
    values = [pet.hunger, pet.happiness, pet.energy, pet.hygiene];
    if min(values) <= 0                        % LOSE condition
      outcome = 'lose';
    elseif pet.age >= 90                       % WIN condition
      if mean(values) > 60
        outcome = 'great';
      else
        outcome = 'win';
      endif
    endif
    draw_screen(pet, 'Take care of your pet!');
    pause(0.1);                                % ~10 images per second
  endwhile
  if !strcmp(outcome, 'quit')
    save_result(outcome, pet.age);
  endif
endfunction

function save_result(outcome, age)
  % Append the result of the game at the end of a text file
  fid = fopen('tamagotchi_scores.txt', 'a');
  fprintf(fid, '%s : %s after %d s\n', datestr(now, 'dd/mm/yyyy HH:MM'), ...
          outcome, age);
  fclose(fid);
endfunction

function key = wait_for_key()
  % Wait until the player presses r (replay) or q (quit)
  global last_key
  last_key = '';
  key = 'q';
  while ishandle(gcf)
    if strcmp(last_key, 'r') || strcmp(last_key, 'q')
      key = last_key;
      return;
    endif
    pause(0.1);
  endwhile
endfunction

%% ----------------------------- MAIN CODE ------------------------------
clear all; close all; clc;
global last_key
last_key = '';
fig = figure('Name', 'Tamagotchi', 'NumberTitle', 'off', ...
             'KeyPressFcn', @on_key_press);    % resizable by default
axes('Position', [0.02 0.02 0.96 0.96]);       % relative -> follows resize

% ---- START of the game: welcome screen ----
cla; axis([0 100 0 100]); axis off;
text(50, 70, 'TAMAGOTCHI', 'HorizontalAlignment', 'center', 'FontSize', 20);
text(50, 50, 'Keep your pet alive for 90 seconds.', ...
     'HorizontalAlignment', 'center');
text(50, 40, 'f=feed  p=play  s=sleep  c=clean  q=quit', ...
     'HorizontalAlignment', 'center');
text(50, 25, 'Press any key to start', 'HorizontalAlignment', 'center');
drawnow;
last_key = '';
while isempty(last_key) && ishandle(fig)
  pause(0.1);
endwhile

% ---- GAME: repeat trials until the player quits ----
keep_playing = ishandle(fig);
while keep_playing
  outcome = play_one_game();                   % one full trial
  % ---- END of the game: message depending on the result ----
  if strcmp(outcome, 'quit')
    break;
  endif
  cla; axis([0 100 0 100]); axis off;
  switch outcome
    case 'great'
      msg = 'GREAT WIN! Your pet is happy and healthy!';
    case 'win'
      msg = 'WIN! Your pet survived (but it is not very happy...)';
    case 'lose'
      msg = 'GAME OVER: your pet died :(';
  endswitch
  text(50, 60, msg, 'HorizontalAlignment', 'center', 'FontSize', 14);
  text(50, 40, 'r = replay    q = quit', 'HorizontalAlignment', 'center');
  drawnow;
  keep_playing = strcmp(wait_for_key(), 'r');  % replay or stop
endwhile

if ishandle(fig)
  close(fig);                                  % clean exit
endif
disp('Thanks for playing!');
