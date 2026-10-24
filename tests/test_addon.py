import sys
from pathlib import Path
import xml.etree.ElementTree as ET
sys.path.insert(0, str(Path("work/pythonlibs").resolve()))
from lupa.lua51 import LuaRuntime

addon = Path(__file__).resolve().parents[1]
mock = Path(__file__).with_name("mock_wow.lua").read_text(encoding="utf-8-sig")
passed = 0
def run(name, setup, body):
    global passed
    lua = LuaRuntime()
    lua.execute(mock)
    lua.execute(setup)
    lua.execute((addon/"Settings.lua").read_text(encoding="utf-8-sig"))
    lua.execute((addon/"TargetFrameBuff.lua").read_text(encoding="utf-8-sig"))
    lua.execute("TargetFrameBuff_OnLoad(); LoadSettings()")
    lua.execute(body)
    passed += 1
    print("PASS", name)

run("batched scans, reordered icons/timers and fresh tooltip indices",
    'InstallAPI(true); auras.HELPFUL={Aura("A",1,30,130),Aura("B",1,40,140)}',
    '''
Tick()
assert(calls.index==0)
assert(TargetFrameBuff1Icon.texture=="A" and TargetFrameBuff1.timer.text=="30")
auras.HELPFUL={Aura("B",1,40,150),Aura("A",1,30,125)}
Tick()
assert(TargetFrameBuff1Icon.texture=="B" and TargetFrameBuff1.timer.text=="50")
assert(TargetFrameBuff2Icon.texture=="A" and TargetFrameBuff2.timer.text=="25")
this=TargetFrameBuff2; this.scripts.OnEnter()
assert(GameTooltip.tooltip[2]==2 and GameTooltip.tooltip[3]=="HELPFUL")
auras.HELPFUL={Aura("C",1,50,160)}
Tick()
assert(TargetFrameBuff1Icon.texture=="C" and not TargetFrameBuff2:IsShown())
assert(not GameTooltip:IsShown())
''')
run("overflow debuff stacks, borders and cleanup on reuse", 'InstallAPI(true)', '''
auras.HELPFUL={Aura("Buff",3)}
for i=1,18 do auras.HARMFUL[i]=Aura("Debuff"..i,4,20,120,false,"Poison") end
Tick()
assert(TargetFrameBuff1.auraCount.text==3)
assert(TargetFrameBuff2Icon.texture=="Debuff17")
assert(TargetFrameBuff2.auraIndex==17 and TargetFrameBuff2.auraFilter=="HARMFUL")
assert(TargetFrameBuff2.auraCount.text==4 and TargetFrameBuff2.auraBorder.color[2]==1)
this=TargetFrameBuff2; this.scripts.OnEnter()
assert(GameTooltip.tooltip[2]==17 and GameTooltip.tooltip[3]=="HARMFUL")
auras.HARMFUL={}; auras.HELPFUL={Aura("Buff"),Aura("Plain")}
Tick()
assert(not TargetFrameBuff2.auraCount:IsShown() and not TargetFrameBuff2.auraBorder:IsShown())
assert(not TargetFrameDebuff1:IsShown())
''')
run("removable buff highlight toggle", 'InstallAPI(true); auras.HELPFUL={Aura("Purge",1,30,130,true)}', '''
Tick(); assert(TargetFrameBuff1.auraBorder:IsShown())
SlashCmdList.TARGETFRAMEBUFF("highlight off"); Tick()
assert(not TargetFrameBuff1.auraBorder:IsShown())
SlashCmdList.TARGETFRAMEBUFF("highlight on"); Tick()
assert(TargetFrameBuff1.auraBorder:IsShown())
''')
run("sweep start, refresh, unchanged timer, disable, expiration and missing duration",
    'InstallAPI(true); auras.HELPFUL={Aura("A",1,30,130)}', '''
assert(not TargetFrameBuff1.cooldown)
SlashCmdList.TARGETFRAMEBUFF("sweeps on"); Tick()
local cd=TargetFrameBuff1.cooldown
assert(cd.start==100 and cd.duration==30 and cd.reverse==true and cd.edge==true)
local n=cd.calls; Tick(); assert(cd.calls==n)
auras.HELPFUL[1][6]=140; Tick(); assert(cd.start==110 and cd.calls==n+1)
SlashCmdList.TARGETFRAMEBUFF("sweeps off"); Tick(); assert(not cd:IsShown())
SlashCmdList.TARGETFRAMEBUFF("sweeps on"); Tick(); assert(cd:IsShown())
now=141; Tick(); assert(not cd:IsShown() and not TargetFrameBuff1.timer:IsShown())
auras.HELPFUL[1][5]=0; auras.HELPFUL[1][6]=0; Tick(); assert(not cd:IsShown())
''')
run("unknown timers, font size and warning settings", 'InstallAPI(true)', '''
auras.HELPFUL={Aura("A",1,0,0)}; Tick(); assert(not TargetFrameBuff1.timer:IsShown())
auras.HELPFUL={Aura("A",1,10,106)}; Tick()
assert(TargetFrameBuff1.timer.color[2]==1)
SlashCmdList.TARGETFRAMEBUFF("warning 10"); Tick()
assert(TargetFrameBuff1.timer.color[2]==.1)
SlashCmdList.TARGETFRAMEBUFF("size 14"); Tick()
assert(TargetFrameBuff1.timer.fontSize==14)
assert(TargetFrameBuff1.timer.font=="Fonts\\\\FRIZQT__.TTF")
SlashCmdList.TARGETFRAMEBUFF("timers off"); Tick(); assert(not TargetFrameBuff1.timer:IsShown())
SlashCmdList.TARGETFRAMEBUFF("timers on"); Tick(); assert(TargetFrameBuff1.timer:IsShown())
SlashCmdList.TARGETFRAMEBUFF("size 999"); assert(TargetFrameBuffDB.timerSize==14)
''')
run("older ClassicAPI and unsupported Cooldown fallback", '''
InstallAPI(false); noCooldown=true; auras.HELPFUL={Aura("Old",2,20,120)}
''', '''
SlashCmdList.TARGETFRAMEBUFF("sweeps on"); Tick()
assert(TargetFrameBuff1.noCooldown and TargetFrameBuff1.timer.text=="20")
assert(calls.index>0 and calls.slots==0)
auras.HELPFUL={Aura("Refreshed",1,30,140)}; Tick()
assert(TargetFrameBuff1Icon.texture=="Refreshed")
''')
run("native client fallback and settings persistence", '''
nativeBuffs={"Native"}; nativeDebuffs={{"Poison",3,"Poison"}}
TargetFrameBuffDB={timers=false,highlight=false,sweeps=false,timerSize=12,warning=7}
''', '''
Tick()
assert(TargetFrameBuff1Icon.texture=="Native")
assert(TargetFrameDebuff1Count.text==3)
assert(not TargetFrameBuff1.timer)
assert(TargetFrameBuffDB.timers==false and TargetFrameBuffDB.timerSize==12)
SlashCmdList.TARGETFRAMEBUFF("sweeps on"); Tick()
assert(not TargetFrameBuff1.cooldown)
''')
run("full 48-icon scan call budget and target clear", 'InstallAPI(true)', '''
for i=1,32 do auras.HELPFUL[i]=Aura("B"..i) end
for i=1,16 do auras.HARMFUL[i]=Aura("D"..i) end
calls={index=0,slots=0,bySlot=0}; Tick()
assert(calls.index==0 and calls.slots==2 and calls.bySlot==48)
assert(TargetFrameBuff32:IsShown() and TargetFrameDebuff16:IsShown())
auras={HELPFUL={},HARMFUL={}}; Tick()
assert(not TargetFrameBuff1:IsShown() and not TargetFrameDebuff16:IsShown())
''')
run("options panel controls, cancel and defaults", '''
InstallAPI(true)
InterfaceOptions_AddCategory=function(p) registered=p end
InterfaceOptionsFrame_OpenToCategory=function(p) p.refresh() end
''', '''
assert(registered.name=="TargetFrameBuff")
SlashCmdList.TARGETFRAMEBUFF("")
this=TargetFrameBuffOption3; this:SetChecked(true); this.scripts.OnClick()
assert(TargetFrameBuffDB.sweeps==true)
TargetFrameBuffSlider1:SetValue(13); assert(TargetFrameBuffDB.timerSize==13)
registered.cancel()
assert(TargetFrameBuffDB.sweeps==false and TargetFrameBuffDB.timerSize==9)
TargetFrameBuffDB.timerSize=15; registered.default(); assert(TargetFrameBuffDB.timerSize==9)
''')
run("corrupt saved settings recover", 'TargetFrameBuffDB={timerSize=999,warning=-1,timers="bad"}', '''
assert(TargetFrameBuffDB.timerSize==9 and TargetFrameBuffDB.warning==5 and TargetFrameBuffDB.timers==true)
''')
run("aura disappears just before hover and lower count overlay", 'InstallAPI(true); auras.HELPFUL={Aura("A")}; auras.HARMFUL={Aura("D",4)}', '''
Tick()
assert(TargetFrameDebuff1.auraCount.text==4)
assert(not TargetFrameDebuff1Count:IsShown())
auras.HELPFUL={}
this=TargetFrameBuff1; this.scripts.OnEnter()
assert(not GameTooltip:IsShown() and not TargetFrameBuff1.auraIndex)
''')
run("cached countdown avoids aura reads; silent recast fallback", 'InstallAPI(true); auras.HELPFUL={Aura("A",1,30,130)}', '''
calls={index=0,slots=0,bySlot=0}
now=101; TargetFrameBuff_OnUpdate(.2)
assert(calls.slots==0 and TargetFrameBuff1.timer.text=="29")
auras.HELPFUL[1][6]=150
TargetFrameBuff_OnUpdate(.2); assert(calls.slots==0)
TargetFrameBuff_OnUpdate(.1)
assert(calls.slots==2 and TargetFrameBuff1.timer.text=="49")
''')
run("unit event filtering and target change refresh", 'InstallAPI(true); auras.HELPFUL={Aura("A")}', '''
calls={index=0,slots=0,bySlot=0}
event="UNIT_AURA"; arg1="party1"; TargetFrameBuffFrame.scripts.OnEvent()
assert(calls.slots==0)
auras.HELPFUL={Aura("B")}; arg1="target"; TargetFrameBuffFrame.scripts.OnEvent()
assert(calls.slots==2 and TargetFrameBuff1Icon.texture=="B")
auras.HELPFUL={}; event="PLAYER_TARGET_CHANGED"; TargetFrameBuffFrame.scripts.OnEvent()
assert(not TargetFrameBuff1:IsShown())
''')
run("idle countdown stops but fallback discovers new timing", 'InstallAPI(true); auras.HELPFUL={Aura("A",1,0,0)}', '''
local writes=0
TargetFrameBuff1.timer.SetText=function() writes=writes+1 end
calls={index=0,slots=0,bySlot=0}
TargetFrameBuff_OnUpdate(.2); TargetFrameBuff_OnUpdate(.2)
assert(writes==0 and calls.slots==0)
auras.HELPFUL[1][5]=30; auras.HELPFUL[1][6]=130
TargetFrameBuff_OnUpdate(.1)
assert(writes==1 and TargetFrameBuff1.timer:IsShown())
SlashCmdList.TARGETFRAMEBUFF("timers off")
writes=0; TargetFrameBuff_OnUpdate(.2)
assert(writes==0 and not TargetFrameBuff1.timer:IsShown())
''')
ET.parse(addon/"TargetFrameBuff.xml")
print("PASS XML parsing")
print(f"{passed} Lua regression scenarios passed; XML parsed.")

