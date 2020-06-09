module ControlUnit(sw, lw, r, branch, jmp, hlt, func, opcode, functCode);
	input [5:0] opcode;
	input [5:0] functCode;
	output reg sw, lw, r, branch, jmp, hlt;
	output reg [2:0] func; //1xx - mul, 000 - ADD, 001 - SUB, 010 - AND, 011 - OR

	parameter R = 6'b000000, LW = 6'b100011, SW = 6'b101011, BEQ = 6'b000100, HLT = 6'b111111, JMP = 6'b000010;
	parameter ADD = 6'b100000, SUB = 6'b100010, AND = 6'b100100, OR = 6'b100101, SLT = 6'b101010, MUL = 6'b100001;

	initial
		hlt = 0;
	
	always@(opcode or functCode)
	begin
	case(opcode)
		R : begin
			//$display($time, " ::::::::::::::::Control : inside OR func : %b", func);
			r = 1;
			sw = 0;
			lw = 0;
			branch = 0;
			jmp = 0;
			hlt = 0;
			if(functCode == ADD)
				func = 3'b000;
			else if(functCode == SUB)
				func = 3'b001;
			else if(functCode == AND) 
				func = 3'b010;
			else if(functCode == OR)
			begin
				func = 3'b011;
				//$display($time, " Control ::::::::::::::::: inside OR func : %b", func);
			end
			else if(functCode == MUL)
				func = 3'b100;
		end
		LW : begin
			r = 0;
			sw = 0;
			lw = 1;
			branch = 0;
			jmp = 0;
			hlt = 0;
		end
		SW : begin
			r = 0;
			sw = 1;
			lw = 0;
			branch = 0;
			jmp = 0;
			hlt = 0;
		end
		BEQ : begin
			r = 0;
			sw = 0;
			lw = 0;
			branch = 1;
			jmp = 0;
			hlt = 0;
		end
		JMP : begin
			r = 0;
			sw = 0;
			lw = 0;
			branch = 0;
			jmp = 1;
			hlt = 0;
		end
		HLT : begin
			r = 0;
			sw = 0;
			lw = 0;
			branch = 0;
			jmp = 0;
			hlt = 1;
		end
	endcase
	end
endmodule

/*module testCtrl;
	reg [5:0] opcode;
	wire regDst, aluSrc, branch, memRead, memWrite, regWrite, memToReg;
	wire [1:0] aluOp;

	ControlUnit c(regDst, aluOp, aluSrc, branch, memRead, memWrite, regWrite, memToReg, opcode);

	initial 
	begin
		opcode = 6'b000000;
		#20 opcode = 6'b100011;
		#20 opcode = 6'b101011;
		#20 opcode = 6'b000100;
		#100 $finish;
	end 

	initial
	begin
		$monitor($time,"aluOp = %b      regDst = %b",aluOp, regDst);
	end

	initial
	begin
		$dumpfile("/home/jasmine/Jan-May2012/CALab/processor/ctrl.vcd");
		$dumpon;
		$dumpvars;
		#100 $dumpoff;
	end	
endmodule*/
