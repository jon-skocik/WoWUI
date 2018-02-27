-- ------------------------------------------------------------------------------ --
--                            TradeSkillMaster_Mailing                            --
--            http://www.curse.com/addons/wow/tradeskillmaster_mailing            --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

local TSMCore = select(2, ...)
local TSM = TSMCore.old.Mailing
local BankUI = TSM:NewPackage("BankUI")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster") -- loads the localization table
local private = {frame=nil, currentBank=nil}


function BankUI:OnEnable()
	TSMAPI_FOUR.Event.Register("GUILDBANKFRAME_OPENED", private.EventHandler)
	TSMAPI_FOUR.Event.Register("BANKFRAME_OPENED", private.EventHandler)
	TSMAPI_FOUR.Event.Register("GUILDBANKFRAME_CLOSED", private.EventHandler)
	TSMAPI_FOUR.Event.Register("BANKFRAME_CLOSED", private.EventHandler)
end

function private.EventHandler(event)
	if event == "GUILDBANKFRAME_OPENED" then
		private.currentBank = "guildbank"
	elseif event == "BANKFRAME_OPENED" then
		private.currentBank = "bank"
	elseif event == "GUILDBANKFRAME_CLOSED" or event == "BANKFRAME_CLOSED" then
		private.currentBank = nil
	end
end

function BankUI.createTab(parent)
	if private.frame then return private.frame end

	local BFC = TSMAPI.GUI:GetBuildFrameConstants()
	local frameInfo = {
		type = "Frame",
		parent = parent,
		hidden = true,
		points = "ALL",
		children = {
			{
				type = "GroupTreeFrame",
				key = "groupTree",
				groupTreeInfo = {"Mailing", "Mailing_Bank"},
				points = {{"TOPLEFT"}, {"BOTTOMRIGHT", 0, 137}},
			},
			{
				type = "Frame",
				key = "buttonFrame",
				points = {{"TOPLEFT", BFC.PREV, "BOTTOMLEFT", 0, 0}, {"BOTTOMRIGHT"}},
				children = {
					{
						type = "Button",
						key = "btnToBank",
						text = L["Move Group to Bank"],
						textHeight = 16,
						size = {0, 26},
						points = {{"TOPLEFT", 5, -5}, {"TOPRIGHT", -5, -5}},
						scripts = {"OnClick"},
					},
					{
						type = "Button",
						key = "btnNonGroup",
						text = L["Move Non Group Items to Bank"],
						textHeight = 16,
						size = {0, 26},
						points = {{"TOPLEFT", BFC.PREV, "BOTTOMLEFT", 0, -5}, {"TOPRIGHT", BFC.PREV, "BOTTOMRIGHT", 0, -5}},
						scripts = {"OnClick"},
					},
					{
						type = "HLine",
						size = {0, 2},
						points = {{"TOPLEFT", BFC.PREV, "BOTTOMLEFT", -5, -5}, {"TOPRIGHT", BFC.PREV, "BOTTOMRIGHT", 5, -5}},
					},
					{
						type = "Button",
						key = "btnTargetToBags",
						text = L["Move Target Shortfall To Bags"],
						textHeight = 16,
						size = {0, 26},
						points = {{"TOPLEFT", BFC.PREV, "BOTTOMLEFT", 5, -5}, {"TOPRIGHT", BFC.PREV, "BOTTOMRIGHT", -5, -5}},
						scripts = {"OnClick"},
					},
					{
						type = "Button",
						key = "btnAllToBags",
						text = L["Move Group To Bags"],
						textHeight = 16,
						size = {0, 27},
						points = {{"TOPLEFT", BFC.PREV, "BOTTOMLEFT", 0, -5}, {"TOPRIGHT", BFC.PREV, "BOTTOMRIGHT", 0, -5}},
						scripts = {"OnClick"},
					},
				},
			},
		},
		handlers = {
			buttonFrame = {
				btnToBank = {
					OnClick = function() BankUI:groupTree(private.frame.groupTree:GetSelectedGroupInfo(), "bags") end,
				},
				btnNonGroup = {
					OnClick = function() BankUI:nonGroupTree(private.frame.groupTree:GetSelectedGroupInfo(), "bags") end,
				},
				btnTargetToBags = {
					OnClick = function() BankUI:groupTree(private.frame.groupTree:GetSelectedGroupInfo(), private.currentBank) end,
				},
				btnAllToBags = {
					OnClick = function() BankUI:groupTree(private.frame.groupTree:GetSelectedGroupInfo(), private.currentBank, true) end,
				},
			},
		},
	}

	private.frame = TSMAPI.GUI:BuildFrame(frameInfo)
	return private.frame
end

