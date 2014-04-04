doors = {}

--{{{ Functions

--{{{ can_open for door with bolt
doors.can_open_bolted = function (pos, node, clicker)
    if string.find(node.name, "_1") then
        local door_facedir = node.param2
        local clicker_facedir = minetest.dir_to_facedir(vector.direction(clicker:getpos(),pos))
        if door_facedir ~= clicker_facedir then return false
        end
    end
    return true
end
--}}}

--{{{ swap_door
doors.swap_door = function (pos, dir, check_name, replace, replace_dir, meta)
    pos.y = pos.y+dir
    if not minetest.get_node(pos).name == check_name then
        return
    end

    minetest.swap_node(pos, {name=replace_dir})

    pos.y = pos.y-dir
    minetest.swap_node(pos, {name=replace})

    if meta ~= nil then
        local metadata = minetest.get_meta(pos)
        metadata:set_string(meta[1], meta[2])

        pos.y = pos.y+dir

        metadata = minetest.get_meta(pos)
        meta:set_string(meta[1], meta[2])
    end
end
--}}}

--{{{ open_door
doors.open_door = function (pos, name)
    local part = name:sub(-3)
    name = name:sub(0,-5)

    if part == "t_1" then
        doors.swap_door(pos,-1, name.."_b_1", name.."_t_2", name.."_b_2")
    elseif part == "b_1" then
        doors.swap_door(pos, 1, name.."_t_1", name.."_b_2", name.."_t_2")
    elseif part == "t_2" then
        doors.swap_door(pos,-1, name.."_b_2", name.."_t_1", name.."_b_1")
    elseif part == "b_2" then
        doors.swap_door(pos, 1, name.."_t_2", name.."_b_1", name.."_t_1")
    end
end
--}}}

--{{{ rightclick_on_locked
doors.rightclick_on_locked = function(pos, node, clicker, wield_item)
    if real_locks.can_open_locked (pos, wield_item) then
        doors.open_door(pos, node.name)
    end
end
--}}}

--{{{ rightclock_on_bolted
doors.rightclick_on_bolted = function(pos, node, clicker)
    if doors.can_open_bolted(pos, node, clicker) then
        doors.open_door(pos, node.name)
    end
end
--}}}

--{{{ rightclick_on_lockable
doors.rightclick_on_lockable = function (pos, node, clicker, wield_item)
    if wield_item:get_name() == "real_locks:lock" then
        doors.swap_door(pos, 1, name.."_t_1",
            name.."locked_b_1", name.."locked_t_1",
            {"lock_pass", wield_item:get_metadata()}
        )
        wield_item:take_item()
    else
        doors.open_door(pos, node.name)
    end
end
--}}}

--{{{ rightclick_on_not_lockable
doors.rightclick_on_not_lockable = function (pos, node)
    doors.open_door(pos, node.name)
end
--}}}
--}}}

