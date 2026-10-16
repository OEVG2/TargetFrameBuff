
-- Title: TargetFrameBuff v0.8
-- Notes: Shows up to 32 Buffs & 16 Debuffs on a Target (Buffs above, Debuffs below),
--        with remaining-time countdowns when ClassicAPI is installed
-- Author: lua@lumpn.de (modified)


local lOriginal_TargetDebuffButton_Update = nil;
local TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS = 16;
local TARGETFRAMEBUFF_MAX_TARGET_BUFFS = 32;

-- How often the countdowns refresh, in seconds.
local TARGETFRAMEBUFF_TIMER_INTERVAL = 0.2;
-- Countdowns at or below this many seconds turn red.
local TARGETFRAMEBUFF_TIMER_WARNING = 5;

local lBuffButtons = {};
local lDebuffButtons = {};
local lTimerElapsed = 0;


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

	button.timer = timer;
	button.timerText = nil;
	button.expiration = 0;
end


-- hook original update-function
function TargetFrameBuff_OnLoad()
	local i, button;
	for i=1, TARGETFRAMEBUFF_MAX_TARGET_BUFFS do
		lBuffButtons[i] = getglobal("TargetFrameBuff"..i);
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

	lOriginal_TargetDebuffButton_Update	= TargetDebuffButton_Update;
	TargetDebuffButton_Update = TargetFrameBuff_Update;

	lOriginal_TargetDebuffButton_Update()
	TargetFrameBuff_Restore();
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
	local debuffCount = getglobal("TargetFrameDebuff"..i.."Count");
	if (count and count > 1) then
		debuffCount:SetText(count);
		debuffCount:Show();
	else
		debuffCount:Hide();
	end
end


-- Stock 1.12 path: UnitBuff/UnitDebuff, no timing data.
function TargetFrameBuff_UpdateNative()
	local button, buff;
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


local function TargetFrameBuff_ShowAura(button, filter, index, icon, expirationTime)
	getglobal(button:GetName().."Icon"):SetTexture(icon);
	button.auraFilter = filter;
	button.auraIndex = index;
	button.id = index;
	button.expiration = expirationTime or 0;
	button:Show();
end


local function TargetFrameBuff_HideAura(button)
	button.expiration = 0;
	button.timerText = nil;
	button.timer:Hide();
	button:Hide();
end


-- ClassicAPI path: buffs and debuffs by their real type, with expiration times.
-- On Turtle WoW the server puts extra debuffs into free buff slots once the
-- 16 debuff slots are full. Those are listed as debuffs here; any that don't
-- fit the 16 debuff buttons go into the buff rows after the real buffs, so
-- nothing on the target goes unseen.
function TargetFrameBuff_UpdateClassicAPI()
	local name, icon, count, dispelType, duration, expirationTime;
	local numBuffs = 0;
	local numDebuffs = 0;
	local i;

	for i=1, TARGETFRAMEBUFF_MAX_TARGET_BUFFS do
		name, icon, count, dispelType, duration, expirationTime = C_UnitAuras.UnitAura("target", i, "HELPFUL");
		if (not name and not icon) then
			break;
		end
		numBuffs = i;
		TargetFrameBuff_ShowAura(lBuffButtons[i], "HELPFUL", i, icon, expirationTime);
	end

	i = 1;
	while (true) do
		name, icon, count, dispelType, duration, expirationTime = C_UnitAuras.UnitAura("target", i, "HARMFUL");
		if (not name and not icon) then
			break;
		end
		if (i <= TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS) then
			numDebuffs = i;
			TargetFrameBuff_ColorBorder(i, dispelType);
			TargetFrameBuff_SetCount(i, count);
			TargetFrameBuff_ShowAura(lDebuffButtons[i], "HARMFUL", i, icon, expirationTime);
		elseif (numBuffs < TARGETFRAMEBUFF_MAX_TARGET_BUFFS) then
			numBuffs = numBuffs + 1;
			TargetFrameBuff_ShowAura(lBuffButtons[numBuffs], "HARMFUL", i, icon, expirationTime);
		else
			break;
		end
		i = i + 1;
	end

	for i=numBuffs+1, TARGETFRAMEBUFF_MAX_TARGET_BUFFS do
		TargetFrameBuff_HideAura(lBuffButtons[i]);
	end
	for i=numDebuffs+1, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
		TargetFrameBuff_HideAura(lDebuffButtons[i]);
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


local function TargetFrameBuff_UpdateTimer(button, now)
	if (not button:IsShown() or not button.auraIndex) then
		return;
	end

	-- Re-read the expiration: recasting a buff that is already up can move it
	-- without the game firing an aura update.
	local name, icon, count, dispelType, duration, expirationTime = C_UnitAuras.UnitAura("target", button.auraIndex, button.auraFilter);
	button.expiration = expirationTime or 0;

	local remaining = button.expiration - now;
	if (button.expiration <= 0 or remaining <= 0) then
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
		if (remaining <= TARGETFRAMEBUFF_TIMER_WARNING) then
			button.timer:SetTextColor(1, 0.1, 0.1);
		else
			button.timer:SetTextColor(1, 1, 1);
		end
		button.timer:Show();
	end
end


-- Driven by TargetFrameBuffFrame, which is parented to TargetFrame, so this
-- only runs while you have a target.
function TargetFrameBuff_OnUpdate(elapsed)
	lTimerElapsed = lTimerElapsed + (elapsed or 0);
	if (lTimerElapsed < TARGETFRAMEBUFF_TIMER_INTERVAL) then
		return;
	end
	lTimerElapsed = 0;

	if (not lBuffButtons[1] or not lBuffButtons[1].timer or not TargetFrameBuff_HasClassicAPI()) then
		return;
	end

	local now = GetTime();
	local i;
	for i=1, TARGETFRAMEBUFF_MAX_TARGET_BUFFS do
		TargetFrameBuff_UpdateTimer(lBuffButtons[i], now);
	end
	for i=1, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
		TargetFrameBuff_UpdateTimer(lDebuffButtons[i], now);
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
