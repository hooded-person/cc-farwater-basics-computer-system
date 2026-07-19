local util = { number = {} }

function util.number.fancy(n, digits)
    digits = digits or 2
    local suffixes = {
        K = 1000,
        M = 1000000,
        B = 1000000000,
    }
    local suffix = nil
    for possible_suffix, factor in pairs(suffixes) do
        if n / factor > 1 then
            suffix = possible_suffix
        end
    end

    if suffix then
        n = n / suffixes[suffix]
    end

    n = math.floor(n * math.pow(10, digits) + 0.5) / math.pow(10, digits)

    return tostring(n) .. (suffix ~= nil and suffix or "")
end

return util
