
-- Title: TargetFrameBuff v0.9.1
-- Notes: Shows up to 32 Buffs & 16 Debuffs on a Target (Buffs above, Debuffs below),
--        with remaining-time countdowns when ClassicAPI is installed
-- Author: lua@lumpn.de (modified)


local lOriginal_TargetDebuffButton_Update = nil;
local TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS = 16;
local TARGETFRAMEBUFF_MAX_TARGET_BUFFS = 32;

-- How often the countdowns refresh, in seconds.
local TARGETFRAMEBUFF_TIMER_INTERVAL = 0.2;

local lBuffButtons = {};
local lDebuffButtons = {};
local lTimerElapsed = 0;
local lAuraElapsed = 0;
local lActiveTimers = {};
local lActiveTimerCount = 0;
local TargetFrameBuff_UpdateTimer;
-- Catch refreshes that change timing without a UNIT_AURA event.
local TARGETFRAMEBUFF_AURA_INTERVAL = 0.5;
local lHelpfulSlots = {};
local lHarmfulSlots = {};
local lRemovableColor = {r = 1, g = 0.82, b = 0};

local function TargetFrameBuff_Setting(key)
	if (TargetFrameBuffDB and TargetFrameBuffDB[key] ~= nil) then
		return TargetFrameBuffDB[key];
	end
	return TargetFrameBuffDefaults[key];
end


-- ClassicAPI (a 1.12 client DLL) backports C_UnitAuras, which reports when
-- each aura on the target expires. Without it, the addon works as before,
-- just without countdowns.
local function TargetFrameBuff_HasClassicAPI()
	return C_UnitAuras and C_UnitAuras.UnitAura and GameTooltip.SetUnitAura and true;
end


-- Tooltip for an aura read through ClassicAPI. auraIndex and auraFilter are in
-- ClassicAPI's HELPFUL/HARMFUL index space, so the tooltip always matches the
-- icon, even for a debuff the server parked in a buff slot.
local function TargetFrameBuff_AuraOnEnter()
	TargetFrameBuff_UpdateClassicAPI();
	if (not this.auraIndex) then GameTooltip:Hide(); return; end
	GameTooltip:SetOwner(this, "ANCHOR_BOTTOMRIGHT", 15, -25);
	GameTooltip:SetUnitAura("target", this.auraIndex, this.auraFilter);
	GameTooltip:Show();
end


-- Add a countdown label to a button. It sits on its own child frame, one level
-- above the button, so it draws over the icon and the debuff border.
local function TargetFrameBuff_AddTimer(button)
	local holder = CreateFrame("Frame", nil, button);
	holder:SetAllPoints(button);
	holder:SetFrameLevel(button:GetFrameLevel() + 2);

	local timer = holder:CreateFontString(nil, "OVERLAY");
	timer:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE");
	timer:SetPoint("CENTER", button, "CENTER", 0, 0);
	timer:Hide();

	if (not button.auraCount) then
		button.auraCount = holder:CreateFontString(nil, "OVERLAY");
		button.auraCount:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE");
		button.auraCount:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1);
		button.auraCount:Hide();
		local stockCount = getglobal(button:GetName().."Count");
		if (stockCount) then stockCount:Hide(); end
	end
	button.timer = timer;
	button.timerText = nil;
	button.expiration = 0;
end


-- hook original update-function
function TargetFrameBuff_OnLoad()
	local i, button, overlay;
	for i=1, TARGETFRAMEBUFF_MAX_TARGET_BUFFS do
		lBuffButtons[i] = getglobal("TargetFrameBuff"..i);
		button = lBuffButtons[i];
		overlay = CreateFrame("Frame", nil, button);
		overlay:SetAllPoints(button);
		overlay:SetFrameLevel(button:GetFrameLevel() + 2);
		button.auraCount = overlay:CreateFontString(nil, "OVERLAY");
		button.auraCount:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE");
		button.auraCount:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1);
		button.auraCount:Hide();
		button.auraBorder = overlay:CreateTexture(nil, "OVERLAY");
		button.auraBorder:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays");
		button.auraBorder:SetTexCoord(0.296875, 0.5703125, 0, 0.515625);
		button.auraBorder:SetPoint("CENTER", button, "CENTER", 0, 0);
		button.auraBorder:SetWidth(23);
		button.auraBorder:SetHeight(23);
		button.auraBorder:Hide();
	end
	for i=1, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
		lDebuffButtons[i] = getglobal("TargetFrameDebuff"..i);
	end

	if (TargetFrameBuff_HasClassicAPI()) then
		for i=1, TARGETFRAMEBUFF_MAX_TARGET_BUFFS do
			button = lBuffButtons[i];
			TargetFrameBuff_AddTimer(button);
			button:SetScript("OnEnter", TargetFrameBuff_AuraOnEnter);
			button:SetScript("OnUpdate", nil);
		end
		for i=1, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
			button = lDebuffButtons[i];
			TargetFrameBuff_AddTimer(button);
			button:SetScript("OnEnter", TargetFrameBuff_AuraOnEnter);
			button:SetScript("OnUpdate", nil);
		end
	end

	TargetFrameBuffFrame:RegisterEvent("UNIT_AURA");
	TargetFrameBuffFrame:RegisterEvent("PLAYER_TARGET_CHANGED");
	TargetFrameBuffFrame:SetScript("OnEvent", function()
		if (event == "PLAYER_TARGET_CHANGED" or (event == "UNIT_AURA" and arg1 == "target")) then
			TargetFrameBuff_Update();
		end
	end);

	lOriginal_TargetDebuffButton_Update = TargetDebuffButton_Update;
	TargetDebuffButton_Update = TargetFrameBuff_Update;

	lOriginal_TargetDebuffButton_Update();
	TargetFrameBuff_Restore();
	TargetFrameBuff_Update();
