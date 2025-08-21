--************************************************************
-- KT_UI_Simplified
-- Most implementation sourced from KT Command Node and KTUI
--************************************************************

-- data to be stored on the model
state = {
  max_wounds  = 0,
  curr_wounds = 0,
  base        = {x=0,z=0},
  savePos     = {position=0,rotation=0},
  uiPosHigh   = true
}

-- in mm
baseDimensions = {
  {x = 25,   z = 25},
  {x = 28.5, z = 28.5},
  {x = 32,   z = 32},
  {x = 40,   z = 40},
  {x = 50,   z = 50},
  {x = 55,   z = 55},
  {x = 60,   z = 35},
  {x = 35,   z = 60},
  {x = 60,   z = 60},
  {x = 100,  z = 100},
  {x = 25,   z = 75},
  {x = 75,   z = 25},
  {x = 120,  z = 92},
  {x = 92,   z = 120},
  {x = 170,  z = 105},
  {x = 105,  z = 170}
}

-- constants
self.max_typed_number = 99

ranges = {
  triangle={
    color=Color(0.10,0.10,0.09),
    range=1
  },
  circle={
    color=Color(1,1,1),
    range=2
  },
  square={
    color=Color(0,0.36,0.62),
    range=3
  },
  pentagon={
    color=Color(0.80,0.08,0.09),
    range=6
  }
}

modelMeasureLineRadius = 0.05
baseLineRadius         = 0.0125
baseLineHeight         = 0.2
rangeShown             = false

-- later set to player color
measureColor           = nil
-- in inches. Used to draw a circle around the model's base
measureRange           = 0

-- not sure if these need to be accessible
uiHeight               = 2
uiAngle                = 0

isConcealed            = true
state_ready            = true
state_display_arrows   = false

--[[
"public" function called externally.
If you want to set more types via the description,
they should go here.
]]
function comSetAttr(t)
  -- t currently does nothing, might need it later
  local desc = self.getDescription()
  for match in string.gmatch(desc, "%b[]") do
    local s = string.find(match, "W =")
    if s then
      local i = tonumber(string.match(match, "%d+[%[%]]*$"):sub(1, -2))
      if i then
        state.max_wounds  = i
        state.curr_wounds = state.max_wounds
        refreshWounds()
        print("Wounds updated.")
      end
    end
    s = string.find(match, "Base =")
    if s then
      local z = tonumber(string.match(match, "%d+[%[%]]*$"):sub(1, -2))
      local x = tonumber(string.match(match, "%d+"))
      if x and z then
        setBaseSize(x, z)
        print("Base size updated.")
      end
    end
  end
end

-- helper function
function textColorXml( color, text )
  return string.format("<textcolor color=\"#%s\">%s</textcolor>", color, text)
end

-- init
function onLoad(ls)
  -- grab data from model
  loadState()
  -- only try to set the base the first time, afterwards x is stored
  if state.base.x == 0 then
    findBase()
  end
  createContextMenuOptions()
  createUI()
  refreshUI()
  refreshVectors(true)
  Wait.frames(function() refreshWounds() end, 1)
end

--[[
  Base Size Functions
]]

-- Tries to determine the base size for spawning circles
-- Usually fails, but that's okay, base size can be manually set
-- Pulled this from the old command node script
function findBase()
  -- I think "modelBase" might be an old holdover. Some models may still have this
  local base = self.getTable("modelBase")
  -- if not, try to determine the model base size (this will likely fail)
  if base == nil then
      local bounds = self.getBoundsNormalized()
      local baseX = 0
      local baseZ = 0

      if bounds.size.x == 0 then
          bounds = self.getBounds()
      end

      if bounds.size.x > 0 then
          local boundsX = bounds.size.x * 25.4
          local boundsZ = bounds.size.z * 25.4
          local baseError = 999999
          for i, dim in pairs(baseDimensions) do
              local difx = (dim.x - boundsX)
              local difz = (dim.z - boundsZ)
              local dimError = difx*difx + difz*difz
              if dimError < baseError then
                  baseError = dimError
                  baseX = dim.x
                  baseZ = dim.z
              end
          end
      else
          print("Could not detect base size for this model. You will need to set it manually.")
          baseX = 32
          baseZ = 32
      end
      base = {x = baseX, z = baseZ}
      setBaseSize(baseX, baseZ)
  end
end

