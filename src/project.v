/*
 * Tiny Tapeout VGA Playground: "Cyber-Outrun: Victory Celebration Edition"
 * Features:
 *   - Smooth Acceleration (Button 0) & Braking Dynamics (Button 1)
 *   - Dynamic Headlight Cones & Nitro Afterburners
 *   - Checkered Finish Line & Fireworks / Confetti Victory Celebration!
 *   - Controls: 0=Gas, 1=Brake, 2=Left, 3=Right, 7=Transform
 */

`default_nettype none

module tt_um_vga_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs (TinyVGA Pmod)
    input  wire [7:0] uio_in,   // IOs: Input path (unused)
    output wire [7:0] uio_out,  // IOs: Output path (unused)
    output wire [7:0] uio_oe,   // IOs: Enable path (unused)
    input  wire       ena,      // always 1 when powered
    input  wire       clk,      // 25.175 MHz pixel clock
    input  wire       rst_n     // active low reset
);

    wire reset = !rst_n;

    // VGA synchronization signals
    wire hsync, vsync, display_on;
    wire [9:0] hpos, vpos;

    hvsync_generator hvsync_gen (
        .clk(clk),
        .reset(reset),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(display_on),
        .hpos(hpos),
        .vpos(vpos)
    );

    // Direct Controls
    wire gas_pedal   = ui_in[0]; // Button 0: Smooth Acceleration
    wire brake_pedal = ui_in[1]; // Button 1: Smooth Brake
    wire steer_left  = ui_in[2]; // Button 2: Steer Left
    wire steer_right = ui_in[3]; // Button 3: Steer Right
    wire is_bike     = ui_in[7]; // Button 7: Transform Car <-> Bike

    // Road Bounds
    localparam ROAD_L = 10'd200;
    localparam ROAD_R = 10'd440;

    // Game Physics & State Registers
    reg [9:0] px = 10'd320;
    reg [9:0] py = 10'd380;
    reg [7:0] speed = 8'd6;      // Velocity: 2 (crawl) to 14 (nitro)
    reg [9:0] t1_x = 10'd250, t1_y = 10'd60;
    reg [9:0] t2_x = 10'd380, t2_y = 10'd200;
    reg [7:0] road_scroll = 8'd0;
    reg [15:0] distance = 16'd0; // Distance to Finish Line (Goal: 1000)
    reg [7:0] lfsr = 8'hD5;
    reg [4:0] crash_flash = 5'd0;
    reg [6:0] invuln = 7'd60;
    reg [3:0] flame_anim = 4'd0;
    reg [5:0] celeb_anim = 6'd0;
    reg       won_race = 1'b0;   // 1 = VICTORY CELEBRATION!
    reg       prev_vsync = 1'b0;

    // Game Loop (60 FPS on vsync)
    always @(posedge clk) begin
        if (reset) begin
            px <= 10'd320; py <= 10'd380; speed <= 8'd6;
            t1_x <= 10'd250; t1_y <= 10'd60;
            t2_x <= 10'd380; t2_y <= 10'd200;
            road_scroll <= 8'd0; distance <= 16'd0;
            crash_flash <= 5'd0; invuln <= 7'd60;
            flame_anim  <= 4'd0; celeb_anim <= 6'd0;
            won_race    <= 1'b0; lfsr <= 8'hD5;
            prev_vsync  <= 1'b0;
        end else begin
            prev_vsync <= vsync;
            if (!prev_vsync && vsync) begin
                lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
                flame_anim <= flame_anim + 4'd1;

                if (invuln > 0) invuln <= invuln - 7'd1;
                if (crash_flash > 0) crash_flash <= crash_flash - 5'd1;

                if (!won_race) begin
                    // Acceleration & Braking
                    if (gas_pedal) begin
                        if (speed < 8'd14) speed <= speed + 8'd1;
                    end else if (brake_pedal) begin
                        if (speed > 8'd2) speed <= speed - 8'd2;
                    end else begin
                        if (speed > 8'd6) speed <= speed - 8'd1;
                        else if (speed < 8'd6) speed <= speed + 8'd1;
                    end

                    road_scroll <= road_scroll + speed;
                    distance    <= distance + {8'd0, speed};

                    if (distance >= 16'd1000) begin
                        won_race <= 1'b1; // Trigger Victory Celebration!
                    end

                    // Steering
                    if (steer_left && px > (ROAD_L - 10'd10))
                        px <= px - (is_bike ? 10'd5 : 10'd4);
                    if (steer_right && px < (ROAD_R + 10'd10))
                        px <= px + (is_bike ? 10'd5 : 10'd4);

                    // Move Traffic Downwards
                    t1_y <= t1_y + (speed > 8'd3 ? (speed - 8'd2) : 8'd2);
                    if (t1_y >= 10'd480) begin
                        t1_y <= 10'd10;
                        t1_x <= (lfsr[0]) ? 10'd240 : 10'd295;
                    end

                    t2_y <= t2_y + (speed > 8'd2 ? (speed - 8'd1) : 8'd3);
                    if (t2_y >= 10'd480) begin
                        t2_y <= 10'd10;
                        t2_x <= (lfsr[1]) ? 10'd345 : 10'd400;
                    end

                    // Off-road Grass Penalty
                    if (!is_bike && (px < ROAD_L + 10'd10 || px > ROAD_R - 10'd10)) begin
                        if (speed > 8'd3) speed <= speed - 8'd1;
                        if (distance > 16'd2) distance <= distance - 16'd2;
                    end

                    // Traffic Collision Detection
                    if (invuln == 0) begin
                        if (((px + (is_bike ? 10'd6 : 10'd14) > t1_x - 10'd12) &&
                             (px - (is_bike ? 10'd6 : 10'd14) < t1_x + 10'd12) &&
                             (py + 10'd14 > t1_y - 10'd16) &&
                             (py - 10'd14 < t1_y + 10'd16)) ||
                            ((px + (is_bike ? 10'd6 : 10'd14) > t2_x - 10'd12) &&
                             (px - (is_bike ? 10'd6 : 10'd14) < t2_x + 10'd12) &&
                             (py + 10'd14 > t2_y - 10'd16) &&
                             (py - 10'd14 < t2_y + 10'd16))) begin
                            crash_flash <= 5'd20;
                            invuln      <= 7'd60;
                            speed       <= 8'd3;
                            distance    <= (distance > 16'd150) ? (distance - 16'd150) : 16'd0;
                        end
                    end
                end else begin
                    // Victory Celebration Loop
                    celeb_anim  <= celeb_anim + 6'd1;
                    road_scroll <= road_scroll + 8'd4;
                    t1_y        <= 10'd500;
                    t2_y        <= 10'd500;
                end
            end
        end
    end

    // Geometry Rendering
    wire on_road   = (hpos >= ROAD_L && hpos <= ROAD_R);
    wire on_curb_l = (hpos >= ROAD_L - 10'd12 && hpos < ROAD_L);
    wire on_curb_r = (hpos > ROAD_R && hpos <= ROAD_R + 10'd12);
    wire curb_neon = ((vpos + road_scroll) >> 4) & 1'b1;

    // Checkered Finish Line
    wire on_finish_line = won_race && (vpos >= 10'd120 && vpos <= 10'd140) && on_road;
    wire finish_check   = ((hpos[3] ^ vpos[3]));

    // Dashed Center Lanes
    wire on_lane1 = (hpos >= 10'd278 && hpos <= 10'd282) && (((vpos + road_scroll) >> 5) & 1'b1);
    wire on_lane2 = (hpos >= 10'd358 && hpos <= 10'd362) && (((vpos + road_scroll) >> 5) & 1'b1);

    // Dynamic Headlight Cones
    wire in_headlight_beam = (vpos < py) && (vpos >= py - 10'd110) &&
                            (hpos >= px - ((py - vpos) >> 2) - 10'd10) &&
                            (hpos <= px + ((py - vpos) >> 2) + 10'd10);

    // Roadside Cyberpunk Neon Wireframe Grid
    wire [7:0] grid_y = vpos[7:0] + road_scroll;
    wire is_cyber_grid = ((hpos[4:0] == 5'd0) || (grid_y[4:0] == 5'd0)) && (!on_road);

    // Player Coordinates
    wire blink_hide = (invuln > 0) && invuln[2];
    wire [9:0] pdx = (hpos > px) ? (hpos - px) : (px - hpos);
    wire [9:0] pdy = (vpos > py) ? (vpos - py) : (py - vpos);

    wire is_player_body   = !blink_hide && (is_bike ? (pdx <= 10'd4 && pdy <= 10'd12) : (pdx <= 10'd12 && pdy <= 10'd16));
    wire is_player_glass  = !blink_hide && (is_bike ? (pdx <= 10'd2 && pdy <= 10'd4)  : (pdx <= 10'd8  && pdy <= 10'd6));
    wire is_player_wheels = !blink_hide && !is_bike && ((pdx >= 10'd11 && pdx <= 10'd14) && (pdy >= 10'd8 && pdy <= 10'd15));
    wire is_player_lights = !blink_hide && (pdy >= 10'd15 && pdy <= 10'd17) && (pdx >= 10'd7 && pdx <= 10'd11);
    wire is_player_brakes = !blink_hide && (vpos >= py + 10'd14 && vpos <= py + 10'd16) && (pdx >= 10'd7 && pdx <= 10'd11);

    // Nitro Flames
    wire is_nitro_flame = (speed > 8'd7) && 
                          (vpos >= py + 10'd16 && vpos <= py + 10'd18 + (speed << 1) + (flame_anim[1] ? 10'd4 : 10'd0)) &&
                          (pdx >= 10'd4 && pdx <= 10'd9);

    // Traffic Cars
    wire [9:0] t1_dx = (hpos > t1_x) ? (hpos - t1_x) : (t1_x - hpos);
    wire [9:0] t1_dy = (vpos > t1_y) ? (vpos - t1_y) : (t1_y - vpos);
    wire is_t1_body  = (t1_dx <= 10'd12 && t1_dy <= 10'd16);
    wire is_t1_glass = (t1_dx <= 10'd8  && t1_dy <= 10'd6);

    wire [9:0] t2_dx = (hpos > t2_x) ? (hpos - t2_x) : (t2_x - hpos);
    wire [9:0] t2_dy = (vpos > t2_y) ? (vpos - t2_y) : (t2_y - vpos);
    wire is_t2_body  = (t2_dx <= 10'd12 && t2_dy <= 10'd16);
    wire is_t2_glass = (t2_dx <= 10'd8  && t2_dy <= 10'd6);

    // Victory Celebration Elements
    wire [7:0] sparkle_hash = (hpos[7:0] ^ (vpos[7:0] + (celeb_anim << 2)));
    wire is_firework = won_race && ((sparkle_hash[4:0] == 5'h1F) || (sparkle_hash[5:0] == 6'h2A));

    wire is_crown = won_race && (vpos >= py - 10'd32 && vpos <= py - 10'd20) &&
                    (pdx <= 10'd14) && (pdy <= 10'd32) &&
                    ((vpos == py - 10'd20) || (pdx == 10'd0) || (pdx == 10'd8) || (pdx == 10'd14));

    // Top HUD Progress Meter
    wire on_hud_bar = (vpos >= 10'd10 && vpos <= 10'd18) && 
                      (hpos >= 10'd220 && hpos <= 10'd220 + (distance >> 2)) &&
                      (hpos <= 10'd420);
    wire on_hud_box = (vpos >= 10'd8 && vpos <= 10'd20) && (hpos >= 10'd218 && hpos <= 10'd422);

    // 6-bit Color Output Generation
    reg [1:0] R, G, B;

    always @(*) begin
        if (!display_on) begin
            R = 2'b00; G = 2'b00; B = 2'b00;
        end else if (crash_flash > 0 && (hpos < 10'd10 || hpos > 10'd630)) begin
            R = 2'b11; G = 2'b00; B = 2'b00;
        end else if (is_firework) begin
            R = celeb_anim[2] ? 2'b11 : 2'b00;
            G = celeb_anim[3] ? 2'b11 : 2'b11;
            B = celeb_anim[1] ? 2'b11 : 2'b01;
        end else if (is_crown) begin
            R = 2'b11; G = 2'b11; B = 2'b00;
        end else if (on_finish_line) begin
            R = finish_check ? 2'b11 : 2'b00;
            G = finish_check ? 2'b11 : 2'b00;
            B = finish_check ? 2'b11 : 2'b00;
        end else if (on_hud_bar) begin
            R = (speed > 8'd10) ? 2'b00 : 2'b11;
            G = 2'b11;
            B = (speed > 8'd10) ? 2'b11 : 2'b00;
        end else if (on_hud_box && (vpos == 10'd8 || vpos == 10'd20 || hpos == 10'd218 || hpos == 10'd422)) begin
            R = 2'b00; G = 2'b11; B = 2'b11;
        end else if (is_nitro_flame) begin
            R = flame_anim[0] ? 2'b11 : 2'b00;
            G = 2'b11;
            B = 2'b11;
        end else if (is_player_lights) begin
            R = 2'b11; G = 2'b11; B = 2'b01;
        end else if (is_player_brakes) begin
            R = brake_pedal ? 2'b11 : 2'b10;
            G = 2'b00;
            B = 2'b00;
        end else if (is_player_wheels) begin
            R = 2'b00; G = 2'b00; B = 2'b00;
        end else if (is_player_glass) begin
            R = 2'b00; G = 2'b11; B = 2'b11;
        end else if (is_player_body) begin
            if (is_bike) begin
                R = 2'b00; G = 2'b11; B = 2'b11;
            end else begin
                R = 2'b11; G = 2'b00; B = 2'b00;
            end
        end else if (is_t1_glass || is_t2_glass) begin
            R = 2'b00; G = 2'b01; B = 2'b01;
        end else if (is_t1_body) begin
            R = 2'b11; G = 2'b11; B = 2'b00;
        end else if (is_t2_body) begin
            R = 2'b11; G = 2'b00; B = 2'b11;
        end else if (on_lane1 || on_lane2) begin
            R = 2'b11; G = 2'b11; B = 2'b11;
        end else if (on_curb_l || on_curb_r) begin
            if (won_race) begin
                R = celeb_anim[3] ? 2'b11 : 2'b00;
                G = celeb_anim[2] ? 2'b11 : 2'b11;
                B = 2'b11;
            end else begin
                R = curb_neon ? 2'b11 : 2'b00;
                G = curb_neon ? 2'b00 : 2'b11;
                B = 2'b11;
            end
        end else if (on_road) begin
            if (in_headlight_beam) begin
                R = 2'b10; G = 2'b10; B = 2'b10;
            end else begin
                R = 2'b01; G = 2'b01; B = 2'b01;
            end
        end else if (is_cyber_grid) begin
            R = won_race ? 2'b11 : 2'b10;
            G = won_race ? 2'b11 : 2'b00;
            B = won_race ? 2'b00 : 2'b11;
        end else begin
            R = 2'b00; G = 2'b00; B = 2'b01;
        end
    end

    // Standard Tiny Tapeout TinyVGA Pinout
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

endmodule
