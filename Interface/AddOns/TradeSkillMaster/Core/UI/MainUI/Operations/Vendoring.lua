-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                http://www.curse.com/addons/wow/tradeskill-master               --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

local _, TSM = ...
local Vendoring = TSM.MainUI.Operations:NewPackage("Vendoring")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster") -- loads the localization table
local private = { currentOperationName = nil }

local RESTOCK_SOURCES = { bank = BANK, guild = GUILD, alts = L["Alts"], alts_ah = L["Alts AH"], ah = L["AH"], mail = L["Mail"] }
local RESTOCK_SOURCES_ORDER = { "bank", "guild", "alts", "alts_ah", "ah", "mail" }

-- ============================================================================
-- Module Functions
-- ============================================================================

function Vendoring.OnInitialize()
	TSM.MainUI.Operations.RegisterModule("Vendoring", private.GetVendoringOperationSettings)
end



-- ============================================================================
-- Vendoring Operation Settings UI
-- ============================================================================

function private.GetVendoringOperationSettings(operationName)
	private.currentOperationName = operationName

	local factionrealmList = {}
	local factionrealmListOrder = {}
	for _, factionrealm in ipairs(TSM.db:GetScopeKeys("factionrealm")) do
		factionrealmList[factionrealm] = factionrealm
		tinsert(factionrealmListOrder, factionrealm)
	end

	-- TODO clean up tables
	local playerList = {}
	local playerListOrder = {}
	for factionrealm in TSM.db:GetConnectedRealmIterator("factionrealm") do
		for _, character in TSM.db:FactionrealmCharacterIterator(factionrealm) do
			local playerFullName = character.." - "..factionrealm
			playerList[playerFullName] = character
			tinsert(playerListOrder, playerFullName)
		end
	end

	local operation = TSM.operations.Vendoring[private.currentOperationName]
	return TSMAPI_FOUR.UI.NewElement("Frame", "content")
		:SetLayout("VERTICAL")
		:AddChild(TSMAPI_FOUR.UI.NewElement("Texture", "line")
			:SetStyle("color", "#9d9d9d")
			:SetStyle("height", 2)
			:SetStyle("margin", { top = 24 })
		)
		:AddChild(TSMAPI_FOUR.UI.NewElement("ScrollFrame", "settings")
			:SetStyle("background", "#1e1e1e")
			:SetStyle("padding", { left = 16, right = 16, top = -8 })
			:AddChild(TSM.MainUI.Operations.CreateHeadingLine("buyOptionsHeading", L["Buy Options"]))
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("enableBuyingLine", L["Enable buying?"])
				:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "enableBuyingFrame")
					:SetLayout("HORIZONTAL")
					-- move the right by the width of the toggle so this frame gets half the total width
					:SetStyle("margin", { right = -TSM.UI.TexturePacks.GetWidth("uiFrames.ToggleOn") })
					:AddChild(TSMAPI_FOUR.UI.NewElement("ToggleOnOff", "toggle")
						:SetSettingInfo(operation, "enableBuy")
						:SetScript("OnValueChanged", private.EnableBuyingToggleOnValueChanged)
					)
					:AddChild(TSMAPI_FOUR.UI.NewElement("Spacer", "spacer"))
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("restockQtyFrame", L["Restock quantity:"], not operation.enableBuy)
				:SetLayout("HORIZONTAL")
				:SetStyle("margin", { right = -112, bottom = 16 })
				:AddChild(TSMAPI_FOUR.UI.NewElement("InputNumeric", "restockQtyInput")
					:SetStyle("width", 96)
					:SetStyle("height", 24)
					:SetStyle("margin", { right = 16 })
					:SetStyle("justifyH", "CENTER")
					:SetStyle("font", TSM.UI.Fonts.MontserratBold)
					:SetStyle("fontHeight", 16)
					:SetSettingInfo(operation, "restockQty")
					:SetMaxNumber(5000)
					:SetDisabled(not operation.enableBuy)
				)
				:AddChild(TSMAPI_FOUR.UI.NewElement("Text", "restockQtyMaxLabel")
					:SetStyle("fontHeight", 14)
					:SetStyle("textColor", operation.enableBuy == nil and "#424242" or "#e2e2e2")
					:SetText(L["(max 5000)"])
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("restockSourcesFrame", L["Sources to include for restock:"], not operation.enableBuy)
				:AddChild(TSMAPI_FOUR.UI.NewElement("Dropdown", "restockSourcesDropdown")
					:SetMultiselect(true)
					:SetDictionaryItems(RESTOCK_SOURCES, operation.restockSources, RESTOCK_SOURCES_ORDER)
					:SetSettingInfo(operation, "restockSources")
					:SetDisabled(not operation.enableBuy)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateHeadingLine("sellOptionsHeading", L["Sell Options"]))
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("enableSellingSettingLine", L["Enable selling?"])
				:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "enableSellingFrame")
					:SetLayout("HORIZONTAL")
					-- move the right by the width of the toggle so this frame gets half the total width
					:SetStyle("margin", { right = -TSM.UI.TexturePacks.GetWidth("uiFrames.ToggleOn") })
					:AddChild(TSMAPI_FOUR.UI.NewElement("ToggleOnOff", "toggle")
						:SetSettingInfo(operation, "enableSell")
						:SetScript("OnValueChanged", private.EnableSellingToggleOnValueChanged)
					)
					:AddChild(TSMAPI_FOUR.UI.NewElement("Spacer", "spacer"))
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("keepQtyFrame", L["Keep quantity:"], not operation.enableSell)
				:SetLayout("HORIZONTAL")
				:SetStyle("margin", { right = -112, bottom = 16 })
				:AddChild(TSMAPI_FOUR.UI.NewElement("InputNumeric", "keepQtyInput")
					:SetStyle("width", 96)
					:SetStyle("height", 24)
					:SetStyle("margin", { right = 16 })
					:SetStyle("justifyH", "CENTER")
					:SetStyle("font", TSM.UI.Fonts.MontserratBold)
					:SetStyle("fontHeight", 16)
					:SetSettingInfo(operation, "keepQty")
					:SetMaxNumber(5000)
					:SetDisabled(not operation.enableSell)
				)
				:AddChild(TSMAPI_FOUR.UI.NewElement("Text", "keepQtyMaxLabel")
					:SetStyle("fontHeight", 14)
					:SetStyle("textColor", not operation.enableSell and "#424242" or "#e2e2e2")
					:SetText(L["(max 5000)"])
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("sellAfterExpiredFrame", L["Minimum expires:"], not operation.enableSell)
				:SetLayout("HORIZONTAL")
				:SetStyle("margin", { right = -112, bottom = 16 })
				:AddChild(TSMAPI_FOUR.UI.NewElement("InputNumeric", "sellAfterExpiredInput")
					:SetStyle("width", 96)
					:SetStyle("height", 24)
					:SetStyle("margin", { right = 16 })
					:SetStyle("justifyH", "CENTER")
					:SetStyle("font", TSM.UI.Fonts.MontserratBold)
					:SetStyle("fontHeight", 16)
					:SetSettingInfo(operation, "sellAfterExpired")
					:SetMaxNumber(5000)
					:SetDisabled(not operation.enableSell)
				)
				:AddChild(TSMAPI_FOUR.UI.NewElement("Text", "sellAfterExpiredMaxLabel")
					:SetStyle("fontHeight", 14)
					:SetStyle("textColor", not operation.enableSell and "#424242" or "#e2e2e2")
					:SetText(L["(max 5000)"])
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("marketValueSettingLine", L["Market Value"], not operation.enableSell))
			:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "marketValueFrame")
				:SetLayout("HORIZONTAL")
				:SetStyle("height", 32)
				:SetStyle("margin", { bottom = 16 })
				:AddChild(TSMAPI_FOUR.UI.NewElement("Input", "marketValueInput")
					:SetSettingInfo(operation, "vsMarketValue", TSM.MainUI.Operations.CheckCustomPrice)
					:SetStyle("background", "#1ae2e2e2")
					:SetStyle("textColor", not operation.enableSell and "#424242" or "#e2e2e2")
					:SetStyle("height", 32)
					:SetDisabled(not operation.enableSell)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("vsMaxMarketValueSettingLine", L["Maximum Market Value (Enter ‘0c’ to disable)"], not operation.enableSell))
			:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "vsMaxMarketValueFrame")
				:SetLayout("HORIZONTAL")
				:SetStyle("height", 32)
				:SetStyle("margin", { bottom = 16 })
				:AddChild(TSMAPI_FOUR.UI.NewElement("Input", "vsMaxMarketValueInput")
					:SetSettingInfo(operation, "vsMaxMarketValue", TSM.MainUI.Operations.CheckCustomPrice)
					:SetStyle("background", "#1ae2e2e2")
					:SetStyle("textColor", not operation.enableSell and "#424242" or "#e2e2e2")
					:SetStyle("height", 32)
					:SetDisabled(not operation.enableSell)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("vsDestroyValueSettingLine", L["Destroy Value"], not operation.enableSell))
			:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "vsDestroyValueFrame")
				:SetLayout("HORIZONTAL")
				:SetStyle("height", 32)
				:SetStyle("margin", { bottom = 16 })
				:AddChild(TSMAPI_FOUR.UI.NewElement("Input", "vsDestroyValueInput")
					:SetSettingInfo(operation, "vsDestroyValue", TSM.MainUI.Operations.CheckCustomPrice)
					:SetStyle("background", "#1ae2e2e2")
					:SetStyle("textColor", not operation.enableSell and "#424242" or "#e2e2e2")
					:SetStyle("height", 32)
					:SetDisabled(not operation.enableSell)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("vsMaxDestroyValueSettingLine", L["Maximum Destroy Value (Enter ‘0c’ to disable)"], not operation.enableSell))
			:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "vsMaxDestroyValueFrame")
				:SetLayout("HORIZONTAL")
				:SetStyle("height", 32)
				:SetStyle("margin", { bottom = 16 })
				:AddChild(TSMAPI_FOUR.UI.NewElement("Input", "vsMaxDestroyValueInput")
					:SetSettingInfo(operation, "vsMaxDestroyValue", TSM.MainUI.Operations.CheckCustomPrice)
					:SetStyle("background", "#1ae2e2e2")
					:SetStyle("textColor", not operation.enableSell and "#424242" or "#e2e2e2")
					:SetStyle("height", 32)
					:SetDisabled(not operation.enableSell)
				)
			)
			:AddChild(TSM.MainUI.Operations.CreateLinkedSettingLine("sellSoulboundSettingLine", L["Sell soulbound items?"], not operation.enableSell)
				:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "sellSoulboundSettingFrame")
					:SetLayout("HORIZONTAL")
					-- move the right by the width of the toggle so this frame gets half the total width
					:SetStyle("margin", { right = -TSM.UI.TexturePacks.GetWidth("uiFrames.ToggleOn") })
					:AddChild(TSMAPI_FOUR.UI.NewElement("ToggleOnOff", "sellSoulbound")
						:SetSettingInfo(operation, "sellSoulbound")
						:SetDisabled(not operation.enableSell)
					)
					:AddChild(TSMAPI_FOUR.UI.NewElement("Spacer", "spacer"))
				)
			)
			:AddChild(TSM.MainUI.Operations.GetOperationManagementElements("Vendoring", private.currentOperationName))
		)
