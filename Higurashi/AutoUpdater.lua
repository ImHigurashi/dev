local status_ = true
local appdata_path = utils.get_appdata_path("PopstarDevs", "2Take1Menu")
local higurashi_path = appdata_path .. "\\scripts\\Higurashi"

local file_paths = {
    main = appdata_path .. "\\scripts\\dev.lua",
    changelog = higurashi_path .. "\\Changelog.md",
    version = higurashi_path .. "\\Version.md",
}

local files = {
    main = [[https://raw.githubusercontent.com/ImHigurashi/dev/main/dev.lua]],
    changelog = [[https://raw.githubusercontent.com/ImHigurashi/dev/main/Higurashi/Changelog.md]],
    version = [[https://raw.githubusercontent.com/ImHigurashi/dev/main/Higurashi/Version.md]],
}

local all_files = 0
local downloaded_files = 0
for k, v in pairs(files) do
    all_files = all_files + 1
    menu.create_thread(function()
        local response_code, file = web.get(v)
        if response_code == 200 then
            files[k] = file
            downloaded_files = downloaded_files + 1
        else
            print("Failed to download: " .. v)
            status_ = false
        end
    end)
end
while downloaded_files < all_files and status_ do
    system.wait(0)
end

if status_ then
    for k, v in pairs(files) do
        local current_file = io.open(file_paths[k], "a+")
        if not current_file then
            status_ = "ERROR REPLACING"
            break
        end
        current_file:close()
    end
    if status_ ~= "ERROR REPLACING" then
        for k, v in pairs(files) do
            local current_file = io.open(file_paths[k], "w+b")
            if current_file then
                current_file:write(v)
                current_file:flush()
                current_file:close()
            else
                status_ = "ERROR REPLACING"
            end
        end
    end
end

return status_
