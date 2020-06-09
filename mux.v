module mux16bit(output[15:0] out, input[15:0] i0, input[15:0] i1, input sel);
	assign out = sel ? i1 : i0;
endmodule
