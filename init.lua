--[[
Placeable Buckets for Catching Rainwater
Copyright (C) 2020 Noodlemire

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
--]]

--Mod-specific global variable
placeable_buckets = {}

--Get the translator wrapper for various bucket descriptions.
local S = minetest.get_translator("bucket")

--Make a copy of the empty bucket's definition to freely change.
local empty_def = table.copy(minetest.registered_items["bucket:bucket_empty"])

--Give the definition properties that are reserved for nodes, including a custom bucket mesh.
empty_def.drawtype = "mesh"
empty_def.mesh = "placeable_bucket.obj"
empty_def.tiles = {"placeable_bucket_empty.png"}
empty_def.use_texture_alpha = true
empty_def.wield_image = "bucket.png"
empty_def.sounds = default.node_sound_metal_defaults()

--Give it a paramtype so that it won't block light.
empty_def.paramtype = "light"

--Give it some node-related groups
empty_def.groups.empty_bucket = 1
empty_def.groups.oddly_breakable_by_hand = 1

--The waterworks_connected group is used to allow empty buckets to be used in waterworks' pipe networks.
empty_def.groups.waterworks_connected = 1

--A simple collision box that is just big enough to fit the whole bucket mesh.
empty_def.collision_box = {
	type = "fixed",
	fixed = {
		{-6/16, -8/16, -6/16, 6/16, 3/16, 6/16},
	},
}
empty_def.selection_box = empty_def.collision_box

--Can't register a node that defines these fields, so they must be erased from the copied definition table.
empty_def.name = nil
empty_def.type = nil
empty_def.mod_origin = nil

--Can't override a craftitem into a node, so buckets need to be aliased into new nodes instead.
minetest.register_node("placeable_buckets:empty", empty_def)
minetest.register_alias_force("bucket:bucket_empty", "placeable_buckets:empty")



--A helper that will copy all fields in t2 into t1.
--Fields inside inner tables will also be individually copied.
--Provided tables should be given as references, so there is no return value.
local function deepmerge(t1, t2)
	if not t2 then
		return
	end

	t1 = t1 or {}

	for k, v in pairs(t2) do
		if type(v) == "table" then
			deepmerge(t1[k], v)
		else
			t1[k] = v
		end
	end
end

