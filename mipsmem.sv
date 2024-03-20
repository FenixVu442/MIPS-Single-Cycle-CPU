// External memories used by MIPS single-cycle processor

module dmem(input  logic        clk, we,
              input  logic [31:0] a, wd,
              output logic [31:0] rd);

  logic [31:0] RAM[63:0];

  assign rd = RAM[a[31:2]]; // word aligned

  always @(posedge clk)
    if (we)
      RAM[a[31:2]] <= wd;
endmodule

module imem(input  logic [5:0]  a,
              output logic [31:0] rd);

  logic [31:0] RAM[63:0];

  initial
  begin
    $readmemh("memfile_c.dat",RAM); // initialize memory, add/remove suffix for test a, b, and c
  end

  assign rd = RAM[a]; // word aligned
endmodule

