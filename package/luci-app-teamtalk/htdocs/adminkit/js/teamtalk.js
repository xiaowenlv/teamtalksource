TeamTalk Manager JavaScript

var TeamTalk = {
    apiUrl: '/admin/services/teamtalk/docker_action',

    checkDocker: function(callback) {
        XHR.get(this.apiUrl, { action: 'check_docker' }, function(x, d) {
            if (callback) callback(d);
        });
    },

    installDocker: function(callback) {
        if (!confirm('Install Docker on this device?')) return;
        XHR.get(this.apiUrl, { action: 'install_docker' }, function(x, d) {
            if (callback) callback(d);
        });
    },

    pullImage: function(imageName, callback) {
        XHR.get(this.apiUrl, { action: 'pull', image: imageName }, function(x, d) {
            if (callback) callback(d);
        });
    },

    deploy: function(config, callback) {
        XHR.get(this.apiUrl, { action: 'deploy' }, function(x, d) {
            if (callback) callback(d);
        });
    },

    start: function(name, callback) {
        XHR.get(this.apiUrl, { action: 'start', name: name }, function(x, d) {
            if (callback) callback(d);
        });
    },

    stop: function(name, callback) {
        XHR.get(this.apiUrl, { action: 'stop', name: name }, function(x, d) {
            if (callback) callback(d);
        });
    },

    restart: function(name, callback) {
        XHR.get(this.apiUrl, { action: 'restart', name: name }, function(x, d) {
            if (callback) callback(d);
        });
    },

    remove: function(name, callback) {
        if (!confirm('Remove container: ' + name + '?')) return;
        XHR.get(this.apiUrl, { action: 'remove', name: name }, function(x, d) {
            if (callback) callback(d);
        });
    },

    getLogs: function(lines, callback) {
        XHR.get(this.apiUrl, { action: 'get_logs', lines: lines || 100 }, function(x, d) {
            if (callback) callback(d);
        });
    },

    getUsers: function(callback) {
        XHR.get(this.apiUrl, { action: 'get_users' }, function(x, d) {
            if (callback) callback(d);
        });
    },

    saveUser: function(userData, callback) {
        XHR.get(this.apiUrl, Object.assign({ action: 'save_user' }, userData), function(x, d) {
            if (callback) callback(d);
        });
    },

    getStatus: function(callback) {
        XHR.get(this.apiUrl, { action: 'status' }, function(x, d) {
            if (callback) callback(d);
        });
    }
};

function startTeamTalk() {
    TeamTalk.start('teamtalk', function(d) {
        alert(d.message || 'Started');
        window.location.reload();
    });
}

function stopTeamTalk() {
    TeamTalk.stop('teamtalk', function(d) {
        alert(d.message || 'Stopped');
        window.location.reload();
    });
}

function restartTeamTalk() {
    TeamTalk.restart('teamtalk', function(d) {
        alert(d.message || 'Restarted');
        window.location.reload();
    });
}

function removeTeamTalk() {
    TeamTalk.remove('teamtalk', function(d) {
        alert(d.message || 'Removed');
        window.location.reload();
    });
}

function installDocker() {
    TeamTalk.installDocker(function(d) {
        alert(d.message || 'Docker installed');
        window.location.reload();
    });
}

function loadLogs(lines) {
    TeamTalk.getLogs(lines || 100, function(d) {
        if (d && d.logs) {
            document.getElementById('log-content').innerText = d.logs;
        }
    });
}

function refreshUsers() {
    TeamTalk.getUsers(function(d) {
        window.location.reload();
    });
}

function saveConfig(formData) {
    XHR.get(TeamTalk.apiUrl, Object.assign({ action: 'save_config' }, formData), function(x, d) {
        alert(d.message || 'Configuration saved');
    });
}

document.addEventListener('DOMContentLoaded', function() {
    var autoRefresh = document.getElementById('auto-refresh');
    if (autoRefresh) {
        autoRefresh.addEventListener('change', function() {
            if (this.checked) {
                window.logInterval = setInterval(function() {
                    loadLogs(document.getElementById('log-lines').value);
                }, 5000);
            } else {
                clearInterval(window.logInterval);
            }
        });
    }
});