-- Currently unused
function doAutoSize()
  local nx = state.base.x
  local nz = state.base.z
  local bounds = self.getBoundsNormalized()
  if bounds.size.x == 0 or bounds.size.y == 0 then
      local r = self.getRotation()
      self.setRotation(Vector(0,0,0))
      bounds = self.getBounds()
      self.setRotation(r)
  end
  local scale = self.getScale()
  local xi = nx / 25.4
  local zi = nz / 25.4
  local xs = (xi / bounds.size.x) * scale.x
  local zs = (zi / bounds.size.z) * scale.z

  self.setScale(Vector(xs, (xs + zs) / 2, zs))
  refreshVectors()
end

-- This one actually sets base size
function setBaseSize( x, z )
  state.base = {x=x, z=z}
  -- state.uiHeight=((x + z)/25)
  saveState()
  refreshVectors()
  refreshUI()
end

-- Context menu callback for saving a location to test out movement
function savePosition(p, r)
  local savePos = {
    position=p or self.getPosition(),
    rotation=r or self.getRotation()
  }
  state.savePos = savePos
  -- I don't think it's necessary to save this to the model but that's how it worked previously
  saveState()
  self.highlightOn(Color(0.19, 0.63, 0.87), 0.5)
end

-- Context menu callback for snapping the model back to saved transform
function loadPosition(pc)
  local sp = state.savePos
  local event = {
    id = self.getGUID(),
    operative = self.getName(),
    coords= sp.position,
    old_coords = self.getPosition(),
    player = Player[pc].steam_name
  }
  if sp then
    self.setPositionSmooth(sp.position, false, true)
    self.setRotationSmooth(sp.rotation, false, true)
    self.highlightOn(Color(0.87, 0.43, 0.19), 0.5)
  end
end

-- These two save/load the state table on the model
function saveState()
  local old_state = self.script_state
  self.script_state = JSON.encode(state)
end
function loadState()
  state = JSON.decode(self.script_state)
end

--I removed the ability to "own" models, but left this in since it wasn't harming anything
function getOwningPlayer()
  for _, player in ipairs(Player.getPlayers()) do
    if player.steam_id == state.owner then
      return player
    end
  end
  return nil
end

--[[
  Operative Order Functions
]]

function setEngage()
  isConcealed = false
  state_ready = true
  refreshUI()
end

function setConceal()
  isConcealed = true
  state_ready = true
  refreshUI()
end

-- Returns properly formatted string used to display the correct Order Token
function getCurrentOrder()
  local orderName = getOrder()
  if state_ready == nil or state_ready then
    return orderName.."_ready"
  else
    return orderName.."_activated"
  end
end

-- Returns a string that represents the current Order
function getOrder()
  if isConcealed == true then
    return "Conceal"
  else
    return "Engage"
  end
end

-- UI click callback trigger when the Order Token is clicked
-- Swaps the Ready state on left click, Order on right
-- Refreshes UI to display correct token
function callback_orders(player, value, id)
  if value == '-1' then
    if state_ready == nil or state_ready then
      state_ready = false
    else
      state_ready = true
    end
  else
    if isConcealed == false then
      isConcealed = true
    else
      isConcealed = false
    end
  end
  refreshUI()
  refreshWounds()
  saveState()
end

--[[
  Wound Functions
]]

-- Sets the bool that enables the draw of the +/- wounds buttons
function toggleArrows()
  state_display_arrows = not state_display_arrows
  refreshUI()
end

function heal(pc)
  local si = isInjured()
  state.curr_wounds = math.min((state.max_wounds or 0), (state.curr_wounds or 0) + 1)
  if si and not isInjured() then
    self.UI.hide("ktcnid-status-injured")
  end
  saveState()
  refreshWounds()
end

function damage(pc)
  local si = isInjured()
  state.curr_wounds = math.max(0, (state.curr_wounds or 0) - 1)
  if not si and isInjured() then
    self.UI.show("ktcnid-status-injured")
  end
  saveState()
  refreshWounds()
end

-- Returns true if the model is Injured
function isInjured()
  return state.max_wounds and state.curr_wounds < state.max_wounds / 2 or false
end

-- callback function used in the right click context menu
-- I don't know if the return is necessary
function SetMaxWounds( pc, n )
  local handled = true
  state.max_wounds = tonumber(n)
  state.curr_wounds = state.max_wounds
  refreshWounds()
  handled = false -- allow other handlers to trigger (eg: state change)
  return handled
end

--[[
  UI Functions
]]

