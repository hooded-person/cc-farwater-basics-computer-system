package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"
local config = require "config"
local assets = require "assets"

local stockticker_name = config.peripherals.logistics.stockticker
local ticker = peripheral.wrap(stockticker_name)

-- load already available item metadata
local base_dir = assets.getAssetDir("items")

local items = assets.loadNamespaced(base_dir, assets.loaders.singular, true)

local skipMap = {
    ["minecraft:player_head"] = true, -- because mob heads fuck with this
}

local stock = ticker.stock(true)
for _, data in ipairs(stock) do
    if not skipMap[data.name] then
        items[data.name] = {
            name = data.name,
            maxCount = data.maxCount,
            displayName = data.displayName,
            mapColor = data.mapColor
        }
    end
end

assets.saveNamespaced(base_dir, assets.savers.singular, items)