--This function changes an existing bucket into a placeable bucket.
--Note that currently, it must replace an existing bucket type that is filled.
function placeable_buckets.register(name, def)
	--Different treatment is given to the 9 levels of partially filled buckets.
	for i = 1, 9 do
		--Copy the empty bucket's definition to use as a base.
		local new_def = table.copy(empty_def)
		--Allow buckets to define fields that change based on current fill level.
		local extra_def = (new_def._register_per_level or function() return {} end)(i)

		--Default the waterworks_connected group to 0.
		new_def.groups.waterworks_connected = 0

		--Merge the given definition information into the copied definition.
		deepmerge(new_def, def)
		deepmerge(new_def, extra_def)

		--Give it a distinct description so that if different fill levels are /given, it's possible to tell them apart.
		new_def.description = def.description.." "..i
		--Only one model exists, which has every possible fill level present. The shown fill level occurs simply by using different textures.
		new_def.tiles = {def._texture_base.."_"..i..".png"}
		--Until a bucket is full, it is only allowed to give an empty bucket when destroyed.
		new_def.drop = "placeable_buckets:empty"

		--Replace the empty_bucket group with a new groupname used mainly for ABMs.
		--The number in _groupname should always be the current fill level.
		new_def.groups.empty_bucket = 0
		new_def.groups[def._groupname] = i

		--Partially full buckets don't need to clutter the creative inventory.
		new_def.groups.not_in_creative_inventory = 1

		--Finally, register the bucket that this fill level.
		minetest.register_node(name.."_"..i, new_def)
	end

	--This time, base the new_def on whichever bucket type is being replaced.
	local new_def = table.copy(minetest.registered_items[def._replace])
	--The fill-level-specific registration function can also apply here, with a fill level of 10.
	local extra_def = (new_def._register_per_level or function() return {} end)(10)

	--Merge the given definition information into the copied definition.
	deepmerge(new_def, def)
	deepmerge(new_def, extra_def)

	--Can't register a node that defines these fields, so they must be erased from the copied definition table.
	--(This isn't done for the partially filled buckets because they copy a definition table that already did this.)
	new_def.name = nil
	new_def.type = nil
	new_def.mod_origin = nil

	--Add information that was also given to the empty_bucket's definition.
	new_def.drawtype = "mesh"
	new_def.mesh = "placeable_bucket.obj"
	new_def.tiles = {def._texture_base.."_10.png"}
	new_def.use_texture_alpha = true
	new_def.wield_image = new_def.inventory_image
	new_def.sounds = default.node_sound_metal_defaults()
	new_def.paramtype = "light"
	new_def.groups[def._groupname] = 10
	new_def.groups.oddly_breakable_by_hand = 1

	new_def.collision_box = {
		type = "fixed",
		fixed = {
			{-6/16, -8/16, -6/16, 6/16, 3/16, 6/16},
		},
	}
	new_def.selection_box = empty_def.collision_box

	--The default on_place function, which is to dump out the bucket's contents.
	local dump_on_place = new_def.on_place
	--Create a new on_place function, which will place the bucket itself if the player is currently sneaking.
	new_def.on_place = function(itemstack, placer, pointed_thing)
		if placer:get_player_control()["sneak"] then
			return minetest.item_place(itemstack, placer, pointed_thing)
		else
			return dump_on_place(itemstack, placer, pointed_thing)
		end
	end

	--Register the node version of the full bucket, and alias it over the original.
	--This is done because it isn't possible to override a craftitem into a node.
	minetest.register_node(name.."_10", new_def)
	minetest.register_alias_force(def._replace, name.."_10")
end

--A helper function for water buckets' functionality with the waterworks mod.
local function place_inlet(pos)
	if waterworks then
		waterworks.place_connected(pos, "inlet", {pos = pos, target = vector.add(pos, {x=0, y=1, z=0}), pressure = pos.y})
	end
end

--Regular water buckets, which can work as inlets for the waterworks mod when it is active.
placeable_buckets.register("placeable_buckets:water", {
	_replace = "bucket:bucket_water",
	description = S("Water Bucket"),
	_texture_base = "placeable_bucket_water",
	_groupname = "water_bucket",

	groups = {waterworks_connected = 1},
	place_param2 = 4,

	_waterworks_update_connected = place_inlet,

	on_construct = function(pos)
		place_inlet(pos)

		if minetest.get_node(pos).name == "placeable_buckets:water_10" then
			minetest.get_meta(pos):set_int("stored_liquid", 1)
		end
	end,

	on_destruct = function(pos)
		if waterworks then
			waterworks.remove_connected(pos, "inlet")
		end
	end,

	_on_fill = function(pos, level)
		if level >= 10 then
			minetest.get_meta(pos):set_int("stored_liquid", 1)
		end
	end,

	--A waterworks compatability function, which empties the bucket whenever it deposits water into a pipe network.
	_waterworks_on_liquid_taken = function(pos, meta)
		if meta:get_int("stored_liquid") <= 0 then
			minetest.swap_node(pos, {name = "placeable_buckets:empty"})
			meta:set_int("water_level", 0)
		end
	end,
})

--River water buckets, which have very little functionality other than existing.
placeable_buckets.register("placeable_buckets:river_water", {
	_replace = "bucket:bucket_river_water",
	description = S("River Water Bucket"),
	_texture_base = "placeable_bucket_river_water",
	_groupname = "river_water_bucket"
})

--Lava buckets, which double as light sources depending on how much lava is present.
--Note that currently, partially full lava buckets are only obtainable through the /give command.
placeable_buckets.register("placeable_buckets:lava", {
	_replace = "bucket:bucket_lava",
	description = S("Lava Bucket"),
	_texture_base = "placeable_bucket_lava",
	_groupname = "lava_bucket",

	_register_per_level = function(i)
		return {
			light_source = minetest.LIGHT_MAX - 10 + i
		}
	end
})



--If the climate_api mod is present, rain will slowly fill empty_buckets with water.
if climate_api and minetest.settings:get_bool("placeable_buckets_rain_filling_buckets") then
	minetest.register_abm({
		label = "Rain Filling Buckets",

		nodenames = {"group:empty_bucket", "group:water_bucket"},

		interval = 5,
		chance = 5,

		action = function(pos, node)
			--If the current bucket is already full, nothing more needs to be done.
			if minetest.get_item_group(node.name, "water_bucket") >= 10 then
				return
			end

			--Humidity is used to determine when water should fill a bucket.
			local humi = climate_api.environment.get_humidity(pos)

			--If humidity is at least a 50%...
			if humi > 50 then
				--Get the current and future water levels.
				--Note that water level growth gets faster if it's extra humid.
				local meta = minetest.get_meta(pos)
				local water_level = meta:get_int("water_level") or 0
				local new_water_level = math.min(water_level + (humi - 50) / 10, 100)

				--Flooring is used to know if the bucket should visually fill up some more.
				if math.floor(water_level / 10) < math.floor(new_water_level / 10) then
					minetest.swap_node(pos, {name = "placeable_buckets:water_"..math.floor(new_water_level / 10)})
				end

				--Either way, set the new water level.
				meta:set_int("water_level", new_water_level)

				--Lastly, let nodes define a callback so that they may do something each time they're filled.
				local def = minetest.registered_nodes[node.name]
				if def._on_fill then
					def._on_fill(pos, new_water_level)
				end
			end
		end
	})
end

--This ABM allows liquids on top of empty buckets to fill them.
--This only happens to the source blocks though, since they're essentially the only units of liquid that actually exist.
if minetest.settings:get_bool("placeable_buckets_source_filling_buckets") then
	minetest.register_abm({
		label = "Sources Filling Buckets",

		nodenames = {"group:empty_bucket"},
		neighbors = {"default:water_source", "default:river_water_source", "default:lava_source"},

		interval = 1,
		chance = 1,

		action = function(pos, node)
			--Get the node above this one, to check later.
			local above = table.copy(pos)
			above.y = above.y + 1
			local anode = minetest.get_node(above)
			--This variable defaults to false, so that any one of the three following if statements can set it to true.
			local filled = false

			--Replace the empty bucket with a filled bucket, the type depending on the type of liquid removed.
			if anode.name == "default:water_source" then
				minetest.set_node(pos, {name = "placeable_buckets:water_10"})
				filled = true
			elseif anode.name == "default:river_water_source" then
				minetest.set_node(pos, {name = "placeable_buckets:river_water_10"})
				filled = true
			elseif anode.name == "default:lava_source" then
				minetest.set_node(pos, {name = "placeable_buckets:lava_10"})
				filled = true
			end

			--If something filled the bucket...
			if filled then
				--Delete the source block above the bucket
				minetest.remove_node(above)

				--Lastly, let nodes define a callback so that they may do something each time they're filled.
				--get_node is used so that the appropriate node name is obtained, since the node has changed at this point.
				local def = minetest.registered_nodes[minetest.get_node(pos).name]
				if def._on_fill then
					def._on_fill(pos, 10)
				end
			end
		end
	})
end

--This allows water to cool nearby lava buckets into stone or obsidian.
if minetest.settings:get_bool("placeable_buckets_cooling_lava_buckets") then
	minetest.register_abm({
		label = "Cooling Lava Buckets",

		nodenames = {"group:lava_bucket"},
		neighbors = {"group:cools_lava"},

		interval = 3,
		chance = 3,

		action = function(pos, node)
			if minetest.get_item_group(node.name, "lava_bucket") >= 10 then
				--If this lava bucket is already full, replace it with an obsidian block.
				minetest.set_node(pos, {name = "default:obsidian"})
			else
				--Otherwise, replace it with stone.
				--Note that currently, partially full lava buckets are unobtainable without /give.
				minetest.set_node(pos, {name = "default:stone"})
			end

			minetest.sound_play("default_cool_lava", {pos = pos, max_hear_distance = 16, gain = 0.25}, true)
		end
	})
end

--This allows lava to vaporize the water or river water in nearby buckets.
if minetest.settings:get_bool("placeable_buckets_vaporizing_water_buckets") then
	minetest.register_abm({
		label = "Vaporizing Water Buckets",

		nodenames = {"group:water_bucket", "group:river_water_bucket"},
		neighbors = {"group:igniter"},

		interval = 3,
		chance = 3,

		action = function(pos, node)
			minetest.set_node(pos, {name = "placeable_buckets:empty"})
			minetest.sound_play("default_cool_lava", {pos = pos, max_hear_distance = 16, gain = 0.25}, true)
		end
	})
end

--If the entitycontrol mod is active, this will allow full lava buckets to incinerate items thrown "into" them.
--Bucket collision is technically just a solid cube, so it's enough for the item to just land on top.
if entitycontrol and minetest.settings:get_bool("placeable_buckets_lava_buckets_incinerate_items") then
	--Get the item's current on_step method.
	local old_on_step = minetest.registered_entities["__builtin:item"].on_step
	--Override it with this extended version of the method.
	entitycontrol.override_entity("__builtin:item", {on_step = function(self, dtime, moveresult)
		--Call the previous on_step first, which handles stuff like when items should despawn.
		old_on_step(self, dtime, moveresult)

		--Only continue if the item is currently on the ground.
		if moveresult.touching_ground then
			--For each collision...
			for _, c in pairs(moveresult.collisions) do
				--If it's colliding with a full lava bucket...
				if c.type == "node" and minetest.get_node(c.node_pos).name == "placeable_buckets:lava_10" then
					--Delete the item.
					self.object:remove()
					minetest.sound_play("default_cool_lava", {pos = pos, max_hear_distance = 16, gain = 0.25}, true)
				end
			end
		end
	end})
end
