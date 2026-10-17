module hvsync_generator (
    input  wire clk,
    input  wire reset,
    output wire hsync,
    output wire vsync,
    output wire display_on,
    output wire [9:0] hpos,
    output wire [9:0] vpos
);
    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    localparam H_DISPLAY = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = 800;

    localparam V_DISPLAY = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = 525;

    always @(posedge clk) begin
        if (reset) begin
            h_cnt <= 10'd0;
            v_cnt <= 10'd0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 10'd0;
                if (v_cnt == V_TOTAL - 1)
                    v_cnt <= 10'd0;
                else
                    v_cnt <= v_cnt + 10'd1;
            end else begin
                h_cnt <= h_cnt + 10'd1;
            end
        end
    end

    assign hsync = (h_cnt >= H_DISPLAY + H_FRONT) && (h_cnt < H_DISPLAY + H_FRONT + H_SYNC);
    assign vsync = (v_cnt >= V_DISPLAY + V_FRONT) && (v_cnt < V_DISPLAY + V_FRONT + V_SYNC);
    assign display_on = (h_cnt < H_DISPLAY) && (v_cnt < V_DISPLAY);
    assign hpos = h_cnt;
    assign vpos = v_cnt;

endmodule
