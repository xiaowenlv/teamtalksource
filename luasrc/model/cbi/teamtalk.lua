module("luci.model.cbi.teamtalk", package.seeall)

local fs = require("nixio.fs")
local sys = require("luci.sys")

function get_teamtalk_config()
    local config = {}
    local uci = require("luci.model.uci").cursor()

    config.global = uci:get_all("teamtalk", "global") or {}
    config.settings = uci:get_all("teamtalk", "settings") or {}
    config.volume = uci:get_all("teamtalk", "volume") or {}

    return config
end

function save_teamtalk_config(config_data)
    local uci = require("luci.model.uci").cursor()

    for section, values in pairs(config_data) do
        for key, value in pairs(values) do
            uci:set("teamtalk", section, key, value)
        end
    end

    uci:save("teamtalk")
    uci:commit("teamtalk")
    return true
end

function check_docker_installed()
    local ret = sys.exec("which docker 2>/dev/null")
    return ret and ret ~= ""
end

function install_docker()
    local cmd = "opkg update && opkg install docker"
    local ret = sys.exec(cmd .. " 2>&1")
    return ret
end

function pull_docker_image(image_name)
    local cmd = string.format("docker pull %s 2>&1", image_name)
    return sys.exec(cmd)
end

function deploy_tt5srv(config)
    local name = config.global.container_name or "tt5srv"
    local image = config.global.docker_image or "deepcomp/tt5srv:latest"
    local srv_dir = config.volume.srv_dir or "/mnt/teamtalk/srv"
    local timezone = config.settings.timezone or "Asia/Shanghai"
    local puid = config.settings.puid or "1000"
    local pgid = config.settings.pgid or "1000"

    sys.exec(string.format("mkdir -p %s", srv_dir))
    sys.exec(string.format("mkdir -p %s/files", srv_dir))

    local cmd = string.format(
        "docker run -d --name %s --network host -v %s:/srv -e TZ=%s -e PUID=%s -e PGID=%s %s",
        name, srv_dir, timezone, puid, pgid, image
    )

    return sys.exec(cmd .. " 2>&1")
end

function get_container_status(name)
    local status = sys.exec(string.format("docker ps --filter 'name=%s' --format '{{.Status}}' 2>/dev/null", name))
    return status and status:gsub("\n", "") or ""
end

function start_container(name)
    return sys.exec(string.format("docker start %s 2>&1", name))
end

function stop_container(name)
    return sys.exec(string.format("docker stop %s 2>&1", name))
end

function restart_container(name)
    return sys.exec(string.format("docker restart %s 2>&1", name))
end

function remove_container(name)
    return sys.exec(string.format("docker rm -f %s 2>&1", name))
end

function get_container_logs(name, lines)
    lines = lines or 100
    return sys.exec(string.format("docker logs --tail %d %s 2>&1", lines, name))
end

function get_config_file(name)
    name = name or "tt5srv"
    return sys.exec(string.format("docker exec %s cat /srv/ttd.json 2>&1", name))
end

function exec_in_container(name, cmd)
    return sys.exec(string.format("docker exec %s %s 2>&1", name, cmd))
end

function get_all_containers()
    local containers = {}
    local output = sys.exec("docker ps -a --format '{{.Names}}|{{.Status}}|{{.Image}}' 2>/dev/null")
    if output then
        for line in output:gmatch("[^\r\n]+") do
            local parts = {}
            for part in line:gmatch("[^|]+") do
                table.insert(parts, part)
            end
            if #parts >= 3 then
                table.insert(containers, {
                    name = parts[1],
                    status = parts[2],
                    image = parts[3]
                })
            end
        end
    end
    return containers
end

function get_all_images()
    local images = {}
    local output = sys.exec("docker images --format '{{.Repository}}:{{.Tag}}|{{.ID}}' 2>/dev/null")
    if output then
        for line in output:gmatch("[^\r\n]+") do
            local parts = {}
            for part in line:gmatch("[^|]+") do
                table.insert(parts, part)
            end
            if #parts >= 2 then
                table.insert(images, {
                    name = parts[1],
                    id = parts[2]
                })
            end
        end
    end
    return images
end

_G["luci.model.cbi.teamtalk"] = teamtalk_model
