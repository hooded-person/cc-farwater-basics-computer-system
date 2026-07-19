package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"
local config = require "config"
local assets = require "assets"
local util = require "util"
package.path = package.path .. ';/lib/telem/vendor/?;/lib/telem/vendor/?.lua;/lib/telem/vendor/?/init.lua'
local telem = require 'telem'

local cycleDelay = config.data.prog_telem.cycleDelay
local stockticker_name = config.peripherals.logistics.stockticker
local ticker = peripheral.wrap(stockticker_name)

-- load item metadata
local base_dir = assets.getAssetDir("items")
local item_meta = assets.loadNamespaced(base_dir, assets.loaders.singular, true)

-- utility function
local function extractFromMetricName(metric_name)
    local metric_info = {}
    local delta_type = metric_name:match("_([^_]+)$")
    if delta_type == "idelta" or delta_type == "delta" or delta_type == "irate" or delta_type == "rate" then
        metric_info.delta_type = delta_type
        metric_name = metric_name:sub(1, #metric_name - #delta_type - 1)
    end
    local prefix, item_id = metric_name:match("^([^:]-:?)([^:]+:[^:]+)$")
end


-- setup the backplane
local backplane = telem.backplane()
    :cache(true)

-- Collect information about all items in the logistics network
backplane:addInput('stockticker', telem.input.custom(function()
    local stock = ticker.stock()

    -- we can not handle/sepperate nbt in a nice way, so we merge the counts here (otherwise the latest count wins, which aint right)
    local items = {}
    for _, item in ipairs(stock) do
        if items[item.name] == nil then
            items[item.name] = item.count
        else
            items[item.name] = items[item.name] + item.count
        end
    end

    local metrics = {}
    local total_count = 0
    for item_name, item_count in pairs(items) do
        total_count = total_count + item_count
        table.insert(metrics,
            telem.metric {
                name = "logistics:" .. item_name, -- .. (item.nbt == nil and "" or ":" .. item.nbt),
                value = item_count,
                unit = "items",
            }
        )
    end
    table.insert(metrics,
        telem.metric {
            name = "logistics:total", -- .. (item.nbt == nil and "" or ":" .. item.nbt),
            value = total_count,
            unit = "items",
        }
    )
    return table.unpack(metrics)
end))

-- output graphs
local graphs = config.data.prog_telem.graphs

for item_id, data in pairs(graphs) do
    local monitor_name
    local prefix = "logistics:"
    local fg = colors.red
    local bg = colors.black
    local maxEntries
    if type(data) == "string" then
        monitor_name = data
    elseif type(data) == "table" then
        monitor_name = data.monitor
        prefix = data.prefix or prefix
        fg = data.lineColor or fg
        bg = data.backgroundColor or bg
        maxEntries = data.maxEntries
    else
        error(("Invalid type '%s', expected string or table"):format(type(data)))
    end

    local mon = peripheral.wrap(monitor_name)
    mon.setTextScale(0.5)
    local monw, monh = mon.getSize()
    local win = window.create(mon, 1, 1, monw, monh)

    backplane:addOutput("mon_graph:" .. item_id, telem.output.plotter.line(
        win,
        prefix ~= nil and prefix .. item_id or item_id,
        bg, fg
    ))
end

-- display change rate
local rates_interval = config.data.prog_telem.rates_interval or "h"
backplane:middleware(telem.middleware.calcDelta(config.data.prog_telem.deltaWindowSize):interval("1" .. rates_interval))
local pinned_rates = config.data.prog_telem.pinned_rates

local isRatePinned = {}
for _, pinned_rate in ipairs(pinned_rates) do
    isRatePinned[pinned_rate .. "_rate"] = true
end

local monitor_counts = peripheral.wrap(config.data.prog_telem.monitor_counts)
local monitor_counts_w, monitor_counts_h = monitor_counts.getSize()
local win_counts = window.create(monitor_counts, 1, 1, monitor_counts_w, monitor_counts_h)

backplane:addOutput("mon_rates", telem.output.custom(function(collection)
    win_counts.setVisible(false)
    win_counts.clear()
    win_counts.setCursorPos(1, 1)

    local rateW, rateH = win_counts.getSize()

    -- get all rates (seperate pinned ones)
    local pinnedMetrics = {}
    local rates = {}
    for _, metric in ipairs(collection.metrics) do
        if metric.name:find("_rate$") then
            if isRatePinned[metric.name] then
                pinnedMetrics[metric.name] = metric
            else
                table.insert(rates, metric)
            end
        end
    end

    -- sort them descending
    table.sort(rates, function(a, b)
        if a.value ~= b.value then
            if math.abs(a.value) ~= math.abs(b.value) then
                return math.abs(a.value) > math.abs(b.value)
            else
                return a.value > b.value
            end
        else
            local _, item_id_a = a.name:match("^([^:]-:?)([^:]+:[^:]+)_rate$")
            local displayNameA = (item_meta[item_id_a] or {}).displayName
            local _, item_id_b = b.name:match("^([^:]-:?)([^:]+:[^:]+)_rate$")
            local displayNameB = (item_meta[item_id_b] or {}).displayName
            if displayNameA ~= nil and displayNameB ~= nil then
                return displayNameA < displayNameB
            end
        end
    end)

    -- generate the metrics we will show
    local displayedMetrics = {}
    local widths = { 0, 0, 0 }
    for _, pinned_rate in ipairs(pinned_rates) do
        local metric_name = pinned_rate .. "_rate"
        local metric = pinnedMetrics[metric_name]
        local prefix, item_id = pinned_rate:match("^([^:]-:?)([^:]+:[^:]+)$")
        local displayName = (item_meta[item_id] or {}).displayName
        local metricInfo = {
            displayName or item_id or pinned_rate,
            util.number.fancy(metric.value),
            metric.unit ~= nil and metric.unit or "",
            metric.value,
        }
        table.insert(displayedMetrics, metricInfo)
        for i = 1, 3 do
            local v = metricInfo[i]
            widths[i] = #v > widths[i] and #v or widths[i]
        end
    end
    table.insert(displayedMetrics, { "", "", "" }) -- easy empty line
    local remaining_space = rateH - #displayedMetrics
    for i = 1, remaining_space do
        local metric = rates[i]
        local prefix, item_id = metric.name:match("^([^:]-:?)([^:]+:[^:]+)_rate$")
        local displayName = (item_meta[item_id] or {}).displayName
        local metricInfo = {
            displayName or item_id or metric.name,
            util.number.fancy(metric.value),
            metric.unit ~= nil and metric.unit or "",
            metric.value,
        }
        table.insert(displayedMetrics, metricInfo)
        for i = 1, 3 do
            local v = metricInfo[i]
            widths[i] = #v > widths[i] and #v or widths[i]
        end
    end

    -- display the metrics
    local rate_unit_suffix = "/" .. rates_interval
    local value_width = 1 + widths[2] + 1 + widths[3] + #rate_unit_suffix
    local unit_width = widths[3] + #rate_unit_suffix
    for y, line in ipairs(displayedMetrics) do
        win_counts.setCursorPos(1, y)
        local name = line[1]
        if #name > rateW - value_width then
            name = name:sub(1, rateW - 2 - value_width) .. ".."
        end
        win_counts.write(name)

        win_counts.setCursorPos(rateW - value_width + 2, y)
        if line[4] ~= nil and line[4] > 0 then
            win_counts.setTextColor(colors.lime)
        elseif line[4] ~= nil and line[4] < 0 then
            win_counts.setTextColor(colors.red)
        else
            win_counts.setTextColor(colors.white)
        end
        win_counts.write(line[2])
        win_counts.setTextColor(colors.white)

        if line[1] ~= "" and line[2] ~= "" then
            win_counts.setCursorPos(rateW - unit_width + 1, y)
            win_counts.write(line[3] .. rate_unit_suffix)
        end
    end

    win_counts.setVisible(true)
end))


-- read all inputs and write all outputs, then wait cycleDelay seconds, repeating indefinitely
parallel.waitForAny(
    backplane:cycleEvery(cycleDelay)
)
