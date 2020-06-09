//instruction memory is byte addressable of size 1KB. big endian
`include "mux.v"
`include "BranchPrediction.v"

module InstructionMemory(instr1, instr2, PC, en);
	input [15:0] PC;
	input en;
	output reg [31:0] instr1, instr2;

	reg[31:0] instructions [0:1023];

	always@(PC)
	begin
		if(en)
		begin
			instr1[31:0] <= instructions[PC];
			instr2[31:0] <= instructions[PC + 1];
		end
	end
	
	initial
	begin
		$readmemh("dataDep.dat", instructions);
	end
endmodule

module Fetch(nextPC_sel, NPC, nxtPC, instr1, instr2, PCSrc, PC, branchTarget, wBIA, hlt, PCWrite);
	parameter PC_WIDTH = 16;
	
	input PCSrc, hlt, PCWrite;
	input[PC_WIDTH-1:0] PC, branchTarget, wBIA;

	output[31:0] instr1, instr2;
	output[PC_WIDTH-1:0] NPC;
	output reg [PC_WIDTH-1:0] nxtPC;

	reg en = 0;
	initial
		en = 1;

	always@(*)
	begin
		if(hlt)
		begin
			en = 0;
			nxtPC = PC;
		end
		else if(PCWrite)
		begin
			nxtPC = PC + 2;
			en = 1;
		end
		else if(~PCWrite)
		begin
			nxtPC = PC;
			en = 0;
		end	
	end	
	//always@(PCSrc)
		//$display($time, "PCSrc = %d", PCSrc);
	InstructionMemory im(instr1, instr2, PC, en);
	mux16bit mux(NPC, nxtPC, target, nextPC_sel);

	wire prediction;
	output reg nextPC_sel;
	wire [15:0] predictedTarget;
	reg [15:0] target;

	initial
		nextPC_sel = 0;

	always@(branchTarget or predictedTarget or hit)
	begin
		if(PCSrc)
		begin
			target = branchTarget;
			nextPC_sel = PCSrc;
		end
		else
		begin
			target = predictedTarget;
			if(hit)
				nextPC_sel = prediction;
			else
				nextPC_sel = 0;
		end
	end
	BranchTargetBuffer btb(predictedTarget, hit, prediction, PC, wBIA, branchTarget, PCSrc);
endmodule

/*module test_fetch;
	parameter PC_WIDTH = 16;
	reg[PC_WIDTH-1:0] PC, branchTarget;
	reg PCSrc;
	wire[31:0] instr;
	wire [PC_WIDTH-1:0] NPC, PCplus4;

	Fetch f(NPC, PCplus4, instr, PCSrc, PC, branchTarget);

	initial
	begin
		PC = 16'b0000000000000011; branchTarget = 16'b0000000000001011; PCSrc = 0;
		#20 PCSrc = 1; PC = 16'b0000000000000111;
		#20 PC = 16'b0000000000001011;
		#20 PC = 16'b0000000000001111;
		#20 PC = 16'b0000000000010011;
		#100 $finish;
	end

	initial
	begin
		$dumpfile("/home/jasmine/Jan-May2012/CALab/scalarProcessor/fetch.vcd");
		$dumpon;
		$dumpvars;
		#100 $dumpoff;
	end

	
endmodule*/


