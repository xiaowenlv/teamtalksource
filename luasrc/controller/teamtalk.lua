module("luci.controller.teamtalk", package.seeall)

local fs = require("nixio.fs")
local sys = require("luci.sys")
local uci = require("luci.model.uci").cursor()

teamtalk = {}

function index()
    entry({"admin", "services", "teamtalk"}, alias("admin", "services", "teamtalk", "status"), _("TeamTalk"), 80)
    entry({"admin", "services", "teamtalk", "status"}, view("teamtalk/status"), _("Status"), 1)
    entry({"admin", "services", "teamtalk", "config"}, view("teamtalk/config"), _("Configuration"), 2)
    entry({"admin", "services", "teamtalk", "users"}, view("teamtalk/users"), _("Users"), 3)
    entry({"admin", "services", "teamtalk", "logs"}, view("teamtalk/logs"), _("Logs"), 4)
    entry({"admin", "services", "teamtalk", "docker_action"}, form("teamtalk/docker_action"), _("Docker Actions"), 5)
end

function teamtalk.get_docker_info()
    local docker_info = {
        installed = false,
        running = false,
        version = "",
        containers = {},
        images = {}
    }

    local ret = sys.exec("which docker")
    if ret and ret ~= "" then
        docker_info.installed = true
        local version = sys.exec("docker --version 2>/dev/null | head -1")
        docker_info.version = version:gsub("\n", "")

        local ps = sys.exec("docker ps -a --format '{{.Names}}|{{.Status}}|{{.Image}}' 2>/dev/null")
        if ps then
            for line in ps:gmatch("[^\r\n]+") do
                local parts = {}
                for part in line:gmatch("[^|]+") do
                    table.insert(parts, part)
                end
                if #parts >= 3 then
                    table.insert(docker_info.containers, {
                        name = parts[1],
                        status = parts[2],
                        image = parts[3]
                    })
                end
            end
        end

        local images = sys.exec("docker images --format '{{.Repository}}:{{.Tag}}|{{.ID}}' 2>/dev/null")
        if images then
            for line in images:gmatch("[^\r\n]+") do
                local parts = {}
                for part in line:gmatch("[^|]+") do
                    table.insert(parts, part)
                end
                if #parts >= 2 then
                    table.insert(docker_info.images, {
                        name = parts[1],
                        id = parts[2]
                    })
                end
            end
        end

        local running = sys.exec("docker info 2>/dev/null | grep 'Server Version'")
        if running and running ~= "" then
            docker_info.running = true
        end
    end

    return docker_info
end

function teamtalk.check_container_status(name)
    local status = sys.exec(string.format("docker ps --filter 'name=%s' --format '{{.Status}}' 2>/dev/null", name))
    return status and status ~= "" and status:gsub("\n", "") or "stopped"
end

function teamtalk.is_tt5srv_running()
    local uci = require("luci.model.uci").cursor()
    local name = uci:get("teamtalk", "global", "container_name") or "tt5srv"
    local status = sys.exec(string.format("docker ps --filter 'name=%s' --format '{{.Status}}' 2>/dev/null", name))
    return status and status:match("Up") ~= nil
end

function teamtalk.pull_image(image_name, callback)
    local cmd = string.format("docker pull %s 2>&1", image_name)
    local handle = io.popen(cmd)
    local result = handle:read("*all")
    handle:close()
    return result
end

function teamtalk.check_port_available(port, proto)
    proto = proto or "tcp"
    local cmd = string.format("netstat -tln 2>/dev/null | grep -E ':%s' | grep -q '%s' && echo 'in_use' || echo 'free'", port, proto)
    local ret = sys.exec(cmd)
    return ret:match("free") ~= nil
end

function teamtalk.check_port_conflict(tcp_port, udp_port, http_port, http_enabled)
    local conflicts = {}
    
    if not teamtalk.check_port_available(tcp_port, "tcp") then
        table.insert(conflicts, "TCP " .. tcp_port .. " is already in use")
    end
    
    if not teamtalk.check_port_available(udp_port, "udp") then
        table.insert(conflicts, "UDP " .. udp_port .. " is already in use")
    end
    
    if http_enabled == "1" and http_port then
        if not teamtalk.check_port_available(http_port, "tcp") then
            table.insert(conflicts, "HTTP " .. http_port .. " is already in use")
        end
    end
    
    return conflicts
end

