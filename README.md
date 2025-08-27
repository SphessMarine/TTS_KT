# TTS_KT
Credit for most implementation goes to KT Command Node and KTUI. I merely pulled out the parts I wanted so I didn't have to jump through a bunch of hoops to get the UI on whatever models I wanted.
## Wound Tracker
Models start with their wound count at 0, you can set this via a right click menu option. Click the wound counter to pull up '+/-' buttons to modify remaining wounds.
## Order Icon
Right click the order token to swap orders. Left click to toggle Ready.
## Check Range
Hover over a model and type a number to spawn a range circle (measured from the edge) of that same amount in inches (so type "2" to see engagement range). The circle should be colored to your player.
## Save/Load Position
Right click and use the Save/Load Position options to play around with movement without needing to Ctrl-Z and reset the whole board state. Save Position also forces the model to encode its state into JSON, so it might help resolve any weird issues on fresh models.
