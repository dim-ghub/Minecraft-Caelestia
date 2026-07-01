package_name = "Minecraft-Caelestia"
bldit_version = "1"
global_dependencies = { "rsync", "python", "ydotool", "jq", "hyprctl", "curl", "unzip" }

function build()
    -- Nothing to build for this project
end

function install(prefix)
    -- Respect the user-defined prefix!
    return os.execute("PREFIX=" .. prefix .. " ./scripts/install.sh")
end

function remove(prefix)
    -- Remove using the designated prefix
    return os.execute("PREFIX=" .. prefix .. " ./scripts/uninstall.sh")
end