end


-- use extended update-function (original code from FrameXML/TargetFrame.lua)
function TargetFrameBuff_Update()
	if (TargetFrameBuff_HasClassicAPI() and lBuffButtons[1] and lBuffButtons[1].timer) then
		TargetFrameBuff_UpdateClassicAPI();
	else
		TargetFrameBuff_UpdateNative();
	end
	TargetFrameBuff_Layout();
	-- Draw countdowns right away instead of waiting for the next tick.
	lTimerElapsed = TARGETFRAMEBUFF_TIMER_INTERVAL;
end


-- Color a debuff border by debuff type (Magic, Curse, Disease, Poison).
-- Without this, a border keeps the color of whatever debuff last used that
-- slot, so debuffs show the wrong category.
local function TargetFrameBuff_ColorBorder(i, debuffType)
	local debuffBorder = getglobal("TargetFrameDebuff"..i.."Border");
	if (debuffBorder and DebuffTypeColor) then
		local color = DebuffTypeColor[debuffType or "none"] or DebuffTypeColor["none"];
		if (color) then
			debuffBorder:SetVertexColor(color.r, color.g, color.b);
		end
	end
end


local function TargetFrameBuff_SetCount(i, count)
	local stockCount = getglobal("TargetFrameDebuff"..i.."Count");
	local debuffCount = lDebuffButtons[i].auraCount or stockCount;
	if (debuffCount ~= stockCount) then stockCount:Hide(); end
	if (count and count > 1) then
		debuffCount:SetText(count);
		debuffCount:Show();
	else
		debuffCount:Hide();
	end
end


-- Stock 1.12 path: UnitBuff/UnitDebuff, no timing data.
function TargetFrameBuff_UpdateNative()
	local button, buff, i;
	for i=1, TARGETFRAMEBUFF_MAX_TARGET_BUFFS do
		buff = UnitBuff("target", i);
		button = lBuffButtons[i];
		if (buff) then
			getglobal("TargetFrameBuff"..i.."Icon"):SetTexture(buff);
			button:Show();
			button.id = i;
		else
			button:Hide();
		end
	end

	local debuff, debuffApplications, debuffType;
	for i=1, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
		debuff, debuffApplications, debuffType = UnitDebuff("target", i);
		button = lDebuffButtons[i];
		if (debuff) then
			TargetFrameBuff_ColorBorder(i, debuffType);
			TargetFrameBuff_SetCount(i, debuffApplications);
			getglobal("TargetFrameDebuff"..i.."Icon"):SetTexture(debuff);
			button:Show();
			button.id = i;
		else
			button:Hide();
		end
	end
end


-- Slot ids are used only during this scan, never cached on buttons.
local function TargetFrameBuff_Sweep(button, duration, expiration)
	local enabled = TargetFrameBuff_Setting("sweeps");
	if (enabled and not button.cooldown and not button.noCooldown) then
		local ok, cd = pcall(CreateFrame, "Cooldown", nil, button, "CooldownFrameTemplate");
		if (ok and cd and cd.SetCooldown) then
			button.cooldown = cd;
			cd:SetAllPoints(button);
			cd:SetFrameLevel(button:GetFrameLevel() + 1);
			cd:SetReverse(true);
			cd:SetDrawEdge(true);
			cd:Hide();
		else
			button.noCooldown = true;
		end
	end
	local cd = button.cooldown;
	if (not cd) then return; end
	if (not enabled or not duration or duration <= 0 or not expiration or expiration <= GetTime()) then
		cd:Hide();
		button.sweepExpiration = nil;
	elseif (button.sweepExpiration ~= expiration or button.sweepDuration ~= duration) then
		cd:SetCooldown(expiration - duration, duration);
		button.sweepExpiration = expiration;
		button.sweepDuration = duration;
	end
