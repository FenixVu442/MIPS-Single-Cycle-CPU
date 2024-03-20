module GPbit (
    input logic Ai, Bi,
    output logic [1:0] GPii
  );

  assign GPii[0] = Ai & Bi;
  assign GPii[1] = Ai | Bi;
endmodule // GPii[0] = Gii, GPii[1] = Pii

module GPblk (
    input logic [1:0] GPik, GPkj,
    output logic [1:0] GPij
  );
  assign GPij[0] = GPik[0] | (GPik[1] & GPkj[0]);
  assign GPij[1] = GPik[1] & GPkj[1];
endmodule

module CarryBit(
    input logic [1:0] GPij,
    input logic cj,
    output logic c_iPlusOne
  );
  assign c_iPlusOne = GPij[0] | (GPij[1] & cj);
endmodule

module SUMbit (
    input logic Ai, Bi, Cin,
    output logic Si
  );

  assign Si = Ai ^ Bi ^ Cin;
endmodule

module PPA16Bit (
    input logic [15:0] a, b,
    input logic C0,
    output logic [15:0] sum,
    output logic cout, OF
  );

  logic [15:0] [1:0] GPii;
  logic [15:0] [1:0] gpi_0;
  logic [14:0] [1:0] GPiPlus1_i;
  logic [12:0] [1:0] GPiPlus3_i;
  logic [8:0]  [1:0] GPiPlus7_i;

  logic [16:0] ci; // 15 ci + carry out

  assign ci[0] = C0;

  // Instantiate GPbit modules using a loop
  genvar i;
  generate
    for (i = 0; i < 16; i = i + 1)
    begin : gpbit_instances
      GPbit gpbit_inst (
              .Ai(a[i]),
              .Bi(b[i]),
              .GPii(GPii[i])
            );
    end
  endgenerate

  // Instantiate GPblk modules level 1
  assign gpi_0[0] = GPii[0];
  assign gpi_0[1] = GPiPlus1_i[0];

  generate
    for (i = 0; i < 15; i = i + 1)
    begin : gpblk_2_instances
      GPblk blk_inst (
              .GPik(GPii[i+1]),
              .GPkj(GPii[i]),
              .GPij(GPiPlus1_i[i])
            );
    end
  endgenerate

  // Instantiate GPblk modules level 2
  GPblk blk_20 (GPiPlus1_i[1], GPii[0], gpi_0[2]);
  assign gpi_0[3] = GPiPlus3_i[0];

  generate
    for (i = 0; i < 13; i = i + 1)
    begin : gpblk_4_instances
      GPblk blk_inst (
              .GPik(GPiPlus1_i[i+2]),
              .GPkj(GPiPlus1_i[i]),
              .GPij(GPiPlus3_i[i])
            );
    end
  endgenerate

  // Instantiate GPblk modules level 3
  GPblk blk_40 (GPiPlus3_i[1], GPii[0], gpi_0[4]);
  GPblk blk_50 (GPiPlus3_i[2], gpi_0[1], gpi_0[5]);
  GPblk blk_60 (GPiPlus3_i[3], gpi_0[2], gpi_0[6]);
  assign gpi_0[7] = GPiPlus7_i[0];

  generate
    for (i = 0; i < 9; i = i + 1)
    begin : gpblk_8_instances
      GPblk blk_inst (
              .GPik(GPiPlus3_i[i+4]),
              .GPkj(GPiPlus3_i[i]),
              .GPij(GPiPlus7_i[i])
            );
    end
  endgenerate

  // Instantiate GPblk modules level 4
  generate
    for (i = 0; i < 8; i = i + 1)
    begin : gpblk_i0_instances
      GPblk blk_inst (
              .GPik(GPiPlus7_i[i+1]),
              .GPkj(gpi_0[i]),
              .GPij(gpi_0[i+8])
            );
    end
  endgenerate

  // Instantiate all Carry Bits modules
  generate
    for (i = 0; i < 16; i = i + 1)
    begin : carryBit_instances
      CarryBit cout (
                 .GPij(gpi_0[i]),
                 .cj(C0),
                 .c_iPlusOne(ci[i+1])
               );
    end
  endgenerate

  // Instantiate SUMbit modules using a loop
  genvar k;
  generate
    for (k = 0; k < 16; k = k + 1)
    begin : sumbit_instances
      SUMbit sb_inst (
               .Ai(a[k]),
               .Bi(b[k]),
               .Cin(ci[k]),
               .Si(sum[k])
             );
    end
  endgenerate

  // Determine cout/OF
  assign cout = ci[16];
  assign OF = ci[16] ^ ci[15];


endmodule

module adderModule(
    input logic [31:0] A, B,
    input logic Cin,
    output logic [31:0] Sum,
    output logic OF, cout2
  );
  logic foo, cout1, cin2;

  PPA16Bit adderLower(A[15:0], B[15:0], Cin, Sum[15:0], cout1, foo);

  assign cin2 = cout1;

  PPA16Bit adderUpper(A[31:16], B[31:16], cin2, Sum[31:16], cout2, OF);

endmodule
