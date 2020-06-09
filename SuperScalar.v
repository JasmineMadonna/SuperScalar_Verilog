`include "PipelineRegisters.v"
`include "fetch.v"
//`include "execute.v"
`include "decode.v"
`include "mem.v"
`include "executionCore.v"
`include "ControlUnit.v"
`include "functionalUnits.v"

module SuperScalarProcessor(input clk, input rst);
	parameter PC_WIDTH = 16, DATA_WIDTH = 16;
	parameter INSTR_WIDTH = 32;
	parameter MEM_SIZE = 1024; //2^10

	//wire PCSrcTmp;
	reg IFFlush, flush;
	wire PCSrc, nextPC_sel_f, nextPC_sel_IFID, nextPC_sel_dis, nextPC_sel_RSB;
	wire[PC_WIDTH-1:0] NPC, PCplus2, PCplus2Out, PCOut, PCplus2Out_dis, PCOut_RSB, branchAddress;
	reg [PC_WIDTH-1:0] PC, branchTarget;
	wire[INSTR_WIDTH-1:0] instr1, instr1Out, instr2, instr2Out;
	
	always@(rst or NPC)
	begin
		if(rst)
		begin
			PC = 16'b0000000000000000;
			$display($time, "PC = %d", PC);
		end
		else
			PC = NPC;
	end
	initial
	begin
		//PCSrc = 0;
		flush = 0;
		IFFlush = 0;
		PCWrite = 1;
		IFIDWrite = 1;
		dispatchWrite = 1;
	end
	
	/*-------------------Fetch--------------------------*/

	reg PCWrite, IFIDWrite, dispatchWrite;
	PCReg reg0(PCOut, PC, clk, rst, PCWrite);

	Fetch f(nextPC_sel_f, NPC, PCplus2, instr1, instr2, (PCSrc || ctrl1[1] || ctrl2[1]), PCOut, branchTarget, PCOut_RSB, ctrl1[0] | ctrl2[0], PCWrite);
	IFIDReg reg1(PCplus2Out, instr1Out, instr2Out, nextPC_sel_IFID, PCplus2, instr1, instr2, nextPC_sel_f, clk, IFIDWrite, (flush || ctrl1[1] || ctrl2[1]));

	/******************************* Decode ********************************/

	wire [20 : 0] readData1, readData2, readData3, readData4;
	wire [15 : 0] dataRs1, dataRt1, dataRs2, dataRt2, imm1, imm2, imm1out, imm2out;
	wire [3:0] rstag1, rstag2, rstag3, rstag4;
	wire [4:0] rs1, rt1, rs2, rt2, rd1, rd2;
	wire [4:0] destBT1, destBT2;
	wire [5:0] ctrl1, ctrl2;
	reg [1:0] regWrite, memWrite;
	reg [15:0] regWData1, regWData2;
	wire [2:0] func1, func2, func1out, func2out;
	reg W;
	always@(posedge clk)
		#1 W = 1;

	always@(negedge clk)
		#1 W = 0;

	decode dec(rs1, rt1, rd1, rs2, rt2, rd2, imm1, imm2, ctrl1, ctrl2, func1, func2, spec1, spec2, instr1Out, instr2Out);
	RegisterFile rf(read, readData1, readData2, readData3, readData4, 1'b1, regWrite, rs1, rt1, rs2, rt2, destReg1, destReg2, regWData1, regWData2, ctrl1[0] | ctrl2[0], W, 1'b1, 1'b1, robIndex1, robIndex2, destBT1, destBT2);

	SourceRead srcRead1(dataRs1, rstag1, readData1[16:0], robdata1[23:7], robtag1, read);
	SourceRead srcRead2(dataRt1, rstag2, readData2[16:0], robdata2[23:7], robtag2, read);
	SourceRead srcRead3(dataRs2, rstag3, readData3[16:0], robdata3[23:7], robtag3, read);
	SourceRead srcRead4(dataRt2, rstag4, readData4[16:0], robdata4[23:7], robtag4, read);

	mux5bit mux1(destBT1, rt1, rd1, ctrl1[3]);
	mux5bit mux2(destBT2, rt2, rd2, ctrl2[3]);

	FindType ft1(type1, ctrl1);
	FindType ft2(type2, ctrl2);

	always@(ctrl1[1] or ctrl2[1])
	begin
		if(ctrl1[1])
			branchTarget = imm1;
		else if(ctrl2[1])
			branchTarget = imm2;
		else
			branchTarget = branchAddress;			
	end

	wire [15 : 0] dataRs1out, dataRt1out, dataRs2out, dataRt2out;
	wire [3:0] rstag1out, rstag2out, rstag3out, rstag4out;
	wire [5:0] ctrl1out, ctrl2out;
	reg [1:0] load_I, load_LS, load_M, load_B;
	wire stall, stall_I, stall_LS, stall_B, stall_M, stall_ROB, LorSout_LS, spec1, spec2;
	wire [3:0] robDest1out, robDest2out;
	
	DispatchBuffer dispatch_buf(rstag1out, rstag2out, rstag3out, rstag4out, dataRs1out, dataRt1out, dataRs2out, dataRt2out, imm1out, imm2out, ctrl1out, ctrl2out, 
 robDest1out, robDest2out, func1out, func2out, spec1out, spec2out, PCplus2Out_dis, nextPC_sel_dis, rstag1, rstag2, rstag3, rstag4, dataRs1, dataRt1, dataRs2, dataRt2, 
imm1, imm2, ctrl1, ctrl2, robIndex1, robIndex2, func1, func2, spec1, spec2, PCplus2Out, nextPC_sel_IFID, clk, flush, dispatchWrite);

	always@(ctrl1out or func1out)
	begin
		if(ctrl1out[5] == 1 || ctrl1out[4] == 1)
		begin
			load_LS[0] = 1;
			LorS1 = ctrl1out[4];
			load_I[0] = 0;
			load_M[0] = 0;
			load_B[0] = 0;
		end
		else if(ctrl1out[3]) // r type instr
		begin
			load_LS[0] = 0;
			load_I[0] = ~func1out[2];
			load_M[0] = func1out[2];
			load_B[0] = 0;
		end
		else if(ctrl1out[2])
		begin
			load_LS[0] = 0;
			load_I[0] = 0;
			load_M[0] = 0;
			load_B[0] = 1;
		end
		else if(ctrl1out[0])
		begin
			load_LS= 2'b0;
			load_I = 2'b0;
			load_M = 2'b0;
			load_B = 2'b0;
		end
		else
		begin
			load_LS[0] = 0;
			load_I[0] = 0;
			load_M[0] = 0;
			load_B[0] = 0;
		end
	end

	always@(ctrl2out or func2out)
	begin
		if(ctrl2out[5] == 1 || ctrl2out[4] == 1)
		begin
			load_LS[1] = 1;
			LorS2 = ctrl2out[4];
			load_I[1] = 0;
			load_M[1] = 0;
			load_B[1] = 0;
		end
		else if(ctrl2out[3] == 1)
		begin
			load_LS[1] = 0;
			load_I[1] = ~func2out[2];
			load_M[1] = func2out[2];
			load_B[1] = 0;
		end
		else if(ctrl2out[2])
		begin
			load_LS[1] = 0;
			load_I[1] = 0;
			load_M[1] = 0;
			load_B[1] = 1;
		end
		else 
		begin
			load_LS[1] = 0;
			load_I[1] = 0;
			load_M[1] = 0;
			load_B[1] = 0;
		end
	end

	wire [15:0] rsout_I, rtout_I, rsout_M, rtout_M, rsout_LS, rtout_LS, immOut_LS, rsout_B, rtout_B, immOut_B;
	wire [3:0] robTagOut_I, robTagOut_M, robTagOut_LS, robTagOut_B;
	wire [41:0] CDBData; //valid2 + tag2 + data2 + valid1 + tag1 + data1
	reg CDBBusy, LorS1, LorS2;
	wire issued_I, issued_LS, issued_M, issued_B;
	
	ReservationStationInt RS_Int(stall_I, issued_I, entryTCout_I, robTagOut_I, rsout_I, rtout_I, aluOp, dataRs1out, dataRt1out, dataRs2out, dataRt2out, rstag1out, rstag2out, rstag3out, rstag4out, func1out[1:0], func2out[1:0], spec1out, spec2out, robDest1out, robDest2out, load_I, clk, CDBData, entryTCin_I, clearRSEntry[0], flush);
	
	ReservationStation RS_mul(stall_M, issued_M, robTagOut_M, rsout_M, rtout_M, dataRs1out, dataRt1out, dataRs2out, dataRt2out, rstag1out, rstag2out, rstag3out, rstag4out, spec1out, spec2out, robDest1out, robDest2out, load_M, clk, CDBData, clearRSEntry[2], flush);
	
	ReservationStationLS RS_ls(stall_LS, issued_LS, entryTCout_LS, robTagOut_LS, rsout_LS, rtout_LS, immOut_LS, LorSout_LS, dataRs1out, dataRt1out, dataRs2out, dataRt2out, rstag1out, rstag2out, rstag3out, rstag4out, imm1out, imm2out, spec1out, spec2out, robDest1out, robDest2out, load_LS, LorS1, LorS2, clk, CDBData, entryTCin_LS, clearRSEntry[1], flush);

	ReservationStation_Branch RS_B(stall_B, issued_B, robTagOut_B, rsout_B, rtout_B, immOut_B, PCOut_RSB, dataRs1out, dataRt1out, dataRs2out, dataRt2out, rstag1out, rstag2out, rstag3out, rstag4out, imm1out, imm2out, spec1out, spec2out, nextPC_sel_RSB, PCplus2Out_dis, robDest1out, robDest2out, load_B, nextPC_sel_dis, clk, CDBData, flush);

	wire [20:0] int_out, mul_out;
	wire [1:0] aluOp, entryTCin_I, entryTCout_I, entryTCin_LS, entryTCout_LS;
	wire [15:0] LSData, LS_out, loadData;
	wire [2:0] clearRSEntry;

	//Functional Units
	IntegerFU IFU(int_out, rsout_I, rtout_I, aluOp, robTagOut_I, issued_I);
	multiply mul(mul_out, rsout_M[7:0], rtout_M[7:0], robTagOut_M, issued_M);
	LoadStore LS(LS_out, rsout_LS, immOut_LS);
	BranchUnit BU(PCSrc, branchAddress, rsout_B, rtout_B, PCOut_RSB, immOut_B, issued_B);

	always@(issued_B or PCSrc)
	begin
		if(issued_B && PCSrc)
			flush = 1;
		else
			flush = 0;
	end
	
	StoreDataBuffer sdb(sdbFull, sdReady, strData1, strData2, strdIndex, strIndex1, strIndex2, LS_out, rtout_LS, (~LorSout_LS && issued_LS));
	DataMemory dm(loadData, LS_out, LorSout_LS, memWrite, strData1[15:0], strData2[15:0], strData1[31:16], strData2[31:16], hlt);

	assign LSData = LorSout_LS ? loadData : {13'b0, strdIndex};
	
	ExecuteBuffer EX_buf(CDBData, clearRSEntry, entryTCin_I, entryTCin_LS, int_out, mul_out, {issued_LS, robTagOut_LS, LSData}, entryTCout_I, entryTCout_LS, clk);

	wire [3:0] robtag1, robtag2, robtag3, robtag4, robIndex1, robIndex2; //this width is subject to change 
	wire [27:0] robdata1, robdata2, robdata3, robdata4;
	wire [1:0] type1, type2;
	wire [20:0] wbData1, wbData2; //includes both dest addr and data
	wire [1:0] wbType1, wbType2;
	wire [3:0] wIndex1, wIndex2;
	wire [15:0] wData1, wData2;
	wire correction;
	
	assign correction = ~(PCSrc^nextPC_sel_RSB);

	assign robtag1 = readData1[20:17];
	assign robtag2 = readData2[20:17];
	assign robtag3 = readData3[20:17];
	assign robtag4 = readData4[20:17];

	ReOrderBuffer1 rob(stall_ROB, wbData1, wbData2, wbType1, wbType2, robIndex1, robIndex2, robdata1, robdata2, robdata3, robdata4, robtag1, robtag2, robtag3, robtag4, spec1, spec2, type1, type2, destBT1, destBT2, clk, CDBData[19:16], CDBData[40:37], CDBData[15:0], CDBData[36:21], robTagOut_B, correction, flush);

	reg [2:0] strIndex1, strIndex2;
	reg [4:0] destReg1, destReg2;
	wire [31:0] strData1, strData2;
	wire [2:0] strdIndex;
	wire [1:0] sdReady;
	wire sdbFull;
	
	always@(wbType1 or wbData1)
	begin
		if(wbType1 == 2'b00)
		begin
			destReg1 = wbData1[4:0];
			regWData1 = wbData1[20:5];
			regWrite[0] = 1'b1;
			memWrite[0] = 1'b0;
		end
		else if(wbType1 == 2'b01)
		begin
			regWrite[0] = 1'b0;
			memWrite[0] = 1'b1;
			strIndex1 = wbData1[7:5];
		end
		else
		begin
			regWrite[0] = 1'b0;
			memWrite[0] = 1'b0;
		end
	end

	always@(wbType2 or wbData2)
	begin
		if(wbType2 == 2'b00)
		begin
			destReg2 = wbData2[4:0];
			regWData2 = wbData2[20:5];
			regWrite[1] = 1'b1;
			memWrite[1] = 1'b0;
		end
		else if(wbType2 == 2'b01)
		begin
			regWrite[1] = 1'b0;
			memWrite[1] = 1'b1;
			strIndex2 = wbData2[7:5];
		end
		else
		begin
			regWrite[1] = 1'b0;
			memWrite[1] = 1'b0;
		end
	end

	always@(stall_I or stall_LS or stall_B or stall_M or stall_ROB)
	begin
		if(stall_I || stall_LS || stall_B || stall_M || stall_ROB)
		begin
			IFIDWrite = 0;
			dispatchWrite = 0;
			PCWrite = 0;
		end
		else
		begin 
			IFIDWrite = 1;
			dispatchWrite = 1;
			PCWrite = 1;
		end
	end

	always@(CDBData)
		$display($time, " Super : CDBData : data1 = %d, tag1 = %d, data2 = %d, tag2 = %d", CDBData[15:0], CDBData[19:16], CDBData[36:21], CDBData[40:37]);

endmodule

module test;
	reg clk;
	reg rst;
	initial
	begin
		clk = 0;
		rst = 1;
		#5 rst = 0;
	end
	always
		#5 clk = ~clk;
	SuperScalarProcessor processor(clk, rst);

	//initial
	//begin
		//$monitor($time,"NPC = %b      instr = %b",NPC, instr);
	//end

	initial
	begin
		$dumpfile("/home/jasmine/Jan-May2012/CALab/SuperScalar/processor.vcd");
		$dumpon;
		$dumpvars;
		#200 $finish;
		#200 $dumpoff;
	end
	
endmodule