function teamtalk.find_available_port(start_port, proto)
    local port = tonumber(start_port) or 10333
    local max_attempts = 100
    
    for i = 0, max_attempts do
        local check_port = port + i
        if teamtalk.check_port_available(check_port, proto) then
            return check_port
        end
    end
    
    return nil
end

function teamtalk.get_tt5srv_config()
    local uci = require("luci.model.uci").cursor()
    local srv_dir = uci:get("teamtalk", "volume", "srv_dir") or "/mnt/teamtalk/srv"
    local config_file = srv_dir .. "/ttd.json"
    
    local content = sys.exec(string.format("cat %s 2>/dev/null || echo '{}'", config_file))
    return content
end

function teamtalk.update_tt5srv_config()
    local uci = require("luci.model.uci").cursor()
    local srv_dir = uci:get("teamtalk", "volume", "srv_dir") or "/mnt/teamtalk/srv"
    local tcp_port = uci:get("teamtalk", "ports", "tcp_port") or "10333"
    local udp_port = uci:get("teamtalk", "ports", "udp_port") or "10333"
    local http_port = uci:get("teamtalk", "ports", "http_port") or "10334"
    local http_enabled = uci:get("teamtalk", "ports", "http_enabled") or "0"
    
    local config_file = srv_dir .. "/ttd.json"
    local content = sys.exec(string.format("cat %s 2>/dev/null", config_file))
    
    if content and content ~= "" and content ~= "{}" then
        local new_content = content
        new_content = new_content:gsub('"tcpport"%s*:%s*"%d+"', '"tcpport": "' .. tcp_port .. '"')
        new_content = new_content:gsub('"udpport"%s*:%s*"%d+"', '"udpport": "' .. udp_port .. '"')
        
        if http_enabled == "1" then
            new_content = new_content:gsub('"httpport"%s*:%s*"%d+"', '"httpport": "' .. http_port .. '"')
        end
        
        sys.exec(string.format("echo '%s' > %s", new_content:gsub("'", "'\\''"), config_file))
        return true
    end
    
    return false
end

function teamtalk.deploy_tt5srv()
    local uci = require("luci.model.uci").cursor()
    local image = uci:get("teamtalk", "global", "docker_image") or "deepcomp/tt5srv:latest"
    local name = uci:get("teamtalk", "global", "container_name") or "tt5srv"
    local srv_dir = uci:get("teamtalk", "volume", "srv_dir") or "/mnt/teamtalk/srv"
    local timezone = uci:get("teamtalk", "settings", "timezone") or "Asia/Shanghai"
    local puid = uci:get("teamtalk", "settings", "puid") or "1000"
    local pgid = uci:get("teamtalk", "settings", "pgid") or "1000"
    local tcp_port = uci:get("teamtalk", "ports", "tcp_port") or "10333"
    local udp_port = uci:get("teamtalk", "ports", "udp_port") or "10333"
    local http_port = uci:get("teamtalk", "ports", "http_port") or "10334"
    local http_enabled = uci:get("teamtalk", "ports", "http_enabled") or "0"

    sys.exec(string.format("mkdir -p %s", srv_dir))
    sys.exec(string.format("mkdir -p %s/files", srv_dir))

    teamtalk.update_tt5srv_config()

    local http_env = ""
    if http_enabled == "1" then
        http_env = string.format(" -e HTTPPORT=%s", http_port)
    end

    local cmd = string.format(
        "docker run -d --name %s --network host -v %s:/srv -e TZ=%s -e PUID=%s -e PGID=%s -e TCPPORT=%s -e UDPPORT=%s %s %s",
        name, srv_dir, timezone, puid, pgid, tcp_port, udp_port, http_env, image
    )

    return sys.exec(cmd .. " 2>&1")
end

function teamtalk.run_setup_wizard()
    local uci = require("luci.model.uci").cursor()
    local srv_dir = uci:get("teamtalk", "volume", "srv_dir") or "/mnt/teamtalk/srv"

    sys.exec(string.format("mkdir -p %s", srv_dir))
    sys.exec(string.format("mkdir -p %s/files", srv_dir))

    local cmd = string.format(
        "docker run -v %s:/srv --rm -it --entrypoint tt5srv deepcomp/tt5srv:latest -wizard -wd /srv",
        srv_dir
    )

    return sys.exec(cmd .. " 2>&1")
end

function teamtalk.start_container(name)
    return sys.exec(string.format("docker start %s 2>&1", name))
end

