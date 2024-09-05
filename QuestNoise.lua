-- QuestNoise v3.3

-- v3.3
-- * changed TOC version from 90200 to 90002
-- v3.2
-- * forgot to update version in TOC
-- v3.1
-- * further update for Shadowlands, fixed events firing in different orders
-- v3.0
-- * update for Shadowlands
-- v2.1
-- * uses Blizzard's SOUNDKIT ids
-- v2.0.4
-- * now checks for quest log updates in UNIT_QUEST_LOG_CHANGED("player") instead of QUEST_LOG_UPDATE
-- v2.0.3
-- * now saves profile data
-- v2.0.2
-- * Now checks for another style of quest objective: "Objective: count" will look for "count Objectives"
-- v2.0.1
-- * wrong toc version
-- v2.0.0
-- * TOC bump for Legion
-- * Updated new UI_INFO_MESSAGE handling
-- v1.9.1
-- * TOC bump
-- v1.9
-- * Now checks for both styles of quest objective: "Objective: count" and "count Objective"
-- * No longer uses .wav files, also automatically replaces ".wav" with ".ogg"
-- v1.8
-- * Bumped TOC to 60000
-- * Fixed objective tracking with WoD
-- v1.7
-- * Bumped TOC to 50400
-- * Will now play highest-priority sound instead of first one encountered in quest log
-- * Now handles .ogg files in MakeSound()
-- v1.6
-- * Fixed crash with nil quest objective strings (like Mark of the World Tree quests have)
-- * Bumped TOC to 50001
-- v1.5.1
-- * Bumped TOC to 40300
-- v1.4
-- * Bumped TOC to 40000
-- v1.3
-- * Fixed bug with saving settings
-- v1.2
-- * Added option to enable/disable "Quest Complete" message
-- v1.1
-- * Added Ace3 config menu (under Interface > Addons) to enable/disable/change sounds for events

-- our Ace3 addon
QuestNoise = LibStub("AceAddon-3.0"):NewAddon("QuestNoise", "AceConsole-3.0")
QuestNoise.version = GetAddOnMetadata("QuestNoise", "Version")
QuestNoise.date = "2017-08-30"

-- our frame
QuestNoiseFrame = CreateFrame("Frame", "QuestNoise", UIParent)
local f = QuestNoiseFrame
local _

