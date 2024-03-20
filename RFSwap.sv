module RFSwap(
    input logic clk, init, swap,
    input logic [2:0] x, y,
    output logic [3:0] r[7:0]
);

logic [2:0] xSel, ySel;

always_ff @(posedge clk, posedge init) begin
    if (init) begin
        for (int i = 0; i < 8; i++) begin
            r[i] <= i;
        end
    end
    else if (swap) begin
        r[x] <= ySel;
        r[y] <= xSel;
    end
end

always_comb begin
    xSel = r[x];
    ySel = r[y];
end

endmodule
