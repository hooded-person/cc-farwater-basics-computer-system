return {init=function(_,_,_,_,_,_)
    local SORT_BY_RED = function(a,b) return a[1] > b[1] end
    local SORT_BY_GRN = function(a,b) return a[2] > b[2] end
    local SORT_BY_BLU = function(a,b) return a[3] > b[3] end

    local function widest_channel_sort(r_min,g_min,b_min,r_max,g_max,b_max)
        local r_channel_delta = r_max-r_min
        local g_channel_delta = g_max-g_min
        local b_channel_delta = b_max-b_min

        if r_channel_delta >= g_channel_delta and r_channel_delta >= b_channel_delta then
            return SORT_BY_RED
        elseif g_channel_delta >= r_channel_delta and g_channel_delta >= b_channel_delta then
            return SORT_BY_GRN
        elseif b_channel_delta >= r_channel_delta and b_channel_delta >= g_channel_delta then
            return SORT_BY_BLU
        else
            return SORT_BY_GRN
        end
    end

    local function add_to_color(base_color,added)
        base_color[1] = base_color[1] + added[1]
        base_color[2] = base_color[2] + added[2]
        base_color[3] = base_color[3] + added[3]
    end

    local function divide_color(color,divisor)
        color[1] = color[1] / divisor
        color[2] = color[2] / divisor
        color[3] = color[3] / divisor
    end

    local HUGE       = math.huge
    local TABLE_SORT = table.sort

    local function median_cut(tbl,splits,parts,split_count)
        local tbl_len = #tbl

        if split_count < splits then
            local r_max = -HUGE
            local g_max = -HUGE
            local b_max = -HUGE

            local r_min = HUGE
            local g_min = HUGE
            local b_min = HUGE

            for c_index=1,tbl_len do
                local color = tbl[c_index]
                local r,g,b = color[1],color[2],color[3]

                if r < r_min then r_min = r end
                if g < r_min then g_min = g end
                if b < b_min then b_min = b end

                if r > r_max then r_max = r end
                if g > g_max then g_max = g end
                if b > b_max then b_max = b end
            end

            local sort_func = widest_channel_sort(
                r_min,g_min,b_min,
                r_max,g_max,b_max
            )

            TABLE_SORT(tbl,sort_func)

            local split_point  = math.floor(tbl_len/2+0.5)
            local split_list_1 = {}
            local split_list_2 = {}

            for i=1,split_point do
                split_list_1[i] = tbl[i]
            end
            for i=split_point+1,tbl_len do
                split_list_2[i-split_point] = tbl[i]
            end

            median_cut(split_list_1,splits,parts,split_count+1)
            median_cut(split_list_2,splits,parts,split_count+1)
        else
            local base_color = {0,0,0}

            for c_index=1,tbl_len do
                local color = tbl[c_index]
                add_to_color(base_color,color)
            end

            divide_color(base_color,tbl_len)

            parts[#parts+1] = base_color
        end
        return parts
    end

    local function deduplicate_color_list(color_list,bit_resolution)
        bit_resolution = bit_resolution or 8

        local unique_colors = {}
        local color_lookup  = {}

        local base_resolution_scale = 2^bit_resolution - 1

        local g_bit_shift = 2^bit_resolution
        local r_bit_shift = g_bit_shift^2

        local unique_color_count = 0

        for color_idx=1,#color_list do
            local color = color_list[color_idx]

            local r = color[1] * base_resolution_scale
            local g = color[2] * base_resolution_scale
            local b = color[3] * base_resolution_scale

            r = r - r % 1
            g = g - g % 1
            b = b - b % 1

            local index = r * r_bit_shift + g * g_bit_shift + b

            if not color_lookup[index] then
                unique_color_count = unique_color_count + 1

                unique_colors[unique_color_count] = color

                color_lookup[index] = true
            end
        end

        return unique_colors
    end

    local function median_cut_color_list(color_list,splits,dedup_bits)
        local unique_color_list = deduplicate_color_list(color_list,dedup_bits)

        if #unique_color_list <= 2^splits then
            return unique_color_list
        else
            return median_cut(unique_color_list,splits,{},0)
        end
    end

    return {
        medcut = {
            from_color_list = median_cut_color_list,
            internal = {
                deduplicate_color_list = deduplicate_color_list,
                widest_channel_sort    = widest_channel_sort,
                divide_color           = divide_color,
                median_cut             = median_cut,
                add_to_color           = add_to_color,
                SORT_BY_RED            = SORT_BY_RED,
                SORT_BY_GRN            = SORT_BY_GRN,
                SORT_BY_BLU            = SORT_BY_BLU
            }
        }
    },{}
end,
    id         = "PB_MODULE:medcut",
    name       = "PB_MedianCut",
    author     = "9551",
    contact    = "https://devvie.cc/contact",
    report_msg = "\n__name: module error, report issues at\n-> __contact"
}