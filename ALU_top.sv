module Mux4_1 (
	input logic [31:0] out0, out1, out2, out3,
	input logic [1:0] F,
	output logic [31:0] Y
);
	always_comb
	begin
		case (F) 
			2'b00: Y = out0;
			2'b01: Y = out1;
			2'b10: Y = out2;
			2'b11: Y = out3;
		endcase
	end
endmodule

module OR_module (
	input logic [31:0] A, B,
	output logic [31:0] Y
);

	assign Y = A | B;
endmodule

module AND_module (
	input logic [31:0] A, B,
	output logic [31:0] Y
);

	assign Y = A & B;
endmodule

module NOR_32_1 (
	input logic [31:0] Y,
	output logic out
);
	assign out = ~|Y;
endmodule


module ALU (
	input logic [31:0] A, B, 
	input logic [2:0] F,
	input logic uns,    //unsigned subtraction for LT
	output logic [31:0] Y,
	output logic zero, OF
);

	logic [31:0] srcA, srcB;
	logic [31:0] outAND, outOR, outSum;
	logic [31:0] outSpecial, outPM, outLT;
	logic        choose_LT;
	logic        cout;   //use cout of adder to simulate uns. subtraction
			     //by doing 33 bit signed sub where 33rd bit always 0

	assign srcA = A;
	assign srcB = F[2] ? ~B : B;
	assign choose_LT = uns ? ~cout : outSum[31] ^ OF;

	AND_module ANDmod (srcA, srcB, outAND);
	OR_module ORmod (srcA, srcB, outOR);
	
	adderModule adder (srcA, srcB, F[2], outSum, OF, cout);

	
	
	assign outLT = {{31{1'b0}}, choose_LT};
	PatMatch matchUnit (A, B, outPM);
	assign outSpecial = F[2] ? outLT : outPM;

	Mux4_1 mux (outAND, outOR, outSum, outSpecial, F[1:0], Y);

	NOR_32_1 norY (Y, zero);
endmodule
