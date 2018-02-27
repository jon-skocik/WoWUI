-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                http://www.curse.com/addons/wow/tradeskill-master               --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

local _, TSM = ...
local Accounting = TSM.MainUI.Settings.Tooltip:NewPackage("Accounting")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster") -- loads the localization table
local private = {}



-- ============================================================================
-- Module Functions
-- ============================================================================

function Accounting.OnInitialize()
	TSM.MainUI.Settings.Tooltip.RegisterTooltipPage(L["Accounting"], private.GetTooltipSettingsFrame)
end



-- ============================================================================
-- Tooltip Settings UI
-- ============================================================================

function private.GetTooltipSettingsFrame()
	return TSMAPI_FOUR.UI.NewElement("ScrollFrame", "tooltipSettings")
		:SetStyle("padding.left", 12)
		:SetStyle("padding.right", 12)
		:AddChild(TSM.MainUI.Settings.Tooltip.CreateHeading("header", L["Accounting Tooltips"]))
		:AddChild(TSMAPI_FOUR.UI.NewElement("Text", "dbHeadingDesc")
			:SetStyle("height", 18)
			:SetStyle("margin.bottom", 24)
			:SetStyle("font", TSM.UI.Fonts.MontserratRegular)
			:SetStyle("fontHeight", 14)
			:SetStyle("textColor", "#ffffff")
			:SetText(L["Select which accounting information to display in item tooltips."])
		)
		:AddChild(TSM.MainUI.Settings.Tooltip.CreateCheckbox(L["Display sale info"], TSM.db.global.tooltipOptions.moduleTooltips.Accounting, "sale"))
		:AddChild(TSM.MainUI.Settings.Tooltip.CreateCheckbox(L["Display market value"], TSM.db.global.tooltipOptions.moduleTooltips.Accounting, "expiredAuctions"))
		:AddChild(TSM.MainUI.Settings.Tooltip.CreateCheckbox(L["Display cancelled since last sale"], TSM.db.global.tooltipOptions.moduleTooltips.Accounting, "cancelledAuctions"))
		:AddChild(TSM.MainUI.Settings.Tooltip.CreateCheckbox(L["Display sale rate"], TSM.db.global.tooltipOptions.moduleTooltips.Accounting, "saleRate"))
		:AddChild(TSM.MainUI.Settings.Tooltip.CreateCheckbox(L["Display purchase info"], TSM.db.global.tooltipOptions.moduleTooltips.Accounting, "purchase"))
end
