anvil = {}

anvil.multiplier_default = 3
anvil.multiplier_neg = 2

anvil.formspec =
    "size[" ..inventory.width.. "," ..(inventory.height + 3).. "]" ..
    default.gui_bg..
    default.gui_bg_img..
    default.gui_slots..
    "list[current_name;hammer;1,1;1,1;]" ..
    "list[current_name;src;2.4,0;3,3;]" ..
    "image[5.7,1;1,1;gui_furnace_arrow_bg.png^[transformR270]" ..
    "list[current_name;dst;7,0;1,1;3]" ..
    "list[current_name;dst;7,1;1,2;]" ..
    inventory.main(0, 3.2) ..
    "listring[current_name;dst]" ..
    "listring[current_player;main]" ..
    "listring[current_name;src]" ..
    "listring[current_player;main]" ..
    "listring[current_name;hammer]" ..
    "listring[current_player;main]"

--{{{ Craft protection
minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
    if metals.contains_metals(old_craft_grid)
    and itemstack:get_modname() ~= "anvil"
    then
        minetest.chat_send_player(player:get_player_name(),
            "Этот предмет нельзя создать голыми руками."
        )
        craft_inv:set_list("craft", old_craft_grid)
        return ItemStack("")
    end
end)
--}}}

--{{{ Functions
local function is_hammer(itemstack)
    local name = itemstack:get_name()
    local tool = minetest.registered_tools[name]

    if tool ~= nil
    and tool.tool_capabilities.groupcaps.anvil ~= nil
    and tool.tool_capabilities.groupcaps.anvil > 0
    then
        return true
    else
        return false
    end
end

local function get_uses(itemstack)
    local name = itemstack:get_name()
    local tool = minetest.registered_tools[name]
    if tool then
        return tool_capabilities.groupcaps.anvil.uses
    end
end

anvil.craft_predict = function(pos, player)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    local craftlist = inv:get_list("src")

    -- Get recipes for anvil
    local output = crafter.get_craft_result({
        method = "anvil",
        width = inv:get_width("src") or 3,
        items = craftlist
    })
    print(dump(output))
    if #output > 3 then
        minetest.log("error",
            "Too many craft recipes (" .. #output .. ") for craftlist " ..
            craftlist
        )
        for i = 4, #output do
            output[i] = nil
        end
    end

    local hammer = inv:get_stack("hammer", 1)
    if hammer:get_name() ~= "" then
        -- If hammer is present
        inv:set_list("dst", output)
    else
        inv:set_list("dst", {})
    end
end

anvil.craft = function (pos, player)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    local craftlist = inv:get_list("src")

    local hammer = inv:get_stack("hammer", 1)
    if hammer:get_name() ~= "" then
        local hammer_level = minetest.get_item_group(hammer, "level")
        local output_level = minetest.get_item_group(output.item, "level")
        local uses = get_uses(hammer)

        local leveldiff = hammer_level - output_level

        local multiplier = anvil.multiplier_default
        if leveldiff < 0 then multiplier = anvil.multiplier_neg end

        -- uses | leveldiff | actual uses
        -- 10   |  0        | 10
        -- 10   |  1        | 10*3
        -- 10   | -1        | 10/2
        hammer:add_wear(65535/(uses * multiplier^leveldiff))
        inv:set_stack("hammer", 1, hammer)
    end

    -- decrease input
    for k, itemstack in ipairs(craftlist) do
        itemstack:take_item()
        inv:set_stack("src", k, itemstack)
    end

    minetest.log("action",
        "player " .. player:get_player_name() ..
        " crafts " .. output.item:get_name() ..
        " on an " .. minetest.get_node(pos).name
    )
end

anvil.register = function (material, anvil_def)
    local material_name = default.strip_modname(material)
    local groups = anvil_def.groups
        or {oddly_breakable_by_hand = 2, falling_node = 1, dig_immediate = 1}
    groups.level = minetest.get_item_group(material, "level")

    local material_tile = material_name
    if default.get_modname(material) == "metals" then
        material_tile = material_tile:sub(1, material_name:find("_unshaped") - 1)
    end

    minetest.register_node("anvil:" .. material_name, {
        description = anvil_def.description or "Накавайня",
        tiles = anvil_def.tiles or {
            "anvil_" .. material_tile .. "_top.png",
            "anvil_" .. material_tile .. "_top.png",
            "anvil_" .. material_tile .. "_side.png"
        },
        drawtype = "nodebox",
        paramtype = "light",
        paramtype2 = "facedir",
        node_box = {
            type = "fixed",
            fixed = {
                {-0.5,-0.5,-0.3,0.5,-0.4,0.3},
                {-0.35,-0.4,-0.25,0.35,-0.3,0.25},
                {-0.3,-0.3,-0.15,0.3,-0.1,0.15},
                {-0.35,-0.1,-0.2,0.35,0.1,0.2},
            },
        },
        selection_box = {
            type = "fixed",
            fixed = {
                {-0.5,-0.5,-0.3,0.5,-0.4,0.3},
                {-0.35,-0.4,-0.25,0.35,-0.3,0.25},
                {-0.3,-0.3,-0.15,0.3,-0.1,0.15},
                {-0.35,-0.1,-0.2,0.35,0.1,0.2},
            },
        },
        groups = groups,
        sounds = anvil_def.sounds or
            default.node_sound_stone_defaults(),

        on_construct = function(pos)
            local meta = minetest.get_meta(pos)
            local inv = meta:get_inventory()
            inv:set_size("src", 9)
            inv:set_width("src", 3)
            inv:set_size("dst", 3)
            inv:set_size("hammer", 1)
            meta:set_string("formspec", anvil.formspec)
        end,
        after_dig_node = function(pos, oldnode, oldmetadata, digger)
            for k, itemstack in pairs(oldmetadata.inventory.src) do
                if itemstack:get_name() ~= "" then
                    minetest.add_item(pos, itemstack)
                end
            end
            local hammer = oldmetadata.inventory.hammer[1]
            if hammer:get_name() ~= "" then
                minetest.add_item(pos, hammer)
            end
        end,

        allow_metadata_inventory_put =
            function (pos, listname, index, stack, player)
                if listname == "dst" then
                    return 0
                elseif listname == "hammer" then
                    if is_hammer(stack)
                    then return stack:get_count()
                    else return 0
                    end
                else
                    return stack:get_count()
                end
            end,
        allow_metadata_inventory_move = 
            function (pos, from_list, from_index, to_list, to_index, count, player)
                if to_list == "dst" then
                    return 0
                elseif from_list == "dst" then
                    anvil.craft(pos, player)
                    return stack:get_count()
                elseif to_list == "hammer" then
                    if is_hammer(stack)
                    then return stack:get_count()
                    else return 0
                    end
                else
                    return count
                end
            end,

        on_metadata_inventory_move =
            function (pos, from_list, from_index, to_list, to_index, count, player)
                anvil.craft_predict(pos, player)
            end,
        on_metadata_inventory_put =
            function (pos, listname, index, stack, player)
                anvil.craft_predict(pos, player)
            end,
        on_metadata_inventory_take =
            function (pos, listname, index, stack, player)
                if listname == "src" then
                    anvil.craft_predict(pos, player)
                elseif listname == "dst" then
                    anvil.craft(pos, player)
                end
            end,
    })

    minetest.register_craft({
        output = "anvil:" .. material_name,
        recipe = {
            { material, material, material },
            {""       , material, ""       },
            { material, material, material },
        }
    })
    minetest.log("action", "Registered: anvil:" .. material_name)
end
--}}}