end

local function TargetFrameBuff_HideAura(button)
	button.expiration = 0;
	button.auraIndex = nil;
	button.auraFilter = nil;
	button.timerText = nil;
	button.timer:Hide();
	if (button.cooldown) then button.cooldown:Hide(); end
	button.sweepExpiration = nil;
	if (button.auraCount) then button.auraCount:Hide(); end
	if (button.auraBorder) then button.auraBorder:Hide(); end
	if (GameTooltip:IsOwned(button)) then GameTooltip:Hide(); end
	button:Hide();
end

local function TargetFrameBuff_ShowAura(button, filter, index, icon, count, dispelType, duration, expiration, removable)
	if (button.auraIcon ~= icon) then
		getglobal(button:GetName().."Icon"):SetTexture(icon);
		button.auraIcon = icon;
	end
	button.auraFilter = filter;
	button.auraIndex = index;
	button.id = index;
	button.expiration = expiration or 0;
	if (button.auraCount) then
		if (count and count > 1) then
			button.auraCount:SetText(count);
			button.auraCount:Show();
		else
			button.auraCount:Hide();
		end
	end
	if (button.auraBorder) then
		local color;
		if (filter == "HARMFUL") then
			color = DebuffTypeColor[dispelType or "none"] or DebuffTypeColor["none"];
		elseif (removable and TargetFrameBuff_Setting("highlight")) then
			color = lRemovableColor;
		end
		if (color) then
			button.auraBorder:SetVertexColor(color.r, color.g, color.b);
			button.auraBorder:Show();
		else
			button.auraBorder:Hide();
		end
	end
	TargetFrameBuff_Sweep(button, duration, expiration);
	button:Show();
	if (TargetFrameBuff_Setting("timers") and button.expiration > GetTime()) then
		lActiveTimerCount = lActiveTimerCount + 1;
		lActiveTimers[lActiveTimerCount] = button;
		TargetFrameBuff_UpdateTimer(button, GetTime());
	else
		button.timerText = nil;
		button.timer:Hide();
	end
	if (GameTooltip:IsOwned(button)) then
		GameTooltip:SetUnitAura("target", index, filter);
	end
end

-- Refresh icons, counts and expiration together so index reordering cannot
-- attach a new aura's timer to an old icon. Older ClassicAPI uses the same
-- presentation path, with its positional index getter.
function TargetFrameBuff_UpdateClassicAPI()
	local oldTimerCount = lActiveTimerCount;
	lActiveTimerCount = 0;
	lAuraElapsed = 0;
	local numBuffs, numDebuffs = 0, 0;
	local pass, filter, slots, n, index, token;
	local name, icon, count, dispelType, duration, expiration, source, removable;
	local batched = C_UnitAuras.GetAuraSlots and C_UnitAuras.UnitAuraBySlot;
	for pass = 1, 2 do
		if (pass == 1) then
			filter, slots = "HELPFUL", lHelpfulSlots;
		else
			filter, slots = "HARMFUL", lHarmfulSlots;
		end
		if (batched) then
			token, n = C_UnitAuras.GetAuraSlots("target", filter, nil, nil, slots);
		else
			n = TARGETFRAMEBUFF_MAX_TARGET_BUFFS + TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS;
		end
		for index = 1, n do
			if (batched) then
				name, icon, count, dispelType, duration, expiration, source, removable = C_UnitAuras.UnitAuraBySlot("target", slots[index]);
			else
				name, icon, count, dispelType, duration, expiration, source, removable = C_UnitAuras.UnitAura("target", index, filter);
			end
			if (not name and not icon) then break; end
			if (pass == 2 and index <= TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS) then
				numDebuffs = index;
				TargetFrameBuff_ColorBorder(index, dispelType);
				TargetFrameBuff_SetCount(index, count);
				TargetFrameBuff_ShowAura(lDebuffButtons[index], filter, index, icon, count, dispelType, duration, expiration, removable);
			elseif (numBuffs < TARGETFRAMEBUFF_MAX_TARGET_BUFFS) then
				numBuffs = numBuffs + 1;
				TargetFrameBuff_ShowAura(lBuffButtons[numBuffs], filter, index, icon, count, dispelType, duration, expiration, removable);
			else
				break;
			end
		end
	end
	for index = numBuffs + 1, TARGETFRAMEBUFF_MAX_TARGET_BUFFS do
		TargetFrameBuff_HideAura(lBuffButtons[index]);
	end
	for index = numDebuffs + 1, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
		TargetFrameBuff_HideAura(lDebuffButtons[index]);
	end
	for index = lActiveTimerCount + 1, oldTimerCount do
		lActiveTimers[index] = nil;
	end
