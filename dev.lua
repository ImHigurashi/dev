local HigurashiScript = true
local Dev = false
local script_version = "1.0.1"
local paths = {}
paths.root = utils.get_appdata_path("PopstarDevs", "2Take1Menu")
paths.higurashi = paths.root .. "\\scripts\\Higurashi"

local m = {
    af = menu.add_feature,
    apf = menu.add_player_feature,
    ct = menu.create_thread,
    df = menu.delete_feature,
    dpf = menu.delete_player_feature,
    dt = menu.delete_thread,
    gcc = menu.get_cat_children,
    gpf = menu.get_player_feature,
    gfbhk = menu.get_feature_by_hierarchy_key,
    n = menu.notify
}

local colors = {
    white = 0xFFFFFF,
    red = 0x0000FF,
    blue = 0xFF0000,
    green = 0x00FF00,
    yellow = 0x00FFFF,
}

local function notify(text, title, seconds, color)
    local title = title or "Dev"
    local seconds = seconds or 3
    local color = color or colors.white
    m.n(text, title, seconds, color)
    print(text)
end

local NATIVE = dofile(paths.higurashi .. "\\Natives.lua")

if not NATIVE then
    notify("Natives failed to load", title, 3, colors.red)
    return menu.exit()
end

local joaat = NATIVE.GET_HASH_KEY
local wait = coroutine.yield

