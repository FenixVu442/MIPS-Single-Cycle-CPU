// files needed for simulation:
//  mipsttest.sv   mipstop.sv, mipsmem.sv,  mips.sv,  mipsparts.sv

// single-cycle MIPS processor
module mips(input  logic        clk, reset,
              output logic [31:0] pc,
              input  logic [31:0] instr,
              output logic        memwrite,
              output logic [31:0] aluout, writedata,
              input  logic [31:0] readdata);

  logic        memtoreg, branch,
               pcsrc, zero,
               alusrc, regdst, regwrite, jump, swap, uns;
  // swap: swap ScrA and SrcB, for doing GT as opposed to LT
  // uns: indicator for sltu
  logic [2:0]  alucontrol;

  controller c(instr[31:26], instr[5:0], zero, aluout[0], // aluout[0]: blt
               memtoreg, memwrite, pcsrc,
               alusrc, regdst, regwrite, jump, swap,
               alucontrol, uns); // controller modifications updated
  datapath dp(clk, reset, memtoreg, pcsrc,
              alusrc, regdst, regwrite, jump,
              uns, swap, // datapath modifications updated
              alucontrol,
              zero, pc, instr,
              aluout, writedata, readdata);
endmodule

module controller(input  logic [5:0] op, funct,
                    input  logic       zero, slt_result, // aluout[0]: blt
                    output logic       memtoreg, memwrite,
                    output logic       pcsrc, alusrc,
                    output logic       regdst, regwrite,
                    output logic       jump,
                    output logic       swap, // added
                    output logic [2:0] alucontrol, // added
                    output logic       uns // added
                   );

  logic [1:0] aluop;
  logic [1:0] eq_comp; // eq_comp[1]: pick type of comp.
  // eq_comp[0]: comp or !comp
  logic       branch;
  logic       comp_res;    //Which result to use (zero or less than)
  logic       inv_comp;    //Do we want to invert it (= vs !=, > vs <= etc.)

  maindec md(op, memtoreg, memwrite, branch,
             alusrc, regdst, regwrite, jump,
             aluop, eq_comp, swap); // main decoder updated
  aludec  ad(funct, aluop, alucontrol, uns); // alu decoded updated

  assign comp_res = eq_comp[1] ? slt_result : zero; // {bne, beq} or {blt}
  assign inv_comp = eq_comp[0] ^ comp_res;  //XOR instead of mux, as we're just enabeling not

  assign pcsrc = branch & inv_comp; // updated zero->inv_comp
endmodule

module maindec(input  logic [5:0] op,
                 output logic       memtoreg, memwrite,
                 output logic       branch, alusrc,
                 output logic       regdst, regwrite,
                 output logic       jump,
                 output logic [1:0] aluop,
                 output logic [1:0] eq_comp,   //what to use for branch comparison
                 output logic       swap       //swaps a and b input, so we can do > as <
                );

  logic [12:0] controls; // controls from 8bit -> 12bit

  assign {regwrite, regdst, alusrc,
          branch, memwrite,
          memtoreg, jump, aluop, eq_comp, swap} = controls;

  always_comb
  case(op)
    6'b000000:
      controls = 12'b110000010000; //Rtype
    6'b100011:
      controls = 12'b101001000000; //LW
    6'b101011:
      controls = 12'b001010000000; //SW
    6'b000100:
      controls = 12'b000100001000; //BEQ
    6'b001000:
      controls = 12'b101000000000; //ADDI
    6'b000010:
      controls = 12'b000000100000; //J

    6'b000101:
      controls = 12'b000100001010; //BNE
    6'b001010:
      controls = 12'b101000011000; //SLTI
    6'b000110:
      controls = 12'b000100011111; //BLE (chose op 6 to follow beq/bne)
    default:
      controls = 12'bxxxxxxxxxxxx; //???
  endcase
endmodule

module aludec(input  logic [5:0] funct,
                input  logic [1:0] aluop,
                output logic [2:0] alucontrol,
                output logic       uns // aludec updated
               );

  logic [3:0] controls; // aludec updated

  assign {alucontrol, uns} = controls; // aludec updated

  always_comb
  case(aluop)
    2'b00:
      controls = 4'b0100;  // add
    2'b01:
      controls = 4'b1100;  // sub
    2'b11:
      controls = 4'b1110;  // SLT for SLTI
    default:
    case(funct)          // RTYPE
      6'b100000:
        controls = 4'b0100; // ADD
      6'b100010:
        controls = 4'b1100; // SUB
      6'b100100:
        controls = 4'b0000; // AND
      6'b100101:
        controls = 4'b0010; // OR
      6'b101010:
        controls = 4'b1110; // SLT
      6'b101011:
        controls = 4'b1111; // SLTU
      default:
        controls = 4'bxxxx; // ???
    endcase
  endcase
endmodule

module datapath(input  logic        clk, reset,
                  input  logic        memtoreg, pcsrc,
                  input  logic        alusrc, regdst,
                  input  logic        regwrite, jump,
                  input  logic        uns, swap, //added functionalities
                  input  logic [2:0]  alucontrol,
                  output logic        zero,
                  output logic [31:0] pc,
                  input  logic [31:0] instr,
                  output logic [31:0] aluout, writedata,
                  input  logic [31:0] readdata);

  logic [4:0]  writereg;
  logic [31:0] pcnext, pcnextbr, pcplus4, pcbranch;
  logic [31:0] signimm, signimmsh;
  logic [31:0] srca, srcb;
  logic [31:0] result;

  // next PC logic
  flopr #(32) pcreg(clk, reset, pcnext, pc);
  adder       pcadd1(pc, 32'b100, pcplus4);
  sl2         immsh(signimm, signimmsh);
  adder       pcadd2(pcplus4, signimmsh, pcbranch);
  mux2 #(32)  pcbrmux(pcplus4, pcbranch, pcsrc, pcnextbr);
  mux2 #(32)  pcmux(pcnextbr, {pcplus4[31:28], instr[25:0], 2'b00},
                    jump, pcnext);

  //Swap logic for reg
  logic [4:0] addr1, addr2;
  assign addr1 = swap ? instr[20:16] : instr[25:21];
  assign addr2 = swap ? instr[25:21] : instr[20:16];

  // register file logic
  regfile     rf(clk, regwrite, addr1, //regfile param updated
                 addr2, writereg,
                 result, srca, writedata);
  mux2 #(5)   wrmux(instr[20:16], instr[15:11], regdst, writereg);
  mux2 #(32)  resmux(aluout, readdata, memtoreg, result);
  signext     se(instr[15:0], signimm);

  // ALU logic
  mux2 #(32)  srcbmux(writedata, signimm, alusrc, srcb);
  ALU         alu(.A(srca), .B(srcb), .F(alucontrol), .uns(uns), .Y(aluout), .zero(zero));
endmodule