function teamtalk.stop_container(name)
    return sys.exec(string.format("docker stop %s 2>&1", name))
end

function teamtalk.restart_container(name)
    return sys.exec(string.format("docker restart %s 2>&1", name))
end

function teamtalk.remove_container(name)
    return sys.exec(string.format("docker rm -f %s 2>&1", name))
end

function teamtalk.remove_image(image_name)
    return sys.exec(string.format("docker rmi %s 2>&1", image_name))
end

function teamtalk.get_container_logs(name, lines)
    lines = lines or 100
    return sys.exec(string.format("docker logs --tail %d %s 2>&1", lines, name))
end

function teamtalk.get_config()
    local config = {}
    local uci = require("luci.model.uci").cursor()

    config.global = uci:get_all("teamtalk", "global") or {}
    config.settings = uci:get_all("teamtalk", "settings") or {}
    config.server = uci:get_all("teamtalk", "server") or {}
    config.login = uci:get_all("teamtalk", "login") or {}
    config.ports = uci:get_all("teamtalk", "ports") or {}
    config.storage = uci:get_all("teamtalk", "storage") or {}
    config.volume = uci:get_all("teamtalk", "volume") or {}

    return config
end

function teamtalk.save_config(data)
    local uci = require("luci.model.uci").cursor()

    if data.global then
        for k, v in pairs(data.global) do
            uci:set("teamtalk", "global", k, v)
        end
    end

    if data.settings then
        for k, v in pairs(data.settings) do
            uci:set("teamtalk", "settings", k, v)
        end
    end

    if data.server then
        for k, v in pairs(data.server) do
            uci:set("teamtalk", "server", k, v)
        end
    end

    if data.login then
        for k, v in pairs(data.login) do
            uci:set("teamtalk", "login", k, v)
        end
    end

    if data.ports then
        for k, v in pairs(data.ports) do
            uci:set("teamtalk", "ports", k, v)
        end
    end

    if data.storage then
        for k, v in pairs(data.storage) do
            uci:set("teamtalk", "storage", k, v)
        end
    end

    if data.volume then
        for k, v in pairs(data.volume) do
            uci:set("teamtalk", "volume", k, v)
        end
    end

    if data.audio_codec_type or data.audio_samplerate then
        if data.audio_codec_type then uci:set("teamtalk", "audio", "codec_type", data.audio_codec_type) end
        if data.audio_samplerate then uci:set("teamtalk", "audio", "samplerate", data.audio_samplerate) end
        if data.audio_channels then uci:set("teamtalk", "audio", "channels", data.audio_channels) end
        if data.audio_bitrate then uci:set("teamtalk", "audio", "bitrate", data.audio_bitrate) end
        if data.audio_complexity then uci:set("teamtalk", "audio", "complexity", data.audio_complexity) end
    end

    uci:save("teamtalk")
    uci:commit("teamtalk")
    return true
end

function teamtalk.check_ports(http)
    local args = http:QU()
    local tcp_port = args.tcp_port or "10333"
    local udp_port = args.udp_port or "10333"
    local http_port = args.http_port or "10334"
    local http_enabled = args.http_enabled or "0"

    local conflicts = teamtalk.check_port_conflict(tcp_port, udp_port, http_port, http_enabled)

    http:startJSON()
    http:send({
        conflicts = conflicts
    })
end

function teamtalk.find_port(http)
    local args = http:QU()
    local start_port = args.start_port or "10333"
    local proto = args.proto or "tcp"

    local port = teamtalk.find_available_port(start_port, proto)

    http:startJSON()
    http:send({
        port = port
    })
end

function teamtalk.get_server_info()
    local info = {}
    local uci = require("luci.model.uci").cursor()
    local name = uci:get("teamtalk", "global", "container_name") or "tt5srv"

    local status = sys.exec(string.format("docker ps --filter 'name=%s' --format '{{.Status}}' 2>/dev/null", name))
    info.running = status and status:match("Up") ~= nil

    local output = sys.exec(string.format("docker exec %s tt5srv --help 2>&1 | head -20", name))
    info.server_version = output

    return info
end

function teamtalk.get_settings()
    local uci = require("luci.model.uci").cursor()
    local name = uci:get("teamtalk", "global", "container_name") or "tt5srv"

    local output = sys.exec(string.format("docker exec %s cat /srv/ttd.json 2>/dev/null || echo '{}'", name))
    return output
end

