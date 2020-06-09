//CDB - tag + data
/*module ArithmeticFU(CDBout, a, b, ctrl, destTag, issued);
	input [15:0] a, b;
	input ctrl, issued;
	input [3:0] destTag;
	output [20:0] CDBout;
	reg [15:0] out;

	assign CDBout = {issued, destTag, out};

	always@(*)
	begin
		if(ctrl)
			out = a + b;
		else
			out = a - b;
	end
endmodule

module LogicalFU(CDBout, a, b, ctrl, destTag);
	input [15:0] a, b;
	input ctrl;
	input [3:0] destTag;
	output [19:0] CDBout;
	reg [15:0] out;

	assign CDBout = {destTag, out};

	always@(*)
	begin
		if(ctrl)
			out = a & b;
		else
			out = a | b;
	end
endmodule*/

module IntegerFU(CDBout, a, b, ctrl, destTag, issued);
	input [15:0] a, b;
	input [1:0] ctrl;
	input [3:0] destTag;
	input issued;
	output [20:0] CDBout;
	reg [15:0] out;

	assign CDBout = {issued, destTag, out};
	always@(*)
	begin
		case(ctrl)
			2'b00: out = a + b;
			2'b01: out = a - b;
			2'b10: out = a & b;
			2'b11: out = a | b;
		endcase
	end
endmodule

module multiply(CDBout, a, b, destTag, issued);
	input [7:0] a, b;
	input issued;
	input [3:0] destTag;
	output [20:0] CDBout;
	wire [15:0] tmp;
	assign tmp = a*b;
	assign #40 CDBout = {issued, destTag, tmp};
endmodule

module LoadStore(out, a, b);
	input [15:0] a, b;
	output [15:0] out;
	assign out = a + b;
endmodule

module BranchUnit(PCSrc, branchTarget, a, b, PC, imm, issued);
	input [15:0] a, b, PC, imm;
	input issued;
	output PCSrc;
	output [15:0] branchTarget;
	assign PCSrc = (issued && a == b) ? 1'b1 : 1'b0;
	assign branchTarget = PCSrc ? PC + imm : PC;
endmodule

module mux5bit(output[4:0] out, input[4:0] i0, input[4:0] i1, input sel);
	assign out = sel ? i1 : i0;
endmodule
