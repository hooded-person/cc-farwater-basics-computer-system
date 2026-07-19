return {init=function(box,module,api,share,api_init,load_flags)
    local function create_multilayer_list(n,tbl)
        tbl = tbl or {}
        if n == 0 then return tbl end
        return setmetatable(tbl, {__index = function(t, k)
            local new = create_multilayer_list(n-1)
            --if k == nil then error("Table index is nil",2) end
            t[k] = new
            return new
        end})
    end

    local function metatable_remap(tbl,mappings)
        local remapped_list = setmetatable({},{__index=function(self,key)
            local remapped_val = mappings[key]
            if remapped_val then
                return rawget(tbl,remapped_val)
            else
                return rawget(tbl,key)
            end
        end})

        return remapped_list
    end

    local function indexer_2d_remap_yx(tbl,key,width)
        local y_index = key/(width+1)
        y_index = (y_index - y_index%1) + 1

        local x_index = (key-1)%width+1

        return tbl[y_index][x_index]
    end

    local function indexer_2d_remap_pnglua(tbl,key,width,height)
        local y_index = key/(width+1)
        y_index = (y_index - y_index%1) + 1

        local x_index = (key-1)%width+1

        return tbl[y_index].pixels[x_index]
    end

    local function metatable_value_remap(tbl,remapping_func)
        local remapped_list = setmetatable({},{
            __index = function(self,key)
                local value = tbl[key]

                if value then
                    return remapping_func(value,key,self)
                end
            end,
            __len = function() return #tbl end
        })

        return remapped_list
    end

    local function metatable_value_remap_memoized(tbl,remapping_func)
        local remapped_list = setmetatable({},{
            __index = function(self,key)
                if rawget(self,key) ~= nil then
                    return rawget(self,key)
                end

                local value = tbl[key]

                if value then
                    local remapped_value = remapping_func(value,key,self)
                    rawset(self,key,remapped_value)
                    return remapped_value
                end
            end,
            __len = function() return #tbl end
        })

        return remapped_list
    end


    local function clone_value_remap(tbl,remapping_func)
        local remapped_list = {}

        for i=1,#tbl do
            remapped_list[i] = remapping_func(tbl[i])
        end

        return remapped_list
    end

    local function metatable_1d_scale_remap(tbl,original_width,original_height,new_width,new_height)
        local inverse_width = 1/new_width

        local inverse_small_width  = 1/(new_width  - 1)
        local inverse_small_height = 1/(new_height - 1)

        local remapped_list = setmetatable({},{
            __index = function(_, index)
                local decoded_x = (index - 1) % new_width
                local decoded_y = (index - 1) * inverse_width
                decoded_y = decoded_y - decoded_y%1

                local normalized_x = decoded_x * inverse_small_width
                local normalized_y = decoded_y * inverse_small_height

                local original_x = normalized_x * (original_width  - 1)
                local original_y = normalized_y * (original_height - 1)

                original_x = original_x - original_x%1
                original_y = original_y - original_y%1

                local mapped_index = original_y * original_width + original_x + 1

                return tbl[mapped_index]
            end,

            __len = function()
                return new_width*new_height
            end
        })

        return remapped_list
    end

    local function metatable_remap_2d_to_1d(tbl,width,height,indexer)
        indexer = indexer or indexer_2d_remap_yx

        local size = width*height
        local remapped_list = setmetatable({},{__index=function(self,key)
            return indexer(tbl,key,width,height)
        end,__len=function()
            return size
        end})

        return remapped_list
    end

    return {arrutil = {
        create_multilayer_list = create_multilayer_list,
        mt_key_remap           = metatable_remap,
        mt_val_remap           = metatable_value_remap,
        mt_val_remap_mem       = metatable_value_remap_memoized,
        mt_scale_remap         = metatable_1d_scale_remap,
        mt_remap_2d_to_1d      = metatable_remap_2d_to_1d,

        cl_val_remap = clone_value_remap,

        map = {
            pnglua = indexer_2d_remap_pnglua,
            yx     = indexer_2d_remap_yx,
        }
    }},{}
end,
    id         = "PB_MODULE:arrutil",
    name       = "PB_ArrayUtil",
    author     = "9551",
    contact    = "https://devvie.cc/contact",
    report_msg = "\n__name: module error, report issues at\n-> __contact"
}