--{{{ doors:register_door
function doors:register_door(name, def)
	def.groups.not_in_creative_inventory = 1
	
    --{{{ Item registration
	minetest.register_craftitem(name, {
		description = def.description,
		inventory_image = def.inventory_image,
		
		on_place = function(itemstack, placer, pointed_thing)
			if not pointed_thing.type == "node" then
				return itemstack
			end
			
			local ptu = pointed_thing.under
			local nu = minetest.get_node(ptu)
			if minetest.registered_nodes[nu.name].on_rightclick then
				return minetest.registered_nodes[nu.name].on_rightclick(ptu, nu, placer, itemstack)
			end
			
			local pt = pointed_thing.above
			local pt2 = {x=pt.x, y=pt.y, z=pt.z}
			pt2.y = pt2.y+1
			if
				not minetest.registered_nodes[minetest.get_node(pt).name].buildable_to or
				not minetest.registered_nodes[minetest.get_node(pt2).name].buildable_to or
				not placer or
				not placer:is_player()
			then
				return itemstack
			end
			
			local p2 = minetest.dir_to_facedir(placer:get_look_dir())
			local pt3 = {x=pt.x, y=pt.y, z=pt.z}
			if p2 == 0 then
				pt3.x = pt3.x-1
			elseif p2 == 1 then
				pt3.z = pt3.z+1
			elseif p2 == 2 then
				pt3.x = pt3.x+1
			elseif p2 == 3 then
				pt3.z = pt3.z-1
			end
			if not string.find(minetest.get_node(pt3).name, name.."_b_") then
				minetest.set_node(pt, {name=name.."_b_1", param2=p2})
				minetest.set_node(pt2, {name=name.."_t_1", param2=p2})
			else
				minetest.set_node(pt, {name=name.."_b_2", param2=p2})
				minetest.set_node(pt2, {name=name.."_t_2", param2=p2})
			end
			
			local passwd = itemstack:get_metadata()
			if passwd ~= nil then
			    local meta = minetest.get_meta(pt)
			    meta:set_string("lock_pass", passwd)
			    meta:set_string("infotext", def.infotext)
			    meta = minetest.get_meta(pt2)
			    meta:set_string("lock_pass", passwd)
			    meta:set_string("infotext", def.infotext)
			end
			
			if not minetest.setting_getbool("creative_mode") then
				itemstack:take_item()
			end
			return itemstack
		end,
	})
    --}}}
	
    --{{{ Node registration

    --{{{ Tables

    --{{{ Nodenames
    local nodes = {
        "t_1", "b_1",
        "t_2", "b_2",

--        cw_t_1, cw_b_1,
--        cw_t_2, cw_b_2,
    }
    --}}}
    
    --{{{ Nodeboxes
	local box      = {-0.5, -0.5, -0.5,  0.5,      0.5, -0.5+3/16}
	local box_open = {-0.5, -0.5, -0.5, -0.5+3/16, 0.5,  0.5     }

    if def.nodeboxes == nil then
        def.nodeboxes = {
            t_1 = box,
            b_1 = box,
            t_2 = box_open,
            b_2 = box_open,

            cw_t_1 = nil,
            cw_b_1 = nil,
            cw_t_2 = nil,
            cw_b_2 = nil,
        }
    end
    --}}}

    --{{{ Tiles
	local tt = def.tiles_top
	local tb = def.tiles_bottom
	
    if def.tiles == nil then
        def.tiles = {
            t_1 = {
                tt[4], tt[4],
                tt[2], tt[2],
                tt[1], tt[1].."^[transformfx"
            },
            b_1 = {
                tb[4], tb[4],
                tb[2], tb[2],
                tb[1], tb[1].."^[transformfx"
            },
            t_2 = {
                tt[5], tt[5],
                tt[1].."^[transformfx", tt[1],
                tt[3], tt[3]
            },
            b_2 = {
                tb[5], tb[5],
                tb[1].."^[transformfx", tb[1],
                tb[3], tb[3]
            },

            cw_t_1 = nil,
            cw_b_1 = nil,
            cw_t_2 = nil,
            cw_b_2 = nil,
        }
    end
    --}}}
    --}}}
	
    --{{{ after_dig
	local function after_dig(pos, oldnode)
        local name, count = string.gsub(oldnode.name, "_t_", "_b_")
        if count == 0 then
            local name, count = string.gsub(name, "_b_", "_t_")
        end
        
        if string.find(name, "_t_") then
            pos.y = pos.y + 1
        else
            pos.y = pos.y - 1
        end

		if minetest.get_node(pos).name == name then
			minetest.remove_node(pos)
		end
	end
    --}}}

    if def.rightclick == nil then
        def.rightclick = doors.rightclick_on_not_lockable
    end

    for k,part in pairs(nodes) do
	    minetest.register_node(name.."_"..part, {
		    tiles = def.tiles[part],
		    paramtype = "light",
		    paramtype2 = "facedir",
		    drop = name,
		    drawtype = "nodebox",
		    node_box = {
                type = "fixed",
                fixed = def.nodeboxes[part],
            },
		    groups = def.groups,
		    after_dig_node = after_dig,
		    on_rightclick = def.rightclick,
	    })
    end

    --}}}
end
--}}}

--{{{ Various doors registration
-- wooden door
doors:register_door("doors:door_wood", {
	description = "Wooden Door",
	inventory_image = "door_wood.png",
	groups = {snappy=1,choppy=2,oddly_breakable_by_hand=2,flammable=2,door=1},
	tiles_top    = {"door_wood_a.png", "door_wood_side.png", "door_wood_side_open.png","door_wood_y.png", "door_wood_y_open.png"},
	tiles_bottom = {"door_wood_b.png", "door_wood_side.png", "door_wood_side_open.png","door_wood_y.png", "door_wood_y_open.png"},
})

minetest.register_craft({
	output = "doors:door_wood",
	recipe = {
		{"group:wood", "group:wood"},
		{"group:wood", "group:wood"},
		{"group:wood", "group:wood"}
	}
})

--}}}

minetest.register_alias("doors:door_wood_a_c", "doors:door_wood_t_1")
minetest.register_alias("doors:door_wood_a_o", "doors:door_wood_t_1")
minetest.register_alias("doors:door_wood_b_c", "doors:door_wood_b_1")
minetest.register_alias("doors:door_wood_b_o", "doors:door_wood_b_1")
