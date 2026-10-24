-- Settings remain usable through /tfb on unmodified 1.12 clients.
TargetFrameBuffDefaults = {
	timers = true, highlight = true, sweeps = false, timerSize = 9, warning = 5
};

local function RefreshAuras()
	if (TargetFrameBuff_Update and TargetFrameBuff1) then
		TargetFrameBuff_Update();
	end
end

local function Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100TargetFrameBuff:|r "..message);
end

local function Validate()
	if (type(TargetFrameBuffDB) ~= "table") then TargetFrameBuffDB = {}; end
	for key, value in pairs(TargetFrameBuffDefaults) do
		if (type(TargetFrameBuffDB[key]) ~= type(value)) then TargetFrameBuffDB[key] = value; end
	end
	if (TargetFrameBuffDB.timerSize ~= TargetFrameBuffDB.timerSize or TargetFrameBuffDB.timerSize < 6 or TargetFrameBuffDB.timerSize > 20) then
		TargetFrameBuffDB.timerSize = 9;
	end
	if (TargetFrameBuffDB.warning ~= TargetFrameBuffDB.warning or TargetFrameBuffDB.warning < 0 or TargetFrameBuffDB.warning > 30) then
		TargetFrameBuffDB.warning = 5;
	end
end

local panel;
local function CreateOptions()
	if (panel or not InterfaceOptions_AddCategory) then return; end
	panel = CreateFrame("Frame", "TargetFrameBuffOptions", UIParent);
	panel.name = "TargetFrameBuff";
	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16);
	title:SetText("TargetFrameBuff");
	local note = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12);
	note:SetText("ClassicAPI features. Sweeps work best with ClassicAPI 1.17.1 or newer.");
	local checks = {};
	local labels = {"Show countdown text", "Highlight enemy buffs you can remove", "Show cooldown sweeps"};
	local keys = {"timers", "highlight", "sweeps"};
	for i = 1, 3 do
		local check = CreateFrame("CheckButton", "TargetFrameBuffOption"..i, panel, "UICheckButtonTemplate");
		check:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -65 - (i - 1) * 32);
		check.key = keys[i];
		getglobal(check:GetName().."Text"):SetText(labels[i]);
		check:SetScript("OnClick", function()
			TargetFrameBuffDB[this.key] = this:GetChecked() and true or false;
			RefreshAuras();
		end);
		checks[i] = check;
	end
	local sliders = {};
	local sliderKeys = {"timerSize", "warning"};
	local sliderLabels = {"Timer font size", "Warning threshold (seconds)"};
	for i = 1, 2 do
		local slider = CreateFrame("Slider", "TargetFrameBuffSlider"..i, panel, "OptionsSliderTemplate");
		slider:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -190 - (i - 1) * 65);
		slider:SetWidth(240);
		slider:SetMinMaxValues(i == 1 and 6 or 0, i == 1 and 20 or 30);
		slider:SetValueStep(1);
		slider.key = sliderKeys[i];
		slider.label = sliderLabels[i];
		getglobal(slider:GetName().."Low"):SetText(i == 1 and "6" or "0");
		getglobal(slider:GetName().."High"):SetText(i == 1 and "20" or "30");
		slider:SetScript("OnValueChanged", function()
			local value = math.floor(this:GetValue() + 0.5);
			TargetFrameBuffDB[this.key] = value;
			getglobal(this:GetName().."Text"):SetText(this.label..": "..value);
			RefreshAuras();
		end);
		sliders[i] = slider;
	end
	local saved = {};
	local function Sync()
		for i = 1, 3 do checks[i]:SetChecked(TargetFrameBuffDB[checks[i].key]); end
		for i = 1, 2 do
			sliders[i]:SetValue(TargetFrameBuffDB[sliders[i].key]);
			getglobal(sliders[i]:GetName().."Text"):SetText(sliders[i].label..": "..TargetFrameBuffDB[sliders[i].key]);
		end
	end
	panel.refresh = function()
		for key in pairs(TargetFrameBuffDefaults) do saved[key] = TargetFrameBuffDB[key]; end
		Sync();
	end;
	panel.cancel = function()
		for key, value in pairs(saved) do TargetFrameBuffDB[key] = value; end
		Sync();
		RefreshAuras();
	end;
	panel.default = function()
		for key, value in pairs(TargetFrameBuffDefaults) do TargetFrameBuffDB[key] = value; end
		Sync();
		RefreshAuras();
	end;
	InterfaceOptions_AddCategory(panel);
end

SLASH_TARGETFRAMEBUFF1 = "/tfb";
SlashCmdList["TARGETFRAMEBUFF"] = function(message)
	Validate();
	local _, _, command, value = string.find(string.lower(message or ""), "^%s*(%S*)%s*(.-)%s*$");
	if (command == "timers" or command == "highlight" or command == "sweeps") then
		if (value == "on") then TargetFrameBuffDB[command] = true;
		elseif (value == "off") then TargetFrameBuffDB[command] = false;
		elseif (value == "") then TargetFrameBuffDB[command] = not TargetFrameBuffDB[command];
		else Print("Use on or off."); return; end
		Print(command..": "..(TargetFrameBuffDB[command] and "on" or "off"));
	elseif (command == "size" or command == "warning") then
		local number = tonumber(value);
		local min, max = 0, 30;
		if (command == "size") then min, max = 6, 20; end
		if (not number or number < min or number > max) then
			Print("Choose a number from "..min.." to "..max.."."); return;
		end
		TargetFrameBuffDB[command == "size" and "timerSize" or "warning"] = math.floor(number + 0.5);
	elseif (command == "reset") then
		TargetFrameBuffDB = nil;
		Validate();
	elseif (command == "" and InterfaceOptionsFrame_OpenToCategory) then
		CreateOptions();
		InterfaceOptionsFrame_OpenToCategory(panel);
	else
		Print("/tfb timers|highlight|sweeps [on|off], /tfb size 6-20, /tfb warning 0-30, /tfb reset");
		return;
	end
	RefreshAuras();
end;

local loader = CreateFrame("Frame");
loader:RegisterEvent("ADDON_LOADED");
loader:SetScript("OnEvent", function()
	if (arg1 == "TargetFrameBuff") then
		Validate();
		CreateOptions();
		RefreshAuras();
		this:UnregisterEvent("ADDON_LOADED");
	end
end);

