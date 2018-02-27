-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                http://www.curse.com/addons/wow/tradeskill-master               --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

local _, TSM = ...
local BidSearch = TSM.Sniper:NewPackage("BidSearch")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster") -- loads the localization table
local private = { scanThreadId = nil }



-- ============================================================================
-- Module Functions
-- ============================================================================

function BidSearch.OnInitialize()
	private.scanThreadId = TSMAPI_FOUR.Thread.New("SNIPER_BID_SEARCH", private.ScanThread)
end

function BidSearch.GetScanContext()
	return private.scanThreadId, private.MarketValueFunction
end



-- ============================================================================
-- Scan Thread
-- ============================================================================

function private.ScanThread(auctionScan)
	auctionScan:SetCustomFilterFunc(private.ScanFilter)
	local numFilters = auctionScan:GetNumFilters()
	if numFilters == 0 then
		auctionScan:NewAuctionFilter()
			:SetSniper(false)
	else
		assert(numFilters == 1)
	end
	local success = auctionScan:StartScanThreaded()
	return true
end

function private.ScanFilter(row)
	local itemDisplayedBid = row:GetField("itemDisplayedBid")
	if itemDisplayedBid == 0 then
		return true
	end

	local itemString = row:GetField("itemString")
	local groupPath = TSMAPI_FOUR.Groups.GetPathByItem(itemString) or TSM.CONST.ROOT_GROUP_PATH
	local _, operationSettings = TSMAPI.Operations:GetFirstByGroup(groupPath, "Sniper")
	if not operationSettings then
		return true
	end

	local maxPrice = TSMAPI_FOUR.CustomPrice.GetValue(operationSettings.belowPrice, itemString)
	if not maxPrice or itemDisplayedBid > maxPrice then
		return true
	end

	return false
end

function private.MarketValueFunction(row)
	local itemString = row:GetField("itemString")
	local groupPath = TSMAPI_FOUR.Groups.GetPathByItem(itemString) or TSM.CONST.ROOT_GROUP_PATH
	local _, operationSettings = TSMAPI.Operations:GetFirstByGroup(groupPath, "Sniper")
	return TSMAPI_FOUR.CustomPrice.GetValue(operationSettings.belowPrice, itemString)
end
