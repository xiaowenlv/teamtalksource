module("luci.controller.teamtalk", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/teamtalk") then
        return
    end

    local page = entry({"admin", "services", "teamtalk"}, alias("admin", "services", "teamtalk", "config"), _("TeamTalk"), 80)
    page.dependent = true

    entry({"admin", "services", "teamtalk", "config"}, cbi("teamtalk/config"), _("Configuration"), 10).leaf = true
    entry({"admin", "services", "teamtalk", "status"}, template("teamtalk/status"), _("Status"), 20).leaf = true
end
