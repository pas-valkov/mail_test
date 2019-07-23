#!/usr/bin/env tarantool

json = require('json')
fio = require('fio')

local key = 'key'
local value = 'value'

local xlog_dir = 'xlogs'
local snaps_dir = 'snaps'
local log_file = 'logs.log'

if not fio.path.exists(xlog_dir) then
	fio.mkdir(xlog_dir)
end

if (not fio.path.exists(snaps_dir)) then
	fio.mkdir(snaps_dir)
end

box.cfg {
	log_level = 5;
	wal_dir = xlog_dir;
	memtx_dir = snaps_dir;
	log = log_file;
}

if (not box.space.mail_test_data) then
	sp = box.schema.space.create('mail_test_data')
	sp:create_index('primary', {type = 'hash', parts = {1, 'string'}})
end

local function handler(req)
	req:json()
	-- i didn't figure out a better way to check empty body
end

local function post_method(req)
	if (not pcall(handler, req)) then
		return { status = 400 }
	end
	
	local json_key = req:json()[key]
	local json_value = req:json()[value]
	if (json_key == nil or json_value == nil) then
		return { status = 400 }
	else
		local obj = box.space.mail_test_data:get(json_key)
		if (obj == nil) then
			box.space.mail_test_data:insert{json_key, json_value}
		else
			return { status = 409 }
		end
	end
end

local function get_method(req)
	local id = req:stash('id')
	local obj = box.space.mail_test_data:get(id)
	if (obj == nil) then
		return { status = 404 }
	else
		return req:render({ json = obj })
	end
end

local function put_method(req)
	if (not pcall(handler, req)) then
		return { status = 400 }
	end
	local id = req:stash('id')
	local json_value = req:json()[value]
	if (json_value == nil) then
		return { status = 400 }
	else
		if (box.space.mail_test_data:get(id) == nil) then
			return { status = 404 }
		else
			box.space.mail_test_data:put{id, json_value}
		end
	end
end

local function delete_method(req)
	local id = req:stash('id')
	local obj = box.space.mail_test_data:delete(id)
	if obj == nil then
		return { status = 404 }
	end
end

local server = require('http.server').new(nil, 8080)
server:route({ path = '/mailtest', method = 'POST' }, post_method)
server:route({ path = '/mailtest/:id', method = 'GET' }, get_method)
server:route({ path = '/mailtest/:id', method = 'PUT' }, put_method)
server:route({ path = '/mailtest/:id', method = 'DELETE' }, delete_method)
server:start()
