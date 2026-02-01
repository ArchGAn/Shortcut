addon.name      = 'Shortcut';
addon.author    = 'ArchGAn';
addon.version   = '2.9';
addon.desc      = 'Shorthand-style targeting';

require('common');
local chat = require('chat');

--[[
Shortcut - Shorthand-style commands for Ashita v4

USAGE:
  //[action]             Uses current target (<t>)
  //[action] <t>         Current target
  //[action] <bt>        Battle target (mob party is fighting)
  //[action] <me>        Yourself
  //[action] <st>        Subtarget cursor (any)
  //[action] <stpc>      Subtarget cursor (players only)
  //[action] <stnpc>     Subtarget cursor (NPCs/mobs only)

EXAMPLES:
  //cure                 Cure current target
  //cure <me>            Cure yourself
  //cure <stpc>          Cure - pick a player
  //dia <stnpc>          Dia - pick a mob
  //cure <bt>            Cure whoever has hate
  //fight                Pet fight current target

NOTE: Partial name targeting (//cure sam) depends on /target working.
      For reliability, use target tokens: <t>, <bt>, <stpc>, <stnpc>, etc.
]]

local SPAWN_MOB = 0x10;
local SPAWN_NPC = 0x02;
local SPAWN_PC = 0x01;

-- ============================================
-- DISTANCE FUNCTIONS
-- ============================================
local function get_player_pos()
    local entity = AshitaCore:GetMemoryManager():GetEntity();
    return {
        x = entity:GetLocalPositionX(0),
        y = entity:GetLocalPositionY(0),
        z = entity:GetLocalPositionZ(0)
    };
end

local function distance_2d(pos1, pos2)
    local dx = pos1.x - pos2.x;
    local dz = pos1.z - pos2.z;
    return math.sqrt(dx*dx + dz*dz);
end

-- ============================================
-- ENTITY SEARCH
-- ============================================
local function find_entity(partial_name, search_type)
    local entity = AshitaCore:GetMemoryManager():GetEntity();
    local player_pos = get_player_pos();
    local partial_lower = string.lower(partial_name);
    
    local best_match = nil;
    local best_dist = 9999;
    
    -- Check player (index 0) for player searches
    if (search_type == 'player' or search_type == 'any') then
        local player_name = entity:GetName(0);
        if (player_name and player_name ~= '') then
            local name_lower = string.lower(player_name);
            if (string.sub(name_lower, 1, #partial_lower) == partial_lower) or
               (string.find(name_lower, partial_lower, 1, true)) then
                return {
                    index = 0,
                    name = player_name,
                    distance = 0
                };
            end
        end
    end
    
    -- Check party members
    if (search_type == 'player' or search_type == 'any') then
        local party = AshitaCore:GetMemoryManager():GetParty();
        if (party) then
            for i = 0, 5 do
                local member_name = party:GetMemberName(i);
                if (member_name and member_name ~= '') then
                    local name_lower = string.lower(member_name);
                    if (string.sub(name_lower, 1, #partial_lower) == partial_lower) or
                       (string.find(name_lower, partial_lower, 1, true)) then
                        local target_idx = party:GetMemberTargetIndex(i);
                        if (target_idx and target_idx > 0) then
                            local pos = {
                                x = entity:GetLocalPositionX(target_idx),
                                y = entity:GetLocalPositionY(target_idx),
                                z = entity:GetLocalPositionZ(target_idx)
                            };
                            local dist = distance_2d(player_pos, pos);
                            if (dist < best_dist) then
                                best_dist = dist;
                                best_match = { index = target_idx, name = member_name, distance = dist };
                            end
                        end
                    end
                end
            end
            if (best_match and search_type == 'player') then
                return best_match;
            end
        end
    end
    
    -- Search all entities
    for i = 1, 2048 do
        local render = entity:GetRenderFlags0(i);
        if (render ~= 0 and render ~= nil) then
            local name = entity:GetName(i);
            if (name ~= nil and name ~= '') then
                local name_lower = string.lower(name);
                local matches = (string.sub(name_lower, 1, #partial_lower) == partial_lower) or
                               (string.find(name_lower, partial_lower, 1, true));
                
                if (matches) then
                    local spawn = entity:GetSpawnFlags(i);
                    local type_ok = false;
                    
                    if (search_type == 'mob') then
                        type_ok = (bit.band(spawn, SPAWN_MOB) ~= 0);
                    elseif (search_type == 'player') then
                        type_ok = (bit.band(spawn, SPAWN_PC) ~= 0);
                    elseif (search_type == 'npc') then
                        type_ok = (bit.band(spawn, SPAWN_NPC) ~= 0);
                    else
                        type_ok = true;
                    end
                    
                    if (type_ok) then
                        local pos = {
                            x = entity:GetLocalPositionX(i),
                            y = entity:GetLocalPositionY(i),
                            z = entity:GetLocalPositionZ(i)
                        };
                        local dist = distance_2d(player_pos, pos);
                        if (dist < best_dist) then
                            best_dist = dist;
                            best_match = { index = i, name = name, distance = dist };
                        end
                    end
                end
            end
        end
    end
    
    return best_match;
end

local function target_entity_by_name(name)
    AshitaCore:GetChatManager():QueueCommand(1, '/target "' .. name .. '"');
end

-- ============================================
-- COMMAND DATABASES
-- ============================================

-- Job Abilities (use /ja)
local job_abilities = {
    -- WAR
    'provoke', 'berserk', 'defender', 'warcry', 'aggressor', 'retaliation', 
    'restraint', 'blood rage', 'tomahawk', 'mighty strikes',
    -- MNK
    'boost', 'dodge', 'focus', 'chakra', 'counterstance', 'chi blast',
    'footwork', 'mantra', 'formless strikes', 'impetus', 'hundred fists',
    -- WHM
    'divine seal', 'afflatus solace', 'afflatus misery', 'sacrosanctity', 'benediction',
    -- BLM
    'elemental seal', 'mana wall', 'enmity douse', 'manawell', 'manafont',
    -- RDM
    'convert', 'composure', 'saboteur', 'spontaneity', 'chainspell',
    -- THF
    'steal', 'sneak attack', 'flee', 'trick attack', 'mug', 'hide',
    'accomplice', 'collaborator', 'bully', 'despoil', 'conspirator', 'larceny', 'perfect dodge', 'feint',
    -- PLD
    'shield bash', 'sentinel', 'cover', 'rampart', 'fealty', 'chivalry', 
    'divine emblem', 'majesty', 'invincible', 'holy circle',
    -- DRK
    'souleater', 'arcane circle', 'last resort', 'weapon bash', 'nether void',
    'arcane crest', 'scarlet delirium', 'blood weapon', 'dark seal', 'diabolic eye',
    -- BST
    'charm', 'gauge', 'tame', 'pet commands', 'snarl', 'sic', 'ready',
    'reward', 'call beast', 'bestial loyalty', 'familiar', 'feral howl', 'killer instinct',
    -- BRD
    'nightingale', 'troubadour', 'soul voice', 'pianissimo', 'tenuto', 'marcato', 'clarion call',
    -- RNG
    'sharpshot', 'scavenge', 'camouflage', 'barrage', 'shadowbind',
    'velocity shot', 'unlimited shot', 'flashy shot', 'decoy shot', 'bounty shot', 'eagle eye shot',
    -- SAM
    'meikyo shisui', 'meditate', 'third eye', 'warding circle', 'sekkanoki',
    'hasso', 'seigan', 'konzen-ittai', 'hamanoha', 'hagakure', 'sengikori',
    -- NIN
    'yonin', 'innin', 'issekigan', 'futae', 'mijin gakure',
    -- DRG
    'ancient circle', 'jump', 'high jump', 'super jump', 'spirit jump', 'soul jump',
    'call wyvern', 'spirit link', 'deep breathing', 'angon', 'fly high', 'steady wing',
    -- SMN
    "avatar's favor", 'assault', 'retreat', 'release', 'blood pact: rage', 
    'blood pact: ward', 'apogee', 'mana cede', 'astral flow', 'elemental siphon',
    -- BLU
    'azure lore', 'burst affinity', 'chain affinity', 'efflux',
    'diffusion', 'unbridled learning', 'unbridled wisdom',
    -- COR
    'wild card', 'phantom roll', 'quick draw', 'random deal', 'snake eye',
    'fold', 'double-up', 'triple shot', 'cutting cards', 'crooked cards',
    -- PUP
    'activate', 'deactivate', 'deploy', 'retrieve', 'repair',
    'ventriloquy', 'role reversal', 'tactical switch', 'cooldown', 'deus ex automata',
    'heady artifice', 'overdrive',
    -- DNC
    'trance', 'drain samba', 'drain samba ii', 'drain samba iii',
    'aspir samba', 'aspir samba ii', 'haste samba',
    'curing waltz', 'curing waltz ii', 'curing waltz iii', 'curing waltz iv', 'curing waltz v',
    'divine waltz', 'divine waltz ii', 'healing waltz',
    'spectral jig', 'chocobo jig', 'chocobo jig ii',
    'quickstep', 'box step', 'stutter step', 'feather step',
    'violent flourish', 'animated flourish', 'desperate flourish',
    'building flourish', 'wild flourish',
    'reverse flourish', 'saber dance', 'fan dance',
    'no foot rise', 'presto', 'climactic flourish', 'striking flourish', 'ternary flourish',
    'contradance',
    -- SCH
    'tabula rasa', 'light arts', 'dark arts', 'sublimation', 'addendum: white', 'addendum: black',
    'stratagems', 'enlightenment', 'stormsurge',
    'penury', 'celerity', 'accession', 'rapture', 'altruism', 'tranquility', 'perpetuance',
    'immanence', 'ebullience', 'focalization', 'equanimity', 'manifestation',
    -- GEO
    'full circle', 'lasting emanation', 'ecliptic attrition', 'life cycle',
    'blaze of glory', 'dematerialize', 'theurgic focus', 'concentric pulse',
    'mending halation', 'radial arcana', 'widened compass', 'bolster',
    -- RUN
    'swordplay', 'lunge', 'pflug', 'embolden', 'valiance', 'gambit',
    'liement', 'one for all', 'battuta', 'rayke', 'inspiration', 'vivacious pulse',
    'ignis', 'gelus', 'flabra', 'tellus', 'sulpor', 'unda', 'lux', 'tenebrae', 'elemental sforzo',
};

-- Pet Commands (use /pet)
local pet_commands = {
    'fight', 'heel', 'stay', 'leave',
    'assault', 'retreat', 'release',
    'deploy', 'activate', 'deactivate', 'retrieve',
    'sic', 'ready',
};

-- Weapon Skills (use /ws) - comprehensive list
local weapon_skills = {
    -- Swords (all)
    'fast blade', 'burning blade', 'red lotus blade', 'flat blade', 'shining blade',
    'seraph blade', 'circle blade', 'spirits within', 'vorpal blade', 'swift blade',
    'savage blade', 'knights of round', 'death blossom', 'atonement', 'expiacion',
    'sanguine blade', 'chant du cygne', 'requiescat', 'uriel blade', 'gust slash',
    -- Great Swords (all)
    'hard slash', 'power slash', 'frostbite', 'freezebite', 'shockwave',
    'crescent moon', 'sickle moon', 'spinning slash', 'ground strike',
    'herculean slash', 'torcleaver', 'scourge', 'resolution',
    -- Daggers (all)
    'wasp sting', 'gust slash', 'shadowstitch', 'viper bite', 'cyclone',
    'energy steal', 'energy drain', 'dancing edge', 'shark bite',
    'evisceration', 'mercy stroke', 'mandalic stab', 'mordant rime', 'pyrrhic kleos',
    'aeolian edge', 'rudras storm', 'exenterator',
    -- Axes (all)
    'raging axe', 'smash axe', 'gale axe', 'avalanche axe', 'spinning axe',
    'rampage', 'calamity', 'mistral axe', 'decimation', 'bora axe', 'ruinator', 'cloudsplitter',
    'primal rend', 'onslaught',
    -- Great Axes (all)
    'shield break', 'iron tempest', 'sturmwind', 'armor break', 'keen edge',
    'weapon break', 'raging rush', 'full break', 'steel cyclone',
    'fell cleave', 'upheaval', "ukko's fury", 'metatron torment',
    -- Scythes (all)
    'slice', 'dark harvest', 'shadow of death', 'nightmare scythe', 'spinning scythe',
    'vorpal scythe', 'guillotine', 'cross reaper', 'spiral hell',
    'infernal scythe', 'entropy', 'insurgency', 'quietus', 'catastrophe',
    -- Polearms (all)
    'double thrust', 'thunder thrust', 'raiden thrust', 'leg sweep', 'penta thrust',
    'vorpal thrust', 'skewer', 'wheeling thrust', 'impulse drive',
    'sonic thrust', 'stardiver', 'geirskogul', 'drakesbane', "camlann's torment",
    -- Katana (all)
    'blade: rin', 'blade: retsu', 'blade: teki', 'blade: to', 'blade: chi',
    'blade: ei', 'blade: jin', 'blade: ten', 'blade: ku', 'blade: yu',
    'blade: metsu', 'blade: kamu', 'blade: hi', 'blade: shun',
    -- Great Katana (all)
    'tachi: enpi', 'tachi: hobaku', 'tachi: goten', 'tachi: kagero', 'tachi: jinpu',
    'tachi: koki', 'tachi: yukikaze', 'tachi: gekko', 'tachi: kasha', 'tachi: ageha',
    'tachi: shoha', 'tachi: rana', 'tachi: fudo', 'tachi: kaiten',
    -- Clubs (all)
    'shining strike', 'seraph strike', 'brainshaker', 'starlight', 'moonlight',
    'skullbreaker', 'true strike', 'judgment', 'hexa strike', 'black halo',
    'randgrith', 'mystic boon', 'flash nova', 'dagan', 'realmrazer',
    -- Staves (all)
    'heavy swing', 'rock crusher', 'earth crusher', 'starburst', 'sunburst',
    'shell crusher', 'full swing', 'spirit taker', 'retribution',
    'gate of tartarus', 'vidohunir', 'garland of bliss', 'omniscience', 'cataclysm', 'myrkr', 'shattersoul',
    -- Hand to Hand (all)
    'combo', 'shoulder tackle', 'one inch punch', 'backhand blow', 'raging fists',
    'spinning attack', 'howling fist', 'dragon kick', 'asuran fists',
    'tornado kick', 'shijin spiral', 'final heaven', "ascetic's fury", 'stringing pummel', 'victory smite',
    -- Archery (all)
    'flaming arrow', 'piercing arrow', 'dulling arrow', 'sidewinder', 'blast arrow',
    'arching arrow', 'empyreal arrow', 'refulgent arrow', 'apex arrow', "jishnu's radiance", 'namas arrow',
    -- Marksmanship (all)
    'hot shot', 'split shot', 'sniper shot', 'slug shot', 'blast shot', 'heavy shot',
    'detonator', 'numbing shot', 'last stand', 'coronach', 'trueflight', 'leaden salute', 'wildfire',
};

-- Items (use /item) - common consumables
local items = {
    'potion', 'hi-potion', 'x-potion', 'max-potion', 'hyper potion',
    'ether', 'hi-ether', 'super ether', 'max-ether', 'hyper ether',
    'elixir', 'megalixir',
    'antidote', 'eye drops', 'echo drops', 'holy water', 'remedy',
    'panacea', 'catholicon',
    'prism powder', 'silent oil', 'deodorizer',
    'reraiser', 'super reraiser', 'instant reraise',
};

-- Build lookup tables
local ja_lookup = {};
for _, v in ipairs(job_abilities) do ja_lookup[string.lower(string.gsub(v, ' ', ''))] = v; end

local pet_lookup = {};
for _, v in ipairs(pet_commands) do pet_lookup[string.lower(string.gsub(v, ' ', ''))] = v; end

local ws_lookup = {};
for _, v in ipairs(weapon_skills) do ws_lookup[string.lower(string.gsub(v, ' ', ''))] = v; end

local item_lookup = {};
for _, v in ipairs(items) do item_lookup[string.lower(string.gsub(v, ' ', ''))] = v; end

-- ============================================
-- TARGET TYPE DETECTION
-- ============================================
local mob_commands = {
    'dia', 'bio', 'poison', 'blind', 'paralyze', 'silence', 'slow', 'gravity', 
    'bind', 'sleep', 'dispel', 'stun', 'drain', 'aspir', 'absorb',
    'stone', 'water', 'aero', 'fire', 'blizzard', 'thunder',
    'provoke', 'check', 'attack', 'fight', 'charm', 'gauge', 'steal', 'mug', 'despoil',
    'ranged', 'ra', 'shoot',
};

local player_commands = {
    'cure', 'cura', 'curaga', 'regen', 'haste', 'refresh', 'flurry',
    'protect', 'shell', 'protectra', 'shellra', 'blink', 'stoneskin', 'aquaveil', 'phalanx',
    'invisible', 'sneak', 'deodorize', 'raise', 'reraise', 'arise',
    'poisona', 'paralyna', 'blindna', 'silena', 'stona', 'viruna', 'cursna', 'erase',
    'sacrifice', 'esuna', 'curing waltz', 'divine waltz', 'healing waltz',
};

local function get_search_type(cmd)
    local cmd_lower = string.lower(string.gsub(cmd, ' ', ''));
    for _, v in ipairs(mob_commands) do
        local check = string.lower(string.gsub(v, ' ', ''));
        if (string.sub(cmd_lower, 1, #check) == check) then return 'mob'; end
    end
    for _, v in ipairs(player_commands) do
        local check = string.lower(string.gsub(v, ' ', ''));
        if (string.sub(cmd_lower, 1, #check) == check) then return 'player'; end
    end
    return 'any';
end

-- ============================================
-- COMMAND TYPE + NAME DETECTION
-- ============================================
local function get_command_info(input, allow_spell_fallback)
    local input_clean = string.lower(string.gsub(input, ' ', ''));
    
    -- Special direct commands
    if (input_clean == 'attack' or input_clean == 'a') then
        return 'direct', '/attack', true;
    end
    if (input_clean == 'ranged' or input_clean == 'ra' or input_clean == 'shoot') then
        return 'direct', '/ra', true;
    end
    if (input_clean == 'check' or input_clean == 'c') then
        return 'direct', '/check', true;
    end
    if (input_clean == 'target' or input_clean == 'ta') then
        return 'direct', '/target', true;
    end
    
    -- Pet commands (highest priority - "fight" must be pet, not confused with anything else)
    if (pet_lookup[input_clean]) then
        return 'pet', pet_lookup[input_clean], true;
    end
    
    -- Job abilities
    if (ja_lookup[input_clean]) then
        return 'ja', ja_lookup[input_clean], true;
    end
    
    -- Weapon skills
    if (ws_lookup[input_clean]) then
        return 'ws', ws_lookup[input_clean], true;
    end
    
    -- Items
    if (item_lookup[input_clean]) then
        return 'item', item_lookup[input_clean], true;
    end
    
    -- If not allowing spell fallback, return nil (used during parsing to find real command)
    if (not allow_spell_fallback) then
        return nil, nil, false;
    end
    
    -- Default to spell (most things are spells)
    -- Format: cure2 -> Cure II, fire3 -> Fire III
    local base, num = string.match(input, "^(%a+)(%d+)$");
    if (base and num) then
        local romans = { '', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII' };
        local roman = romans[tonumber(num)] or num;
        local formatted = base:gsub("^%l", string.upper) .. ' ' .. roman;
        return 'ma', formatted, true;
    end
    
    -- Format: cureii -> Cure II, fireiv -> Fire IV, protectra -> Protectra
    -- Check longest suffixes first to avoid "cureiii" matching "i" before "iii"
    local roman_suffixes = {
        { 'viii', 'VIII' }, { 'vii', 'VII' }, { 'vi', 'VI' }, { 'iv', 'IV' },
        { 'iii', 'III' }, { 'ii', 'II' }, { 'v', 'V' }
        -- Note: don't include single 'i' - too many false positives (Divi, etc)
    };
    local input_lower = string.lower(input);
    for _, pair in ipairs(roman_suffixes) do
        local suffix = pair[1];
        local roman = pair[2];
        if (string.sub(input_lower, -#suffix) == suffix and #input_lower > #suffix) then
            local base_part = string.sub(input, 1, #input - #suffix);
            -- Make sure base is at least 3 chars (cure, fire, etc)
            if (#base_part >= 3) then
                local formatted = base_part:gsub("^%l", string.upper) .. ' ' .. roman;
                return 'ma', formatted, true;
            end
        end
    end
    
    -- Just capitalize for spell
    local formatted = input:gsub("(%a)([%w_']*)", function(a,b) return string.upper(a)..string.lower(b) end);
    return 'ma', formatted, true;
end

-- ============================================
-- MAIN COMMAND HANDLER
-- ============================================
ashita.events.register('command', 'shortcut_cmd', function(e)
    local cmd = e.command;
    
    if (string.sub(cmd, 1, 2) ~= '//') then
        return;
    end
    
    e.blocked = true;
    
    local rest = string.sub(cmd, 3);
    if (rest == '' or rest == nil) then return; end
    
    -- Find where the target name starts (last word(s) that match an entity)
    -- Try progressively shorter action strings
    local parts = {};
    for word in string.gmatch(rest, "%S+") do
        table.insert(parts, word);
    end
    
    if (#parts == 0) then return; end
    
    local action_str = nil;
    local target_str = nil;
    local found_known = false;
    
    -- Try to find the LONGEST known command
    -- Check from longest to shortest
    for split = #parts, 1, -1 do
        local potential_action = table.concat(parts, ' ', 1, split);
        local potential_target = nil;
        if (split < #parts) then
            potential_target = table.concat(parts, ' ', split + 1);
        end
        
        -- Check if this is a KNOWN command (not spell fallback)
        local cmd_type, cmd_name, is_known = get_command_info(potential_action, false);
        
        if (is_known) then
            action_str = potential_action;
            target_str = potential_target;
            found_known = true;
            break;
        end
    end
    
    -- If no known command found, treat first word as spell, rest as target
    if (not found_known) then
        action_str = parts[1];
        if (#parts > 1) then
            target_str = table.concat(parts, ' ', 2);
        end
    end
    
    local cmd_type, cmd_name = get_command_info(action_str, true);
    
    -- Build the command string
    local final_cmd;
    if (cmd_type == 'direct') then
        final_cmd = cmd_name .. ' <t>';
    elseif (cmd_type == 'pet') then
        final_cmd = '/pet "' .. cmd_name .. '" <t>';
    elseif (cmd_type == 'ja') then
        final_cmd = '/ja "' .. cmd_name .. '" <t>';
    elseif (cmd_type == 'ws') then
        final_cmd = '/ws "' .. cmd_name .. '" <t>';
    elseif (cmd_type == 'item') then
        final_cmd = '/item "' .. cmd_name .. '" <t>';
    else -- ma (spell)
        final_cmd = '/ma "' .. cmd_name .. '" <t>';
    end
    
    -- No target, just execute with <t>
    if (not target_str or target_str == '') then
        AshitaCore:GetChatManager():QueueCommand(1, final_cmd);
        return;
    end
    
    -- Check for <me>, <t>, <st>, <bt>, <stpc>, <stnpc>, <pet>, etc - pass through directly
    if (string.sub(target_str, 1, 1) == '<') then
        final_cmd = string.gsub(final_cmd, '<t>', target_str);
        AshitaCore:GetChatManager():QueueCommand(1, final_cmd);
        return;
    end
    
    -- Find target
    local search_type = get_search_type(action_str);
    local found = find_entity(target_str, search_type);
    if (not found) then
        found = find_entity(target_str, 'any');
    end
    
    if (found) then
        -- FFXI commands don't accept named targets - must use /target first, then <t>
        target_entity_by_name(found.name);
        local delayed_cmd = final_cmd;
        ashita.tasks.once(0.5, function()
            AshitaCore:GetChatManager():QueueCommand(1, delayed_cmd);
        end);
        -- Success - no output needed
    else
        print(chat.header('SC'):append(chat.warning(string.format('No match for "%s"', target_str))));
    end
end);

-- Help
ashita.events.register('command', 'shortcut_help', function(e)
    local args = e.command:args();
    if (#args < 1 or (args[1] ~= '/sc' and args[1] ~= '/shortcut')) then return; end
    e.blocked = true;
    print(chat.header('Shortcut'):append(chat.message('v2.9')));
    print('  //[action]           Uses current target');
    print('  //[action] <t>       Current target');
    print('  //[action] <bt>      Battle target (mob fighting)');
    print('  //[action] <me>      Yourself');
    print('  //[action] <st>      Subtarget cursor');
    print('  //[action] <stpc>    Subtarget (players only)');
    print('  //[action] <stnpc>   Subtarget (NPCs/mobs only)');
    print('');
    print('  //cure <stpc>        Cure - pick a player');
    print('  //dia <stnpc>        Dia - pick a mob');
    print('  //cure <bt>          Cure whoever has hate');
    print('  //fight              Pet fight <t>');
end);

print(chat.header('Shortcut'):append(chat.message('v2.9 Loaded - //[action] [target]')));
