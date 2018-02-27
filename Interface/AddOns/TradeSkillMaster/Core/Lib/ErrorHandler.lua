-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                http://www.curse.com/addons/wow/tradeskill-master               --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

-- TSM's error handler

local _, TSM = ...
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster")
local AceGUI = LibStub("AceGUI-3.0")
local private = { errorFrame = nil, isSilent = nil, errorSuppressed = nil, errorReports = {}, num = 0 }
local IS_DEV_VERSION = GetAddOnMetadata("TradeSkillMaster", "Version") == "@project-version@"
local MAX_ERROR_REPORT_AGE = 7 * 24 * 60 * 60 -- 1 week
local MAX_STACK_DEPTH = 50
local ADDON_SUITES = {
	"ArkInventory",
	"AtlasLoot",
	"Altoholic",
	"Auc-",
	"Bagnon",
	"BigWigs",
	"Broker",
	"ButtonFacade",
	"Carbonite",
	"DataStore",
	"DBM",
	"Dominos",
	"DXE",
	"EveryQuest",
	"Forte",
	"FuBar",
	"GatherMate2",
	"Grid",
	"LightHeaded",
	"LittleWigs",
	"Masque",
	"MogIt",
	"Odyssey",
	"Overachiever",
	"PitBull4",
	"Prat-3.0",
	"RaidAchievement",
	"Skada",
	"SpellFlash",
	"TidyPlates",
	"TipTac",
	"Titan",
	"UnderHood",
	"WowPro",
	"ZOMGBuffs",
}



-- ============================================================================
-- Module Functions
-- ============================================================================

function TSM:ShowManualError()
	private.isManual = true
	TSM:ShowError("Manually triggered error")
end

function TSM:ShowError(err, thread)
	local stackLine
	if thread then
		local stackLine = debugstack(thread, 0, 1, 0)
		local oldModule = strmatch(stackLine, "(lMaster_[A-Za-z]+)")
		if oldModule and tContains(TSM.CONST.OLD_TSM_MODULES, "TradeSkil"..oldModule) then
			-- ignore errors from old modules
			return
		end
	end
	-- show an error, but don't cause an exception to be thrown
	private.isSilent = true
	private.ErrorHandler(err, thread, debugprofilestop())
end