function teamtalk.exec_command(cmd)
    local uci = require("luci.model.uci").cursor()
    local name = uci:get("teamtalk", "global", "container_name") or "tt5srv"
    return sys.exec(string.format("docker exec %s %s 2>&1", name, cmd))
end

function teamtalk.import_config(http)
    local args = http:QU()
    local content = args.content or ""
    
    if content ~= "" then
        content = require("luci.http").urldecode(content)
        local uci = require("luci.model.uci").cursor()
        local srv_dir = uci:get("teamtalk", "volume", "srv_dir") or "/mnt/teamtalk/srv"
        
        local file = io.open(srv_dir .. "/ttd.json", "w")
        if file then
            file:write(content)
            file:close()
            http:startJSON()
            http:send({ message = "Configuration imported successfully" })
        else
            http:startJSON()
            http:send({ error = "Failed to write configuration file" })
        end
    else
        http:startJSON()
        http:send({ error = "No content to import" })
    end
end

function teamtalk.get_users(http)
    local uci = require("luci.model.uci").cursor()
    local srv_dir = uci:get("teamtalk", "volume", "srv_dir") or "/mnt/teamtalk/srv"
    local config_file = srv_dir .. "/ttd.json"
    
    local users = {}
    local content = sys.exec(string.format("cat %s 2>/dev/null", config_file))
    
    if content and content ~= "" then
        local json = require("luci.json")
        local ok, decoded = pcall(json.decode, content)
        if ok and decoded and decoded.users then
            for _, user in ipairs(decoded.users.user or {}) do
                table.insert(users, {
                    username = user.username or "",
                    password = user.password or "",
                    user_type = user["user-type"] or "1",
                    user_rights = user["user-rights"] or "0",
                    init_channel = user["init-channel"] or "",
                    active = true,
                    modified_time = user["modified-time"] or ""
                })
            end
        end
    end
    
    http:startJSON()
    http:send({ users = users })
end

function teamtalk.get_user(http)
    local args = http:QU()
    local username = args.username or ""
    
    local uci = require("luci.model.uci").cursor()
    local srv_dir = uci:get("teamtalk", "volume", "srv_dir") or "/mnt/teamtalk/srv"
    local config_file = srv_dir .. "/ttd.json"
    
    local content = sys.exec(string.format("cat %s 2>/dev/null", config_file))
    
    if content and content ~= "" then
        local json = require("luci.json")
        local ok, decoded = pcall(json.decode, content)
        if ok and decoded and decoded.users then
            for _, user in ipairs(decoded.users.user or {}) do
                if user.username == username then
                    http:startJSON()
                    http:send({
                        user = {
                            username = user.username or "",
                            password = user.password or "",
                            user_type = user["user-type"] or "1",
                            user_rights = user["user-rights"] or "0",
                            init_channel = user["init-channel"] or "",
                            active = true,
                            modified_time = user["modified-time"] or ""
                        }
                    })
                    return
                end
            end
        end
    end
    
    http:startJSON()
    http:send({ error = "User not found" })
end

function teamtalk.save_user(http)
    local args = http:QU()
    local username = args.username or ""
    local password = args.password or ""
    local original_username = args.original_username or ""
    local user_type = args.user_type or "1"
    local init_channel = args.init_channel or ""
    local active = args.active or "1"
    
    local uci = require("luci.model.uci").cursor()
    local srv_dir = uci:get("teamtalk", "volume", "srv_dir") or "/mnt/teamtalk/srv"
    local config_file = srv_dir .. "/ttd.json"
    
    local content = sys.exec(string.format("cat %s 2>/dev/null", config_file))
    
    local config = {}
    if content and content ~= "" then
        local json = require("luci.json")
        local ok, decoded = pcall(json.decode, content)
        if ok and decoded then
            config = decoded
        end
    else
        config = { general = {}, users = { user = {} } }
    end
    
    if not config.users then
        config.users = { user = {} }
    end
    
    local users = config.users.user
    local found = false
    local timestamp = os.date("%Y/%m/%d %H:%M")
    
    for i, user in ipairs(users) do
        if original_username ~= "" and user.username == original_username then
            user.username = username
            if password ~= "" then
                user.password = password
            end
            user["user-type"] = user_type
            user["init-channel"] = init_channel
            user["modified-time"] = timestamp
            found = true
            break
        elseif original_username == "" and user.username == username then
            http:startJSON()
            http:send({ success = false, error = "Username already exists" })
            return
        end
    end
    
    if not found then
        if password == "" then
            http:startJSON()
            http:send({ success = false, error = "Password is required for new users" })
            return
        end
        
        table.insert(users, {
            username = username,
            password = password,
            ["user-type"] = user_type,
            ["user-rights"] = (user_type == "2") and "0" or "1308167",
            note = "",
            userdata = "0",
            ["init-channel"] = init_channel,
            ["modified-time"] = timestamp,
            ["audio-codec-bps-limit"] = "0",
            ["abuse-prevention"] = {
                ["commands-limit"] = "0",
                ["commands-interval-msec"] = "0"
            },
            ["channel-operator"] = ""
        })
    end
    
    local json = require("luci.json")
    local new_content = json.encode(config)
    
    local file = io.open(config_file, "w")
    if file then
        file:write(new_content)
        file:close()
        http:startJSON()
        http:send({ success = true, message = "User saved successfully" })
    else
        http:startJSON()
        http:send({ success = false, error = "Failed to save configuration" })
    end
