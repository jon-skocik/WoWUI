-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                http://www.curse.com/addons/wow/tradeskill-master               --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

local _, TSM = ...
local Sniper = TSM:NewPackage("Sniper")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster") -- loads the localization table
local private = {}
local OPERATION_DEFAULTS = {
	belowPrice = "max(vendorsell, ifgt(DBRegionMarketAvg, 250000g, 0.8, ifgt(DBRegionMarketAvg, 100000g, 0.7, ifgt(DBRegionMarketAvg, 50000g, 0.6, ifgt(DBRegionMarketAvg, 25000g, 0.5, ifgt(DBRegionMarketAvg, 10000g, 0.4, ifgt(DBRegionMarketAvg, 5000g, 0.3, ifgt(DBRegionMarketAvg, 2000g, 0.2, ifgt(DBRegionMarketAvg, 1000g, 0.1, 0.05)))))))) * DBRegionMarketAvg)",
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Sniper.OnInitialize()
	TSM.Operations.Register("Sniper", OPERATION_DEFAULTS, 1, private.GetOperationInfo)
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.GetOperationInfo(operationName)
	local operation = TSM.operations.Sniper[operationName]
	if not operation then return end
	return L["Sniping items below a max price"]
end
