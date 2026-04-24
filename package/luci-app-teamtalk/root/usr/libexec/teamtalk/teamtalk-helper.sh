#!/bin/sh

check_docker_installed() {
    which docker >/dev/null 2>&1
    return $?
}

install_docker() {
    opkg update && opkg install docker
}

check_docker_running() {
    docker info >/dev/null 2>&1
    return $?
}

pull_image() {
    local image="$1"
    docker pull "$image"
}

check_port_available() {
    local port="$1"
    local proto="${2:-tcp}"
    if netstat -tln 2>/dev/null | grep -E ":${port}\s" | grep -q "${proto}"; then
        echo "in_use"
    else
        echo "free"
    fi
}

check_port_conflict() {
    local tcp_port="${1:-10333}"
    local udp_port="${2:-10333}"
    local http_port="${3:-10334}"
    local http_enabled="${4:-0}"
    local conflicts=""
    
    if [ "$(check_port_available "$tcp_port" tcp)" = "in_use" ]; then
        conflicts="${conflicts}TCP ${tcp_port} is already in use\n"
    fi
    
    if [ "$(check_port_available "$udp_port" udp)" = "in_use" ]; then
        conflicts="${conflicts}UDP ${udp_port} is already in use\n"
    fi
    
    if [ "$http_enabled" = "1" ]; then
        if [ "$(check_port_available "$http_port" tcp)" = "in_use" ]; then
            conflicts="${conflicts}HTTP ${http_port} is already in use\n"
        fi
    fi
    
    if [ -n "$conflicts" ]; then
        echo "$conflicts"
        return 1
    fi
    return 0
}

find_available_port() {
    local start_port="${1:-10333}"
    local proto="${2:-tcp}"
    local max_attempts=100
    local port=$((start_port))
    
    while [ $port -lt $((start_port + max_attempts)) ]; do
        if [ "$(check_port_available "$port" "$proto")" = "free" ]; then
            echo "$port"
            return 0
        fi
        port=$((port + 1))
    done
    
    return 1
}

deploy_tt5srv() {
    local config_file="/etc/config/teamtalk"
    
    . "$config_file"
    
    local name="${teamtalk_global_container_name:-tt5srv}"
    local image="${teamtalk_global_docker_image:-deepcomp/tt5srv:latest}"
    local srv_dir="${teamtalk_volume_srv_dir:-/mnt/teamtalk/srv}"
    local timezone="${teamtalk_settings_timezone:-Asia/Shanghai}"
    local puid="${teamtalk_settings_puid:-1000}"
    local pgid="${teamtalk_settings_pgid:-1000}"
    local tcp_port="${teamtalk_ports_tcp_port:-10333}"
    local udp_port="${teamtalk_ports_udp_port:-10333}"
    local http_port="${teamtalk_ports_http_port:-10334}"
    local http_enabled="${teamtalk_ports_http_enabled:-0}"
    
    mkdir -p "$srv_dir"
    mkdir -p "$srv_dir/files"
    
    if [ -f "$srv_dir/ttd.json" ]; then
        sed -i "s/\"tcpport\": \"[0-9]*\"/\"tcpport\": \"$tcp_port\"/g" "$srv_dir/ttd.json"
        sed -i "s/\"udpport\": \"[0-9]*\"/\"udpport\": \"$udp_port\"/g" "$srv_dir/ttd.json"
        if [ "$http_enabled" = "1" ]; then
            sed -i "s/\"httpport\": \"[0-9]*\"/\"httpport\": \"$http_port\"/g" "$srv_dir/ttd.json"
        fi
    fi
    
    local http_env=""
    if [ "$http_enabled" = "1" ]; then
        http_env="-e HTTPPORT=$http_port"
    fi
    
    docker rm -f "$name" 2>/dev/null
    
    docker run -d --name "$name" \
        --network host \
        -v "$srv_dir:/srv" \
        -e TZ="$timezone" \
        -e PUID="$puid" \
        -e PGID="$pgid" \
        -e TCPPORT="$tcp_port" \
        -e UDPPORT="$udp_port" \
        $http_env \
        "$image"
}

run_setup_wizard() {
    local config_file="/etc/config/teamtalk"
    
    . "$config_file"
    
    local srv_dir="${teamtalk_volume_srv_dir:-/mnt/teamtalk/srv}"
    
    mkdir -p "$srv_dir"
    mkdir -p "$srv_dir/files"
    
    docker run -v "$srv_dir:/srv" --rm -it \
        --entrypoint tt5srv \
        deepcomp/tt5srv:latest \
        -wizard -wd /srv
}

start_container() {
    local name="${1:-tt5srv}"
    docker start "$name"
}

stop_container() {
    local name="${1:-tt5srv}"
    docker stop "$name"
}

restart_container() {
    local name="${1:-tt5srv}"
    docker restart "$name"
}

remove_container() {
    local name="${1:-tt5srv}"
    docker rm -f "$name"
}

get_logs() {
    local name="${1:-tt5srv}"
    local lines="${2:-100}"
    docker logs --tail "$lines" "$name" 2>&1
}

get_status() {
    local name="${1:-tt5srv}"
    docker ps --filter "name=$name" --format '{{.Status}}' 2>/dev/null
}

get_config_file() {
    local name="${1:-tt5srv}"
    docker exec "$name" cat /srv/ttd.json 2>/dev/null || echo '{}'
}

import_config_file() {
    local content="$1"
    local srv_dir="${2:-/mnt/teamtalk/srv}"
    
    if [ -n "$content" ]; then
        echo "$content" > "$srv_dir/ttd.json"
        return 0
    fi
    return 1
}

generate_config() {
    local srv_dir="${1:-/mnt/teamtalk/srv}"
    
    . /etc/config/teamtalk
    
    local server_name="${teamtalk_server_server_name:-TeamTalk Server}"
    local motd="${teamtalk_server_motd:-Welcome}"
    local max_users="${teamtalk_server_max_users:-1000}"
    local tcp_port="${teamtalk_ports_tcp_port:-10333}"
    local udp_port="${teamtalk_ports_udp_port:-10333}"
    local files_root="${teamtalk_storage_files_root:-/mnt/teamtalk/srv/files}"
    
    cat > "$srv_dir/ttd.json" << EOF
{
  "server-name": "$server_name",
  "motd": "$motd",
  "max-users": $max_users,
  "tcpport": $tcp_port,
  "udpport": $udp_port,
  "files-root": "$files_root"
}
EOF
}

list_server_logs() {
    local srv_dir="/mnt/teamtalk/srv"
    if [ -d "$srv_dir/logs" ]; then
        ls -la "$srv_dir/logs/"
    else
        echo "No logs directory found"
    fi
}

case "$1" in
    check)
        check_docker_installed
        ;;
    install)
        install_docker
        ;;
    pull)
        pull_image "$2"
        ;;
    deploy)
        deploy_tt5srv
        ;;
    setup-wizard)
        run_setup_wizard
        ;;
    start)
        start_container "$2"
        ;;
    stop)
        stop_container "$2"
        ;;
    restart)
        restart_container "$2"
        ;;
    remove)
        remove_container "$2"
        ;;
    logs)
        get_logs "$2" "$3"
        ;;
    status)
        get_status "$2"
        ;;
    get-config)
        get_config_file "$2"
        ;;
    list-logs)
        list_server_logs
        ;;
    check-port)
        check_port_available "$2" "$3"
        ;;
    check-conflict)
        check_port_conflict "$2" "$3" "$4" "$5"
        ;;
    find-port)
        find_available_port "$2" "$3"
        ;;
esac