if HigurashiScript and
    (menu.is_trusted_mode_enabled(1 << 3) and
        menu.is_trusted_mode_enabled(1 << 2)) then
    m.ct(function()
        local vercheckKeys = {
            ctrl = MenuKey(),
            space = MenuKey(),
            enter = MenuKey(),
            rshift = MenuKey()
        }
        vercheckKeys.ctrl:push_vk(0x11);
        vercheckKeys.space:push_vk(0x20);
        vercheckKeys.enter:push_vk(0x0D);
        vercheckKeys.rshift:push_vk(0xA1)
        local response_code, github_version = web.get(
            "https://raw.githubusercontent.com/ImHigurashi/dev/main/Higurashi/Version.md")
        if response_code == 200 then
            github_version = github_version:gsub("[\r\n]", "")
            if github_version ~= script_version then
                local text_size = graphics.get_screen_width() *
                    graphics.get_screen_height() / 3686400 *
                    0.5 + 0.5
                local strings = {
                    version_compare = "\nCurrent Version:" .. script_version ..
                        "\nLatest Version:" .. github_version,
                    version_compare_x_offset = v2(
                        -scriptdraw.get_text_size(
                            "\nCurrent Version:" .. script_version ..
                            "\nLatest Version:" .. github_version, text_size)
                        .x / graphics.get_screen_width(), 0),
                    new_ver_x_offset = v2(
                        -scriptdraw.get_text_size(
                            "New version available. Press CTRL or SPACE to skip or press ENTER or RIGHT SHIFT to update.",
                            text_size).x / graphics.get_screen_width(), 0)
                }
                strings.changelog_rc, strings.changelog = web.get(
                    "https://raw.githubusercontent.com/ImHigurashi/dev/main/Higurashi/Changelog.md")
                if strings.changelog_rc == 200 then
                    strings.changelog = "\n\n\nChangelog:\n" ..
                        strings.changelog
                else
                    strings.changelog = ""
                end
                strings.changelog_x_offset = v2(
                    -scriptdraw.get_text_size(
                        strings.changelog,
                        text_size).x /
                    graphics.get_screen_width(),
                    0)
                local stringV2size = v2(2, 2)
                while true do
                    scriptdraw.draw_text(
                        "New version available. Press CTRL or SPACE to skip or press ENTER or RIGHT SHIFT to update.",
                        strings.new_ver_x_offset, stringV2size, text_size,
                        0xFFFFFFFF, 2)
                    scriptdraw.draw_text(strings.version_compare,
                        strings.version_compare_x_offset,
                        stringV2size, text_size, 0xFFFFFFFF, 2)
                    scriptdraw.draw_text(strings.changelog,
                        strings.changelog_x_offset,
                        stringV2size, text_size, 0xFFFFFFFF, 2)
                    if Dev or vercheckKeys.ctrl:is_down() or
                        vercheckKeys.space:is_down() then
                        MainScript()
                        break
                    elseif vercheckKeys.enter:is_down() or
                        vercheckKeys.rshift:is_down() then
                        local response_code, auto_updater = web.get(
                            [[ https://raw.githubusercontent.com/ImHigurashi/dev/main/Higurashi/AutoUpdater.lua ]])
                        if response_code == 200 then
                            auto_updater = load(auto_updater)
                            m.ct(function()
                                notify("Update initiated, please wait a moment...")
                                local status_ = auto_updater()
                                if status_ then
                                    if type(status_) == "string" then
                                        notify("Updating local files failed.")
                                    else
                                        notify("Update Succeeded")
                                        dofile(
                                            utils.get_appdata_path(
                                                "PopstarDevs", "2Take1Menu") ..
                                            "\\scripts\\dev.lua")
                                    end
                                else
                                    notify("Download for updated files failed.")
                                end
                            end, nil)
                            break
                        else
                            notify("Getting updater failed.")
                        end
                    end
                    wait(0)
                end
            else
                MainScript()
            end
        end
    end, nil)
else
    if menu.is_trusted_mode_enabled(1 << 2) then
        http_trusted_off = true
    else
        m.n(
            "Trusted mode > Natives has to be on. If you wish for auto updates enable Http too.",
            title, 3, c.red1)
    end
    menu.exit()
end
function MainScript()
    local function get_user_coords()
        return NATIVE.GET_ENTITY_COORDS(NATIVE.PLAYER_PED_ID(), false)
    end

    local function get_player_coords(pid)
        if pid == NATIVE.PLAYER_ID() then
            return get_user_coords()
        else
            return NATIVE.NETWORK_GET_LAST_PLAYER_POS_RECEIVED_OVER_NETWORK(pid)
        end
    end

    local function request_model(hash, timeout)
        while NATIVE.GET_NUMBER_OF_STREAMING_REQUESTS() > 0 do
            wait(0)
        end
        timeout = timeout or 3
        NATIVE.REQUEST_MODEL(hash)
        local cur_time = os.time()
        local end_time = cur_time + timeout
        while not NATIVE.HAS_MODEL_LOADED(hash) and end_time >= os.time() do
            wait(0)
        end
        return NATIVE.HAS_MODEL_LOADED(hash)
    end

    local function request_control(...)
        local Entity, timeout = ...
        if not NATIVE.NETWORK_HAS_CONTROL_OF_ENTITY(Entity) and NATIVE.IS_AN_ENTITY(Entity)
            and (not NATIVE.IS_ENTITY_A_PED(Entity) or not NATIVE.IS_PED_A_PLAYER(Entity)) then
            local time = utils.time_ms() + (timeout or 1000)
            local net_id = NATIVE.NETWORK_GET_NETWORK_ID_FROM_ENTITY(Entity)
            NATIVE.SET_NETWORK_ID_CAN_MIGRATE(net_id, true)
            NATIVE.NETWORK_REQUEST_CONTROL_OF_ENTITY(Entity)
            while not NATIVE.NETWORK_HAS_CONTROL_OF_ENTITY(Entity) and time > utils.time_ms() do
                wait(0)
            end
        end
        return NATIVE.NETWORK_HAS_CONTROL_OF_ENTITY(Entity)
    end

    local function remove_entity(Entity)
        local count = 1
        if request_control(Entity) then
            if NATIVE.IS_ENTITY_ATTACHED(Entity) then
                NATIVE.DETACH_ENTITY(Entity, false, false)
            end
            if not NATIVE.IS_ENTITY_ATTACHED(Entity) then
                if NATIVE.IS_ENTITY_A_VEHICLE(Entity) then
                    NATIVE.SET_ENTITY_AS_MISSION_ENTITY(Entity, true, true)
                elseif NATIVE.IS_ENTITY_AN_OBJECT(Entity) then
                    NATIVE.SET_ENTITY_AS_MISSION_ENTITY(Entity, false, true)
                elseif NATIVE.IS_ENTITY_A_PED(Entity) then
                    NATIVE.SET_ENTITY_AS_MISSION_ENTITY(Entity, false, false)
                end
                local hash = NATIVE.GET_ENTITY_MODEL(Entity)
                entity.delete_entity(Entity)
                NATIVE.SET_MODEL_AS_NO_LONGER_NEEDED(hash)
            end
            count = count + 1
        end
        if count % 10 == 0 then
            wait(0)
        end
    end

    local function create_ped(pedtype, modelhash, pos, heading, isnetworked, scripthostped)
        local Ped = 0
        local pedtype = pedtype or -1
        local pos = pos or v3()
        local heading = heading or 0.0
        local isnetworked = isnetworked or false
        local scripthostped = scripthostped or false
        local status = request_model(modelhash)
        if status then
            Ped = NATIVE.CREATE_PED(pedtype, modelhash, pos, heading, isnetworked, scripthostped)
        end
        NATIVE.SET_MODEL_AS_NO_LONGER_NEEDED(modelhash)
        return Ped
    end

    local function create_vehicle(modelhash, pos, heading, isnetworked, scripthostveh, p7)
        local Veh = 0
        local pos = pos or v3()
        local heading = heading or 0.0
        local isnetworked = isnetworked or false
        local scripthostveh = scripthostveh or false
        local p7 = p7 or false
        local status = request_model(modelhash)
        if status then
            Veh = NATIVE.CREATE_VEHICLE(modelhash, pos, heading, isnetworked, scripthostveh, p7)
        end
        NATIVE.SET_MODEL_AS_NO_LONGER_NEEDED(modelhash)
        return Veh
    end

    local function create_object(modelhash, pos, isnetworked, scripthostobj, dynamic)
        local Obj = 0
        local pos = pos or v3()
        local isnetworked = isnetworked or false
        local scripthostobj = scripthostobj or false
        local dynamic = dynamic or false
        local status = request_model(modelhash)
        if status then
            Obj = NATIVE.CREATE_OBJECT(modelhash, pos, isnetworked, scripthostobj, dynamic)
        end
        NATIVE.SET_MODEL_AS_NO_LONGER_NEEDED(modelhash)
        return Obj
    end

    local function create_world_object(modelhash, pos, isnetworked, dynamic)
        local Obj = 0
        local pos = pos or v3()
        local isnetworked = isnetworked or true
        local dynamic = dynamic or false
        local status = request_model(modelhash)
        if status then
            Obj = object.create_world_object(modelhash, pos, isnetworked, dynamic)
        end
        NATIVE.SET_MODEL_AS_NO_LONGER_NEEDED(modelhash)
        return Obj
    end

    Parent1 = m.apf("Dev", "parent", 0)

    PlayerFeature = m.apf("", "parent", Parent1.id)

    do
        local is_valid = player.is_player_valid
        function players(me)
            local pid = -1
            if not me then
                me = NATIVE.PLAYER_ID()
            end
            return function()
                repeat
                    pid = pid + 1
                until pid == 32 or (me ~= pid and is_valid(pid))
                if pid ~= 32 then
                    return pid
                end
            end
        end
    end


    Parent2 = m.af("Dev", "parent", 0)

    EntitySpawner = m.af("Entity Spawner", "parent", Parent2.id)

    local custom_ped, custom_veh, custom_obj, custom_world_obj = {}, {}, {}, {}

    m.af("Custom Pedestrian", "action_value_str", EntitySpawner.id, function(f)
        if f.value == 0 then
            local r, s = input.get("Enter the name of the world object.", "", 250, 0)
            if r == 1 then
                return HANDLER_CONTINUE
            end
            if r == 2 then
                notify("Input canceled.", title, 3, colors.yellow)
                return HANDLER_POP
            end
            selected_ped = s
            custom_ped = create_ped(-1, joaat(selected_ped), get_user_coords(), 0, true, false)
            --NATIVE.FREEZE_ENTITY_POSITION(custom_ped, true)
            if NATIVE.DOES_ENTITY_EXIST(custom_ped) then
                notify("Spawned " .. selected_ped, title, 3, colors.green)
            else
                notify("Failed to spawn " .. selected_ped, title, 3, colors.red)
            end
        elseif f.value == 1 then
            remove_entity(custom_ped)
            if not NATIVE.DOES_ENTITY_EXIST(custom_ped) then
                notify("Deleted " .. selected_ped, title, 3, colors.green)
            else
                notify("Failed to delete " .. selected_ped, title, 3, colors.red)
                remove_entity(custom_ped)
            end
        end
    end):set_str_data({ "Spawn", "Delete" })

    m.af("Custom Vehicle", "action_value_str", EntitySpawner.id, function(f)
        if f.value == 0 then
            local r, s = input.get("Enter the name of the world object.", "", 250, 0)
            if r == 1 then
                return HANDLER_CONTINUE
            end
            if r == 2 then
                notify("Input canceled.", title, 3, colors.yellow)
                return HANDLER_POP
            end
            selected_veh = s
            custom_veh = create_vehicle(joaat(selected_veh), get_user_coords(), 0, true, false, false)
            --NATIVE.FREEZE_ENTITY_POSITION(custom_veh, true)
            if NATIVE.DOES_ENTITY_EXIST(custom_veh) then
                notify("Spawned " .. selected_veh, title, 3, colors.green)
            else
                notify("Failed to spawn " .. selected_veh, title, 3, colors.red)
            end
        elseif f.value == 1 then
            remove_entity(custom_veh)
            if not NATIVE.DOES_ENTITY_EXIST(custom_veh) then
                notify("Deleted " .. selected_veh, title, 3, colors.green)
            else
                notify("Failed to delete " .. selected_veh, title, 3, colors.red)
                remove_entity(custom_veh)
            end
        end
    end):set_str_data({ "Spawn", "Delete" })

    m.af("Custom Object", "action_value_str", EntitySpawner.id, function(f)
        if f.value == 0 then
            local r, s = input.get("Enter the name of the object.", "", 250, 0)
            if r == 1 then
                return HANDLER_CONTINUE
            end
            if r == 2 then
                notify("Input canceled.", title, 3, colors.yellow)
                return HANDLER_POP
            end
            selected_obj = s
            custom_obj = create_object(joaat(selected_obj), get_user_coords(), true, false,
                false)
            -- NATIVE.FREEZE_ENTITY_POSITION(custom_obj, true)
            if NATIVE.DOES_ENTITY_EXIST(custom_obj) then
                notify("Spawned " .. selected_obj, title, 3, colors.green)
            else
                notify("Failed to spawn " .. selected_obj, title, 3, colors.red)
            end
        elseif f.value == 1 then
            remove_entity(custom_obj)
            if not NATIVE.DOES_ENTITY_EXIST(custom_obj) then
                notify("Deleted " .. selected_obj, title, 3, colors.green)
            else
                notify("Failed to delete " .. selected_obj, title, 3, colors.red)
                remove_entity(custom_obj)
            end
        end
    end):set_str_data({ "Spawn", "Delete" })

    m.af("Custom World Object", "action_value_str", EntitySpawner.id, function(f)
        if f.value == 0 then
            local r, s = input.get("Enter the name of the world object.", "", 250, 0)
            if r == 1 then
                return HANDLER_CONTINUE
            end
            if r == 2 then
                notify("Input canceled.", title, 3, colors.yellow)
                return HANDLER_POP
            end
            selected_world_obj = s
            custom_world_obj = create_world_object(
                joaat(selected_world_obj),
                get_user_coords(), true, false)
            --NATIVE.FREEZE_ENTITY_POSITION(custom_world_obj, true)
            if NATIVE.DOES_ENTITY_EXIST(custom_world_obj) then
                notify("Spawned " .. selected_world_obj, title, 3, colors.green)
            else
                notify("Failed to spawn " .. selected_world_obj, title, 3, colors.red)
            end
        elseif f.value == 1 then
            remove_entity(custom_world_obj)
            if not NATIVE.DOES_ENTITY_EXIST(custom_world_obj) then
                notify("Deleted " .. selected_world_obj, title, 3, colors.green)
            else
                notify("Failed to delete " .. selected_world_obj, title, 3, colors.red)
                remove_entity(custom_world_obj)
            end
        end
    end):set_str_data({ "Spawn", "Delete" })
end
