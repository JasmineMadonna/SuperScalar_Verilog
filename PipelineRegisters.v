module PCReg(PCOut, PCIn, clk, rst, PCWrite);
	input [15:0] PCIn;
	output reg [15:0] PCOut;
	input clk, rst, PCWrite;
	always@(posedge clk or PCWrite)
	begin
	if(rst)
		PCOut <= 16'b0000000000000000;
	else if(PCWrite)
		PCOut <= PCIn;
	end

endmodule

module IFIDReg(PCplus4Out, instrOut1, instrOut2, nextPC_selOut, PCplus4In, instrIn1, instrIn2, nextPC_selIn, clk, IFIDWrite, IFFlush);
	input[15:0] PCplus4In;
	input[31:0] instrIn1, instrIn2;
	input clk, IFIDWrite, IFFlush, nextPC_selIn;

	output reg [15:0] PCplus4Out;
	output reg [31:0] instrOut1, instrOut2;
	output reg nextPC_selOut;

	//reg[15:0] PCplus4Out;
	//reg[31:0] instrOut;

	always@(posedge clk)
	begin
	if(IFIDWrite)
	begin
		if(IFFlush)
		begin
			instrOut1 <= 32'b0;
			instrOut2 <= 32'b0;
		end
		else
		begin
			instrOut1 <= instrIn1;
			instrOut2 <= instrIn2;
		end
		PCplus4Out <= PCplus4In;
		nextPC_selOut <= nextPC_selIn;
	end	
	end
endmodule

module DispatchBuffer(rstag1out, rstag2out, rstag3out, rstag4out, dataRs1out, dataRt1out, dataRs2out, dataRt2out, imm1out, imm2out, ctrl1out, ctrl2out, robDest1out, robDest2out, func1out, func2out, spec1out, spec2out, PCplus2out, nextPC_selOut, rstag1in, rstag2in, rstag3in, rstag4in, dataRs1in, dataRt1in, dataRs2in, dataRt2in, imm1in, imm2in, ctrl1in, ctrl2in, robDest1in, robDest2in, func1, func2, spec1in, spec2in, PCplus2in, nextPC_selIn, clk, flush, dispatchWrite);

	input [3:0] rstag1in, rstag2in, rstag3in, rstag4in;
	input [15:0] dataRs1in, dataRt1in, dataRs2in, dataRt2in, imm1in, imm2in, PCplus2in;
	input [5:0] ctrl1in, ctrl2in;
	input [3:0] robDest1in, robDest2in;
	input [2:0] func1, func2;
	input clk, spec1in, spec2in, flush, nextPC_selIn, dispatchWrite;
	
	output reg [3:0] rstag1out, rstag2out, rstag3out, rstag4out;
	output reg [15:0] dataRs1out, dataRt1out, dataRs2out, dataRt2out, imm1out, imm2out, PCplus2out;
	output reg [5:0] ctrl1out, ctrl2out;
	output reg [3:0] robDest1out, robDest2out;
	output reg [2:0] func1out, func2out;
	output reg spec1out, spec2out, nextPC_selOut;

	always@(posedge clk)
	begin
		if(dispatchWrite)
		begin
			if(flush)
			begin
				rstag1out <= 4'b0;
				rstag2out <= 4'b0;
				rstag3out <= 4'b0;
				rstag4out <= 4'b0;
		
				dataRs1out <= 16'b0;
				dataRt1out <= 16'b0;
				dataRs2out <= 16'b0;
				dataRt2out <= 16'b0;

				imm1out <= 16'b0;
				imm2out <= 16'b0; 

				ctrl1out <= 6'b0;
				ctrl2out <= 6'b0;

				robDest1out <= 4'b0;
				robDest2out <= 4'b0;

				func1out <= 3'b0;
				func2out <= 3'b0;

				spec1out <= 1'b1;
				spec2out <= 1'b1;
			end
			else
			begin
				rstag1out <= rstag1in;
				rstag2out <= rstag2in;
				rstag3out <= rstag3in;
				rstag4out <= rstag4in;
		
				dataRs1out <= dataRs1in;
				dataRt1out <= dataRt1in;
				dataRs2out <= dataRs2in;
				dataRt2out <= dataRt2in;

				imm1out <= imm1in;
				imm2out <= imm2in; 

				ctrl1out <= ctrl1in;
				ctrl2out <= ctrl2in;

				robDest1out <= robDest1in;
				robDest2out <= robDest2in;

				func1out <= func1;
				func2out <= func2;

				spec1out <= spec1in;
				spec2out <= spec2in;

				PCplus2out <= PCplus2in;
			end
			nextPC_selOut <= nextPC_selIn;
		end
	end	
	
endmodule

