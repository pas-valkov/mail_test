Config = {
--general
    snaps_dir = 'bin/snaps',

--logger
    xlog_dir = 'bin/xlogs',
    log_file_name = 'bin/logs/logs.log',
    log_level = 5,

--server
    port = 8080,
    request_limit = 3000, --per second
    storage_name = "mail_test"
}

return Config
