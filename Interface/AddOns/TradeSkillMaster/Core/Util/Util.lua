-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--          http://www.curse.com/addons/wow/tradeskillmaster_warehousing          --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

--- Util TSMAPI_FOUR Functions
-- @module Util

TSMAPI_FOUR.Util = {}
local private = { freeTempTables = {}, tempTableState = {}, filterTemp = {} }
private.iterContext = { arg = {}, index = {}, helperFunc = {}, cleanupFunc = {} }
setmetatable(private.iterContext.arg, { __mode = "k" })
setmetatable(private.iterContext.index, { __mode = "k" })
setmetatable(private.iterContext.helperFunc, { __mode = "k" })
setmetatable(private.iterContext.cleanupFunc, { __mode = "k" })
local NUM_TEMP_TABLES = 100
local MAGIC_CHARACTERS = { '[', ']', '(', ')', '.', '+', '-', '*', '?', '^', '$' }
local RELEASED_TEMP_TABLE_MT = {
	__newindex = function(self, key, value)
		error("Attempt to access temp table after release")
		rawset(self, key, value)
	end,
	__index = function(self, key)
		error("Attempt to access temp table after release")
		return rawget(self, key)
	end,
}

-- setup the temporary tables
do
	for i = 1, NUM_TEMP_TABLES do
		local tempTbl = setmetatable({}, RELEASED_TEMP_TABLE_MT)
		tinsert(private.freeTempTables, tempTbl)
	end
end



-- ============================================================================
-- TSMAPI Functions - String
-- ============================================================================

--- Splits a string in a way which won't cause stack overflows for large inputs.
-- The lua strsplit function causes a stack overflow if passed large inputs. This API fixes that issue and also supports
-- separators which are more than one character in length.
-- @tparam string str The string to be split
-- @tparam string sep The seperator to use to split the string
-- @treturn table The result as a list of substrings
-- @within String
function TSMAPI_FOUR.Util.SafeStrSplit(str, sep)
	local parts = {}
	local s = 1
	local sepLength = #sep
	if sepLength == 0 then
		tinsert(parts, str)
		return parts
	end
	while true do
		local e = strfind(str, sep, s)
		if not e then
			tinsert(parts, strsub(str, s))
			break
		end
		tinsert(parts, strsub(str, s, e - 1))
		s = e + sepLength
	end
	return parts
end

--- Escapes any magic characters used by lua's pattern matching.
-- @tparam string str The string to be escaped
-- @treturn string The escaped string
-- @within String
function TSMAPI_FOUR.Util.StrEscape(str)
	assert(not strmatch(str, "\001"), "Input string must not contain '\\001' characters")
	str = gsub(str, "%%", "\001")
	for _, char in ipairs(MAGIC_CHARACTERS) do
		str = gsub(str, "%"..char, "%%"..char)
	end
	str = gsub(str, "\001", "%%%%")
	return str
end



-- ============================================================================
-- TSMAPI Functions - Math
-- ============================================================================

--- Rounds a value to a specified significant value.
-- @tparam number value The number to be rounded
-- @tparam number sig The value to round to the nearest multiple of
-- @treturn number The rounded value
-- @within Math
function TSMAPI_FOUR.Util.Round(value, sig)
	sig = sig or 1
	return floor((value / sig) + 0.5) * sig
end

--- Rounds a value down to a specified significant value.
-- @tparam number value The number to be rounded
-- @tparam number sig The value to round down to the nearest multiple of
-- @treturn number The rounded value
-- @within Math
function TSMAPI_FOUR.Util.Floor(value, sig)
	sig = sig or 1
	return floor(value / sig) * sig
end

--- Rounds a value up to a specified significant value.
-- @tparam number value The number to be rounded
-- @tparam number sig The value to round up to the nearest multiple of
-- @treturn number The rounded value
-- @within Math
function TSMAPI_FOUR.Util.Ceil(value, sig)
	sig = sig or 1
	return ceil(value / sig) * sig
end

--- Scales a value from one range to another.
-- @tparam number value The number to be scaled
-- @tparam number fromMin The minimum value of the range to scale from
-- @tparam number fromMax The maximum value of the range to scale from
-- @tparam number toMin The minimum value of the range to scale to
-- @tparam number toMax The maximum value of the range to scale to
-- @treturn number The scaled value
-- @within Math
function TSMAPI_FOUR.Util.Scale(value, fromMin, fromMax, toMin, toMax)
	assert(fromMax > fromMin and toMax > toMin)
	assert(value >= fromMin and value <= fromMax)
	return toMin + ((value - fromMin) / (fromMax - fromMin)) * (toMax - toMin)
