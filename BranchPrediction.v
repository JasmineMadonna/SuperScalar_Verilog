/*BIA-Branch Instruction Address, BTA - Branch Target Address*/
module BranchTargetBuffer(BTA, hit, prediction, BIA, wBIA, wBTA, taken);
	input [15:0] BIA, wBIA, wBTA;
	input taken;
	output reg [15:0] BTA;
	output reg hit;
	output prediction;
	
	reg [31:0] btb [0:7];
	reg head;
	initial
	begin
		head = 0;
		//prediction = 0; //prediction = 0 means not taken
	end

	wire [15:0] nextBIA;
	reg [3:0] PCToPredict;
	assign nextBIA = BIA + 1;
	integer i;
	
	always@(BIA)
	begin
		hit = 0;
		for(i=0; i<=head; i=i+1)
		begin
			if(BIA == btb[i][31:16])
			begin
				BTA = btb[i][15:0];
				hit = 1;
				PCToPredict = BIA[3:0];
			end
			else if(nextBIA == btb[i][31:16])
			begin
				BTA = btb[i][15:0];
				hit = 1;
				PCToPredict = nextBIA[3:0];
			end
		end
	end
	
	always@(wBIA or wBTA)
	begin
		btb[head][31:0] = {wBIA, wBTA};
		head = head + 1;
	end
	BranchPredictor predict(prediction, PCToPredict, wBIA[3:0], taken);
endmodule

module BranchPredictor(prediction, PC, wPCindex, taken);
	input [3:0] PC, wPCindex;
	input taken;
	output prediction;
	
	reg [3:0] GHSR;
	wire [3:0] lptIndex, wlptIndex;
	wire takenOut_lpt, takenOut_gpt, takenOut_cpt;

	initial	
		GHSR = 4'b0000;

	always@(wPCindex or taken)
		GHSR = {GHSR[2:0], taken};
	
	LocalHistoryTable lht(lptIndex, wlptIndex, PC, wPCindex, taken);
	
	PredictionTable lpt(takenOut_lpt, lptIndex, wlptIndex, taken);
	PredictionTable gpt(takenOut_gpt, GHSR, GHSR, taken);
	PredictionTable cpt(takenOut_cpt, GHSR, GHSR, taken);

	mux1bit mux(prediction, takenOut_lpt, takenOut_gpt, takenOut_cpt);
endmodule 

module LocalHistoryTable(lptIndex, wlptIndex, rPCindex, wPCindex, taken);
	input [3:0] rPCindex, wPCindex;
	input taken;
	output reg [3:0] lptIndex;
	output reg [3:0] wlptIndex;

	reg [3:0] LHT [0:15];

	integer i;
	initial
	begin
		for(i=0; i<=15; i=i+1)
			LHT[i] = 4'b00;
	end

	always@(rPCindex)
	begin
		lptIndex = LHT[rPCindex];
	end
	
	always@(wPCindex or taken)
	begin
		wlptIndex = LHT[wPCindex];
		LHT[wPCindex] = {LHT[wPCindex][2:0], taken};
	end
	
endmodule

module PredictionTable(takenOut, index, wIndex, takenIn);
	input [3:0] index, wIndex;
	input takenIn;
	output takenOut;
	
	reg [1:0] PT [0:15];

	reg [1:0] CS, CS_update;
	wire [1:0] NS;

	integer i;
	initial
	begin
		for(i=0; i<=15; i=i+1)
			PT[i] = 2'b10;
	end
	
	always@(index)
		CS = PT[index];

	always@(wIndex)
		CS_update = PT[wIndex];

	always@(NS or wIndex)
		PT[wIndex] = NS;

	Prediction_2bit pred(NS, takenOut, takenIn, CS, CS_update);
endmodule

module Prediction_2bit(NS, takenOut, taken, CS_read, CS_update);
	input [1:0] CS_read, CS_update;
	input taken;
	output reg [1:0] NS;
	output reg takenOut;
	
	parameter ST = 2'b00, T = 2'b01, NT = 2'b10, SNT = 2'b11;

	always@(CS_read)
	begin
	  case(CS_read)
		ST: takenOut = 1;
		T:takenOut = 1;
		NT: takenOut = 0;
		SNT: takenOut = 0;
	  endcase
	end
	
	always@(CS_update or taken)
	begin
		case(CS_update)
			ST :
			begin
				if(taken)
					NS = ST;
				else
					NS = T;
			end
			T :
			begin
				if(taken)
					NS = ST;
				else
					NS = SNT;
			end
			NT :
			begin
				if(taken)
					NS = ST;
				else
					NS = SNT;
			end
			SNT :
			begin
				if(taken)
					NS = NT;
				else
					NS = SNT;
			end
		endcase
	end 
endmodule

module mux1bit(output out, input i0, input i1, input sel);
	assign out = sel ? i1 : i0;
endmodule

