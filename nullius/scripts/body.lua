function add_chart_tag(player, character)
  if ((player == nil) or (character == nil)) then
    return
  end
  local icon = "nullius-android-1"
  if (character.name == "nullius-android-2") then
    icon = "nullius-android-2"
  end

  local name = nil
  if (global.nullius_android_name ~= nil) then
    name = global.nullius_android_name[character.unit_number]
  end
  if (name == nil) then
    name = player.name
  end

  local ctag = player.force.add_chart_tag(character.surface,
      {position=character.position, icon={type="item", name=icon},
	    text=name, last_user=player})
  if (global.nullius_tag_android == nil) then
    global.nullius_tag_android = {}
	global.nullius_android_tag = {}
  end
  global.nullius_tag_android[ctag.tag_number] = character
  global.nullius_android_tag[character.unit_number] = ctag
end

function switch_body(player, target)
  local target_vehicle = nil
  if ((target.vehicle ~= nil) and ((target.vehicle.type == "car") or
	  (target.vehicle.type == "spider-vehicle"))) then
    target_vehicle = target.vehicle
  end

  if (global.nullius_android_tag ~= nil) then
    local tag = global.nullius_android_tag[target.unit_number]
	if (tag ~= nil) then
	  global.nullius_android_tag[target.unit_number] = nil
	  if (tag.valid) then
	      if (global.nullius_android_name == nil) then
		    global.nullius_android_name = {}
		  end
		  global.nullius_android_name[target.unit_number] = tag.text
		  global.nullius_tag_android[tag.tag_number] = nil
		  tag.destroy()
	  end
	end
  end

  local character = player.character
  local vehicle = player.vehicle
  player.set_controller{type=defines.controllers.character, character=target}

  if ((vehicle ~= nil) and (character ~= nil)) then
	if (((vehicle.type == "car") or (vehicle.type == "spider-vehicle")) and
        (vehicle.get_passenger() == nil)) then
	  vehicle.set_passenger(character)
	elseif ((vehicle.type == "locomotive") and
	    (vehicle.get_driver() == nil)) then
	  vehicle.set_driver(character)
	else
	  add_chart_tag(player, character)
	end
  else
    add_chart_tag(player, character)
  end

  if (global.nullius_body_queue ~= nil) then
    local queue = global.nullius_body_queue[player.index]
	if (queue ~= nil) then
	  queue.last_index = target.unit_number
	end
  end

  if ((target_vehicle ~= nil) and (target_vehicle.get_driver() == nil) and
      (target == target_vehicle.get_passenger())) then
	target_vehicle.set_passenger(nil)
	target_vehicle.set_driver(target)
  end
end

function update_queue(player, oldchar)
  local newchar = player.character
  if ((newchar == oldchar) or (newchar == nil) or (oldchar == nil)) then
    return
  end

  if (global.nullius_body_queue == nil) then
    global.nullius_body_queue = {}
  end
  local queue = global.nullius_body_queue[player.index]
  if (queue == nil) then
    queue = {}
	queue.nodes = {}
    global.nullius_body_queue[player.index] = queue
  end
  local node1 = queue.nodes[oldchar.unit_number]
  if ((node1 == nil) or (node1.next == nil) or (node1.next.prev ~= node1)) then
    node1 = { body = oldchar }
    node1.next = node1
    node1.prev = node1
	queue.nodes[oldchar.unit_number] = node1
  end

  local node2 = queue.nodes[newchar.unit_number]
  if (node2 == node1.next) then return end
  if ((node2 == nil) or (node2.body ~= newchar) or
      (node2.next == nil) or (node2.prev == nil) or
      (node2.next.prev ~= node2) or (node2.prev.next ~= node2)) then
    node2 = { body = newchar }
    queue.nodes[newchar.unit_number] = node2
  else
    local n2n = node2.next
	local n2p = node2.prev
    n2n.prev = n2p
	n2p.next = n2n
  end

  local nn = node1.next
  node2.next = nn
  node2.prev = node1
  nn.prev = node2
  node1.next = node2
end

function upload_mind(player, target)
  if ((target.type == "car") or (target.type == "spider-vehicle")) then
	target = target.get_passenger()
    if ((target == nil) or (not target.valid)) then
	  return
	end
  elseif (target.type == "locomotive") then
	target = target.get_driver()
    if ((target == nil) or (not target.valid)) then
	  return
	end
  end
  if ((target.type ~= "character") or (target.player ~= nil) or
      (target.force ~= player.force)) then
    return
  end
  local oldchar = player.character
  if (target == oldchar) then return end

  switch_body(player, target)
  update_queue(player, oldchar)
end

function cycle_body(player, rev)
  if (global.nullius_body_queue == nil) then return end
  local queue = global.nullius_body_queue[player.index]
  if (queue == nil) then return end

  local node = nil
  if (player.character ~= nil) then
	node = queue.nodes[player.character.unit_number]
  end
  if ((node == nil) and (queue.last_index ~= nil)) then
    node = queue.nodes[queue.last_index]
  end
  if (node == nil) then return end
  local orgnode = node

  if (rev) then
    node = node.prev
  else
    node = node.next
  end
  if (node == nil) then
    global.nullius_body_queue[player.index] = nil
    return
  end

  local body = node.body
  while ((body == nil) or (not body.valid) or (body.type ~= "character") or
      (body.player ~= nil) or (body.force ~= player.force)) do
    local np = node.prev
	local nn = node.next
    if ((nn == nil) or (np == nil) or (nn.prev == nil) or
	    (np.next == nil) or (nn == node) or (np == node)) then
      global.nullius_body_queue[player.index] = nil
      return		
	end
    if ((body == nil) or (not body.valid) or (body.type ~= "character")) then
      np.next = nn
	  nn.prev = np
	  node.next = node
	  node.prev = node
	end
	if (node == orgnode) then return end
	if (rev) then node = np else node = nn end
	body = node.body
  end

  switch_body(player, body)
end


script.on_event("nullius-upload-mind", function(event)
  local player = game.players[event.player_index]
  local target = player.selected
  if ((target ~= nil) and target.valid) then
    upload_mind(player, target)
  end
end)

script.on_event("nullius-previous-body", function(event)
  local player = game.players[event.player_index]
  cycle_body(player, true)
end)

script.on_event("nullius-next-body", function(event)
  local player = game.players[event.player_index]
  cycle_body(player, false)
end)

script.on_event(defines.events.on_chart_tag_removed, function(event)
  if ((global.nullius_tag_android ~= nil) and
      (event.tag ~= nil) and event.tag.valid) then
    local android = global.nullius_tag_android[event.tag.tag_number]
	if (android ~= nil) then
	  global.nullius_tag_android[event.tag.tag_number] = nil
	  if (android.valid) then
		global.nullius_android_tag[android.unit_number] = nil
		if (event.player_index ~= nil) then
		  local player = game.players[event.player_index]
		  if (player ~= nil) then
		    upload_mind(player, android)
		  end
		end
	  end
	end
  end
end)

script.on_event(defines.events.on_player_respawned, function(event)
  local player = game.players[event.player_index]
  local oldchar = player.character
  if ((oldchar == nil) or (not oldchar.valid)) then return end
  cycle_body(player, true)
  local newchar = player.character
  if ((newchar == nil) or (not newchar.valid)) then return end
  if (newchar == oldchar) then return end
  oldchar.destroy()
end)
