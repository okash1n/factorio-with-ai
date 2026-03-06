local util = require("util")

local bot_entity = util.table.deepcopy(data.raw["spider-vehicle"]["spidertron"])
bot_entity.name = "fwai-bot"
bot_entity.localised_name = {"", "FWAI Bot"}
bot_entity.minable = {mining_time = 1, result = "fwai-bot"}
bot_entity.max_health = 4000
bot_entity.guns = {}
bot_entity.equipment_grid = "spidertron-equipment-grid"

local bot_item = util.table.deepcopy(data.raw["item-with-entity-data"]["spidertron"])
bot_item.name = "fwai-bot"
bot_item.localised_name = {"", "FWAI Bot"}
bot_item.place_result = "fwai-bot"
bot_item.order = "b[personal-transport]-c[spidertron]-z[fwai-bot]"

local bot_recipe = {
  type = "recipe",
  name = "fwai-bot",
  enabled = false,
  ingredients = {
    {type = "item", name = "iron-plate", amount = 1}
  },
  results = {
    {type = "item", name = "fwai-bot", amount = 1}
  }
}

data:extend({bot_entity, bot_item, bot_recipe})
