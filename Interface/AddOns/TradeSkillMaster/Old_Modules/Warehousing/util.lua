-- ------------------------------------------------------------------------------ --
--                          TradeSkillMaster_Warehousing                          --
--          http://www.curse.com/addons/wow/tradeskillmaster_warehousing          --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

local TSMCore = select(2, ...)
local TSM = TSMCore.old.Warehousing
local util = TSM:NewPackage("util")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster") -- loads the localization table

-- this is a set of wrapper functions so that I can switch
-- between guildbank and bank function easily


util.pickupContainerItemSrc = nil
util.getContainerItemIDSrc = nil
util.getContainerNumSlotsSrc = nil
util.getContainerItemLinkSrc = nil
util.getContainerNumFreeSlotsSrc = nil
util.splitContainerItemSrc = nil

util.pickupContainerItemDest = nil
util.getContainerItemIDDest = nil
util.getContainerNumSlotsDest = nil
util.getContainerItemLinkDest = nil
util.getContainerNumFreeSlotsDest = nil

util.getItemString = nil
util.autoStoreItem = nil


function util:setSrcBagFunctions(bagType)
	if bagType == "guildbank" then
		util.autoStoreItem = function(bag, slot) AutoStoreGuildBankItem(bag, slot) end
		util.splitContainerItemSrc = function(bag, slot, need) SplitGuildBankItem(bag, slot, need); end
		util.pickupContainerItemSrc = function(bag, slot) PickupGuildBankItem(bag, slot) end
		util.getContainerNumSlotsSrc = function(bag) return MAX_GUILDBANK_SLOTS_PER_TAB or 98 end
		util.getContainerItemLinkSrc = function(bag, slot) return GetGuildBankItemLink(bag, slot) end
		util.getContainerNumFreeSlotsSrc = function(bag) return MAX_GUILDBANK_SLOTS_PER_TAB or 98 end --need to change this eventually
		util.getContainerItemIDSrc = function(bag, slot)
			local tmpLink = GetGuildBankItemLink(bag, slot)
			local quantity = select(2, GetGuildBankItemInfo(bag, slot))
			if tmpLink then
				return TSMAPI.Item:ToItemString(tmpLink), quantity
			else
				return nil
			end
		end
	elseif bagType == "mail" then
		util.autoStoreItem = function(bag, slot) TakeInboxItem(bag, slot) end
		util.splitContainerItemSrc = function(bag, slot, need) TakeInboxItem(bag, slot) end
		util.pickupContainerItemSrc = function(bag, slot) return end
		util.getContainerItemIDSrc = function(bag, slot)
			local quantity = select(3, GetInboxItem(bag, slot))
			local tmpLink = GetInboxItemLink(bag, slot)
			return TSMAPI.Item:ToItemString(tmpLink), quantity
		end
		util.getContainerNumSlotsSrc = function(bag) return 16 end
		util.getContainerItemLinkSrc = function(bag, slot) return GetInboxItemLink(bag, slot) end
		util.getContainerNumFreeSlotsSrc = function(bag) return 16 end
	else
		util.autoStoreItem = function(bag, slot) UseContainerItem(bag, slot) end
		util.splitContainerItemSrc = function(bag, slot, need) SplitContainerItem(bag, slot, need) end
		util.pickupContainerItemSrc = function(bag, slot) PickupContainerItem(bag, slot) end
		util.getContainerItemIDSrc = function(bag, slot)
			local tmpLink = GetContainerItemLink(bag, slot)
			local quantity = select(2, GetContainerItemInfo(bag, slot))
			return TSMAPI.Item:ToItemString(tmpLink), quantity
		end
		util.getContainerNumSlotsSrc = function(bag) return GetContainerNumSlots(bag) end
		util.getContainerItemLinkSrc = function(bag, slot) return GetContainerItemLink(bag, slot) end
		util.getContainerNumFreeSlotsSrc = function(bag) return GetContainerNumFreeSlots(bag) end
	end
end

function util:setDestBagFunctions(bagType)
	if bagType == "guildbank" then
		util.pickupContainerItemDest = function(bag, slot) PickupGuildBankItem(bag, slot) end
		util.getContainerNumSlotsDest = function(bag) return 98 end
		util.getContainerNumFreeSlotsDest = function(bag) return 98 end --need to change this eventually
		util.getContainerItemLinkDest = function(bag, slot) return GetGuildBankItemLink(bag, slot) end
		util.getContainerItemIDDest = function(bag, slot)
			local tmpLink = GetGuildBankItemLink(bag, slot)
			local quantity = select(2, GetGuildBankItemInfo(bag, slot))
			if tmpLink then
				return TSMAPI.Item:ToItemString(tmpLink), quantity
			else
				return nil
			end
		end
	else
		util.pickupContainerItemDest = function(bag, slot) PickupContainerItem(bag, slot) end
		util.getContainerItemIDDest = function(bag, slot)
			local tmpLink = GetContainerItemLink(bag, slot)
			local quantity = select(2, GetContainerItemInfo(bag, slot))
			return TSMAPI.Item:ToItemString(tmpLink), quantity
		end
		util.getContainerNumSlotsDest = function(bag) return GetContainerNumSlots(bag) end
		util.getContainerItemLinkDest = function(bag, slot) return GetContainerItemLink(bag, slot) end
		util.getContainerNumFreeSlotsDest = function(bag) return GetContainerNumFreeSlots(bag) end
	end
end
