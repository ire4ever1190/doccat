import os
switch("d", "ssl")
# switch("forceBuild") # So it doesn't cache git version
putEnv("DB_DRIVER", "sqlite")
putEnv("DB_CONNECTION", "docs.db")
putEnv("DB_USER", "")
putEnv("DB_PASSWORD", "")
putEnv("DB_DATABASE", "")

putEnv("LOG_IS_DISPLAY", "true")
putEnv("LOG_IS_FILE", "false")
putEnv("LOG_DIR", "logs/")
switch("d", "discordv8")
switch("forceBuild", "")
