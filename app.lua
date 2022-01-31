#!/usr/bin/env tarantool

package.path = package.path .. ";src/?.lua"

local Config = require("config")
local Server = require("Server")


server = Server:new(Config)
server:start()