module ExecuteBuffer(CDBData, clearRSEntry, entryTCout_I, entryTCout_LS, int_datain, MUL_datain, LS_datain, entryTCin_I, entryTC_LS, clk);
	input [20:0] int_datain, MUL_datain, LS_datain;
	input [1:0] entryTCin_I, entryTC_LS;
	output reg [1:0] entryTCout_I, entryTCout_LS;
	//output reg [20:0] AU_dataout, LU_dataout, MUL_dataout, LS_dataout; //LS - Load/Store
	output reg [41:0] CDBData;
	input clk;
	output reg [2:0] clearRSEntry;
	
	always@(posedge clk)
	begin
		//CDBData[20:0] = int_datain;
		//CDBData[41:21] = MUL_datain;
		if(int_datain[20])
		begin
			CDBData[20:0] = int_datain;
			clearRSEntry[0] = 1;
			entryTCout_I = entryTCin_I;
			if(LS_datain[20])
			begin
				CDBData[41:21] = LS_datain; 
				clearRSEntry[1] = 1;
				entryTCout_LS = entryTC_LS;
				clearRSEntry[2] = 0;
			end
			else if(MUL_datain[20])
			begin
				CDBData[41:21] = MUL_datain;
				clearRSEntry[2] = 1;
				clearRSEntry[1] = 0;
			end
		end
		else if(LS_datain[20])
		begin
			CDBData[20:0] = LS_datain;
			clearRSEntry[1] = 1;
			clearRSEntry[0] = 0;
			entryTCout_I = 2'bxx;
			entryTCout_LS = entryTC_LS;
			if(MUL_datain[20])
			begin
				CDBData[41:21] = MUL_datain;
				clearRSEntry[2] = 1;
			end
		end
		else if(MUL_datain[20])
		begin
			CDBData[20:0] = MUL_datain;
			entryTCout_I = 2'bxx;
			clearRSEntry[2] = 1;
			clearRSEntry[1] = 0;
			clearRSEntry[0] = 0;
		end
	end
endmodule

/*module IDEXReg(ReadData1Out, ReadData2Out, ImmOut, rsOut, rdOut, rtOut, exCtrlOut, memCtrlOut, wbCtrlOut, hltOut, ReadData1In, ReadData2In, ImmIn, rsIn, rdIn, rtIn, exCtrlIn, memCtrlIn, wbCtrlIn, hlt, clk);
	input[15:0] ReadData1In, ReadData2In, ImmIn;
	input[4:0] rdIn, rtIn, rsIn;
	input [3:0] exCtrlIn; // 0 - aluSrc, 2,1 - [1:0]aluOp, 3 - regDst;
	input [1:0] memCtrlIn; //1 - memRead, 0 - memWrite
	input [1:0] wbCtrlIn; // 1 - regWrite, 0 - memToReg
	input clk, hlt;
	
	output reg [15:0] ReadData1Out, ReadData2Out, ImmOut;
	output reg [4:0] rdOut, rtOut, rsOut;
	output reg [3:0] exCtrlOut;
	output reg [1:0] memCtrlOut;
	output reg [1:0] wbCtrlOut;
	output reg hltOut;

	always@(posedge clk)
	begin
	//if(~rst)
	//begin
		ReadData1Out <= ReadData1In;
		ReadData2Out <= ReadData2In;
		ImmOut <= ImmIn;
		rdOut <= rdIn;
		rtOut <= rtIn;
		rsOut <= rsIn;
		exCtrlOut <= exCtrlIn;
		memCtrlOut <= memCtrlIn;
		wbCtrlOut <= wbCtrlIn;
		hltOut <= hlt;
	//end
	end	

	//always@(rsIn or rtIn)
		//$display("rs = %d, rt = %d", rsIn, rtIn);
	
endmodule

module EXMEMReg(aluResOut, writeDataOut, regDstOut, memCtrlOut, wbCtrlOut, hltOut, aluResIn, writeDataIn, regDstIn, memCtrlIn, wbCtrlIn, hlt, clk);
	
	input [15:0] aluResIn, writeDataIn;
	input clk, hlt;
	input [4:0] regDstIn;
	input [1:0] memCtrlIn; //1 - memRead, 0 - memWrite
	input [1:0] wbCtrlIn; // 1 - regWrite, 0 - memToReg

	output reg [15:0] aluResOut, writeDataOut;
	output reg [4:0] regDstOut;
	output reg [1:0] memCtrlOut;
	output reg [1:0] wbCtrlOut;
	output reg hltOut;

	always@(posedge clk)
	begin
	//if(~rst)
	//begin
		writeDataOut <= writeDataIn;
		aluResOut <= aluResIn;
		regDstOut <= regDstIn;
		memCtrlOut <= memCtrlIn;
		wbCtrlOut <= wbCtrlIn;
		hltOut <= hlt;
		//$display($time, "writeDataOut = %d, aluResOut = %d",writeDataOut,  aluResOut);
	//end
	end	
	
endmodule

module MEMWBReg(readDataOut, aluResOut, regDstOut, wbCtrlOut, hltOut, readDataIn, aluResIn, regDstIn, wbCtrlIn, hlt, clk);
	input [15:0] readDataIn, aluResIn;
	input [4:0] regDstIn;
	input [1:0] wbCtrlIn; // 1 - regWrite, 0 - memToReg
	input clk, hlt;

	output reg [15:0] readDataOut, aluResOut;
	output reg [4:0] regDstOut;
	output reg [1:0] wbCtrlOut;
	output reg hltOut;
		
	always@(posedge clk)
	begin
	//if(~rst)
	//begin
		readDataOut <= readDataIn;
		aluResOut <= aluResIn;
		regDstOut <= regDstIn;
		wbCtrlOut <= wbCtrlIn;
		hltOut <= hlt;
	//end
	end

endmodule*/

