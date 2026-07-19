package.path = package.path .. ";/lib/?.lua;/lib/?/init.lua"
local pngImage = require("png")
local pixelbox = require("pixelbox.bb_lite")

local player_head = {
    url_template = "https://mc-heads.net/avatar/%s/8"
}

function player_head.getPngImage(url)
    local res = http.get(url)
    local data = res.readAll()
    if res.getResponseCode() ~= 200 then
        error(res.getResponseCode())
    end
    res.close()
    local img = pngImage(nil, { input = data })
    return img
end

function player_head.pngImageConvert(imgPng)
    local img = {}
    local color_list = {}
    for y = 1, imgPng.height do
        img[y] = {}
        for x = 1, imgPng.width do
            local pixel = imgPng:get_pixel(x, y)
            img[y][x] = {
                r = pixel.r,
                g = pixel.g,
                b = pixel.b,
            }
            table.insert(color_list, { pixel.r, pixel.g, pixel.b })
        end
    end
    return img, color_list
end

function player_head.getPngImageForPlayer(name)
    return player_head.getPngImage(player_head.url_template:format(name))
end

function player_head.drawPngImage(x, y, imgPng, terminal, paletteOverwriteIndexes)
    paletteOverwriteIndexes = paletteOverwriteIndexes or { 2, 3, 6, 9, 10, 11, 12, 13 }
    local splits = math.log(#paletteOverwriteIndexes, 2) -- 2^3 = 8 colors in palette
    if splits ~= math.floor(splits) and splits < 5 and splits > 0 then
        error("paletteOverwriteIndexes length must be a 2^n (1 <= n <= 4)")
    end

    local box = pixelbox.new(terminal)
    box:load_module {
        require("pixelbox.pb_arrutil"),
        require("pixelbox.pb_rgbquant"),
        require("pixelbox.pb_medcut"),
        force   = false,
        supress = false,
    }
    -- generate img[y][x] table and color list
    local img, color_list = player_head.pngImageConvert(imgPng)

    local palette = box.medcut.from_color_list(color_list, splits)
    -- convert palette for rgbquant
    local rgbquant_palette = {}
    for i = 1, #palette do
        table.insert(rgbquant_palette, {
            palette_index = paletteOverwriteIndexes[i],
            color = {
                r = palette[i][1],
                g = palette[i][2],
                b = palette[i][3]
            }
        })
    end

    local colorspace = box.rgbquant.make_colorspace(rgbquant_palette)

    for img_y = 1, #img do
        for img_x = 1, #img[img_y] do
            local pixel = img[img_y][img_x]
            local r, g, b = pixel.r, pixel.g, pixel.b
            img[img_y][img_x] = box.rgbquant.from_rgb(colorspace, r, g, b)
        end
    end

    -- apply palette
    for i = 1, #rgbquant_palette do
        local index = rgbquant_palette[i].palette_index
        local color = rgbquant_palette[i].color
        terminal.setPaletteColor(2 ^ index, color.r, color.g, color.b)
    end

    local offset_x = x - 1
    local offset_y = y - 1
    for img_y = 1, #img do
        for img_x = 1, #img[img_y] do
            local color = 2 ^ img[img_y][img_x]
            box.canvas[img_y + offset_y][img_x + offset_x] = color
        end
    end
    box:render()
end

function player_head.drawPlayerHead(x, y, name, terminal)
    if terminal == nil then
        terminal = term.current()
    end
    local win
    if terminal.getPosition ~= nil and select(1, terminal.getSize()) == 8 and select(2, terminal.getSize()) == 6 then
        win = terminal
        win.setVisible(false)
        win.reposition(x, y)
    else
        win = window.create(terminal,
            x, y,
            8, 6, -- 8x8 bixels = 8x6 chars
            false
        )
    end
    local imgPng = player_head.getPngImageForPlayer(name)

    player_head.drawPngImage(1, 1, imgPng, win) -- {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15})

    win.setVisible(true)
    return win
end

return player_head