-- Determines vector of circle to draw
function getCircleVectorPoints(radius, height, segments)
    local bounds = self.getBoundsNormalized()
    local result = {}
    local scaleFactorX = 1/self.getScale().x
    local scaleFactorY = 1/self.getScale().y
    local scaleFactorZ = 1/self.getScale().z
    local steps = segments or 64
    local degrees,sin,cos,toRads = 360/steps, math.sin, math.cos, math.rad

    local mtoi = 0.0393701
    local baseX = state.base.x * 0.5 * mtoi
    local baseZ = state.base.z * 0.5 * mtoi

    for i = 0,steps do
        table.insert(result,{
            x = cos(toRads(degrees*i))*((radius+baseX)*scaleFactorX),
            z = sin(toRads(degrees*i))*((radius+baseZ)*scaleFactorZ),
            y = height*scaleFactorY
        })
    end

    return result
end

-- TTS Event Handler. Draws a small circle around the base
function onNumberTyped( pc, n )
  local handled = true
  rangeShown = n > 0
  measureColor = Color.fromString(pc)
  measureRange = n

  scaleFactor = 1/self.getScale().x

  if lastRange == measureRange then
    sphereRange = getCircleVectorPoints(measureRange - modelMeasureLineRadius + 0.05, 0.125, 1)[1].x * 2 / scaleFactor
    Physics.cast({
          origin       = self.getPosition(),
          direction    = {0,1,0},
          type         = 2,
          size         = {sphereRange,sphereRange,sphereRange},
          max_distance = 0,
          debug        = true,
    })
    handled = false -- allow other handlers to trigger (eg: state change)
  end
  lastRange = measureRange
  refreshVectors()
  Player[pc].broadcast(string.format("%d\"", measureRange))
  return handled
end

-- Draws a little circle around the base which can be helpful in games.
-- If getOwningPlayer is implemented properly the circle can be recolored to match.
-- Could also give it a setter via description.
function refreshVectors(norotate)
  local op = getOwningPlayer()
  local circ = {}
  local scaleFactor = 1/self.getScale().x

  local rotation = self.getRotation()

  local newLines = {
    {
      points = getCircleVectorPoints(0 - baseLineRadius, baseLineHeight),
      color = op and Color.fromString(op.color) or {0.5, 0.5, 0.5},
      thickness = baseLineRadius*2*scaleFactor
    }
  }

  if rangeShown then
    if measureRange > 0 then
      table.insert(newLines,{
        points=getCircleVectorPoints(measureRange - modelMeasureLineRadius + 0.05, 0.125),
        color = measureColor,
        thickness = modelMeasureLineRadius*2*scaleFactor,
        rotation = (norotate and {0, 0, 0} or {-rotation.x, 0, -rotation.z})
      })
    else
      for _,r in pairs(ranges) do
        local range = r.range
        table.insert(newLines,{
          points=getCircleVectorPoints(range - modelMeasureLineRadius + 0.05, 0.125),
          color = r.color,
          thickness = modelMeasureLineRadius*2*scaleFactor,
          rotation = (norotate and {0, 0, 0} or {-rotation.x, 0, -rotation.z})
        })
      end
    end
  end

  self.setVectorLines(newLines)
end

-- Redraws the Wounds but also part of the UI?
-- It was mentioned that the two could be combined.
function refreshWounds()

  local w = state.curr_wounds
  local m = state.max_wounds

  local uiwstring = function()
    if w == 0 then
      return textColorXml("DA1A18", "DEAD")
    end
    return string.format("%d/%d", w, m)
  end

  local namewstring = function()
    if w == 0 then
      return "{[DA1A18]DEAD[-]}"
    elseif w < m/2 then
      return string.format("{[9A1111]*[-]%d/%d[9A1111]*[-]}", w, m)
    end
    return string.format("{%d/%d}", w, m)
  end

  self.UI.setValue("ktcnid-status-wounds", uiwstring())
  local nname = self.getName()

  if string.find(nname, "%b{}") == nil then
    nname = "{} "..nname
  else
    nname = string.sub(nname, string.find(nname, "%b{}"), 100)
  end

  local norder = "[FF5500]"
  if state_ready == false then
    norder = "[999999]"
  end

  if isConcealed == true then
    norder = norder.."C"
  else
    norder = norder.."E"
  end
  norder = norder.."[-] "

  self.setName(string.gsub(nname, "%b{}", norder..namewstring()))
end

