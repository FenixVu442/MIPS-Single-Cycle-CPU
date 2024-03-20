module MatchUnit ( // check if A equals pattern B, with Don'tCare from decode
	input logic [3:0] A, B, decode,
	output logic Y
);
	logic [3:0] diff, x;

	assign diff = A ~^ B;
	
	genvar i;
	generate
		for (i = 0; i < 4; i = i + 1) begin : withDecode
			assign x[i] = diff[i] | decode[i];
		end
	endgenerate
	
	assign Y = &x; // x[0] & x[1] & x[2] & x[3];
endmodule


module EncoderControl ( // 2-4 Encoder with enable
	input logic [1:0] d,
	input logic enable,
	output logic [3:0] decode
);

	always_comb
	case ({enable, d})
		3'b100: decode = 4'b0001;
		3'b101: decode = 4'b0010;
		3'b110: decode = 4'b0100;
		3'b111: decode = 4'b1000;
		default: decode = 4'b0000;
	endcase
endmodule


module PatMatch (
	input logic [31:0] A, B,
	output logic [31:0] Y
);
	
	logic [3:0] d; // decode, eg. 0001
	logic [28:0] mapOfMatch;

	// Instantiate EncoderControl module
	EncoderControl encode(B[5:4], B[6], d);

	// Instantiate PatternMatch modules
	genvar i;
	generate
		for (i = 0; i < 29; i = i + 1) begin : checkMatch
			MatchUnit MU_inst (
				.A(A[i+3:i]),
				.B(B[3:0]),
				.decode(d),
				.Y(mapOfMatch[i])
			);
		end
	endgenerate
	
	// Concatenate mapOfMatch with 3'b000 to make Y
	assign Y = {3'b000, mapOfMatch};
endmodule

module top_module (
	input logic [31:0] A, B,
	output logic [31:0] Y
);
	PatMatch matchUnit (A, B, Y);
endmodule