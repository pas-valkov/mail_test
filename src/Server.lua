fio = require('fio')
--queue = require('TimeQueue')
http_server = require('http.server')

local Server = {
    req_fields = {
        key = 'key',
        value = 'value'
    }
}
setmetatable(Server, {__index = http_server})
Server.__index = Server

function Server:new(config)
    Server.storage_name = config.storage_name
    --Server.queue = queue(config.request_limit)

    local self = setmetatable(http_server.new(nil, config.port), Server)

    self:prepare_config(config)

    self:route({ path = config.storage_name, method = 'POST' }, self.post_method)
    self:route({ path = config.storage_name..'/:id', method = 'GET' }, self.get_method)
    self:route({ path = config.storage_name..'/:id', method = 'PUT' }, self.put_method)
    self:route({ path = config.storage_name..'/:id', method = 'DELETE' }, self.delete_method)
    return self
end

local function json_body_handler(req)
    return req:json()
end

function Server:prepare_config(config) -- todo make it private
    for _, dir_ in ipairs({ config.xlog_dir, config.snaps_dir }) do
        if (not fio.path.exists(dir_)) then
            os.execute( "mkdir -p " .. dir_)
        end
    end

    for _, file_ in ipairs({ config.log_file_name }) do
        os.execute('mkdir -p $(dirname '..file_..')') --..' && touch '..file_
    end

    box.cfg {
        wal_dir = config.xlog_dir;
        memtx_dir = config.snaps_dir;
        log = config.log_file_name;
        log_level = config.log_level;
    }

    if (not box.space[config.storage_name]) then
        sp = box.schema.space.create(config.storage_name)
        sp:create_index('primary', {type = 'hash', parts = {1, 'string'}})
    end
end

function Server.post_method(req)
    --Server.queue.push(os.time())

    body_exists, body = pcall(json_body_handler, req)

    if (not body_exists) then
        return { status = 400 }
    end


    local json_key = body[Server.req_fields.key]
    local json_value = body[Server.req_fields.value]
    
    if (json_key == nil or json_value == nil) then
        return { status = 400 }
    end

    local obj = box.space[Server.storage_name]:get(json_key)
    if (obj == nil) then
        box.space[Server.storage_name]:insert{json_key, json_value}
    else
        return { status = 409 }
    end
end

function Server.get_method(req)
    --Server.queue.push(os.time())

    local id = req:stash('id') 
    local obj = box.space[Server.storage_name]:get(id)
    if (obj == nil) then
        return { status = 404 }
    else
        return req:render({ json = obj })
    end
end

function Server.put_method(req)
    --Server.queue.push(os.time())

    body_exists, body = pcall(json_body_handler, req)
    if (not body_exists) then
        return { status = 400 }
    end
    local id = req:stash('id')
    local json_value = body[Server.req_fields.value]
    if (json_value == nil) then
        return { status = 400 }
    end
    
    if (box.space[Server.storage_name]:get(id) == nil) then
        return { status = 404 }
    else
        box.space[Server.storage_name]:put{id, json_value}
    end
end

function Server.delete_method(req)
    --Server.queue.push(os.time())

    local id = req:stash('id')
    local obj = box.space[Server.storage_name]:delete(id)
    if obj == nil then
        return { status = 404 }
    end
end


return Server
