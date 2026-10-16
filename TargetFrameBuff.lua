
-- Title: TargetFrameBuff v0.7
-- Notes: Shows up to 32 Buffs & 16 Debuffs on a Target (Buffs above, Debuffs below)
-- Author: lua@lumpn.de (modified)


local lOriginal_TargetDebuffButton_Update = nil;
local TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS = 16;
local TARGETFRAMEBUFF_MAX_TARGET_BUFFS = 32;


-- hook original update-function
function TargetFrameBuff_OnLoad()
	lOriginal_TargetDebuffButton_Update	= TargetDebuffButton_Update;
	TargetDebuffButton_Update = TargetFrameBuff_Update;
	
	lOriginal_TargetDebuffButton_Update()
	TargetFrameBuff_Restore();
end


-- use extended update-function (original code from FrameXML/TargetFrame.lua)
function TargetFrameBuff_Update()
	
	local num_buff = 0;
	local num_debuff = 0;
	local button, buff;
	for i=1, TARGETFRAMEBUFF_MAX_TARGET_BUFFS do
		buff = UnitBuff("target", i);
		button = getglobal("TargetFrameBuff"..i);
		if (buff) then
			getglobal("TargetFrameBuff"..i.."Icon"):SetTexture(buff);
			button:Show();
			button.id = i;
			num_buff = i;
		else
			button:Hide();
		end
	end

	local debuff, debuffApplication, debuffCount;
	for i=1, TARGETFRAMEBUFF_MAX_TARGET_DEBUFFS do
		debuff, debuffApplications = UnitDebuff("target", i);
		button = getglobal("TargetFrameDebuff"..i);
		if (debuff) then
			debuffCount = getglobal("TargetFrameDebuff"..i.."Count");
			if (debuffApplications > 1) then
				debuffCount:SetText(debuffApplications);
				debuffCount:Show();
			else
				debuffCount:Hide();
			end
			getglobal("TargetFrameDebuff"..i.."Icon"):SetTexture(debuff);
			button:Show();
			button.id = i;
			num_debuff = i;
		else
			button:Hide();
		end
	end
	
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
		button = getglobal("TargetFrameDebuff"..i);
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