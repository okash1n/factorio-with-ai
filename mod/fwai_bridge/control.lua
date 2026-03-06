local BOT_NAME = "fwai-bot"
local MOD_VERSION = "0.1.0"

local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function b64decode(data)
  data = string.gsub(data or "", "[^" .. BASE64_ALPHABET .. "=]", "")
  local bit_string = data:gsub(".", function(x)
    if x == "=" then
      return ""
    end
    local value = BASE64_ALPHABET:find(x, 1, true) - 1
    local bits = ""
    for i = 6, 1, -1 do
      if value % 2 ^ i - value % 2 ^ (i - 1) > 0 then
        bits = bits .. "1"
      else
        bits = bits .. "0"
      end
    end
    return bits
  end)

  local decoded = bit_string:gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
    if #x ~= 8 then
      return ""
    end
    local c = 0
    for i = 1, 8 do
      if x:sub(i, i) == "1" then
        c = c + 2 ^ (8 - i)
      end
    end
    return string.char(c)
  end)

  return decoded
end

local function parse_kv(text)
  local result = {}
  for token in string.gmatch(text or "", "%S+") do
    local key, value = token:match("^([^=]+)=(.+)$")
    if key and value then
      result[key] = value
    end
  end
  return result
end

local function decode_request(parameter)
  if not parameter or parameter == "" then
    return {}
  end

  local decoded = b64decode(parameter)
  if decoded and decoded ~= "" then
    local ok_json, parsed_json = pcall(helpers.json_to_table, decoded)
    if ok_json and type(parsed_json) == "table" then
      return parsed_json
    end
  end

  local ok_direct, parsed_direct = pcall(helpers.json_to_table, parameter)
  if ok_direct and type(parsed_direct) == "table" then
    return parsed_direct
  end

  return parse_kv(parameter)
end

local function reply(payload)
  if not rcon then
    return
  end
  rcon.print(helpers.table_to_json(payload))
end