-- Redraws the UI. This will need to be called any time the display is updated.
function refreshUI()
  local sc = self.getScale()
  local scaleFactorX = 1/sc.x
  local scaleFactorY = 1/sc.y
  local scaleFactorZ = 1/sc.z

  local circOffset = function(d, a)
    local ra = math.rad(a)
    return string.format("%d %d", math.cos(ra)*d, math.sin(ra)*d)
  end

  local off_injured = -35
  local off_order = 65
  if state_display_arrows then
    off_injured = -75
    off_order = 95
  end

  local p = getOwningPlayer()
  local wound_color = "red"
  if p ~= nil then
    if p.color ~= "Red" then
      wound_color = "blue"
    end
  end

  local position = "0 0 -"..tostring(uiHeight*100*scaleFactorZ)

  if state.uiPosHigh == false then
    position = "0 -"..tostring(60*scaleFactorY).." -"..tostring(20*scaleFactorZ)
  end
  local xmlTable = [[<Defaults>
  <Image class="statusDisplay" hideAnimation="Shrink" showAnimation="Grow" preserveAspect="true" />
</Defaults>
<Panel position="]]..position..[[" width="100" height="100" rotation="0 0 ]]..(uiAngle or 0)..[[" scale="]]..scaleFactorX..[[ ]]..scaleFactorY..[[ ]]..scaleFactorZ..[[">
    <Panel color="#808080" outline="#FF5500" outlineSize="2 2" width="80" height="25" offsetXY="]]..circOffset(40, 270)..[[">
    <Image id="ktcnid-status-injured" image="Wound_]]..wound_color..[[" width="30" height="30" rectAlignment="MiddleLeft" offsetXY="]]..off_injured..[[ 0" active="]]..tostring(isInjured())..[[" />
        <Button text="-" width="30" height="30" offsetXY="-65 0" onClick="damage" active="]]..tostring((state_display_arrows or false))..[[" />
        <Text id="ktcnid-status-wounds" text="]]..string.format("%d/%d", state.curr_wounds or 0, state.max_wounds or 0)..[[" resizeTextForBestFit="true" color="#ffffff" onClick="toggleArrows" />
        <Button text="+" width="30" height="30" offsetXY="65 0" onClick="heal" active="]]..tostring((state_display_arrows or false))..[[" />
    <Image id="ktcnid-status-order" image="]]..getCurrentOrder()..[[" rectAlignment="MiddleRight" width="55" height="55" offsetXY="]]..off_order..[[ 0" active="true" onClick="callback_orders" />
    </Panel>
</Panel>]]

  self.UI.setXml(xmlTable)
end

-- Set right click menu callbacks
function createContextMenuOptions()
  -- clicking on the order icon works, but you can uncomment these if you need them
  -- self.addContextMenuItem("Engage", function(pc)  setEngage() end)
  -- self.addContextMenuItem("Conceal", function(pc)  setConceal() end)
  self.addContextMenuItem("Save place", function(pc) savePosition() end)
  self.addContextMenuItem("Load place", function(pc) loadPosition(pc) end)
  self.addContextMenuItem("Set Wounds", function(pc)
    Player[pc].showInputDialog(
      "Enter desired range: (0 to disable)",
      function (text, player_color)
        SetMaxWounds(player_color, tonumber(text))
      end)
  end)
  local change_UI_text = "Lower UI"
  if state.uiPosHigh == false then
    change_UI_text = "Raise UI"
  end
  self.addContextMenuItem(change_UI_text, function(pc) if state.uiPosHigh ~= false then state.uiPosHigh = false else state.uiPosHigh = true end refreshUI() end)
end

-- Set up custom assets for the floating UI (order tokens)
function createUI()
  local baseBundle = {
    {name="Engage_ready",      url=[=[https://steamusercontent-a.akamaihd.net/ugc/1857172427760474363/695DDBC1E5EBD24801831E34F2C640B0B0DACF20/]=]},
    {name="Engage_activated",  url=[=[https://steamusercontent-a.akamaihd.net/ugc/1857172427760474790/63E7C5132CFE12964FFAA74EE03535EA6FEE2637/]=]},
    {name="Conceal_ready",     url=[=[https://steamusercontent-a.akamaihd.net/ugc/1857172427760474921/2051CBD8272374F262C88AC0DABF50BEAAB2C3BA/]=]},
    {name="Conceal_activated", url=[=[https://steamusercontent-a.akamaihd.net/ugc/1857172427760474857/9CE3B9494B93973E94B71E062558E88D83BEC6BC/]=]},
    {name="Wound_blue",        url=[=[https://steamusercontent-a.akamaihd.net/ugc/1857171492582455772/CFB7B4D001501AC54B4D0CC7FEE35AF679B73D34/]=]},
    {name="Wound_red",         url=[=[https://steamusercontent-a.akamaihd.net/ugc/1857171826950614938/C515FF37C3D1D269533C1B5FDA675895F792BC15/]=]},
  }
  self.UI.setCustomAssets(baseBundle)
end
