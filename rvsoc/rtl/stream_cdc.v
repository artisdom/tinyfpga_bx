// Moves a valid/ready byte stream between two unrelated clock domains.
//
// One byte in flight at a time, using a toggle handshake: the source flips
// `req` when it latches a byte, the destination flips `ack` once it has
// handed the byte on. Each toggle crosses through a two-flop synchronizer.
// The data register stays stable from the req toggle until ack returns,
// so the destination can sample it directly.

module stream_cdc (
    input  wire       src_clk,
    input  wire [7:0] src_data,
    input  wire       src_valid,
    output wire       src_ready,

    input  wire       dst_clk,
    output wire [7:0] dst_data,
    output wire       dst_valid,
    input  wire       dst_ready
);
    reg       req = 0, ack = 0;
    reg [7:0] data;

    // source domain
    reg [1:0] ack_sync = 0;
    always @(posedge src_clk) begin
        ack_sync <= {ack_sync[0], ack};
        if (src_valid && src_ready) begin
            data <= src_data;
            req  <= !req;
        end
    end
    assign src_ready = req == ack_sync[1];

    // destination domain
    reg [1:0] req_sync = 0;
    always @(posedge dst_clk) begin
        req_sync <= {req_sync[0], req};
        if (dst_valid && dst_ready)
            ack <= !ack;
    end
    assign dst_valid = req_sync[1] != ack;
    assign dst_data  = data;
endmodule
