-- Bagshui Empty Bag
--
-- Adds an "Empty Bag" button to the Bagshui toolbar (after Restack). Click it, then click
-- one of the bags in the bag bar: every item in that bag is moved, one at a time, into
-- free slots in the other bags of the same window. Normal bags are filled first, then
-- profession bags (herb, soul, ammo...) - if a bag refuses an item, the next slot is tried.
--
-- Shift-click the bag: once the same window's bags are full, also use the other window
-- (bank bag -> your bags, or your bag -> bank bags while the bank is open).
--
-- Alt-click the button: compact - move items from the rightmost bags into free slots in the
-- leftmost bags as far as there is room. Alt+Shift-click: the same towards the rightmost bags.
--
-- Cancel: click the button again, or right-click a bag while it's waiting.
--
-- Kept as a separate addon so the Bagshui folder stays an untouched git clone.

local TEXTURE = "Interface\\AddOns\\Bagshui\\Images\\Icons\\Remove"
local STEP_DELAY = 0.15      -- seconds between moves (same pace as Bagshui's restack)
local LOCK_RETRIES = 20      -- steps to wait on a locked slot before skipping it

local MSG_R, MSG_G, MSG_B = 0.85, 0.78, 0.55  -- muted status colour

local function msg(text)
	UIErrorsFrame:AddMessage(text, MSG_R, MSG_G, MSG_B, 1.0, 3)
end

local function chat(text)
	DEFAULT_CHAT_FRAME:AddMessage("|cffd9c78cBagshui Empty Bag:|r " .. text)
end

local function slotHasItem(bag, slot)
	return GetContainerItemInfo(bag, slot) ~= nil
end

local function slotLocked(bag, slot)
	local _, _, locked = GetContainerItemInfo(bag, slot)
	return locked
end

-- Pick up / put down with modifier keys forced off, like Bagshui's restack does,
-- because some addons change PickupContainerItem behaviour when a modifier is held.
local function moveItem(fromBag, fromSlot, toBag, toSlot)
	local oldAlt, oldCtrl, oldShift = IsAltKeyDown, IsControlKeyDown, IsShiftKeyDown
	local no = function() return nil end
	IsAltKeyDown, IsControlKeyDown, IsShiftKeyDown = no, no, no
	ClearCursor()
	PickupContainerItem(fromBag, fromSlot)
	PickupContainerItem(toBag, toSlot)
	IsAltKeyDown, IsControlKeyDown, IsShiftKeyDown = oldAlt, oldCtrl, oldShift
end


------------------------------------------------------------------------------
-- The move job
------------------------------------------------------------------------------

local job = nil
local runner = CreateFrame("Frame")
runner:Hide()

local function finishJob(cancelled)
	if not job then return end
	local j = job
	job = nil
	runner:Hide()
	ClearCursor()

	local left = 0
	for _, s in ipairs(j.sources) do
		if slotHasItem(s.bag, s.slot) then left = left + 1 end
	end
	for _, s in ipairs(j.failed) do
		if slotHasItem(s.bag, s.slot) then left = left + 1 end
	end

	local text
	if j.compact then
		text = string.format("Compacted %s: moved %d item%s.", j.bagName, j.moved, j.moved == 1 and "" or "s")
	else
		text = string.format("Moved %d item%s out of %s.", j.moved, j.moved == 1 and "" or "s", j.bagName)
	end
	if cancelled then
		text = text .. " Cancelled."
	end
	-- (when compacting, items that stay put are expected, not a failure)
	if left > 0 and not j.compact then
		text = text .. string.format(" %d item%s didn't fit.", left, left == 1 and "" or "s")
	end
	msg(text)
	chat(text)

	if j.inventory and j.inventory.UpdateToolbar then
		j.inventory:UpdateToolbar()
	end
end

-- In compact mode an item may only move to a slot nearer the side being filled.
local function targetAllowed(j, src, t)
	return not j.compact or t.pos < src.pos
end

local function step()
	local j = job
	if not j then return end

	-- Loop until one move is attempted (or the job ends), so skipped items don't each cost a tick.
	local src, target, targetIndex
	while true do
		-- Drop any source slot that's already empty.
		while j.sources[1] and not slotHasItem(j.sources[1].bag, j.sources[1].slot) do
			table.remove(j.sources, 1)
		end
		src = j.sources[1]
		if not src then
			finishJob(false)
			return
		end

		if slotLocked(src.bag, src.slot) then
			j.lockWaits = j.lockWaits + 1
			if j.lockWaits > LOCK_RETRIES then
				j.lockWaits = 0
				table.insert(j.failed, table.remove(j.sources, 1))
			end
			return
		end

		-- First free, unlocked target this item hasn't been refused by.
		target, targetIndex = nil, nil
		local anyFreeBefore = false
		for i, t in ipairs(j.targets) do
			if targetAllowed(j, src, t) and not slotHasItem(t.bag, t.slot) then
				anyFreeBefore = true
				if not slotLocked(t.bag, t.slot) and not src.refused[t.key] then
					target, targetIndex = t, i
					break
				end
			end
		end

		if target then
			break
		end

		-- Nowhere left for this item (bags full, or only special bags that don't take it).
		table.insert(j.failed, table.remove(j.sources, 1))

		-- Compacting: sources go from the far side inward, so once no free slot is left
		-- before this one, none of the remaining items can move either.
		if j.compact and not anyFreeBefore then
			finishJob(false)
			return
		end
	end

	moveItem(src.bag, src.slot, target.bag, target.slot)

	if CursorHasItem() then
		-- The target bag refused it (e.g. a herb bag and a non-herb item). Put it back
		-- and try the next slot for this item.
		ClearCursor()
		src.refused[target.key] = true
		return
	end

	j.moved = j.moved + 1
	j.lockWaits = 0
	table.remove(j.sources, 1)
	table.remove(j.targets, targetIndex)
end

runner:SetScript("OnUpdate", function()
	if not job then
		this:Hide()
		return
	end
	job.elapsed = job.elapsed + arg1
	if job.elapsed < STEP_DELAY then return end
	job.elapsed = 0
	step()
end)

-- Free slots in the given inventory's bags (except skipBag): normal bags first, profession bags last.
local function collectTargets(inventory, skipBag, into)
	local normal, special = {}, {}
	for _, otherBag in ipairs(inventory.containerIds) do
		if otherBag ~= skipBag then
			local info = inventory.containers and inventory.containers[otherBag]
			local list = (info and info.isProfessionBag) and special or normal
			for slot = 1, (GetContainerNumSlots(otherBag) or 0) do
				if not slotHasItem(otherBag, slot) then
					table.insert(list, { bag = otherBag, slot = slot, key = otherBag .. ":" .. slot })
				end
			end
		end
	end
	for _, t in ipairs(normal) do table.insert(into, t) end
	for _, t in ipairs(special) do table.insert(into, t) end
	return into
end

-- The bags window for the bank and vice versa, if it's live right now (bank must be open).
local function overflowInventory(inventory)
	local otherType
	if inventory.inventoryType == "Bags" then
		otherType = "Bank"
	elseif inventory.inventoryType == "Bank" then
		otherType = "Bags"
	end
	local other = otherType and Bagshui.components and Bagshui.components[otherType]
	if other and other.online and other.containerIds then
		return other, otherType
	end
	return nil, otherType
end

local function startJob(inventory, bagNum, allowOverflow)
	if job then
		finishJob(true)
	end

	local numSlots = GetContainerNumSlots(bagNum) or 0
	local bagInfo = inventory.containers and inventory.containers[bagNum]
	local bagName = (bagInfo and bagInfo.name) or GetBagName(bagNum) or ("bag " .. bagNum)

	local sources = {}
	for slot = 1, numSlots do
		if slotHasItem(bagNum, slot) then
			table.insert(sources, { bag = bagNum, slot = slot, refused = {} })
		end
	end
	if table.getn(sources) == 0 then
		msg(bagName .. " is already empty.")
		return
	end

	-- Free slots in the other bags of this window first. With Shift held, the other
	-- window (bank <-> bags) is added after them as overflow, if it's open.
	local targets = collectTargets(inventory, bagNum, {})
	local ownCount = table.getn(targets)
	local overflowNote = ""
	if allowOverflow then
		local other, otherType = overflowInventory(inventory)
		if other then
			collectTargets(other, nil, targets)
			overflowNote = string.format(" (overflow into %s)", otherType == "Bank" and "the bank" or "your bags")
		elseif otherType == "Bank" then
			msg("The bank isn't open, so only your other bags are used.")
		end
	end
	if table.getn(targets) == 0 then
		msg(ownCount == 0 and "No free slots in your other bags." or "No free slots.")
		return
	end
	if overflowNote ~= "" then
		msg("Emptying " .. bagName .. overflowNote .. "...")
	end

	job = {
		inventory = inventory,
		bagName = bagName,
		sources = sources,
		targets = targets,
		failed = {},
		moved = 0,
		lockWaits = 0,
		elapsed = STEP_DELAY,  -- first move right away
	}
	runner:Show()
	if inventory.UpdateToolbar then
		inventory:UpdateToolbar()
	end
end


-- Compact the whole window: move items from the rightmost bags into free slots in the
-- leftmost bags (bag-bar order), as far as there is room. reverse = fill from the right.
local function startCompactJob(inventory, reverse)
	if job then
		finishJob(true)
	end

	-- Rank bags in bag-bar order (containerIds is the order the bag bar is built in).
	local bags = {}
	for _, bag in ipairs(inventory.containerIds) do
		if (GetContainerNumSlots(bag) or 0) > 0 then
			table.insert(bags, bag)
		end
	end
	local count = table.getn(bags)

	local sources, targets = {}, {}
	for i, bag in ipairs(bags) do
		local rank = reverse and (count - i + 1) or i
		for slot = 1, GetContainerNumSlots(bag) do
			local pos = rank * 1000 + slot
			if slotHasItem(bag, slot) then
				table.insert(sources, { bag = bag, slot = slot, pos = pos, refused = {} })
			else
				table.insert(targets, { bag = bag, slot = slot, pos = pos, key = bag .. ":" .. slot })
			end
		end
	end

	-- Take items from the far end first, fill free slots from the near end first.
	table.sort(sources, function(a, b) return a.pos > b.pos end)
	table.sort(targets, function(a, b) return a.pos < b.pos end)

	local name = inventory.inventoryType == "Bank" and "bank bags" or "bags"
	if table.getn(targets) == 0 then
		msg("No free slots - your " .. name .. " are already full.")
		return
	end

	job = {
		inventory = inventory,
		compact = true,
		bagName = "your " .. name,
		sources = sources,
		targets = targets,
		failed = {},
		moved = 0,
		lockWaits = 0,
		elapsed = STEP_DELAY,
	}
	msg(string.format("Compacting your %s towards the %s...", name, reverse and "right" or "left"))
	runner:Show()
	if inventory.UpdateToolbar then
		inventory:UpdateToolbar()
	end
end


------------------------------------------------------------------------------
-- Waiting for a bag click ("armed")
------------------------------------------------------------------------------

local function canUse(inventory)
	return inventory.online
		and inventory.activeCharacterId == Bagshui.currentCharacterId
		and not inventory.editMode
end

local function setArmed(inventory, armed)
	inventory.bseb_armed = armed or nil
	if inventory.UpdateToolbar and inventory.ui and inventory.ui.buttons then
		inventory:UpdateToolbar()
	end
end

local function onToolbarClick(inventory)
	PlaySound("igMainMenuOptionCheckBoxOn")
	if job and job.inventory == inventory then
		finishJob(true)
		return
	end
	if inventory.bseb_armed then
		setArmed(inventory, false)
		msg("Empty Bag cancelled.")
		return
	end
	if not canUse(inventory) then
		msg("Empty Bag only works on your current character's open bags.")
		return
	end
	-- Alt: compact towards the leftmost bags. Alt+Shift: towards the rightmost bags.
	if IsAltKeyDown() then
		startCompactJob(inventory, IsShiftKeyDown())
		return
	end
	setArmed(inventory, true)
	if inventory.inventoryType == "Bank" then
		msg("Click the bank bag to empty. Shift-click: overflow into your bags. Right-click: cancel.")
	elseif inventory.inventoryType == "Bags" then
		msg("Click the bag to empty. Shift-click: overflow into the bank if it's open. Right-click: cancel.")
	else
		msg("Click the bag to empty (right-click to cancel).")
	end
end

-- Wrap a bag-bar button's OnClick so it starts the job while armed.
local function patchBagButton(inventory, button)
	if button.bseb_patched then return end
	button.bseb_patched = true
	local oldOnClick = button:GetScript("OnClick")
	button:SetScript("OnClick", function()
		if inventory.bseb_armed then
			setArmed(inventory, false)
			if arg1 == "RightButton" then
				msg("Empty Bag cancelled.")
				return
			end
			if not inventory:BagSlotButtonHasBag(this) then
				msg("There's no bag in that slot.")
				return
			end
			-- Shift on the bag click: also allow the bank <-> bags overflow.
			startJob(inventory, this.bagshuiData.bagNum, IsShiftKeyDown())
			return
		end
		if oldOnClick then
			oldOnClick()
		end
	end)
end

local function patchBagButtons(inventory)
	local ui = inventory.ui
	if not (ui and ui.buttons and ui.buttons.bagSlots) then return end
	for _, button in ipairs(ui.buttons.bagSlots) do
		patchBagButton(inventory, button)
	end
end


------------------------------------------------------------------------------
-- Hooks into Bagshui
------------------------------------------------------------------------------

local hooked = false

local function installHooks()
	if hooked then return true end
	local Inventory = Bagshui and Bagshui.prototypes and Bagshui.prototypes.Inventory
	if not (Inventory and Inventory.PopulateToolbarAndMainMenuItems and Inventory.InitUi and Inventory.UpdateToolbar) then
		return false
	end

	-- 1. Add the toolbar item right after Restack (also shows up in the main menu's actions).
	local origPopulate = Inventory.PopulateToolbarAndMainMenuItems
	Inventory.PopulateToolbarAndMainMenuItems = function(self)
		origPopulate(self)
		local items = self.toolbarAndMainMenuItems
		if type(items) ~= "table" then return end

		local insertAt = table.getn(items) + 1
		local groupGap
		for i, item in ipairs(items) do
			if item.name == "Restack" then
				insertAt = i + 1
				-- Restack carries the wider gap that ends its button group; hand it to us
				-- so Resort / Restack / Empty Bag stay grouped.
				groupGap = item.xOffset
				item.xOffset = nil
				break
			end
		end
		local inventory = self
		table.insert(items, insertAt, {
			name = "EmptyBag",
			id = "emptyBag",
			xOffset = groupGap,
			texture = TEXTURE,
			tooltipTitle = "Empty Bag",
			tooltipText = "Click, then click a bag below to move everything in it into free slots in your other bags."
				.. " Shift-click the bag to also overflow between bank and bags when the bank is open."
				.. " Click again or right-click a bag to cancel."
				.. "\n\nAlt-click: compact - fill the leftmost bags, empty the rightmost ones."
				.. "\nAlt+Shift-click: compact the other way (fill the rightmost bags).",
			onClick = function()
				onToolbarClick(inventory)
			end,
			_bagshuiCheckedFunc = function()
				return inventory.bseb_armed or (job and job.inventory == inventory) or false
			end,
		})
	end

	-- 2. After the window is built, take over bag-bar clicks while armed, and disarm when it closes.
	local origInitUi = Inventory.InitUi
	Inventory.InitUi = function(self)
		origInitUi(self)
		patchBagButtons(self)
		local inventory = self
		local frame = self.uiFrame
		if frame then
			local oldOnHide = frame:GetScript("OnHide")
			frame:SetScript("OnHide", function()
				if oldOnHide then oldOnHide() end
				inventory.bseb_armed = nil
			end)
		end
	end

	-- 3. Keep the button's state in sync (enabled only online for the current character, lit while armed/running).
	local origUpdateToolbar = Inventory.UpdateToolbar
	Inventory.UpdateToolbar = function(self)
		origUpdateToolbar(self)
		local button = self.ui and self.ui.buttons and self.ui.buttons.toolbar and self.ui.buttons.toolbar.emptyBag
		if button then
			local active = self.bseb_armed or (job and job.inventory == self)
			self:SetToolbarButtonState(button, nil, canUse(self) or active, active)
			self.ui:SetIconButtonColors(button)
		end
		-- Bag buttons can be (re)created later; patch any new ones.
		patchBagButtons(self)
	end

	hooked = true
	return true
end

-- Bagshui builds its components when it gets ADDON_LOADED and its windows at PLAYER_LOGIN,
-- so the hooks must be in place in between.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
	if installHooks() then
		loader:UnregisterAllEvents()
	elseif event == "PLAYER_LOGIN" then
		chat("couldn't hook into Bagshui (version changed?). The Empty Bag button won't appear.")
	end
end)
installHooks()