end

function teamtalk.change_password(http)
    local args = http:QU()
    local username = args.username or ""
    local password = args.password or ""
    
    if password == "" then
        http:startJSON()
        http:send({ success = false, error = "Password cannot be empty" })
        return
    end
    
    local uci = require("luci.model.uci").cursor()
    local srv_dir = uci:get("teamtalk", "volume", "srv_dir") or "/mnt/teamtalk/srv"
    local config_file = srv_dir .. "/ttd.json"
    
    local content = sys.exec(string.format("cat %s 2>/dev/null", config_file))
    
    if content and content ~= "" then
        local json = require("luci.json")
        local ok, decoded = pcall(json.decode, content)
        if ok and decoded and decoded.users then
            local timestamp = os.date("%Y/%m/%d %H:%M")
            for _, user in ipairs(decoded.users.user or {}) do
                if user.username == username then
                    user.password = password
                    user["modified-time"] = timestamp
                    
                    local new_content = json.encode(decoded)
                    local file = io.open(config_file, "w")
                    if file then
                        file:write(new_content)
                        file:close()
                        http:startJSON()
                        http:send({ success = true, message = "Password changed successfully" })
                    else
                        http:startJSON()
                        http:send({ success = false, error = "Failed to save configuration" })
                    end
                    return
                end
            end
        end
    end
    
    http:startJSON()
    http:send({ success = false, error = "User not found" })
end

function teamtalk.delete_user(http)
    local args = http:QU()
    local username = args.username or ""
    
    local uci = require("luci.model.uci").cursor()
    local srv_dir = uci:get("teamtalk", "volume", "srv_dir") or "/mnt/teamtalk/srv"
    local config_file = srv_dir .. "/ttd.json"
    
    local content = sys.exec(string.format("cat %s 2>/dev/null", config_file))
    
    if content and content ~= "" then
        local json = require("luci.json")
        local ok, decoded = pcall(json.decode, content)
        if ok and decoded and decoded.users then
            local users = decoded.users.user
            for i, user in ipairs(users) do
                if user.username == username then
                    table.remove(users, i)
                    
                    local new_content = json.encode(decoded)
                    local file = io.open(config_file, "w")
                    if file then
                        file:write(new_content)
                        file:close()
                        http:startJSON()
                        http:send({ success = true, message = "User deleted successfully" })
                    else
                        http:startJSON()
                        http:send({ success = false, error = "Failed to save configuration" })
                    end
                    return
                end
            end
        end
    end
    
    http:startJSON()
    http:send({ success = false, error = "User not found" })
end

function teamtalk.save_audio(http)
    local args = http:QU()
    local codec_type = args.codec_type or "3"
    local samplerate = args.samplerate or "48000"
    local channels = args.channels or "2"
    local bitrate = args.bitrate or "128000"
    local complexity = args.complexity or "10"
    
    local uci = require("luci.model.uci").cursor()
    uci:set("teamtalk", "audio", "codec_type", codec_type)
    uci:set("teamtalk", "audio", "samplerate", samplerate)
    uci:set("teamtalk", "audio", "channels", channels)
    uci:set("teamtalk", "audio", "bitrate", bitrate)
    uci:set("teamtalk", "audio", "complexity", complexity)
    uci:save("teamtalk")
    uci:commit("teamtalk")
    
    http:startJSON()
    http:send({ success = true, message = "Audio settings saved to UCI config" })
end

_G["luci.controller.teamtalk"] = teamtalk
