package_name = "Minecraft-Caelestia"
bldit_version = "1"
global_dependencies = { "rsync", "python", "ydotool", "jq", "hyprctl", "curl", "unzip" }
dependencies = {}

targets = {
    default = {
        build = function()
            -- Nothing to build for this project
            return true
        end,
        install = function()
            -- Respect the user-defined prefix!
            return os.execute("PREFIX=" .. prefix .. " ./scripts/install.sh")
        end,
        uninstall = function()
            -- Remove using the designated prefix
            return os.execute("PREFIX=" .. prefix .. " ./scripts/uninstall.sh")
        end,
    }
}
