# Cyber-Outrun 2088 (Ultimate Edition)

## How it works
This chip generates a real-time 640x480 60Hz VGA arcade racing game using purely combinational and synchronous Verilog hardware logic. 
Features dynamic headlight projection, nitro afterburners, a Cyber-Shield forcefield for invincibility, police siren strobe lights, vehicle transformation between a sports car and superbike, heavy side-impact penalties, and a complete victory celebration sequence with fireworks upon reaching the finish line.

## How to test
1. Connect a TinyVGA Pmod to the output pins (`uo_out`).
2. Connect input buttons to `ui_in`:
   - `ui_in[0]`: Gas / Nitro Boost
   - `ui_in[1]`: Brake
   - `ui_in[2]`: Steer Left
   - `ui_in[3]`: Steer Right
   - `ui_in[5]`: Cyber-Shield (Hold for complete crash invincibility)
   - `ui_in[6]`: Police Siren (Strobe lights)
   - `ui_in[7]`: Transform between Car and Superbike
3. Avoid traffic, use your shield wisely, and cross the 1500m finish line to trigger the victory fireworks!
