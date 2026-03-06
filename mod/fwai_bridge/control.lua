local BOT_NAME = "fwai-bot"
local MOD_VERSION = "0.1.0"

local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DIRECTION_BY_NAME = {
  north = defines.direction.north,
  east = defines.direction.east,
  south = defines.direction.south,
  west = defines.direction.west,
  northeast = defines.direction.northeast,
  southeast = defines.direction.southeast,
  southwest = defines.direction.southwest,
  northwest = defines.direction.northwest
}

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

  local aggregated = {}
  for index = 1, #inventory do
    local stack = inventory[index]
    if stack and stack.valid_for_read then
      local current = aggregated[stack.name]
      if current then
        current.count = current.count + stack.count
      else
        aggregated[stack.name] = {name = stack.name, count = stack.count}
      end
    end
  end

  local entries = {}
  for _, entry in pairs(aggregated) do
    entries[#entries + 1] = entry
  end
  table.sort(entries, function(a, b) return a.name < b.name end)

  local limit = math.min(max_entries or 50, #entries)
  local out = {}
  for i = 1, limit do
    out[#out + 1] = entries[i]
  end
  return out
end

local function distance(a, b)
  if not (a and b) then
    return math.huge
  end
  local ax = tonumber(a.x)
  local ay = tonumber(a.y)
  local bx = tonumber(b.x)
  local by = tonumber(b.y)
  if not (ax and ay and bx and by) then
    return math.huge
  end
  return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

local function normalize_count(value, default_value)
  local count = tonumber(value)
  if not count then
    return default_value
  end
  count = math.floor(count)
  if count < 1 then
    return nil
  end
  return count
end

local function normalize_direction(value)
  if type(value) == "number" then
    return math.floor(value)
  end
  if type(value) == "string" then
    return DIRECTION_BY_NAME[string.lower(value)] or defines.direction.north
  end
  return defines.direction.north
end

local function get_bot_inventory(bot)
  if not (bot and bot.valid) then
    return nil
  end
  return bot.get_inventory(defines.inventory.spider_trunk)
end

local function get_entity_main_inventory(entity)
  if not (entity and entity.valid) then
    return nil
  end
  if entity.type == "container" or entity.type == "logistic-container" then
    return entity.get_inventory(defines.inventory.chest)
  end
  if entity.type == "car" then
    return entity.get_inventory(defines.inventory.car_trunk)
  end
  if entity.type == "spider-vehicle" then
    return entity.get_inventory(defines.inventory.spider_trunk)
  end
  if entity.type == "construction-robot" or entity.type == "logistic-robot" then
    return entity.get_inventory(defines.inventory.robot_cargo)
  end
  return nil
end

local function get_entity_input_inventory(entity)
  if not (entity and entity.valid) then
    return nil
  end
  if entity.type == "furnace" then
    return entity.get_inventory(defines.inventory.furnace_source)
  end
  if entity.type == "assembling-machine" then
    return entity.get_inventory(defines.inventory.crafter_input)
  end
  if entity.type == "lab" then
    return entity.get_inventory(defines.inventory.lab_input)
  end
  return get_entity_main_inventory(entity)
end

local function get_entity_output_inventory(entity)
  if not (entity and entity.valid) then
    return nil
  end
  local output_inventory = entity.get_output_inventory and entity.get_output_inventory() or nil
  if output_inventory and output_inventory.valid then
    return output_inventory
  end
  return get_entity_main_inventory(entity)
end

local function collect_entity_inventories(entity)
  local inventories = {}
  local main_inventory = get_entity_main_inventory(entity)
  local input_inventory = get_entity_input_inventory(entity)
  local output_inventory = get_entity_output_inventory(entity)

  if main_inventory and main_inventory.valid then
    inventories.main = inventory_snapshot(main_inventory, 32)
  end
  if input_inventory and input_inventory.valid and input_inventory ~= main_inventory then
    inventories.input = inventory_snapshot(input_inventory, 32)
  end
  if output_inventory and output_inventory.valid and output_inventory ~= main_inventory and output_inventory ~= input_inventory then
    inventories.output = inventory_snapshot(output_inventory, 32)
  end

  if next(inventories) then
    return inventories
  end
  return nil
end

local function serialize_entity(entity)
  local serialized = {
    unit_number = entity.unit_number,
    name = entity.name,
    type = entity.type,
    position = {x = entity.position.x, y = entity.position.y}
  }
  if entity.force then
    serialized.force = entity.force.name
  end
  if entity.health then
    serialized.health = entity.health
  end
  if entity.type == "resource" and entity.amount then
    serialized.amount = entity.amount
  end
  local inventories = collect_entity_inventories(entity)
  if inventories then
    serialized.inventories = inventories
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
    health = bot.health,
    inventory = inventory_snapshot(get_bot_inventory(bot), 64)
  }
end

local function collect_entities(surface, center, radius, max_entities)
  local entities = surface.find_entities_filtered{position = center, radius = radius}
  local ranked = {}
  for _, entity in pairs(entities) do
    if entity.valid then
      ranked[#ranked + 1] = {
        entity = entity,
        distance = distance(center, entity.position)
      }
    end
  end
  table.sort(ranked, function(a, b) return a.distance < b.distance end)

  local out = {}
  local limit = math.max(1, tonumber(max_entities) or 64)
  for _, ranked_entity in pairs(ranked) do
    out[#out + 1] = serialize_entity(ranked_entity.entity)
    if #out >= limit then
      break
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
      connected = player.connected,
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

local function resolve_place_entity_name(item_name, params)
  local explicit_name = params.name or params.entity_name
  if type(explicit_name) == "string" and explicit_name ~= "" then
    return explicit_name
  end
  local item_prototype = game.item_prototypes[item_name]
  if not item_prototype then
    return nil, "item_prototype_not_found"
  end
  if not item_prototype.place_result then
    return nil, "item_not_placeable"
  end
  return item_prototype.place_result.name
end

local function find_target_entity(bot, action)
  if not (bot and bot.valid) then
    return nil
  end

  local params = action.params or {}
  local target_unit_number = tonumber(params.target_unit_number or action.target_unit_number)
  local target_x = tonumber(params.x or action.x)
  local target_y = tonumber(params.y or action.y)
  local search_radius = tonumber(params.search_radius) or 8
  local candidates = bot.surface.find_entities_filtered{
    position = bot.position,
    radius = search_radius
  }

  if target_unit_number then
    for _, entity in pairs(candidates) do
      if entity.valid and entity.unit_number == target_unit_number then
        return entity
      end
    end
  end

  if target_x and target_y then
    local best_entity = nil
    local best_distance = math.huge
    local target_position = {x = target_x, y = target_y}
    for _, entity in pairs(candidates) do
      if entity.valid then
        local current_distance = distance(entity.position, target_position)
        if current_distance < best_distance then
          best_distance = current_distance
          best_entity = entity
        end
      end
    end
    if best_distance <= 0.75 then
      return best_entity
    end
  end

  return nil
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

local function action_place(bot, action)
  if not (bot and bot.valid) then
    return {ok = false, status = "failed", reason = "bot_not_found"}
  end

  local params = action.params or {}
  local item_name = params.item or params.item_name
  local x = tonumber(params.x or action.x)
  local y = tonumber(params.y or action.y)
  if type(item_name) ~= "string" or item_name == "" then
    return {ok = false, status = "failed", reason = "item_name_missing"}
  end
  if not (x and y) then
    return {ok = false, status = "failed", reason = "invalid_target"}
  end

  local bot_inventory = get_bot_inventory(bot)
  if not (bot_inventory and bot_inventory.valid) then
    return {ok = false, status = "failed", reason = "bot_inventory_missing"}
  end
  if bot_inventory.get_item_count(item_name) < 1 then
    return {ok = false, status = "failed", reason = "bot_inventory_missing_item"}
  end

  local entity_name, entity_error = resolve_place_entity_name(item_name, params)
  if not entity_name then
    return {ok = false, status = "failed", reason = entity_error}
  end

  local target_position = {x = x, y = y}
  local direction = normalize_direction(params.direction)
  if not bot.surface.can_place_entity{
    name = entity_name,
    position = target_position,
    direction = direction,
    force = bot.force
  } then
    return {ok = false, status = "failed", reason = "cannot_place_entity"}
  end

  local removed = bot_inventory.remove({name = item_name, count = 1})
  if removed ~= 1 then
    return {ok = false, status = "failed", reason = "bot_inventory_missing_item"}
  end

  local created = bot.surface.create_entity{
    name = entity_name,
    position = target_position,
    direction = direction,
    force = bot.force,
    create_build_effect_smoke = false
  }
  if not (created and created.valid) then
    bot_inventory.insert({name = item_name, count = 1})
    return {ok = false, status = "failed", reason = "create_entity_failed"}
  end

  return {
    ok = true,
    status = "done",
    reason = "placed",
    count = 1,
    placed_entity = serialize_entity(created)
  }
end

local function action_insert(bot, action)
  if not (bot and bot.valid) then
    return {ok = false, status = "failed", reason = "bot_not_found"}
  end

  local params = action.params or {}
  local item_name = params.item or params.item_name
  local count = normalize_count(params.count, 1)
  if type(item_name) ~= "string" or item_name == "" then
    return {ok = false, status = "failed", reason = "item_name_missing"}
  end
  if not count then
    return {ok = false, status = "failed", reason = "invalid_count"}
  end

  local target = find_target_entity(bot, action)
  if not (target and target.valid) then
    return {ok = false, status = "failed", reason = "target_entity_not_found"}
  end

  local bot_inventory = get_bot_inventory(bot)
  if not (bot_inventory and bot_inventory.valid) then
    return {ok = false, status = "failed", reason = "bot_inventory_missing"}
  end
  if bot_inventory.get_item_count(item_name) < count then
    return {ok = false, status = "failed", reason = "bot_inventory_missing_item"}
  end

  local target_inventory = get_entity_input_inventory(target)
  if not (target_inventory and target_inventory.valid) then
    return {ok = false, status = "failed", reason = "target_inventory_unavailable"}
  end

  local removed = bot_inventory.remove({name = item_name, count = count})
  if removed < 1 then
    return {ok = false, status = "failed", reason = "bot_inventory_missing_item"}
  end

  local inserted = target_inventory.insert({name = item_name, count = removed})
  if inserted < removed then
    bot_inventory.insert({name = item_name, count = removed - inserted})
  end
  if inserted < 1 then
    return {ok = false, status = "failed", reason = "target_inventory_rejected"}
  end

  return {
    ok = true,
    status = "done",
    reason = "inserted",
    count = inserted,
    target = serialize_entity(target)
  }
end

local function action_take(bot, action)
  if not (bot and bot.valid) then
    return {ok = false, status = "failed", reason = "bot_not_found"}
  end

  local params = action.params or {}
  local item_name = params.item or params.item_name
  local count = normalize_count(params.count, 1)
  if type(item_name) ~= "string" or item_name == "" then
    return {ok = false, status = "failed", reason = "item_name_missing"}
  end
  if not count then
    return {ok = false, status = "failed", reason = "invalid_count"}
  end

  local target = find_target_entity(bot, action)
  if not (target and target.valid) then
    return {ok = false, status = "failed", reason = "target_entity_not_found"}
  end

  local bot_inventory = get_bot_inventory(bot)
  if not (bot_inventory and bot_inventory.valid) then
    return {ok = false, status = "failed", reason = "bot_inventory_missing"}
  end

  local target_inventory = get_entity_output_inventory(target)
  if not (target_inventory and target_inventory.valid) then
    return {ok = false, status = "failed", reason = "target_inventory_unavailable"}
  end

  local removed = target_inventory.remove({name = item_name, count = count})
  if removed < 1 then
    return {ok = false, status = "failed", reason = "target_inventory_missing_item"}
  end

  local inserted = bot_inventory.insert({name = item_name, count = removed})
  if inserted < removed then
    target_inventory.insert({name = item_name, count = removed - inserted})
  end
  if inserted < 1 then
    return {ok = false, status = "failed", reason = "bot_inventory_full"}
  end

  return {
    ok = true,
    status = "done",
    reason = "taken",
    count = inserted,
    target = serialize_entity(target)
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
  elseif action_type == "place" then
    result = action_place(bot, action)
  elseif action_type == "insert" then
    result = action_insert(bot, action)
  elseif action_type == "take" then
    result = action_take(bot, action)
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