end

function TargetFrameBuff_Layout()
	local button;

	-- Position buffs above target frame
	TargetFrameBuff1:ClearAllPoints();
	TargetFrameBuff1:SetPoint("BOTTOMLEFT", "TargetFrame", "TOPLEFT", 5, -10);

	-- Position debuffs below target frame using default positioning (no gap)
	-- Layout: 4-4-8 (three rows: 4 debuffs, 4 debuffs, 8 debuffs)
	-- Debuff 1 uses default WoW positioning to avoid gap with target frame
	-- TargetFrameDebuff1:ClearAllPoints();
	-- TargetFrameDebuff1:SetPoint("TOPLEFT", "TargetFrame", "BOTTOMLEFT", 5, 0);

	-- Position remaining buttons in 4-4-8 layout
	for i=2, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
		button = lDebuffButtons[i];
		if button then
			button:ClearAllPoints();
			if i == 5 then
				-- Row 2: Start below button 1
				button:SetPoint("TOPLEFT", "TargetFrameDebuff1", "BOTTOMLEFT", 0, -2);
			elseif i == 9 then
				-- Row 3: Start below button 5
				button:SetPoint("TOPLEFT", "TargetFrameDebuff5", "BOTTOMLEFT", 0, -2);
			else
				-- Position horizontally relative to previous button
				button:SetPoint("LEFT", "TargetFrameDebuff"..(i-1), "RIGHT", 3, 0);
			end
		end
	end
end


-- "1h", "12m", "45", ... rounded up, so a countdown never shows 0 while
-- the aura is still up.
local function TargetFrameBuff_FormatTime(remaining)
	if (remaining >= 3600) then
		return math.ceil(remaining / 3600).."h";
	elseif (remaining >= 60) then
		return math.ceil(remaining / 60).."m";
	end
	return tostring(math.ceil(remaining));
end


TargetFrameBuff_UpdateTimer = function(button, now)
	if (not button:IsShown() or not button.auraIndex) then
		return;
	end

	local size = TargetFrameBuff_Setting("timerSize");
	if (button.timerSize ~= size) then
		button.timer:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE");
		button.timerSize = size;
	end

	local remaining = button.expiration - now;
	if (not TargetFrameBuff_Setting("timers") or button.expiration <= 0 or remaining <= 0) then
		if (button.timerText) then
			button.timerText = nil;
			button.timer:Hide();
		end
		return;
	end

	local text = TargetFrameBuff_FormatTime(remaining);
	if (text ~= button.timerText) then
		button.timerText = text;
		button.timer:SetText(text);
		button.timer:Show();
	end
	if (remaining <= TargetFrameBuff_Setting("warning")) then
		button.timer:SetTextColor(1, 0.1, 0.1);
	else
		button.timer:SetTextColor(1, 1, 1);
	end
end


-- Driven by TargetFrameBuffFrame, which is parented to TargetFrame, so this
-- only runs while you have a target.
function TargetFrameBuff_OnUpdate(elapsed)
	if (not lBuffButtons[1] or not lBuffButtons[1].timer or not TargetFrameBuff_HasClassicAPI()) then
		return;
	end
	elapsed = elapsed or 0;
	lAuraElapsed = lAuraElapsed + elapsed;
	if (lAuraElapsed >= TARGETFRAMEBUFF_AURA_INTERVAL) then
		TargetFrameBuff_UpdateClassicAPI();
	end
	if (lActiveTimerCount == 0) then
		lTimerElapsed = 0;
		return;
	end
	lTimerElapsed = lTimerElapsed + elapsed;
	if (lTimerElapsed < TARGETFRAMEBUFF_TIMER_INTERVAL) then return; end
	lTimerElapsed = 0;
	local now = GetTime();
	local i = lActiveTimerCount;
	while (i >= 1) do
		local button = lActiveTimers[i];
		TargetFrameBuff_UpdateTimer(button, now);
		if (not button:IsShown() or button.expiration <= now or not TargetFrameBuff_Setting("timers")) then
			lActiveTimers[i] = lActiveTimers[lActiveTimerCount];
			lActiveTimers[lActiveTimerCount] = nil;
			lActiveTimerCount = lActiveTimerCount - 1;
		end
		i = i - 1;
	end
end

function TargetFrameBuff_Restore()
	-- Resize debuffs to full size
	local button, debuffFrame;
	for i=1, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
		button = getglobal("TargetFrameDebuff"..i);
		if button then
			debuffFrame = getglobal("TargetFrameDebuff"..i.."Border");
			button:SetWidth(21);
			button:SetHeight(21);
			if debuffFrame then
				debuffFrame:SetWidth(23);
				debuffFrame:SetHeight(23);
			end
		end
	end
end

