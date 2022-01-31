function time_queue(len_lim)
    local first, last = 0, -1
    local out = {}
        out.len_lim = len_lim or 5000
        
        out.len = function()
            return last - first + 1
        end

        out.pop = function()
            if (first <= last) then
                local value = out[first]
                out[first] = nil
                first = first + 1
                --print("Poped", value)
            end
        end

        out.push = function(item)
            if (out:len() < len_lim) then
                last = last + 1
                out[last] = item
                --print("Pushed", item)
                return true
            else
                if (item - out[first] < 1) then
                    --print("Skiped", item)
                    return false
                else
                    out:pop()
                    out.push(item)
                    return true
                end
            end
        end

    return out
end

return time_queue