-- AceConfig options tree
local options = {
  name = "QuestNoise",
  type = "group",
  get = function(info) return QuestNoise.db.profile[info[#info]] end,
  set = function(info, value) QuestNoise.db.profile[info[#info]] = value end,

  args = {
    General = {
      order = 1,
      type = "group",
      name = "General Settings",
      desc = "General Settings",
      args = {
        desc = {
          type = "description",
          order = 1,
          name = "Addon that plays sounds upon making progress on quest objectives",
        },
        hdr1 = {
          type = "header",
          name = "Objective Progress",
          order = 2,
        },
        enableObjProgress = {
          type = "toggle",
          order = 3,
--          width = "double",
          name = "Enabled",
          desc = "Enables/disables playing a sound when objective progress has been made",
        },
        objProgressSound = {
          type = "select",
          style = "dropdown",
          order = 5,
          width = "double",
          name = "Pick Sound",
          desc = "Pick Sound",
          values = {"AuctionWindowOpen","AuctionWindowClose"}
        },
        hdr2 = {
          type = "header",
          name = "Objective Complete",
          order = 6,
        },
        enableObjComplete = {
          type = "toggle",
          order = 7,
--          width = "double",
          name = "Enabled",
          desc = "Enables/disables playing a sound when an objective has been completed",
        },
        objCompleteSound = {
          type = "select",
          style = "dropdown",
          order = 8,
          width = "double",
          name = "Pick Sound",
          desc = "Pick Sound",
          values = {"AuctionWindowOpen","AuctionWindowClose"}
        },
        hdr3 = {
          type = "header",
          name = "Quest Complete",
          order = 9,
        },
        enableQuestComplete = {
          type = "toggle",
          order = 10,
--          width = "double",
          name = "Enabled",
          desc = "Enables/disables playing a sound when a quest has been completed",
        },
        questCompleteSound = {
          type = "select",
          style = "dropdown",
          order = 11,
          width = "double",
          name = "Pick Sound",
          desc = "Pick Sound",
          values = {"ReadyCheck","+558132"}
        },
        hdr4 = {
          type = "header",
          name = "\"Quest Complete\" Message",
          order = 12,
        },
        enableQuestCompleteMsg = {
          type = "toggle",
          order = 13,
--          width = "double",
          name = "Enabled",
          desc = "Enables/disables a center-screen message indicating which quest you have just completed",
        },
      },
    },
  },
}
QuestNoise.Options = options
local defaults = {
  profile =  {
    enableObjProgress = true,
    objProgressSound = 1,
    enableObjComplete = true,
    objCompleteSound = 2,
    enableQuestComplete = true,
    questCompleteSound = 2,
    enableQuestCompleteMsg = true,
  },
}

local SoundKitIDLookup = {
  ["auctionwindowopen"] = SOUNDKIT.AUCTION_WINDOW_OPEN,
  ["auctionwindowclose"] = SOUNDKIT.AUCTION_WINDOW_CLOSE,
  ["readycheck"] = SOUNDKIT.READY_CHECK,
  ["+558132"] = "558132"
}

-- note this is the Ace3 addon frame, not the one we originally had
-- eventually i'll merge them together but meh
function QuestNoise:OnInitialize()
  QuestNoise.OptionsFrames = {}

  QuestNoise.db = LibStub("AceDB-3.0"):New("QuestNoiseDB", defaults, "Default")
  options.args.Profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(QuestNoise.db)
  options.args.Profiles.cmdHidden = true
  options.args.Profiles.order = -1

  LibStub("AceConfig-3.0"):RegisterOptionsTable("QuestNoise", options)

  QuestNoise.OptionsFrames.General = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("QuestNoise", nil, nil, "General")
  QuestNoise.OptionsFrames.Profiles = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("QuestNoise", "Profiles", "QuestNoise", "Profiles")
end


-- events and main event handler (simply forwards to a member function of the same name)
f:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("UI_INFO_MESSAGE")
f:SetScript("OnEvent", function(this, event, ...)
  this[event](this, ...)
end)

-- a few constants for clarity in our sound function
local QUESTNOISE_OBJECTIVEPROGRESS = 1
local QUESTNOISE_OBJECTIVECOMPLETE = 2
local QUESTNOISE_QUESTCOMPLETE = 3

-- holds stored messages from UI_INFO_MESSAGE
QuestNoise_ObjectivesBuffer = {}

-- When a message is output to the screen, the quest info obtained from GetQuestLogTitle/GetQuestLogLeaderBoard isn't updated yet,
-- so we save it here and then look for it later in QUEST_LOG_UPDATE. This is slightly better than just checking for any changes
-- to previously-saved objectives in QUEST_LOG_UPDATE since it will only check if there has been recent info messages displayed,
-- and it only checks for exact string matches of the displayed message.
function f:UI_INFO_MESSAGE(messageType, message)
  msgName = GetGameMessageInfo(messageType)
  --print(messageType.." "..msgName.." "..message)

  if msgName and msgName:sub(1, 10) == "ERR_QUEST_" and message ~= "Objective Complete." then
    local event = self:EvalMsg(message)
    if event then
      --print("UI_INFO_MESSAGE eval'd sound")
      self:MakeSound(event)
    else
      --print("UI_INFO_MESSAGE could not eval sound, adding to buffer")
      QuestNoise_ObjectivesBuffer[#QuestNoise_ObjectivesBuffer + 1] = message
    end
  end
  
end

-- old info for QUEST_LOG_UPDATE
  -- This is the only quest-related function that I can find that is guaranteed called AFTER any objective change are reported via
  -- GetNumQuestLeaderBoards. UNIT_QUEST_LOG_CHANGED seemingly isn't called on item-based objectives, and QUEST_WATCH_UPDATE is called
  -- before the objective changes are reported via GetQuestLogLeaderBoard.

  -- UNIT_QUEST_LOG_CHANGED now works for item-based objectives and is called after objective changes are reported via
  -- GetQuestLogLeaderBoard. This function simply iterates through the list of queued UI messages (if any) and calls
  -- the EvalMsg function. This function should have a fairly low overhead cost since it does nothing if there are no
  -- saved messages in the queue. Afterwards, it plays a sound corresponding to the highest completion status.
  
--Shadowlands note
-- UI_INFO_MESSAGE and QUEST events all fire in an unpredictable order (but at the same timestamp, according to /eventtrace)

-- UI_INFO_MESSAGE will try to handle the message, and if it fails, then it will store it for handling in the QUEST events

function f:UNIT_QUEST_LOG_CHANGED(unitID)
  if unitID ~= "player" then return end  
  
  --print("UNIT_QUEST_LOG_CHANGED")
  self:HandleBuffer()
end

function f:QUEST_LOG_UPDATE()
  --print("QUEST_LOG_UPDATE")
  self:HandleBuffer()
end

function f:HandleBuffer()
  local text = QuestNoise_ObjectivesBuffer[#QuestNoise_ObjectivesBuffer]
  local event = nil
  local tevent = nil
  while text do
    --print("processing: " .. text)
    QuestNoise_ObjectivesBuffer[#QuestNoise_ObjectivesBuffer] = nil
    tevent = self:EvalMsg(text)
    
    --if tevent then
    --  print("tevent: " .. tevent)
    --else
    --  print("no tevent, could not handle message")
    --end
    
    -- if this event is higher than saved event, change saved event
    -- if saved event is nil and this event isn't, changed saved event
    if (tevent and event and tevent > event) or (tevent and not event) then event = tevent end
    text = QuestNoise_ObjectivesBuffer[#QuestNoise_ObjectivesBuffer]
  end

  -- finally, play sound if we have one to play
  if event then
    self:MakeSound(event)
  end
end


-- This function takes a message (that originated from UI_INFO_MESSAGE) and scans all quests for a matching objective string.
-- If it finds one, it determines the current status of quest (quest completed, objective completed, objective progress)
-- and returns the highest status (in case multiple quests had the same objective state)
function f:EvalMsg(arg)
  if not arg then return end

  local msg, msg2, msg3 = arg
  
  -- reorder arg for a second possible matching message
  -- new patch swapped quest leaderboard text around from:
  -- "objective: 8/8" to "8/8 objective"
  -- but message displayed center screen is still "objective: 8/8" for most quests
  local objective, count = msg:match("(.*): (.*)")
  if objective and count then
    msg2 = count .. " " .. objective
  end
  
  -- add s for a third possible pluralized message
  -- example: quest leaderboard text says
  -- "45/200 War of the Ancients Fragments"
  -- but center message is
  -- "War of the Ancients Fragment: 45/200"
  if msg2 then
    msg3 = msg2.."s"
  end
  
  -- highest priority event found
  local event = nil

  -- begin looping through every quest
  local numQuests = C_QuestLog.GetNumQuestLogEntries()
  for qindex = 1, numQuests do
    local qinfo = C_QuestLog.GetInfo(qindex)
    local title, questid, isHeader = qinfo.title, qinfo.questID, qinfo.isHeader
    local isComplete = C_QuestLog.IsComplete(questid)
    
    -- C_QuestLog.GetInfo returns EVERY line in the Quest Log, including the zone headers, and we don't care about them
    if (not isHeader) then

      -- begin checking each of this quest's objectives
      local oinfo = C_QuestLog.GetQuestObjectives(questid)
      for i, q in pairs(oinfo) do

        local text, finished = q.text, q.finished
        --print("qtext: " .. text)
          
        -- check if this objective matches what was displayed
        if (text and (text == msg or text == msg2 or text == msg3)) then
        
          --print("match!")

          -- quest complete has higher priority
          if (isComplete) then
            if not event or event < QUESTNOISE_QUESTCOMPLETE then
              event = QUESTNOISE_QUESTCOMPLETE
            end
            if (QuestNoise.db.profile.enableQuestCompleteMsg) then
              UIErrorsFrame:AddMessage("Quest complete: "..title, 1, 1, 0, 1, 5);
            end

          -- then we see if the objective we just made progress on is complete
          elseif (finished) then
            if not event or event < QUESTNOISE_OBJECTIVECOMPLETE then
              event = QUESTNOISE_OBJECTIVECOMPLETE
            end

          -- otherwise we just made some progress
          else
            if not event or event < QUESTNOISE_OBJECTIVEPROGRESS then
              event = QUESTNOISE_OBJECTIVEPROGRESS
            end
          end
          
        end
      end
    end
  end

  return event
end

-- This is just a helper function to play sounds based on a specific event constant
function f:MakeSound(event)
  local sound = nil
  
  if (event == QUESTNOISE_QUESTCOMPLETE) then
    if (QuestNoise.db.profile.enableQuestComplete) then
      sound = QuestNoise.Options.args.General.args.questCompleteSound.values[QuestNoise.db.profile.questCompleteSound]
    end
  elseif (event == QUESTNOISE_OBJECTIVECOMPLETE) then
    if (QuestNoise.db.profile.enableObjComplete) then
      sound = QuestNoise.Options.args.General.args.objCompleteSound.values[QuestNoise.db.profile.objCompleteSound]
    end
  elseif (event == QUESTNOISE_OBJECTIVEPROGRESS) then
    if (QuestNoise.db.profile.enableObjProgress) then
      sound = QuestNoise.Options.args.General.args.objProgressSound.values[QuestNoise.db.profile.objProgressSound]
    end
  end
  
  if (not sound) then
    return
  end
  
  sound = strlower(sound)
 
  if (string.sub(sound, 1, 1) == "+") then
    PlaySoundFile(SoundKitIDLookup[sound], "Master")
  else
    PlaySound(SoundKitIDLookup[sound], "Master", true)
  end


end