local function inventory_snapshot(inventory, max_entries)
  if not inventory or not inventory.valid then
    return {}
  end

  local entries = {}
  for name, count in pairs(inventory.get_contents()) do
    entries[#entries + 1] = {name = name, count = count}
  end
  table.sort(entries, function(a, b) return a.name < b.name end)

  local limit = math.min(max_entries or 50, #entries)
  local out = {}
  for i = 1, limit do
    out[#out + 1] = entries[i]
  end
  return out
end

local function serialize_entity(entity)
  local serialized = {
    unit_number = entity.unit_number,
    name = entity.name,
    type = entity.type,
    position = {x = entity.position.x, y = entity.position.y}
  }
  if entity.health then
    serialized.health = entity.health
  end
  if entity.type == "resource" and entity.amount then
    serialized.amount = entity.amount
  end
  return serialized
end

local function get_player(player_index)
  local index = tonumber(player_index) or 1
  local player = game.get_player(index)
  if not (player and player.valid) then
    return nil
  end
  return player
end

local function get_bot_by_unit_number(unit_number)
  if not unit_number then
    return nil
  end
  for _, surface in pairs(game.surfaces) do
    local entities = surface.find_entities_filtered{name = BOT_NAME}
    for _, entity in pairs(entities) do
      if entity.valid and entity.unit_number == unit_number then
        return entity
      end
    end
  end
  return nil
end

local function find_bot(player)
  local tracked = get_bot_by_unit_number(storage.bot_unit_number)
  if tracked then
    return tracked
  end

  local entities = player.surface.find_entities_filtered{
    name = BOT_NAME,
    force = player.force,
    limit = 1
  }
  if #entities == 0 then
    return nil
  end
  storage.bot_unit_number = entities[1].unit_number
  return entities[1]
end

local function create_bot(player)
  local position = player.surface.find_non_colliding_position(BOT_NAME, player.position, 24, 0.5) or player.position
  local bot = player.surface.create_entity{
    name = BOT_NAME,
    position = position,
    force = player.force,
    create_build_effect_smoke = false
  }
  if bot and bot.valid then
    storage.bot_unit_number = bot.unit_number
  end
  return bot
end

local function ensure_bot(player)
  local bot = find_bot(player)
  if bot then
    return bot
  end
  return create_bot(player)
end

local function bot_snapshot(bot)
  if not (bot and bot.valid) then
    return nil
  end
  return {
    unit_number = bot.unit_number,
    name = bot.name,
    type = bot.type,
    position = {x = bot.position.x, y = bot.position.y},
    health = bot.health
  }
end

local function collect_entities(surface, center, radius, max_entities)
  local entities = surface.find_entities_filtered{position = center, radius = radius}
  local out = {}
  local limit = math.max(1, tonumber(max_entities) or 64)
  for _, entity in pairs(entities) do
    if entity.valid then
      out[#out + 1] = serialize_entity(entity)
      if #out >= limit then
        break
      end
    end
  end
  return out
end

local function handle_health(_command)
  reply({
    ok = true,
    name = "fwai_bridge",
    version = MOD_VERSION,
    tick = game.tick
  })
end

local function handle_reset(command)
  local request = decode_request(command.parameter)
  local player = get_player(request.player_index)
  if not player then
    reply({ok = false, error = "player_not_found"})
    return
  end

  for _, surface in pairs(game.surfaces) do
    local entities = surface.find_entities_filtered{name = BOT_NAME, force = player.force}
    for _, entity in pairs(entities) do
      if entity.valid then
        entity.destroy()
      end
    end
  end
  storage.bot_unit_number = nil

  local bot = create_bot(player)
  reply({
    ok = bot ~= nil,
    tick = game.tick,
    bot = bot_snapshot(bot)
  })
end

local function handle_observe(command)
  local request = decode_request(command.parameter)
  local player = get_player(request.player_index)
  if not player then
    reply({ok = false, error = "player_not_found"})
    return
  end

  local bot = nil
  if request.ensure_bot == false then
    bot = find_bot(player)
  else
    bot = ensure_bot(player)
  end

  local center = player.position
  if bot and bot.valid then
    center = bot.position
  end

  local radius = tonumber(request.radius) or 32
  local max_entities = tonumber(request.max_entities) or 64
  local inventory = player.get_main_inventory()
  local current_research = player.force.current_research

  reply({
    ok = true,
    tick = game.tick,
    player = {
      index = player.index,
      name = player.name,
      position = {x = player.position.x, y = player.position.y},
      surface = player.surface.name,
      inventory = inventory_snapshot(inventory, 64)
    },
    bot = bot_snapshot(bot),
    research = {
      current = current_research and current_research.name or nil,
      progress = current_research and player.force.research_progress or nil
    },
    entities = collect_entities(player.surface, center, radius, max_entities)
  })
end

local function handle_bot_state(command)
  local request = decode_request(command.parameter)
  local player = get_player(request.player_index)
  if not player then
    reply({ok = false, error = "player_not_found"})
    return
  end

  local bot = find_bot(player)
  reply({
    ok = true,
    tick = game.tick,
    bot = bot_snapshot(bot)
  })
end

local function parse_action(request)
  if type(request.action) == "table" then
    return request.action
  end
  return request
end

local function action_move(bot, action)
  if not (bot and bot.valid) then
    return {ok = false, status = "failed", reason = "bot_not_found"}
  end

  local params = action.params or {}
  local x = tonumber(params.x or action.x)
  local y = tonumber(params.y or action.y)
  if not (x and y) then
    return {ok = false, status = "failed", reason = "invalid_move_target"}
  end

  bot.autopilot_destination = {x = x, y = y}
  return {
    ok = true,
    status = "pending",
    reason = "moving",
    target = {x = x, y = y}
  }
end

local function handle_act(command)
  local request = decode_request(command.parameter)
  local player = get_player(request.player_index)
  if not player then
    reply({ok = false, status = "failed", reason = "player_not_found"})
    return
  end

  local bot = ensure_bot(player)
  local action = parse_action(request)
  local action_type = action.type or "wait"

  local result
  if action_type == "wait" then
    result = {ok = true, status = "done", reason = "noop"}
  elseif action_type == "move" then
    result = action_move(bot, action)
  elseif action_type == "spawn_bot" then
    bot = ensure_bot(player)
    result = {ok = bot ~= nil, status = "done", reason = "bot_ready"}
  else
    result = {ok = false, status = "failed", reason = "unsupported_action"}
  end

  result.tick = game.tick
  result.bot = bot_snapshot(bot)
  reply(result)
end

script.on_init(function()
  storage.bot_unit_number = nil
end)

commands.add_command("fwai.health", "Health check for fwai bridge", handle_health)
commands.add_command("fwai.observe", "Observe current game state", handle_observe)
commands.add_command("fwai.act", "Execute action request", handle_act)
commands.add_command("fwai.bot_state", "Read bot state", handle_bot_state)
commands.add_command("fwai.reset", "Reset bot instance", handle_reset)
