--************************************************************
-- KT_UI_Simplified Injector
-- GUID: b6b370
--************************************************************

state = {
  max_wounds  = 0,
  curr_wounds = 0,
  base        = {x=0,z=0},
  savePos     = {position=0,rotation=0},
  uiPosHigh   = true
}

function onLoad(ls)
  params = {
    label="Inject Script",
    click_function="insertCode", function_owner=self,
    position={0,1,10}, rotation={0,0,0},
    height=350, width=2300,
    font_size=250, color={0.2,0.95,0}, font_color={0,0,0}
  }
  self.createButton(params)
end

function detectItemOnTop()  --casts a box that detects all the items on top
    local start = {self.getPosition().x,self.getPosition().y,self.getPosition().z}
    local hitList = Physics.cast({
        origin       = start,
        direction    = {0,1,0},
        type         = 3, -- box
        size         = {30,1,18},
    orientation  = {x=self.getRotation().x,y=self.getRotation().y,z=self.getRotation().z},
        max_distance = 3,
        debug        = true,
    })
    return hitList
end

function insertCode(player)
  local allTops = detectItemOnTop()
  for _,hitlist in ipairs(allTops) do
    local object = hitlist["hit_object"]
    if object.getGUID() != self.getGUID() and object.getGUID() != "f861e4" then
      WebRequest.get("https://raw.githubusercontent.com/SphessMarine/TTS_KT/refs/heads/main/KT_UI_Simplified.lua", function(req)
        if req.is_error then
          log(req.error)
        else
          object.setLuaScript(req.text)
          object.script_state = JSON.encode(state)
          object = object.reload()
        end
      end) -- webrequest callback
    end
  end
end
