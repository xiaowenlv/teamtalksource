local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()

m = Map("teamtalk", translate("TeamTalk"), translate("Configure TeamTalk Docker deployment settings."))

s = m:section(NamedSection, "global", "teamtalk", translate("Basic Settings"))
s.anonymous = true

enabled = s:option(Flag, "enabled", translate("Enable TeamTalk"))
enabled.rmempty = false

docker_image = s:option(Value, "docker_image", translate("Docker Image"))
docker_image.default = "deepcomp/tt5srv:latest"
docker_image.rmempty = false

container_name = s:option(Value, "container_name", translate("Container Name"))
container_name.default = "tt5srv"
container_name.rmempty = false

arch = s:option(ListValue, "arch", translate("Architecture"))
arch:value("amd64", "AMD64 (x86_64)")
arch:value("arm64", "ARM64")
arch:value("armhf", "ARMHF (ARMv7)")
arch.default = "amd64"

s2 = m:section(NamedSection, "settings", "settings", translate("System Settings"))
s2.anonymous = true

timezone = s2:option(Value, "timezone", translate("Timezone"))
timezone.default = "Asia/Shanghai"

puid = s2:option(Value, "puid", translate("File Owner UID (PUID)"))
puid.default = "1000"

pgid = s2:option(Value, "pgid", translate("File Owner GID (PGID)"))
pgid.default = "1000"

s3 = m:section(NamedSection, "server", "server", translate("Server Settings"))
s3.anonymous = true

server_name = s3:option(Value, "server_name", translate("Server Name"))
server_name.default = "TeamTalk Server"

motd = s3:option(Value, "motd", translate("MOTD"))
motd.default = "Welcome to TeamTalk Server"

max_users = s3:option(Value, "max_users", translate("Max Users"))
max_users.datatype = "uinteger"
max_users.default = "1000"

user_timeout = s3:option(Value, "user_timeout", translate("User Timeout (seconds)"))
user_timeout.datatype = "uinteger"
user_timeout.default = "60"

s4 = m:section(NamedSection, "ports", "ports", translate("Port Settings"))
s4.anonymous = true

tcp_port = s4:option(Value, "tcp_port", translate("TCP Port"))
tcp_port.datatype = "port"
tcp_port.default = "10333"

udp_port = s4:option(Value, "udp_port", translate("UDP Port"))
udp_port.datatype = "port"
udp_port.default = "10333"

http_enabled = s4:option(Flag, "http_enabled", translate("Enable HTTP"))
http_enabled.default = http_enabled.disabled

http_port = s4:option(Value, "http_port", translate("HTTP Port"))
http_port.datatype = "port"
http_port.default = "10334"

s5 = m:section(NamedSection, "storage", "storage", translate("Storage Settings"))
s5.anonymous = true

files_root = s5:option(Value, "files_root", translate("Files Root Directory"))
files_root.default = "/mnt/teamtalk/srv/files"

max_diskusage = s5:option(Value, "max_diskusage", translate("Max Disk Usage (MB, 0=unlimited)"))
max_diskusage.datatype = "uinteger"
max_diskusage.default = "0"

channel_diskquota = s5:option(Value, "channel_diskquota", translate("Channel Disk Quota (MB, 0=unlimited)"))
channel_diskquota.datatype = "uinteger"
channel_diskquota.default = "0"

s6 = m:section(NamedSection, "volume", "volume", translate("Storage Paths"))
s6.anonymous = true

srv_dir = s6:option(Value, "srv_dir", translate("SRV Directory"))
srv_dir.default = "/mnt/teamtalk/srv"

s7 = m:section(NamedSection, "audio", "audio", translate("Audio Codec Settings"))
s7.anonymous = true

codec_type = s7:option(ListValue, "codec_type", translate("Codec Type"))
codec_type:value("0", "Speex")
codec_type:value("1", "CELT")
codec_type:value("2", "MP3")
codec_type:value("3", "Opus")
codec_type:value("4", "Speex VBR")
codec_type.default = "3"

samplerate = s7:option(ListValue, "samplerate", translate("Sample Rate"))
samplerate:value("8000", "8000 Hz")
samplerate:value("16000", "16000 Hz")
samplerate:value("32000", "32000 Hz")
samplerate:value("48000", "48000 Hz")
samplerate.default = "48000"

channels = s7:option(ListValue, "channels", translate("Channels"))
channels:value("1", translate("Mono"))
channels:value("2", translate("Stereo"))
channels.default = "2"

bitrate = s7:option(ListValue, "bitrate", translate("Bitrate"))
bitrate:value("32000", "32 Kbps")
bitrate:value("64000", "64 Kbps")
bitrate:value("128000", "128 Kbps")
bitrate:value("256000", "256 Kbps")
bitrate:value("512000", "512 Kbps")
bitrate.default = "128000"

complexity = s7:option(ListValue, "complexity", translate("Complexity"))
complexity:value("5", "5 (Fast)")
complexity:value("10", "10 (High Quality)")
complexity.default = "10"

return m