function BankUI:groupTree(grpInfo, src, all)
	local next = next
	local targets = {}
	local newgrp = {}
	local totalItems = BankUI:getTotalItems(src)
	local bagItems = BankUI:getTotalItems("bags") or {}
	for groupName, data in pairs(grpInfo) do
		groupName = TSMAPI.Groups:FormatPath(groupName, true)
		for _, opName in ipairs(data.operations) do
			TSMAPI.Operations:Update("Mailing", opName)
			local operation = TSM.operations[opName]
			if TSM.Groups:ValidateOperation(operation, opName) then
				--it's a valid operation
				for itemString in pairs(data.items) do
					local totalq = 0
					local usedq = 0
					if totalItems then
						totalq = totalItems[itemString] or 0
					end
					if src == "bags" then -- move them all back to bank/gbank
						if totalq > 0 then
							newgrp[itemString] = totalq * -1
							totalItems[itemString] = nil -- remove the current bag count in case we loop round for another operation
						end
					else -- move from bank/gbank to bags
						if totalq > 0 then
							if all then
								newgrp[itemString] = totalq
								totalq = 0
							else
								local numAvailable = (totalItems[itemString] or 0) - operation.keepQty
								if numAvailable > 0 then
									local quantity, reserveQty = 0, 0
									if operation.maxQtyEnabled then
										if not operation.restock then
											quantity = min(numAvailable, operation.maxQty)
										else
											local targetQty = TSM.Groups:GetTargetQuantity(operation.target, itemString, operation.restockSources)
											if TSMAPI.Player:IsPlayer(operation.target) and targetQty <= operation.maxQty then
												quantity = numAvailable
											else
												quantity = min(numAvailable, operation.maxQty - targetQty)
											end
											if TSMAPI.Player:IsPlayer(operation.target) then
												-- if using restock and target == player ensure that subsequent operations don't take reserved bag inventory
												reserveQty = numAvailable - (targetQty - operation.maxQty)
											end
										end
									else
										quantity = numAvailable
									end
									if quantity > 0 then
										totalItems[itemString] = totalItems[itemString] - quantity
										targets[operation.target] = targets[operation.target] or {}
										targets[operation.target][itemString] = quantity
									elseif reserveQty > 0 then -- some of the bag inventory is reserved so make unavailable for next operation
										totalItems[itemString] = totalItems[itemString] - reserveQty
									end
								else -- as available quantity was used up by this operation make sure its not available for any subsequent operations
									totalItems[itemString] = nil
								end
							end
						end
					end
				end
			end
		end
	end

	for target in pairs(targets) do
		if TSMAPI.Player:IsPlayer(target) then
			targets[target] = nil
		end
	end

	for target, data in pairs(targets) do
		for itemString, quantity in pairs(data) do
			newgrp[itemString] = (newgrp[itemString] or 0) + quantity
		end
	end


	if next(newgrp) == nil then
		TSM:Print(L["Nothing to Move"])
	else
		TSM:Print(L["Preparing to Move"])
		TSMAPI:MoveItems(newgrp, BankUI.PrintMsg, false)
	end
end

function BankUI:nonGroupTree(grpInfo, src)
	local next = next
	local newgrp = {}
	local bagItems = BankUI:getTotalItems("bags")
	for groupName, data in pairs(grpInfo) do
		groupName = TSMAPI.Groups:FormatPath(groupName, true)
		for _, opName in ipairs(data.operations) do
			TSMAPI.Operations:Update("Mailing", opName)
			local operation = TSM.operations[opName]
			if TSM.Groups:ValidateOperation(operation, opName) then
				-- it's a valid operation so remove all the items from bagItems so we are left with non group items to move
				for itemString in pairs(data.items) do
					if bagItems then
						if bagItems[itemString] then
							bagItems[itemString] = nil
						end
					end
				end
			end
		end
	end


	for itemString, quantity in pairs(bagItems) do
		quantity = quantity * -1
		if newgrp[itemString] then
			newgrp[itemString] = newgrp[itemString] + quantity
		else
			newgrp[itemString] = quantity
		end
	end

	if next(newgrp) == nil then
		TSM:Print(L["Nothing to Move"])
	else
		TSM:Print(L["Preparing to Move"])
		TSMAPI:MoveItems(newgrp, BankUI.PrintMsg)
	end
end

function BankUI.PrintMsg(message)
	TSM:Print(message)
end

function BankUI:getTotalItems(src)
	local results = {}
	if src == "bank" then
		local function ScanBankBag(bag)
			for slot = 1, GetContainerNumSlots(bag) do
				if not TSMAPI.Item:IsSoulbound(bag, slot, true) then
					local itemString = TSMAPI.Item:ToBaseItemString(GetContainerItemLink(bag, slot), true)
					if itemString then
						local quantity = select(2, GetContainerItemInfo(bag, slot))
						if not results[itemString] then results[itemString] = 0 end
						results[itemString] = results[itemString] + quantity
					end
				end
			end
		end

		for bag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
			ScanBankBag(bag)
		end
		ScanBankBag(-1)
		if IsReagentBankUnlocked() then
			ScanBankBag(-3)
		end

		return results
	elseif src == "guildbank" then
		for bag = 1, GetNumGuildBankTabs() do
			for slot = 1, MAX_GUILDBANK_SLOTS_PER_TAB or 98 do
				local link = GetGuildBankItemLink(bag, slot)
				local itemString = TSMAPI.Item:ToBaseItemString(link, true)
				if itemString then
					if itemString == "i:82800" then
						local speciesID = GameTooltip:SetGuildBankItem(bag, slot)
						itemString = speciesID and ("p:" .. speciesID)
					end
					local quantity = select(2, GetGuildBankItemInfo(bag, slot))
					if not results[itemString] then results[itemString] = 0 end
					results[itemString] = results[itemString] + quantity
				end
			end
		end

		return results
	elseif src == "bags" then
		for _, _, _, itemString, quantity in TSMAPI.Inventory:BagIterator(true, false, true) do
			results[itemString] = (results[itemString] or 0) + quantity
		end
	end
	return results
end