end

--- Calculates the has of the specified data
-- This data can handle data of type string or number. It can also handle a table being passed as the data assuming
-- all keys and values of the table are also hashable (strings, numbers, or tables with the same restriction). This
-- function uses the [djb2 algorithm](http://www.cse.yorku.ca/~oz/hash.html).
-- @param data The data to be hased
-- @tparam[opt] number hash The initial value of the hash
-- @treturn number The hash value
-- @within Math
function TSMAPI_FOUR.Util.CalculateHash(data, hash)
	hash = hash or 5381
	local maxValue = 2 ^ 24
	if type(data) == "string" then
		for i = 1, #data do
			hash = (hash * 33 + strbyte(data, i)) % maxValue
		end
	elseif type(data) == "number" then
		assert(data == floor(data), "Invalid number")
		while data > 0 do
			hash = (hash * 33 + data % 256) % maxValue
			data = floor(data / 256)
		end
	elseif type(data) == "table" then
		local keys = TSMAPI_FOUR.Util.AcquireTempTable()
		for k in pairs(data) do
			tinsert(keys, k)
		end
		sort(keys)
		for _, key in TSMAPI_FOUR.Util.TempTableIterator(keys) do
			hash = TSMAPI_FOUR.Util.CalculateHash(key, hash)
			hash = TSMAPI_FOUR.Util.CalculateHash(data[key], hash)
		end
	else
		error("Invalid data")
	end
	return hash
end



-- ============================================================================
-- TSMAPI Functions - Vararg
-- ============================================================================

--- Stores a varag into a table.
-- @tparam table tbl The table to store the values in
-- @param ... Zero or more values to store in the table
-- @within Vararg
function TSMAPI_FOUR.Util.VarargIntoTable(tbl, ...)
	for i = 1, select("#", ...) do
		tbl[i] = select(i, ...)
	end
end

--- Creates an iterator from a vararg.
-- NOTE: This iterator must be run to completion and not interrupted (i.e. with a `break` or `return`).
-- @param ... The values to iterate over
-- @return An iterator with fields: `index, value`
-- @within Vararg
function TSMAPI_FOUR.Util.VarargIterator(...)
	return TSMAPI_FOUR.Util.TempTableIterator(TSMAPI_FOUR.Util.AcquireTempTable(...))
end



-- ============================================================================
-- TSMAPI Functions - Table
-- ============================================================================

--- Creates an iterator from a table.
-- NOTE: This iterator must be run to completion and not interrupted (i.e. with a `break` or `return`).
-- @tparam table tbl The table (numerically-indexed) to iterate over
-- @tparam[opt] function helperFunc A helper function which gets passed the current index, value, and user-specified arg
-- and returns nothing if an entry in the table should be skipped or the result of an iteration loop
-- @param[opt] arg A value to be passed to the helper function
-- @tparam[opt] function cleanupFunc A function to be called (passed `tbl`) to cleanup at the end of iterator
-- @return An iterator with fields: `index, value` or the return of `helperFunc`
-- @within Table
function TSMAPI_FOUR.Util.TableIterator(tbl, helperFunc, arg, cleanupFunc)
	local iterContext = TSMAPI_FOUR.Util.AcquireTempTable()
	iterContext.data = tbl
	iterContext.arg = arg
	iterContext.index = 0
	iterContext.helperFunc = helperFunc
	iterContext.cleanupFunc = cleanupFunc
	return private.TableIterator, iterContext
end

--- Creates an iterator from the keys of a table.
-- @tparam table tbl The table to iterate over the keys of
-- @return An iterator with fields: `key`
-- @within Table
function TSMAPI_FOUR.Util.TableKeyIterator(tbl)
	return private.TableKeyIterator, tbl, nil
end

--- Uses a function to filter the entries in a table.
-- @tparam table tbl The table to be filtered
-- @tparam function func The filter function which gets passed `key, value, ...` and returns true if that entry should
-- be removed from the table
-- @param[opt] ... Optional arguments to be passed to the filter function
-- @within Table
function TSMAPI_FOUR.Util.TableFilter(tbl, func, ...)
	assert(not next(private.filterTemp))
	for k, v in pairs(tbl) do
		if func(k, v, ...) then
			tinsert(private.filterTemp, k)
		end
	end
	for _, k in ipairs(private.filterTemp) do
		tbl[k] = nil
	end
	wipe(private.filterTemp)
end

--- Removes all occurences of the value in the table.
-- Only the numerically-indexed entries are checked.
-- @tparam table tbl The table to remove the value from
-- @param value The value to remove
-- @treturn number The number of values removed
-- @within Table
function TSMAPI_FOUR.Util.TableRemoveByValue(tbl, value)
	local numRemoved = 0
	for i = #tbl, 1, -1 do
		if tbl[i] == value then
			tremove(tbl, i)
			numRemoved = numRemoved + 1
		end
	end
	return numRemoved
end

--- Gets the table key by value.
-- @tparam table tbl The table to look through
-- @param value The value to get the key of
-- @return The key for the specified value or `nil`
-- @within Table
function TSMAPI_FOUR.Util.TableKeyByValue(tbl, value)
	for k, v in pairs(tbl) do
		if v == value then
			return k
		end
	end
end

--- Gets the number of entries in the table.
-- This can be used when the count of a non-numerically-indexed table is desired (i.e. `#tbl` wouldn't work).
-- @tparam table tbl The table to get the number of entries in
-- @treturn number The number of entries
-- @within Table
function TSMAPI_FOUR.Util.Count(tbl)
	local count = 0

	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
end

--- Gets the distinct table key by value.
-- This function will assert if the value is not found in the table or if more than one key is found.
-- @tparam table tbl The table to look through
-- @param value The value to get the key of
-- @return The key for the specified value
-- @within Table
function TSMAPI_FOUR.Util.GetDistinctTableKey(tbl, value)
	local key = nil
	for k, v in pairs(tbl) do
		if v == value then
			assert(not key)
			key = k
		end
	end
	assert(key)
	return key
end

--- Gets the first table index by value in the table.
-- This function assumes the table is a list of tables which is sorted by `tbl[key]` in ascending order. It uses a
-- binary search to efficiently find the first index where `tbl[key] == value`.
-- @tparam table tbl The table to look through
-- @param value The value to search for
-- @param key The key within each entry to compare with value
-- @return The first index which matches or `nil` if not found
-- @within Table
function TSMAPI_FOUR.Util.BinarySearchGetFirstIndex(tbl, value, key)
	local found, index = private.BinarySearchHelper(tbl, value, key, "FIRST")
	return found and index or nil
end

--- Gets the last table index by value in the table.
-- This function assumes the table is a list of tables which is sorted by `tbl[key]` in ascending order. It uses a
-- binary search to efficiently find the last index where `tbl[key] == value`.
-- @tparam table tbl The table to look through
-- @param value The value to search for
-- @param key The key within each entry to compare with value
-- @return The last index which matches or `nil` if not found
-- @within Table
function TSMAPI_FOUR.Util.BinarySearchGetLastIndex(tbl, value, key)
	local found, index = private.BinarySearchHelper(tbl, value, key, "LAST")
	return found and index or nil
end

--- Gets an index at which to insert a value into the table.
-- This function assumes the table is a list of tables which is sorted by `tbl[key]` in ascending order. It uses a
-- binary search to efficiently find where the value should be inserted into the table.
-- @tparam table tbl The table to look through
-- @param value The value to be inserted
-- @param key The key within each entry to compare with value
-- @return The index to insert at
-- @within Table
function TSMAPI_FOUR.Util.BinarySearchGetInsertIndex(tbl, value, key)
	local _, index = private.BinarySearchHelper(tbl, value, key, "ANY")
	return index
end



-- ============================================================================
-- TSMAPI Functions - Table Recycling
-- ============================================================================

--- Acquires a temporary table.
-- Temporary tables are recycled tables which can be used instead of creating a new table every time one is needed for a
-- defined lifecycle. This avoids relying on the garbage collector and improves overall performance.
-- @param ... Any number of valuse to insert into the table initially
-- @treturn table The temporary table
-- @within Temporary Table
function TSMAPI_FOUR.Util.AcquireTempTable(...)
	local tbl = tremove(private.freeTempTables, 1)
	assert(tbl, "Could not acquire temp table")
	setmetatable(tbl, nil)
	private.tempTableState[tbl] = TSMAPI_FOUR.Util.GetDebugStackInfo(2).." -> "..(TSMAPI_FOUR.Util.GetDebugStackInfo(3) or "?")
	TSMAPI_FOUR.Util.VarargIntoTable(tbl, ...)
	return tbl
end

--- Iterators over a temporary table, releasing it when done.
-- NOTE: This iterator must be run to completion and not interrupted (i.e. with a `break` or `return`).
-- @tparam table tbl The temporary table to iterator over
-- @tparam[opt] function helperFunc A helper function for the iterator (see @{TSMAPI_FOUR.Util.TableIterator})
-- @param[opt] arg The argument to pass to `helperFunc` (see @{TSMAPI_FOUR.Util.TableIterator})
-- @return An iterator with fields: `index, value` or the return of `helperFunc`
-- @within Temporary Table
function TSMAPI_FOUR.Util.TempTableIterator(tbl, helperFunc, arg)
	assert(private.tempTableState[tbl])
	return TSMAPI_FOUR.Util.TableIterator(tbl, helperFunc, arg, TSMAPI_FOUR.Util.ReleaseTempTable)
end

--- Releases a temporary table.
-- The temporary table will be returned to the pool and must not be accessed after being released.
-- @tparam table tbl The temporary table to release
-- @within Temporary Table
function TSMAPI_FOUR.Util.ReleaseTempTable(tbl)
	private.TempTableReleaseHelper(tbl)
end

--- Releases a temporary table and returns its values.
-- Releases the temporary table (see @{TSMAPI_FOUR.Util.ReleaseTempTable}) and returns its unpacked values.
-- @tparam table tbl The temporary table to release and unpack
-- @return The result of calling `unpack` on the table
-- @within Temporary Table
function TSMAPI_FOUR.Util.UnpackAndReleaseTempTable(tbl)
	return private.TempTableReleaseHelper(tbl, unpack(tbl))
end

function TSMAPI_FOUR.Util.GetTempTableDebugInfo()
	local counts = {}
	for _, info in pairs(private.tempTableState) do
		counts[info] = (counts[info] or 0) + 1
	end
	local debugInfo = {}
	for info, count in pairs(counts) do
		tinsert(debugInfo, format("%d acquired by %s", count, info))
	end
	if #debugInfo == 0 then
		tinsert(debugInfo, "<none>")
	end
	return debugInfo
end



-- ============================================================================
-- TSMAPI Functions - WoW Util
-- ============================================================================

--- Shows a WoW static popup dialog.
-- @tparam string name The unique (global) name of the dialog to be shown
-- @within WoW Util
function TSMAPI_FOUR.Util.ShowStaticPopupDialog(name)
	StaticPopupDialogs[name].preferredIndex = 4
	StaticPopup_Show(name)
	for i = 1, 100 do
		if _G["StaticPopup" .. i] and _G["StaticPopup" .. i].which == name then
			_G["StaticPopup" .. i]:SetFrameStrata("TOOLTIP")
			break
		end
	end
end

--- Sets the WoW tooltip to the specified link.
-- @tparam string link The itemLink or TSM itemString to show the tooltip for
-- @within WoW Util
function TSMAPI_FOUR.Util.SafeTooltipLink(link)
	if strmatch(link, "p:") then
		link = TSMAPI_FOUR.Item.GetLink(link)
	end
	if strmatch(link, "battlepet") then
		local _, speciesID, level, breedQuality, maxHealth, power, speed, battlePetID = strsplit(":", link)
		BattlePetToolTip_Show(tonumber(speciesID), tonumber(level) or 0, tonumber(breedQuality) or 0, tonumber(maxHealth) or 0, tonumber(power) or 0, tonumber(speed) or 0, gsub(gsub(link, "^(.*)%[", ""), "%](.*)$", ""))
	elseif strmatch(link, "currency") then
		local currencyID = strmatch(link, "currency:(%d+)")
		GameTooltip:SetCurrencyByID(currencyID)
	else
		GameTooltip:SetHyperlink(TSMAPI_FOUR.Item.GetLink(link))
	end
end

--- Sets the WoW item ref frame to the specified link.
-- @tparam string link The itemLink to show the item ref frame for
-- @within WoW Util
function TSMAPI_FOUR.Util.SafeItemRef(link)
	if type(link) ~= "string" then return end
	-- extract the Blizzard itemString for both items and pets
	local blizzItemString = strmatch(link, "^\124c[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]\124H(item:[^\124]+)\124.+$")
	blizzItemString = blizzItemString or strmatch(link, "^\124c[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]\124H(battlepet:[^\124]+)\124.+$")
	if blizzItemString then
		SetItemRef(blizzItemString, link)
	end
end

--- Checks if an addon is installed.
-- This function only checks if the addon is installed, not if it's enabled.
-- @tparam string name The name of the addon
-- @treturn boolean Whether or not the addon is installed
-- @within WoW Util
function TSMAPI_FOUR.Util.IsAddonInstalled(name)
	return select(2, GetAddOnInfo(name)) and true or false
end

--- Checks if an addon is currently enabled.
-- @tparam string name The name of the addon
-- @treturn boolean Whether or not the addon is enabled
-- @within WoW Util
function TSMAPI_FOUR.Util.IsAddonEnabled(name)
	return GetAddOnEnableState(UnitName("player"), name) == 2 and select(4, GetAddOnInfo(name)) and true or false
end



-- ============================================================================
-- TSMAPI Functions - Misc.
-- ============================================================================

--- Returns whether not the value exists within the vararg.
-- @param value The value to search for
-- @param ... Any number of values to search in
-- @treturn boolean Whether or not the value was found in the vararg
-- @within Misc
function TSMAPI_FOUR.Util.In(value, ...)
	for i = 1, select("#", ...) do
		if value == select(i, ...) then
			return true
		end
	end
	return false
end

--- Gets debug stack info.
-- @tparam number targetLevel The stack level to get info for
-- @tparam[opt] thread thread The thread to get info for
-- @treturn string The stack frame info (file and line number) or `nil`
-- @within Misc
function TSMAPI_FOUR.Util.GetDebugStackInfo(targetLevel, thread)
	targetLevel = targetLevel + 1
	assert(targetLevel > 0)
	for level = 1, 100 do
		local stackLine = nil
		if thread then
			stackLine = debugstack(thread, level, 1, 0)
		else
			stackLine = debugstack(level, 1, 0)
		end
		if not stackLine then
			return
		end
		stackLine = strmatch(stackLine, "^%.*([^:]+:%d+):")
		-- ignore the class code's wrapper function
		if stackLine and not strmatch(stackLine, "Class%.lua:192") then
			targetLevel = targetLevel - 1
			if targetLevel == 0 then
				stackLine = gsub(stackLine, "/", "\\")
				stackLine = gsub(stackLine, ".-lMaster\\", "TSM\\")
				return stackLine
			end
		end
	end
end



-- ============================================================================
-- Private Helper Functions
-- ============================================================================

function private.TableKeyIterator(tbl, prevKey)
	local key = next(tbl, prevKey)
	return key
end

function private.TableIterator(iterContext)
	iterContext.index = iterContext.index + 1
	if iterContext.index > #iterContext.data then
		local data = iterContext.data
		local cleanupFunc = iterContext.cleanupFunc
		TSMAPI_FOUR.Util.ReleaseTempTable(iterContext)
		if cleanupFunc then
			cleanupFunc(data)
		end
		return
	end
	if iterContext.helperFunc then
		local result = TSMAPI_FOUR.Util.AcquireTempTable(iterContext.helperFunc(iterContext.index, iterContext.data[iterContext.index], iterContext.arg))
		if #result == 0 then
			TSMAPI_FOUR.Util.ReleaseTempTable(result)
			return private.TableIterator(iterContext)
		end
		return TSMAPI_FOUR.Util.UnpackAndReleaseTempTable(result)
	else
		return iterContext.index, iterContext.data[iterContext.index]
	end
end

function private.TempTableReleaseHelper(tbl, ...)
	assert(private.tempTableState[tbl])
	wipe(tbl)
	tinsert(private.freeTempTables, tbl)
	private.tempTableState[tbl] = nil
	setmetatable(tbl, RELEASED_TEMP_TABLE_MT)
	return ...
end

function private.BinarySearchHelper(tbl, value, key, searchType)
	-- binary search for index
	local low, mid, high = 1, 0, #tbl
	while low <= high do
		mid = floor((low + high) / 2)
		local rowValue = key and tbl[mid][key] or tbl[mid]
		if rowValue == value then
			if searchType == "FIRST" then
				if mid == 1 or (key and tbl[mid-1][key] or tbl[mid]) ~= value then
					-- we've found the row we want
					return true, mid
				else
					-- we're too high
					high = mid - 1
				end
			elseif searchType == "LAST" then
				if mid == high or (key and tbl[mid+1][key] or tbl[mid]) ~= value then
					-- we've found the row we want
					return true, mid
				else
					-- we're too low
					low = mid + 1
				end
			elseif searchType == "ANY" then
				return true, mid
			else
				error("Invalid searchType: "..tostring(searchType))
			end
		elseif rowValue < value then
			-- we're too low
			low = mid + 1
		else
			-- we're too high
			high = mid - 1
		end
	end
	-- didn't find it but return where it should be inserted
	return false, low
end
