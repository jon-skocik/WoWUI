-- ------------------------------------------------------------------------------ --
--                           TradeSkillMaster_Accounting                          --
--           http://www.curse.com/addons/wow/tradeskillmaster_accounting          --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

-- create a local reference to the TradeSkillMaster_Accounting table and register a new module
local TSMCore = select(2, ...)
local TSM = TSMCore.old.Accounting
local Merchant = TSM:NewPackage("Merchant", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster") -- loads the localization table
local private = {repairMoney=0, couldRepair=nil, repairCost=0, canRepair=nil, pendingSales={}}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Merchant:OnEnable()
	TSMAPI_FOUR.Event.Register("MERCHANT_SHOW", private.SetupRepairCost)
	TSMAPI_FOUR.Event.Register("MERCHANT_UPDATE", private.OnMerchantUpdate)
	TSMAPI_FOUR.Event.Register("UPDATE_INVENTORY_DURABILITY", private.AddRepairCosts)
	TSMAPI_FOUR.Event.Register("MERCHANT_CLOSED", private.OnMerchantClosed)
	Merchant:SecureHook("UseContainerItem", private.CheckMerchantSale)
	Merchant:SecureHook("BuyMerchantItem", private.OnMerchantBuy)
	Merchant:SecureHook("BuybackItem", private.OnMerchantBuyback)
end



-- ============================================================================
-- Repair Cost Tracking
-- ============================================================================

function private.SetupRepairCost()
	private.repairMoney = GetMoney()
	private.couldRepair = CanMerchantRepair()
	-- if merchant can repair set up variables so we can track repairs
	if private.couldRepair then
		local cost, canRepair = GetRepairAllCost()
		private.repairCost = cost
		private.canRepair = canRepair
	end
end

function private.OnMerchantUpdate()
	-- Could have bought something before or after repair
	private.repairMoney = GetMoney()
	-- log any pending sales
	for _, info in ipairs(private.pendingSales) do
		if GetTime() - info.insertTime < 5 then
			TSM.Data:InsertItemSaleRecord(unpack(info))
		end
	end
	wipe(private.pendingSales)
end

function private.AddRepairCosts()
	if private.couldRepair and private.repairCost > 0 then
		local cash = GetMoney()
		if private.repairMoney > cash then
			-- this is probably a repair bill
			local cost = private.repairMoney - cash
			TSM.Data:InsertMoneyExpenseRecord("Repair", cost, "Merchant")
			-- reset money as this might have been a single item repair
			private.repairMoney = cash
			-- reset the repair cost for the next repair
			private.repairCost, private.canRepair = GetRepairAllCost()
		end
	end
end

function private.OnMerchantClosed()
	private.couldRepair = nil
	private.repairCost = 0
end


-- ============================================================================
-- Merchant Purchases / Sales Tracking
-- ============================================================================

function private.CheckMerchantSale(bag, slot, onSelf)
	-- check if we are trying to sell something to a vendor
	if MerchantFrame:IsShown() and not onSelf then
		local itemString = TSMAPI_FOUR.Item.ToItemString(GetContainerItemLink(bag, slot))
		local quantity = select(2, GetContainerItemInfo(bag, slot))
		local copper = TSMAPI_FOUR.Item.GetVendorSell(itemString)
		tinsert(private.pendingSales, {itemString, "Vendor", quantity, copper, "Merchant", insertTime=GetTime()})
	end
end

function private.OnMerchantBuy(index, quantity)
	local price, batchQuantity = select(3, GetMerchantItemInfo(index))
	if not price or price <= 0 then return end
	quantity = quantity or batchQuantity
	local itemString = TSMAPI_FOUR.Item.ToItemString(GetMerchantItemLink(index))
	local copper = TSMAPI_FOUR.Util.Round(price / batchQuantity)
	TSM.Data:InsertItemBuyRecord(itemString, "Vendor", quantity, copper, "Merchant")
end

function private.OnMerchantBuyback(index)
	local price, quantity = select(3, GetBuybackItemInfo(index))
	local itemString = TSMAPI_FOUR.Item.ToItemString(GetBuybackItemLink(index))
	local copper = TSMAPI_FOUR.Util.Round(price / quantity)
	TSM.Data:InsertItemBuyRecord(itemString, "Vendor", quantity, copper, "Merchant")
end
