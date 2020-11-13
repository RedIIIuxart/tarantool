#!/usr/bin/env tarantool
local http_router = require('http.router')
local http_server = require('http.server')
local json = require('json')
local log = require('log')

local httpd = http_server.new('127.0.0.1',8080,{log_requests = true,log_errors = true})
local router = http_router.new()

box.cfg {
    listen = 3301,
    log_format = 'plain',
    log = 'server.log',
    background = true,
    pid_file = 'server.pid'
}

box.once('create', function()
    box.schema.space.create('test')
    box.space.test:format({
        { name = 'key', type = 'string' },
        { name = 'val', type = 'string' }
    })
    box.space.test:create_index('primary',
            { type = 'hash', parts = { 1, 'string' } })
end)

router:route({ method = 'POST', path = '/kv' }, function(req)
    local ok, key, val = isJsonPostCorrect(req)
    if not ok then
        return { status = 400 }
    end

    kv = box.space.test:get(key)
    if kv == nil or #kv == 0 then
        box.space.test:insert { key, val }
        log.info("Ok, key, val:")
        log.info(key)
        log.info(val)
        return { status = 200 }
    else
        log.info("Error: Key already exist:")
        log.info(key)
        return { status = 409 }
    end
end)

router:route({ method = 'PUT', path = '/kv/:key' }, function(req)
    local ok, key, val = isJsonPutCorrect(req)
    if not ok then
        return { status = 400 }
    end

    kv = box.space.test:get(key)
    if kv == nil or #kv == 0 then
        log.info("Error: Key not found")
        return { status = 404 }
    else
        box.space.test:update(key, { { '=', 2, val } })
        log.info("Ok, new value:")
        log.info(val)
        return { status = 200 }
    end
end)

router:route({ method = 'GET', path = '/kv/:key' }, function(req)
    local key, val, kv
    key = req:stash('key')

    kv = box.space.test:get(key)
    if kv == nil or #kv == 0 then
        log.info("Error: Key not found, key: " .. key)
        return { status = 404 }
    end
    val = kv[2]
    log.info("Ok, value:")
    log.info(val)
    return { status = 200, body = val }
end)

router:route({ method = 'DELETE', path = '/kv/:key' }, function(req)
    local key, kv

    key = req:stash('key')
    kv = box.space.test:get(key)
    if kv == nil or #kv == 0 then
        log.info("Error: Key not found, key: " .. key)
        return { status = 404 }
    end

    box.space.test:delete(key)
    log.info("Ok, key: " .. key)
    return { status = 200 }
end)

httpd:set_router(router)
httpd:start()   