function TSM.SaveErrorReports(appDB)
	appDB.errorReports = appDB.errorReports or { updateTime = 0, data = {} }
	if #private.errorReports > 0 then
		appDB.errorReports.updateTime = private.errorReports[#private.errorReports].timestamp
	end
	-- remove any events which are too old
	for i = #appDB.errorReports.data, 1, -1 do
		local event = appDB.errorReports.data
		local timestamp = strmatch(appDB.errorReports.data[i], "([0-9]+)%]$") or ""
		if (tonumber(timestamp) or 0) < time() - MAX_ERROR_REPORT_AGE then
			tremove(appDB.errorReports.data, i)
		end
	end
	for _, report in ipairs(private.errorReports) do
		local line = format("[\"%s\",\"%s\",%d]", report.errMsg, report.details, report.timestamp)
		tinsert(appDB.errorReports.data, line)
	end
end



-- ============================================================================
-- Error Handler
-- ============================================================================

function private.ErrorHandler(msg, thread, errorTime)
	-- ignore errors while we are handling this error
	private.ignoreErrors = true
	local isSilent = private.isSilent
	private.isSilent = nil
	local isManual = private.isManual
	private.isManual = nil

	if type(thread) ~= "thread" then
		thread = nil
	end

	if thread then
		msg = gsub(msg, ".+TradeSkillMaster\\Core\\Threading%.lua:%d+:", "")
	end

	local color = "|cff99ffff"
	local errMsgParts = {}

	-- build stack trace with locals and get addon name
	local addonName = "?"
	local errLocation = strmatch(msg, "[A-Za-z]+%.lua:[0-9]+")
	local stackInfo = { color.."Stack Trace:|r" }
	local stackStarted = false
	for i = 0, MAX_STACK_DEPTH do
		local stackLine = nil
		if thread then
			stackLine = debugstack(thread, i, 1, 0)
		else
			stackLine = debugstack(i, 1, 0)
		end
		if not stackStarted then
			if errLocation then
				stackStarted = strmatch(stackLine, "[A-Za-z]+%.lua:[0-9]+") == errLocation
			else
				stackStarted = (i > (thread and 1 or 4) and not strmatch(stackLine, "^%[C%]:"))
			end
			if stackStarted then
				addonName = private.IsTSMAddon(stackLine) or (isSilent and "TradeSkillMaster")
			end
		end
		if stackStarted then
			stackLine = gsub(stackLine, "%.%.%.T?r?a?d?e?S?k?i?l?lM?a?ster([_A-Za-z]*)\\", "TradeSkillMaster%1\\")
			stackLine = gsub(stackLine, "%.%.%.", "")
			stackLine = strtrim(stackLine)
			local strStart = strfind(stackLine, "in function")
			local functionName = nil
			if strStart then
				stackLine = gsub(stackLine, "`", "<", 1)
				stackLine = gsub(stackLine, "'", ">", 1)
				local inFunction = strmatch(stackLine, "<[^>]*>", strStart)
				if inFunction then
					inFunction = gsub(gsub(inFunction, ".*\\", ""), "<", "")
					if inFunction ~= "" then
						local str = strsub(stackLine, 1, strStart-2)
						str = strsub(str, strfind(str, "TradeSkillMaster") or 1)
						if strfind(inFunction, "`") then
							inFunction = strsub(inFunction, 2, -2)..">"
						end
						str = gsub(str, "TradeSkillMaster([^%.])", "TSM%1")
						functionName = strsub(inFunction, 1, -2)
						stackLine = str.." <"..inFunction
					end
				end
			end
			if strfind(stackLine, "Class%.lua:192") then
				-- ignore stack frames from the class code's wrapper function
				stackLine = ""
				if functionName and not strmatch(functionName, "^.+:[0-9]+$") and #stackInfo > 0 then
					local prevFunctionName = strmatch(stackInfo[#stackInfo], "[^\n]+<([^>]+)>\n")
					if prevFunctionName and strmatch(prevFunctionName, "^.+:[0-9]+$") then
						-- this stack frame includes the class method we were accessing in the previous one, so go back and fix it up
						local locals = debuglocals(i)
						local className = locals and strmatch(locals, "\n +str = \"([A-Za-z_0-9]+):[0-9A-F]+\"\n") or "?"
						functionName = className.."."..functionName
						stackInfo[#stackInfo] = gsub(stackInfo[#stackInfo], gsub(prevFunctionName, "%.", "%."), functionName)
					end
				end
			end
			if stackLine ~= "" then
				local localsInfo = {}
				-- add locals for addon functions (debuglocals() doesn't always work - or ever for threads)
				local locals = debuglocals(i)
				if locals and not strmatch(stackLine, "^%[") then
					locals = gsub(locals, "<table> {[\n\t ]+}", "<table> {}")
					for _, localLine in ipairs({strsplit("\n", locals)}) do
						if localLine ~= "" and not strmatch(localLine, "^ *%(") then
							localLine = strrep("  ", #strmatch(localLine, "^ *"))..strtrim(localLine)
							localLine = gsub(localLine, "@Interface\\[aA]dd[Oo]ns\\TradeSkillMaster", "@TSM")
							localLine = gsub(localLine, "\124", "\\124")
							localLine = "        |cffaaaaaa"..localLine.."|r"
							tinsert(localsInfo, localLine)
						end
					end
				end
				if #localsInfo > 0 then
					stackLine = stackLine.."\n"..table.concat(localsInfo, "\n")
				end
				tinsert(stackInfo, stackLine)
			end
		end
	end

	-- add error message
	tinsert(errMsgParts, color.."Message:|r "..msg)

	-- add current date/time
	tinsert(errMsgParts, color.."Time:|r "..date("%m/%d/%y %H:%M:%S").." ("..floor(errorTime)..")")

	-- add current client version number
	tinsert(errMsgParts, color.."Client:|r "..GetBuildInfo())

	-- add locale name
	tinsert(errMsgParts, color.."Locale:|r "..GetLocale())

	-- is player in combat
	tinsert(errMsgParts, color.."Combat:|r "..tostring(InCombatLockdown()))

	-- add the error number
	private.num = private.num + 1
	tinsert(errMsgParts, color.."Error Count:|r "..private.num)

	-- add stack info
	tinsert(errMsgParts, table.concat(stackInfo, "\n    "))

	-- add temp table info
	local status, tempTableInfo = pcall(TSMAPI_FOUR.Util.GetTempTableDebugInfo)
	if status then
		tinsert(errMsgParts, color.."Temp Table Info:|r\n    "..table.concat(tempTableInfo, "\n    "))
	end

	-- add TSM thread info
	local status, threadInfo = pcall(TSMAPI_FOUR.Thread.GetDebugInfo)
	if status then
		tinsert(errMsgParts, color.."New TSM Thread Info:|r\n    "..table.concat(threadInfo, "\n    "))
	end
	local status, threadInfo = pcall(function() return TSMAPI_FOUR.Threading.GetThreadInfo() end)
	if status then
		tinsert(errMsgParts, color.."TSM Thread Info:|r\n    "..table.concat(threadInfo, "\n    "))
	end

	-- add recent TSM debug log entries
	local status, logEntries = pcall(function() return TSMAPI_FOUR.Logger.GetRecentLogEntries(200, 150) end)
	if status then
		tinsert(errMsgParts, color.."TSM Debug Log:|r\n    "..table.concat(logEntries, "\n    "))
	end

	-- add addons
	local hasAddonSuite = {}
	local addons = { color.."Addons:|r" }
	for i = 1, GetNumAddOns() do
		local name, _, _, loadable = GetAddOnInfo(i)
		if loadable then
			local version = GetAddOnMetadata(name, "X-Curse-Packaged-Version") or GetAddOnMetadata(name, "Version") or ""
			local loaded = IsAddOnLoaded(i)
			local isSuite
			for _, commonTerm in ipairs(ADDON_SUITES) do
				if strsub(name, 1, #commonTerm) == commonTerm then
					isSuite = commonTerm
					break
				end
			end
			local commonTerm = "TradeSkillMaster"
			if isSuite then
				if not hasAddonSuite[isSuite] then
					tinsert(addons, name.." ("..version..")"..(loaded and "" or " [Not Loaded]"))
					hasAddonSuite[isSuite] = true
				end
			elseif strsub(name, 1, #commonTerm) == commonTerm then
				name = gsub(name, "TradeSkillMaster", "TSM")
				tinsert(addons, name.." ("..version..")"..(loaded and "" or " [Not Loaded]"))
			else
				tinsert(addons, name.." ("..version..")"..(loaded and "" or " [Not Loaded]"))
			end
		end
	end
	tinsert(errMsgParts, table.concat(addons, "\n    "))

	-- show the error message if applicable
	msg = gsub(msg, "%%", "%%%%")
	local isOfficial = not TSM.Modules or TSM.Modules.IsOfficial(addonName)
	if not isOfficial then
		return false
	end
	if not private.errorFrame:IsVisible() then
		if TSM.LOG_ERR and TSM.AnalyticsEvent and not IS_DEV_VERSION and not isManual then
			TSM:LOG_ERR(msg)
			TSM:AnalyticsEvent("ERROR", msg)
		end
		print("|cffff0000TradeSkillMaster:|r "..L["Looks like TradeSkillMaster has encountered an error. Please help the author fix this error by following the instructions shown."])
		private.errorFrame.error = table.concat(errMsgParts, "\n")
		private.errorFrame.isManual = isManual
		private.errorFrame:Show()
	elseif not private.errorSuppressed then
		private.errorSuppressed = true
		if TSM.LOG_ERR then
			TSM:LOG_ERR(msg)
		end
		print("|cffff0000TradeSkillMaster:|r "..L["Additional error suppressed"])
	end

	private.ignoreErrors = false
	return true
end

function private.IsTSMAddon(str)
	if strfind(str, "Auc-Adcanced\\CoreScan.lua") then
		-- ignore auctioneer errors
		return nil
	elseif strfind(str, "Core\\Lib\\TooltipLib%.lua") then
		-- ignore tooltip lib errors
		return nil
	elseif strfind(str, "Master\\Libs\\") then
		-- ignore errors from libraries
		return nil
	elseif strfind(str, "Master_AppHelper\\") then
		return "TradeSkillMaster_AppHelper"
	elseif strfind(str, "lMaster\\") then
		return "TradeSkillMaster"
	elseif strfind(str, "ster\\Core\\UI\\") then
		return "TradeSkillMaster"
	end
	return nil
end

function private.AddonBlockedEvent(event, addonName, addonFunc)
	if not strmatch(addonName, "TradeSkillMaster") then return end
	-- just log it - it might not be TSM
	if TSM.LOG_ERR then
		TSM:LOG_ERR("[%s] AddOn '%s' tried to call the protected function '%s'.", event, addonName or "<name>", addonFunc or "<func>")
	end
end

function private.SantizeErrorReportString(str)
	str = gsub(str, "\124cff[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]([^\124]+)\124r", "%1")
	str = gsub(str, "\\", "/")
	str = gsub(str, "\"", "'")
	return str
end

function private.SubmitErrorReport(errMsg, details)
	tinsert(private.errorReports, {
		errMsg = private.SantizeErrorReportString(errMsg),
		details = private.SantizeErrorReportString(details),
		timestamp = time()
	})
end



-- ============================================================================
-- Create Error Frame
-- ============================================================================

do
	local STEPS_LINES = {
		"Steps leading up to the error:",
		"1) List",
		"2) Steps",
		"3) Here",
	}
	local STEPS_TEXT = table.concat(STEPS_LINES, "\n")
	local function HasValidSteps(text)
		if text == STEPS_TEXT then
			return false
		end
		text = gsub(text, "\n *\n", "\n")
		text = strtrim(text)
		local textLines = { strsplit("\n", text) }
		for i = 1, #textLines do
			textLines[i] = strtrim(textLines[i])
		end
		if #textLines > 150 then
			-- they probably copied in the error
			return false
		end
		if textLines[1] == STEPS_LINES[1] then
			if #textLines == 1 then
				-- they just deleted all the other lines
				return false
			end
			-- they kept the first line the same - make sure they significantly changed at least one other
			for i = 2, #textLines do
				if select("#", strsplit(" ", textLines[i])) >= 3 and #textLines[i] >= 15 then
					return true
				end
			end
			return false
		end

		-- make sure at least one line has significant text
		for _, line in ipairs(textLines) do
			if select("#", strsplit(" ", line)) >= 2 and #line >= 12 then
				return true
			end
		end
		return false
	end

	local frame = CreateFrame("Frame", nil, UIParent)
	private.errorFrame = frame
	frame:Hide()
	frame:SetWidth(500)
	frame:SetHeight(400)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetPoint("RIGHT", -100, 0)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 2,
	})
	frame:SetBackdropColor(0, 0, 0, 1)
	frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
	frame:SetScript("OnShow", function(self)
		self.showingError = self.isManual or IS_DEV_VERSION
		self.details = STEPS_TEXT
		if self.showingError then
			-- this is a dev version so show the error (only)
			self.text:SetText("Looks like TradeSkillMaster has encountered an error.")
			self.switchBtn:Hide()
			self.editBox:SetText(self.error)
		else
			self.text:SetText("Looks like TradeSkillMaster has encountered an error. Please provide the steps which lead to this error to help the TSM team fix it, then click either button at the bottom of the window to automatically report this error.")
			self.switchBtn:SetText("Show Error")
			self.switchBtn:Show()
			self.editBox:SetText(self.details)
		end
		self.requireSteps = not self.showingError and private.num == 1
		if self.requireSteps then
			-- require steps to be entered before enabling the reload / close buttons
			self.stepsText:Show()
			self.reloadBtn:Disable()
			self.closeBtn:Disable()
		else
			self.stepsText:Hide()
			self.reloadBtn:Enable()
			self.closeBtn:Enable()
		end
	end)
	frame:SetScript("OnHide", function()
		private.errorSuppressed = nil
	end)

	local title = frame:CreateFontString()
	title:SetHeight(20)
	title:SetPoint("TOPLEFT", 0, -10)
	title:SetPoint("TOPRIGHT", 0, -10)
	title:SetFontObject(GameFontNormalLarge)
	title:SetTextColor(1, 1, 1, 1)
	title:SetJustifyH("CENTER")
	title:SetJustifyV("MIDDLE")
	title:SetText("TSM Error Window")

	local hLine = frame:CreateTexture(nil, "ARTWORK")
	hLine:SetHeight(2)
	hLine:SetColorTexture(0.3, 0.3, 0.3, 1)
	hLine:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	hLine:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -10)

	local text = frame:CreateFontString()
	frame.text = text
	text:SetHeight(40)
	text:SetPoint("TOPLEFT", hLine, "BOTTOMLEFT", 8, -8)
	text:SetPoint("TOPRIGHT", hLine, "BOTTOMRIGHT", -8, -8)
	text:SetFontObject(GameFontNormal)
	text:SetTextColor(1, 1, 1, 1)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("MIDDLE")

	local switchBtn = CreateFrame("Button", nil, frame)
	frame.switchBtn = switchBtn
	switchBtn:SetPoint("TOPRIGHT", -4, -10)
	switchBtn:SetWidth(100)
	switchBtn:SetHeight(20)
	local fontString = switchBtn:CreateFontString()
	fontString:SetFontObject(GameFontNormalSmall)
	fontString:SetJustifyH("LEFT")
	switchBtn:SetFontString(fontString)
	switchBtn:SetScript("OnClick", function(self)
		private.errorFrame.showingError = not private.errorFrame.showingError
		if private.errorFrame.showingError then
			private.errorFrame.details = private.errorFrame.editBox:GetText()
			self:SetText("Hide Error")
			private.errorFrame.editBox:SetText(private.errorFrame.error)
		else
			self:SetText("Show Error")
			private.errorFrame.editBox:SetText(private.errorFrame.details)
		end
	end)

	local hLine2 = frame:CreateTexture(nil, "ARTWORK")
	hLine2:SetHeight(2)
	hLine2:SetColorTexture(0.3, 0.3, 0.3, 1)
	hLine2:SetPoint("TOPLEFT", text, "BOTTOMLEFT", -4, -4)
	hLine2:SetPoint("TOPRIGHT", text, "BOTTOMRIGHT", 4, -4)

	local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", hLine2, "BOTTOMLEFT", 8, -4)
	scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 38)

	local editBox = CreateFrame("EditBox", nil, scrollFrame)
	frame.editBox = editBox
	editBox:SetWidth(scrollFrame:GetWidth())
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetMultiLine(true)
	editBox:SetAutoFocus(false)
	editBox:SetMaxLetters(0)
	editBox:SetTextColor(1, 1, 1, 1)
	editBox:SetScript("OnUpdate", function(self)
		local offset = scrollFrame:GetVerticalScroll()
		self:SetHitRectInsets(0, 0, offset, self:GetHeight() - offset - scrollFrame:GetHeight())
	end)
	editBox:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	editBox:SetScript("OnTextChanged", function(self)
		if not self:HasFocus() or not private.errorFrame.requireSteps then
			return
		end
		if HasValidSteps(self:GetText()) then
			frame.stepsText:Hide()
			frame.reloadBtn:Enable()
			frame.closeBtn:Enable()
		else
			frame.stepsText:Show()
			frame.reloadBtn:Disable()
			frame.closeBtn:Disable()
		end
	end)
	editBox:SetScript("OnCursorChanged", function(self)
		if private.errorFrame.showingError and self:HasFocus() then
			self:HighlightText()
		end
	end)
	editBox:SetScript("OnEscapePressed", function(self)
		if private.errorFrame.showingError then
			self:HighlightText(0, 0)
		end
		self:ClearFocus()
	end)
	scrollFrame:SetScrollChild(editBox)

	local hLine3 = frame:CreateTexture(nil, "ARTWORK")
	hLine3:SetHeight(2)
	hLine3:SetColorTexture(0.3, 0.3, 0.3, 1)
	hLine3:SetPoint("BOTTOMLEFT", frame, 0, 35)
	hLine3:SetPoint("BOTTOMRIGHT", frame, 0, 35)

	local reloadBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.reloadBtn = reloadBtn
	reloadBtn:SetPoint("BOTTOMLEFT", 4, 4)
	reloadBtn:SetWidth(120)
	reloadBtn:SetHeight(30)
	reloadBtn:SetText(RELOADUI)
	reloadBtn:SetScript("OnClick", function()
		if not private.errorFrame.showingError then
			private.errorFrame.details = private.errorFrame.editBox:GetText()
		end
		if (not IS_DEV_VERSION and not private.errorFrame.isManual) or IsShiftKeyDown() then
			private.SubmitErrorReport(private.errorFrame.error, private.errorFrame.details)
		end
		ReloadUI()
	end)

	local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	frame.closeBtn = closeBtn
	closeBtn:SetPoint("BOTTOMRIGHT", -4, 4)
	closeBtn:SetWidth(120)
	closeBtn:SetHeight(30)
	closeBtn:SetText(DONE)
	closeBtn:SetScript("OnClick", function()
		if not private.errorFrame.showingError then
			private.errorFrame.details = private.errorFrame.editBox:GetText()
		end
		if not IS_DEV_VERSION or IsShiftKeyDown() then
			private.SubmitErrorReport(private.errorFrame.error, private.errorFrame.details)
		end
		frame:Hide()
	end)

	local stepsText = frame:CreateFontString()
	frame.stepsText = stepsText
	stepsText:SetWidth(200)
	stepsText:SetHeight(30)
	stepsText:SetPoint("BOTTOM", 0, 4)
	stepsText:SetFontObject(GameFontNormal)
	stepsText:SetTextColor(1, 0, 0, 1)
	stepsText:SetJustifyH("CENTER")
	stepsText:SetJustifyV("MIDDLE")
	stepsText:SetText("Steps required before submitting")
end



-- ============================================================================
-- Register Error Handler
-- ============================================================================

do
	private.origErrorHandler = geterrorhandler()
	seterrorhandler(function(errMsg)
		local errorTime = debugprofilestop()
		local tsmErrMsg = strtrim(tostring(errMsg))
		if private.ignoreErrors then
			-- we're ignoring errors
			tsmErrMsg = nil
		elseif strmatch(tsmErrMsg, "auc%-stat%-wowuction") or strmatch(tsmErrMsg, "TheUndermineJournal%.lua") or strmatch(tsmErrMsg, "\\SavedVariables\\TradeSkillMaster") or strmatch(tsmErrMsg, "AddOn TradeSkillMaster[_a-zA-Z]* attempted") then
			-- explicitly ignore these errors
			tsmErrMsg = nil
		end
		if tsmErrMsg then
			-- look at the stack trace to see if this is a TSM error
			for i = 2, MAX_STACK_DEPTH do
				local stackLine = debugstack(i, 1, 0)
				local oldModule = strmatch(stackLine, "(lMaster_[A-Za-z]+)")
				if oldModule and tContains(TSM.CONST.OLD_TSM_MODULES, "TradeSkil"..oldModule) then
					-- ignore errors from old modules
					return
				end
				if not strmatch(stackLine, "^%[C%]:") and not strmatch(stackLine, "^%(tail call%):") then
					if not private.IsTSMAddon(stackLine) then
						tsmErrMsg = nil
					end
					break
				end
			end
		end
		if tsmErrMsg then
			local status, ret = pcall(private.ErrorHandler, tsmErrMsg, nil, errorTime)
			if status and ret then
				return ret
			end
		end
		local oldModule = strmatch(errMsg, "(lMaster_[A-Za-z]+)")
		if oldModule and tContains(TSM.CONST.OLD_TSM_MODULES, "TradeSkil"..oldModule) then
			-- ignore errors from old modules
			return
		end
		return private.origErrorHandler and private.origErrorHandler(errMsg) or nil
	end)
	TSMAPI_FOUR.Event.Register("ADDON_ACTION_FORBIDDEN", private.AddonBlockedEvent)
	TSMAPI_FOUR.Event.Register("ADDON_ACTION_BLOCKED", private.AddonBlockedEvent)
end
