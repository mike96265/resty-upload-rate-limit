local ngx_req = ngx.req
local req_socket = ngx.req.socket
local ngx_now = ngx.now
local ngx_sleep = ngx.sleep
local _M = { version = '0.0.3' }

local CHUNK_SIZE = 4
local BUFFER_SIZE = 128

local mt = {
    __index = _M
}

local function limit_upload_rate(rate, after, buf_size, chunk_size)
    if rate then
        local sock,err = req_socket()
        if ( err == "no body" ) then
            ngx.log(ngx.ERR,err)
            return
        end
        local start = ngx_now()

        local rate_in_bytes = rate * 1024
        local body_size = 0 - after * 1024
        local content_length = tonumber(ngx.req.get_headers()["Content-Length"])

        ngx_req.init_body(buf_size * 1024)
        while true do
            local read_size = chunk_size * 1024
            if content_length > 0 and content_length < read_size then
                read_size = content_length
            end
            content_length = content_length - read_size
            local chunk, err = sock:receive(read_size)
            if not chunk then
                if err == "closed" then
                    break
                else
                    ngx.log(ngx.ERR, "fail to read request body, err: " .. err)
                    return false, "fail to read body"
                end
            else
                ngx_req.append_body(chunk)
                body_size = body_size + #chunk
                local delay = ngx_now() - start
                local expected = body_size / rate_in_bytes
                local interval = expected - delay
                if interval > 0 then
                    ngx_sleep(interval)
                end
            end
        end
        ngx_req.finish_body()
        return true, ""
    else
        ngx_req.read_body()
        return true, ""
    end
end

function _M.new(self, rate, after, buf_size, chunk_size)
    return setmetatable({
        rate = rate or 0,
        after = after or 0,
        buf_size = buf_size or BUFFER_SIZE,
        chunk_size = chunk_size or CHUNK_SIZE
    }, mt)
end

function _M.upload(self)
    return limit_upload_rate(self.rate, self.after, self.buf_size, self.chunk_size)
end



return _M