end




-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.EnableBuyingToggleOnValueChanged(toggle, value)
	local operation = TSM.operations.Vendoring[private.currentOperationName]
	local settingsFrame = toggle:GetParentElement():GetParentElement():GetParentElement()
	settingsFrame:GetElement("restockQtyFrame.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("restockQtyFrame.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("restockQtyFrame.restockQtyInput")
		:SetDisabled(not value)
		:SetText(TSMAPI_FOUR.Money.ToString(operation.restockQty, "OPT_NO_COLOR") or operation.restockQty or "")
	settingsFrame:GetElement("restockSourcesFrame.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("restockSourcesFrame.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("restockSourcesFrame.restockSourcesDropdown")
		:SetDisabled(not value)
	settingsFrame:Draw()
end

function private.EnableSellingToggleOnValueChanged(toggle, value)
	local operation = TSM.operations.Vendoring[private.currentOperationName]
	local settingsFrame = toggle:GetParentElement():GetParentElement():GetParentElement()
	settingsFrame:GetElement("keepQtyFrame.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("keepQtyFrame.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("keepQtyFrame.keepQtyInput")
		:SetDisabled(not value)
		:SetText(TSMAPI_FOUR.Money.ToString(operation.keepQty, "OPT_NO_COLOR") or operation.keepQty or "")
	settingsFrame:GetElement("keepQtyFrame.keepQtyMaxLabel")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")

	settingsFrame:GetElement("sellAfterExpiredFrame.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("sellAfterExpiredFrame.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("sellAfterExpiredFrame.sellAfterExpiredInput")
		:SetDisabled(not value)
		:SetText(TSMAPI_FOUR.Money.ToString(operation.sellAfterExpired, "OPT_NO_COLOR") or operation.sellAfterExpired or "")
	settingsFrame:GetElement("sellAfterExpiredFrame.sellAfterExpiredMaxLabel")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")

	settingsFrame:GetElement("marketValueSettingLine.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("marketValueSettingLine.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("marketValueFrame.marketValueInput")
		:SetDisabled(not value)
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")

	settingsFrame:GetElement("vsMaxMarketValueSettingLine.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("vsMaxMarketValueSettingLine.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("vsMaxMarketValueFrame.vsMaxMarketValueInput")
		:SetDisabled(not value)
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")

	settingsFrame:GetElement("vsDestroyValueSettingLine.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("vsDestroyValueSettingLine.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("vsDestroyValueFrame.vsDestroyValueInput")
		:SetDisabled(not value)
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")

	settingsFrame:GetElement("vsMaxDestroyValueSettingLine.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("vsMaxDestroyValueSettingLine.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("vsMaxDestroyValueFrame.vsMaxDestroyValueInput")
		:SetDisabled(not value)
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")

	settingsFrame:GetElement("sellSoulboundSettingLine.left.linkBtn")
		:SetStyle("backgroundVertexColor", value and "#ffffff" or "#424242")
		:SetDisabled(not value)
	settingsFrame:GetElement("sellSoulboundSettingLine.left.label")
		:SetStyle("textColor", value and "#e2e2e2" or "#424242")
	settingsFrame:GetElement("sellSoulboundSettingLine.sellSoulboundSettingFrame.sellSoulbound")
		:SetDisabled(not value)

	settingsFrame:Draw()
end
