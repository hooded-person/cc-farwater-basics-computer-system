return {init=function(box,module,api,_,_,load_flags)
    local dep_arrutil

    local function pythagorean_quantize(palette,r,g,b,color_space)
        if color_space then
            r,g,b = color_space(r,g,b)
        end

        local closest_distance = math.huge
        local closest_index    = nil

        for pal_index=1,#palette do
            local palette_entry = palette[pal_index].color

            local palette_a,palette_b,palette_c
                = palette_entry.r,palette_entry.g,palette_entry.b

            if color_space then
                palette_a,palette_b,palette_c = color_space(
                    palette_a,palette_b,palette_c
                )
            end

            local delta_r = palette_a - r
            local delta_g = palette_b - g
            local delta_b = palette_c - b

            -- ommiting sqrt
            local color_distance = delta_r^2+delta_g^2+delta_b^2
            if color_distance <= closest_distance then
                closest_distance = color_distance
                closest_index    = palette[pal_index].palette_index
            end
        end

        return closest_index
    end

    local function generate_lookup_space(base,r_res,g_res,b_res,data_colorspace)
        local color_space = dep_arrutil.create_multilayer_list(2)

        local reverse_map = {}
        for i=1,#base do
            local base_value = base[i]

            reverse_map[base_value.palette_index] = i
        end

        for r_position=0,r_res do
            for g_position=0,g_res do
                for b_position=0,b_res do
                    local r_normalized = r_position/r_res
                    local g_normalized = g_position/g_res
                    local b_normalized = b_position/b_res

                    color_space[r_position][g_position][b_position] = pythagorean_quantize(
                        base,r_normalized,g_normalized,b_normalized,
                        data_colorspace
                    )
                end
            end
        end

        color_space.r_upper_bound = r_res
        color_space.g_upper_bound = g_res
        color_space.b_upper_bound = b_res

        color_space.source_palette = base
        color_space.reverse_map    = reverse_map

        return color_space
    end

    local function palette_index_from_rgb(color_space,r,g,b)
        local r_snapped = r*color_space.r_upper_bound
        local g_snapped = g*color_space.g_upper_bound
        local b_snapped = b*color_space.b_upper_bound

        r_snapped = r_snapped - r_snapped % 1
        g_snapped = g_snapped - g_snapped % 1
        b_snapped = b_snapped - b_snapped % 1

        return color_space[r_snapped][g_snapped][b_snapped]
    end

    local function quant_rgb_from_rgb(color_space,r,g,b)
        local r_snapped = r*color_space.r_upper_bound
        local g_snapped = g*color_space.g_upper_bound
        local b_snapped = b*color_space.b_upper_bound

        r_snapped = r_snapped - r_snapped % 1
        g_snapped = g_snapped - g_snapped % 1
        b_snapped = b_snapped - b_snapped % 1

        local index = color_space[r_snapped][g_snapped][b_snapped]

        return color_space.source_palette[
            color_space.reverse_map[index]
        ].color
    end

    local function user_end_make_colorspace(palette,scale_r_res,g_res,b_res,color_space)
        if not scale_r_res then
            scale_r_res = math.sqrt(#palette)*2
        end

        if not g_res or not b_res then
            g_res = scale_r_res
            b_res = scale_r_res
        end

        return generate_lookup_space(
            palette,
            scale_r_res,g_res,b_res,
            color_space
        )
    end

    return {
        rgbquant = {
            from_rgb        = palette_index_from_rgb,
            idx_from_rgb    = palette_index_from_rgb,
            rgb_from_rgb    = quant_rgb_from_rgb,
            make_colorspace = user_end_make_colorspace,

            internal = {
                pythagorean_quantize  = pythagorean_quantize,
                generate_lookup_space = generate_lookup_space,
            }
        }
    },{verified_load=function()
        if not box.modules["PB_MODULE:arrutil"] then
            api.module_error(module,"Missing dependency PB_MODULE:arrutil",3,load_flags.supress)
        end

        dep_arrutil = box.modules["PB_MODULE:arrutil"].__fn.arrutil
    end}
end,
    id         = "PB_MODULE:rgbquant",
    name       = "PB_RGBQuantizer",
    author     = "9551",
    contact    = "https://devvie.cc/contact",
    report_msg = "\n__name: module error, report issues at\n-> __contact"
}