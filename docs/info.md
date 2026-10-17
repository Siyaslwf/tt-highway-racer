# Retro Highway Racer (Synthwave Edition)

## How it works
This chip generates a real-time 640x480 60Hz VGA arcade racing game using purely combinational and synchronous Verilog hardware logic. 
Features dynamic real-time headlight projection on dark asphalt, nitro exhaust afterburners, neon racing curbs, scrolling traffic vehicles, smooth acceleration/braking physics, and a checkered finish line celebration.

## How to test
1. Connect a TinyVGA Pmod to the output pins (uo_out).
2. Connect input switches or buttons to ui_in:
   - ui_in[0]: Gas / Nitro Boost (smooth acceleration)
   - ui_in[1]: Brake (smooth deceleration + bright brake lights)
   - ui_in[2]: Steer Left
   - ui_in[3]: Steer Right
   - ui_in[7]: Transform between Cyber Car and Neon Superbike
3. Reach the 1000m finish line to trigger the victory fireworks celebration!
