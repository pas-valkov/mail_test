fio = require('fio')
queue = require('TimeQueue')
logger = require("log")
http_server = require('http.server')

local Codes = {
    SUCCESS = 200,
    BODY_ERROR = 400,
    KEY_NOT_FOUND = 404,
    KEY_EXISTS = 409,
    LIMIT_EXCEEDED = 429
}

local Server = {
    req_fields = {
        key = 'key',
        value = 'value'
    }
}
setmetatable(Server, {__index = http_server})
Server.__index = Server

function Server:new(config)
    self.storage_name = config.storage_name
    self.queue = queue(config.request_limit)

    self:prepare_config(config)

    local httpd = setmetatable(http_server.new(nil, config.port), self)
        httpd:route({ path = config.storage_name, method = 'POST' }, Server.post_method)
        httpd:route({ path = config.storage_name..'/:id', method = 'GET' }, Server.get_method)
        httpd:route({ path = config.storage_name..'/:id', method = 'PUT' }, Server.put_method)
        httpd:route({ path = config.storage_name..'/:id', method = 'DELETE' }, Server.delete_method)
    return httpd
end

local function json_body_handler(req) -- todo simplify
    return req:json()
end

function Server:prepare_config(config)
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

function Server.post_method(req) --todo use self not Server
    if (not Server.queue.push(os.time())) then
        logger.debug("POST [Status: %s]", Codes.LIMIT_EXCEEDED)
        return { status = Codes.LIMIT_EXCEEDED }
    end

    local body_exists, body = pcall(json_body_handler, req)

    if (not body_exists) then
        logger.debug("POST [Status: %s]", Codes.BODY_ERROR)
        return { status = Codes.BODY_ERROR }
    end


    local json_key = body[Server.req_fields.key]
    local json_value = body[Server.req_fields.value]
    
    if (json_key == nil or json_value == nil) then
        logger.debug("POST [Status: %s]", Codes.BODY_ERROR)
        return { status = Codes.BODY_ERROR }
    end

    local obj = box.space[Server.storage_name]:get(json_key)
    if (obj == nil) then
        box.space[Server.storage_name]:insert{json_key, json_value}
        logger.debug("POST [Status: %s] [Body %s]", Codes.SUCCESS, body)
        return { status = Codes.SUCCESS }
    else
        logger.debug("POST [Status: %s]", Codes.KEY_EXISTS)
        return { status = Codes.KEY_EXISTS }
    end
end

function Server.get_method(req)
    if (not Server.queue.push(os.time())) then
        logger.debug("GET [Status: %s]", Codes.LIMIT_EXCEEDED)
        return { status = Codes.LIMIT_EXCEEDED }
    end

    local id = req:stash('id') 
    local obj = box.space[Server.storage_name]:get(id)
    if (obj == nil) then
        logger.debug("GET [Status: %s]", Codes.KEY_NOT_FOUND)
        return { status = Codes.KEY_NOT_FOUND }
    else
        logger.debug("GET [Status %s] [Key: %s]", Codes.SUCCESS, id)
        local body = {}
            body[Server.req_fields.value] = obj[2]
        return req:render({ json = body })
    end
end

function Server.put_method(req)
    if (not Server.queue.push(os.time())) then
        logger.debug("PUT [Status: %s]", Codes.LIMIT_EXCEEDED)
        return { status = Codes.LIMIT_EXCEEDED }
    end

    local body_exists, body = pcall(json_body_handler, req)
    if (not body_exists) then
        logger.debug("PUT [Status: %s]", Codes.BODY_ERROR)
        return { status = Codes.BODY_ERROR }
    end
    local id = req:stash('id')
    local json_value = body[Server.req_fields.value]
    if (json_value == nil) then
        logger.debug("PUT [Status: %s]", Codes.BODY_ERROR)
        return { status = Codes.BODY_ERROR }
    end
    
    if (box.space[Server.storage_name]:get(id) == nil) then
        logger.debug("PUT [Status: %s]", Codes.KEY_NOT_FOUND)
        return { status = Codes.KEY_NOT_FOUND }
    else
        box.space[Server.storage_name]:put{id, json_value}
        logger.debug("PUT [Status: %s] [Body: %s]", Codes.SUCCESS, body)
        return { status = Codes.SUCCESS }
    end
end

function Server.delete_method(req)
    if (not Server.queue.push(os.time())) then
        logger.debug("DELETE [Status: %s]", Codes.LIMIT_EXCEEDED)
        return { status = Codes.LIMIT_EXCEEDED }
    end

    local id = req:stash('id')
    local obj = box.space[Server.storage_name]:delete(id)
    if obj == nil then
        logger.debug("DELETE [Status: %s]", Codes.KEY_NOT_FOUND)
        return { status = Codes.KEY_NOT_FOUND }
    end
    logger.debug("DELETE [Status: %s] [Key: %s]", Codes.SUCCESS, id)
    return { status = Codes.SUCCESS }
end


return Server