--{{{ Anvils registrations
anvil.register("default:cobble", {
    description = "Каменная наковальня",
    tiles = {
        "anvil_stone_top.png",
        "anvil_stone_top.png",
        "anvil_stone_side.png"
    },
    groups = {
        oddly_breakable_by_hand = 2,
        cracky = 3,
        stone = 2,
        falling_node = 1,
        dig_immediate = 1,
    },
})

--anvil.register("minerals:malachite", {
--    description = "Малахитовая наковальня",
--    groups = {
--        oddly_breakable_by_hand = 2,
--        cracky = 3,
--        stone = 3,
--        falling_node = 1,
--        dig_immediate = 2,
--    },
--})
--
--anvil.register("minerals:marble", {
--    description = "Мраморная наковальня",
--    groups = {
--        oddly_breakable_by_hand = 2,
--        cracky = 3,
--        stone = 3,
--        falling_node = 1,
--        dig_immediate = 2,
--    },
--})

anvil.register("metals:copper_unshaped", {
    description = "Медная наковальня",
    groups = {
        oddly_breakable_by_hand = 2,
        metal = 3,
        snappy = 1,
        cracky = 2,
        falling_node = 1,
        dig_immediate = 1,
    },
})

--[[
anvil.register("metals:lead_unshaped", {
    description = "Свинцовая наковальня",
    groups = {
        oddly_breakable_by_hand = 2,
        metal = 3,
        snappy = 1,
        cracky = 2,
        falling_node = 1,
        dig_immediate = 1,
    },
})
--]]

anvil.register("metals:bronze_unshaped", {
    description = "Бронзовая наковальня",
    groups = {
        oddly_breakable_by_hand = 2,
        metal = 3,
        snappy = 1,
        cracky = 2,
        falling_node = 1,
        dig_immediate = 1,
    },
})

--[[
anvil.register("metals:brass_unshaped", {
    description = "Латунная наковальня",
    groups = {
        oddly_breakable_by_hand = 1,
        metal = 3,
        snappy = 1,
        cracky = 2,
        falling_node = 1,
        dig_immediate = 1,
    },
})
--]]

--[[
anvil.register("metals:black_bronze_unshaped", {
    description = "Тёмная наковальня",
    groups = {
        oddly_breakable_by_hand = 1,
        metal = 3,
        snappy = 1,
        cracky = 2,
        falling_node = 1,
        dig_immediate = 1,
    },
})
--]]

--[[
anvil.register("metals:tumbaga_unshaped", {
    description = "Блестящая жёлтая наковальня",
    groups = {
        oddly_breakable_by_hand = 1,
        metal = 3,
        snappy = 1,
        cracky = 2,
        falling_node = 1,
        dig_immediate = 1,
    },
})
--]]

--[[
anvil.register("metals:pig_iron_unshaped", {
    description = "Чугунная наковальня",
    groups = {
        oddly_breakable_by_hand = 1,
        metal = 3,
        snappy = 1,
        cracky = 2,
        falling_node = 1,
        dig_immediate = 1,
    },
})
--]]

anvil.register("metals:wrought_iron_unshaped", {
    description = "Железная наковальня",
    groups = {
        oddly_breakable_by_hand = 1,
        metal = 3,
        snappy = 1,
        cracky = 2,
        falling_node = 1,
        dig_immediate = 1,
    },
})

anvil.register("metals:steel_unshaped", {
    description = "Стальная наковальня",
    groups = {
        oddly_breakable_by_hand = 1,
        metal = 3,
        snappy = 1,
        cracky = 2,
        falling_node = 1,
        dig_immediate = 1,
    },
})
--}}}
