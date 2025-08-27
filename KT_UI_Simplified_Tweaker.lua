--************************************************************
-- KT_UI_Simplified Base Tweaker
-- GUID: f861e4
--************************************************************

function onLoad(ls)
  params = {
    label="Set Base Dimensions",
    click_function="callback_tweakBase", function_owner=self,
    position={0,1,1}, rotation={0,0,0},
    height=350, width=2300,
    font_size=250, color={0.2,0.95,0}, font_color={0,0,0}
  }
  self.createButton(params)
end

function rcall(target, fname, args)
  if target.getVar(fname) then
    target.call(fname, args)
  end
end

function callback_tweakBase( obj, color, alt_click )
  for _, player in ipairs(Player.getPlayers()) do
    if player.color == color then
      local so = player.getSelectedObjects()
      if next(so) ~= nil then
        for k,v in pairs(so) do
          rcall(v, "comSetAttr")
        end
      else
        player.broadcast("Select some operatives first")
      end
    end
  end
end
