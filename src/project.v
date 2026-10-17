/*
 * Tiny Tapeout VGA Playground: "Retro Highway Racer (Tuned Score Edition)"
 * - Hitting traffic removes 300 points instantly
 * - Driving on grass continuously drains score
 * - Player blinks when hit
 * - Button 2/3 = Steer, Button 0 = Turbo, Button 7 = Transform
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

    // Direct Clickable Controls
    wire move_up    = ui_in[0]; // Button 0: Gas / Speed Boost
    wire move_left  = ui_in[2]; // Button 2: Steer Left
    wire move_right = ui_in[3]; // Button 3: Steer Right
    wire is_bike    = ui_in[7]; // Button 7: TRANSFORM (Click = Bike, Unclick = Car)

    // Road Bounds
    localparam ROAD_L = 10'd200;
    localparam ROAD_R = 10'd440;

    // Game Registers
    reg [9:0] px = 10'd320;
    reg [9:0] py = 10'd390;
    reg [9:0] t1_x = 10'd250, t1_y = 10'd60;
    reg [9:0] t2_x = 10'd380, t2_y = 10'd220;
    reg [7:0] road_scroll = 8'd0;
    reg [15:0] score = 16'd0;
    reg [7:0] lfsr = 8'h9E;
    reg [4:0] crash_flash = 5'd0;
    reg [6:0] invuln = 7'd60;
    reg prev_vsync = 1'b0;

    // Game Logic Loop (60 FPS on vsync)
    always @(posedge clk) begin
        if (reset) begin
            px <= 10'd320; py <= 10'd390;
            t1_x <= 10'd250; t1_y <= 10'd60;
            t2_x <= 10'd380; t2_y <= 10'd220;
            road_scroll <= 8'd0; score <= 16'd0;
            crash_flash <= 5'd0; invuln <= 7'd60;
            lfsr <= 8'h9E; prev_vsync <= 1'b0;
        end else begin
            prev_vsync <= vsync;
            if (!prev_vsync && vsync) begin
                // Random lane generator
                lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};

                if (invuln > 0) invuln <= invuln - 7'd1;
                if (crash_flash > 0) crash_flash <= crash_flash - 5'd1;

                // Road Scroll & Normal Score gain
                road_scroll <= road_scroll + (is_bike ? 8'd4 : (move_up ? 8'd8 : 8'd6));
                score       <= score + (is_bike ? 16'd1 : 16'd2);

                // Player Steering
                if (move_left && px > (ROAD_L - 10'd20))
                    px <= px - (is_bike ? 10'd5 : 10'd4);
                if (move_right && px < (ROAD_R + 10'd20))
                    px <= px + (is_bike ? 10'd5 : 10'd4);

                // Move Traffic Cars Down
                t1_y <= t1_y + 10'd3;
                if (t1_y >= 10'd480) begin
                    t1_y <= 10'd10;
                    t1_x <= (lfsr[0]) ? 10'd240 : 10'd290;
                end

                t2_y <= t2_y + 10'd4;
                if (t2_y >= 10'd480) begin
                    t2_y <= 10'd10;
                    t2_x <= (lfsr[1]) ? 10'd350 : 10'd400;
                end

                // 1. Off-Road Grass Penalty: Driving in the grass continuously drains score
                if (!is_bike && (px < ROAD_L + 10'd10 || px > ROAD_R - 10'd10)) begin
                    if (score > 16'd2) score <= score - 16'd3; // Drain score
                end

                // 2. Traffic Crash Collision (Subtracts 300 Points!)
                if (invuln == 0) begin
                    if (((px + (is_bike ? 10'd6 : 10'd14) > t1_x - 10'd12) &&
                         (px - (is_bike ? 10'd6 : 10'd14) < t1_x + 10'd12) &&
                         (py + 10'd14 > t1_y - 10'd16) &&
                         (py - 10'd14 < t1_y + 10'd16)) ||
                        ((px + (is_bike ? 10'd6 : 10'd14) > t2_x - 10'd12) &&
                         (px - (is_bike ? 10'd6 : 10'd14) < t2_x + 10'd12) &&
                         (py + 10'd14 > t2_y - 10'd16) &&
                         (py - 10'd14 < t2_y + 10'd16))) begin
                        crash_flash <= 5'd20; // Red border flash
                        invuln      <= 7'd60; // 1s safety shield
                        // PENALTY: Lose 300 points visibly!
                        score       <= (score > 16'd300) ? (score - 16'd300) : 16'd0;
                    end
                end
            end
        end
    end

    // Geometry & Rendering
    wire on_road    = (hpos >= ROAD_L && hpos <= ROAD_R);
    wire on_curb_l  = (hpos >= ROAD_L - 10'd12 && hpos < ROAD_L);
    wire on_curb_r  = (hpos > ROAD_R && hpos <= ROAD_R + 10'd12);
    wire curb_strip = ((vpos + road_scroll) >> 4) & 1'b1;

    // Dashed White Lane Lines
    wire on_lane1 = (hpos >= 10'd278 && hpos <= 10'd282) && (((vpos + road_scroll) >> 5) & 1'b1);
    wire on_lane2 = (hpos >= 10'd358 && hpos <= 10'd362) && (((vpos + road_scroll) >> 5) & 1'b1);

    // Player Vehicle Geometry (Blinks when hit/shield active)
    wire blink_hide = (invuln > 0) && invuln[2];
    wire [9:0] pdx = (hpos > px) ? (hpos - px) : (px - hpos);
    wire [9:0] pdy = (vpos > py) ? (vpos - py) : (py - vpos);

    wire is_player_body = !blink_hide && (is_bike ? 
                          (pdx <= 10'd4 && pdy <= 10'd12) : 
                          (pdx <= 10'd13 && pdy <= 10'd16));

    wire is_windshield = !blink_hide && (is_bike ? 
                         (pdx <= 10'd2 && pdy <= 10'd4) : 
                         (pdx <= 10'd8 && pdy <= 10'd6));

    wire is_headlight = !blink_hide && !is_bike && (pdy >= 10'd14 && pdy <= 10'd16) && (pdx >= 10'd8 && pdx <= 10'd12);

    // Traffic Cars
    wire [9:0] t1_dx = (hpos > t1_x) ? (hpos - t1_x) : (t1_x - hpos);
    wire [9:0] t1_dy = (vpos > t1_y) ? (vpos - t1_y) : (t1_y - vpos);
    wire is_traffic1 = (t1_dx <= 10'd12 && t1_dy <= 10'd16);

    wire [9:0] t2_dx = (hpos > t2_x) ? (hpos - t2_x) : (t2_x - hpos);
    wire [9:0] t2_dy = (vpos > t2_y) ? (vpos - t2_y) : (t2_y - vpos);
    wire is_traffic2 = (t2_dx <= 10'd12 && t2_dy <= 10'd16);

    // Top HUD Score Bar
    wire on_score_bar = (vpos >= 10'd10 && vpos <= 10'd18) && 
                        (hpos >= 10'd220 && hpos <= 10'd220 + (score >> 5)) &&
                        (hpos <= 10'd420);
    wire on_score_box = (vpos >= 10'd8 && vpos <= 10'd20) && (hpos >= 10'd218 && hpos <= 10'd422);

    // Output Colors
    reg [1:0] R, G, B;

    always @(*) begin
        if (!display_on) begin
            R = 2'b00; G = 2'b00; B = 2'b00; // Blanking
        end else if (crash_flash > 0 && (hpos < 10'd10 || hpos > 10'd630)) begin
            // Red crash warning flash
            R = 2'b11; G = 2'b00; B = 2'b00;
        end else if (on_score_bar) begin
            // Bright Gold Score Meter (turns red during crash!)
            R = 2'b11;
            G = (crash_flash > 0) ? 2'b00 : 2'b11;
            B = 2'b00;
        end else if (on_score_box && (vpos == 10'd8 || vpos == 10'd20 || hpos == 10'd218 || hpos == 10'd422)) begin
            R = 2'b11; G = 2'b11; B = 2'b11;
        end else if (is_headlight) begin
            R = 2'b11; G = 2'b11; B = 2'b01;
        end else if (is_windshield) begin
            R = 2'b00; G = 2'b11; B = 2'b11;
        end else if (is_player_body) begin
            if (is_bike) begin
                R = 2'b00; G = 2'b11; B = 2'b11; // Cyan Motorcycle
            end else begin
                R = 2'b11; G = 2'b00; B = 2'b00; // Red Sports Car
            end
        end else if (is_traffic1) begin
            R = 2'b11; G = 2'b11; B = 2'b00; // Yellow Taxi
        end else if (is_traffic2) begin
            R = 2'b11; G = 2'b00; B = 2'b11; // Purple Sedan
        end else if (on_lane1 || on_lane2) begin
            R = 2'b11; G = 2'b11; B = 2'b11;
        end else if (on_curb_l || on_curb_r) begin
            R = 2'b11;
            G = curb_strip ? 2'b00 : 2'b11;
            B = curb_strip ? 2'b00 : 2'b11;
        end else if (on_road) begin
            R = 2'b01; G = 2'b01; B = 2'b01;
        end else begin
            R = 2'b00;
            G = ((hpos ^ vpos) & 8'h08) ? 2'b10 : 2'b01;
            B = 2'b00;
        end
    end

    // Standard Tiny Tapeout Pinout
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

endmodule
