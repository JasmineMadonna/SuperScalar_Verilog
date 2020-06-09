//`include "mux.v"

module execute(aluOut, writeData, regDst, rd, rt, immediate, readData2, readData1, regDstSel, aluOp, aluSrc, prevALURes, prevMEMRes, rs, rd_exmem, rd_memwb, regWrite_exmem, regWrite_memwb);
	input [4:0] rd, rt, rs, rd_exmem, rd_memwb;
	input [15:0] immediate, readData2, readData1, prevALURes, prevMEMRes;
	input regDstSel, aluSrc, regWrite_exmem, regWrite_memwb;
	input [1:0] aluOp;

	output [4:0] regDst;
	output [15:0] aluOut, writeData;

	wire [2:0] ctrl;
	wire [15:0] aluIp2;
	wire [1:0] forwardA, forwardB;
	wire [15:0] aluA, aluB;

	mux5bit mux1(regDst, rt, rd, regDstSel);
	aluCtrl ac(ctrl, aluOp, immediate[5:0]);
	//mux16bit mux2(aluIp2, readData2, immediate, aluSrc);
	mux16bit mux2(aluB, aluIp2, immediate, aluSrc);
	alu alu(aluA, aluB, ctrl, aluOut); 

	//always@(aluOut)
		//$display($time, "alu out = %d", aluOut);
	
	forwardingUnit fu(forwardA, forwardB, rs, rt, rd_exmem, rd_memwb, regWrite_exmem, regWrite_memwb);
	muxAluIp muxA(aluA, readData1, prevMEMRes, prevALURes, forwardA);
	//muxAluIp muxB(aluB, aluIp2, prevMEMRes, prevALURes, forwardB);
	muxAluIp muxB(aluIp2, readData2, prevMEMRes, prevALURes, forwardB);	
	
	//assign branchTarget = NPC + immediate;
	assign writeData = readData2;
	
endmodule

module mux5bit(output[4:0] out, input[4:0] i0, input[4:0] i1, input sel);
	assign out = sel ? i1 : i0;
endmodule

module aluCtrl(ctrl, aluOp, funct);
	output reg [2:0] ctrl;
	input[1:0] aluOp;
	input[5:0] funct;

	reg[5:0] f;
	parameter ADD = 6'b100000, SUB = 6'b100010, AND = 6'b100100, OR = 6'b100101, SLT = 6'b101010, MUL = 6'b100001;
	
	always@(aluOp or funct)
	begin
		case(aluOp)
			2'b00 :
			begin
				ctrl = 3'b010; //f = 6'bxxxxxx;
			end
			2'b01:
			begin
				ctrl = 3'b110; //f = 6'bxxxxxx;
			end
			2'b10 : f = funct;
			2'b11 : ctrl = 3'b011;
		endcase
	end

	always@(f)
	begin
		case(f)	
			ADD : ctrl = 3'b010;
			SUB : ctrl = 3'b110;
			AND : ctrl = 3'b000;
			OR : ctrl = 3'b001;
			SLT : ctrl = 3'b111;
			MUL : ctrl = 3'b100;
			default : ctrl = 3'b011;		
		endcase
	 end
endmodule

module alu(input[15:0] a, input[15:0] b, input[2:0] ctrl, output[15:0] out);
	reg [15:0]tempout;
	
	assign out = tempout;
	//assign zero = (tempout == 16'b0 && ctrl == 3'b110) ? 1 : 0;	
	
	initial
	begin
		tempout = 16'b0;
	end
	always@(a or b or ctrl)
	begin
          case (ctrl)
		3'b000 : tempout = a & b;
		3'b001 : tempout = a | b;
		3'b010 : tempout = a + b;
		3'b110 : tempout = a - b;
		3'b100 : tempout = a * b;
		3'b111 : 
		begin
		  if(a<=b)
			tempout = 16'b0000000000000001;
		  else
			tempout = 16'b0000000000000000;
		//$display($time, " +++++++++++++++++in slt a = %d  b = %d", a, b);
		end
		default : tempout = 16'b0;
	  endcase
	end 
endmodule

//forwardA- ctrl signal for selecting first alu operand
//forwardB- ctrl signal for selecting second alu operand
module forwardingUnit(forwardA, forwardB, rs, rt, rd_exmem, rd_memwb, regWrite_exmem, regWrite_memwb);
	input[4:0] rs, rt, rd_exmem, rd_memwb;
	input regWrite_exmem, regWrite_memwb;
	output reg [1:0] forwardA, forwardB;

	initial
	begin
		forwardA = 2'b00;
		forwardB = 2'b00;
	end
	
	always@(rs or rt)
	begin
		if(regWrite_exmem && rd_exmem != 0 )
		begin
			if(rs == rd_exmem && rt == rd_exmem)
			begin
				forwardA <= 2'b10;
				forwardB <= 2'b10;
			end
			else if(rt == rd_exmem)
			begin
				forwardA <= 2'b00;
				forwardB <= 2'b10;
				//$display($time, " ----------forwardB = %b", forwardB);
			end
			else if(rs == rd_exmem)
			begin
				forwardA <= 2'b10;
				forwardB <= 2'b00;
			end
			/*else
			begin
				forwardA <= 2'b00;
				forwardB <= 2'b00;
			end*/	
		end 
		if(regWrite_memwb && rd_memwb != 0)
		begin
			if(rs == rd_memwb && rt == rd_memwb)
			begin
				forwardA = 2'b01;
				forwardB = 2'b01;
			end
			else if(rt == rd_memwb)
			begin
				forwardB = 2'b01;
				forwardA = 2'b00;
			end
			else if(rs == rd_memwb)
			begin
				forwardB = 2'b00;
				forwardA = 2'b01;
			end
			else
			begin
				forwardA = 2'b00;
				forwardB = 2'b00;
			end
		end
		else
		begin
			forwardA = 2'b00;
			forwardB = 2'b00;
		end
		//$display($time, " ----------forwardB = %b", forwardB);
	end
endmodule

module muxAluIp(out, i0, i1, i2, sel);
	output reg [15:0] out;
	input[15:0] i0, i1, i2;
	input[1:0] sel;
	always@(*)
	begin
		case(sel)
		2'b00 : out = i0;
		2'b01 : out = i1;
		2'b10 : out = i2;
		endcase
	end
endmodule

