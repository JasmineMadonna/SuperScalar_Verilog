/*
one entry correspond to a resvervation entry (resEntry).
resEntry[0] - ready; resEntry[16:1] - operand1; resEntry[20:17] - tag1; resEntry[36:21] - operand1; resEntry[40:37] - tag1 resEntry[44:41] destROB - resEntry[45] - busy 
rs, rt => operand1, operand2 
*/
module ReservationStation(stall, issued, robTagOut, rsOut, rtOut, rs1in, rt1in, rs2in, rt2in, tag_rs1in, tag_rt1in, tag_rs2in, tag_rt2in, spec1, spec2, robDest1, robDest2, load, clk, CDBData, clearRSEntry, flush);
	input [15:0] rs1in, rt1in, rs2in, rt2in;
	input [3:0] tag_rs1in, tag_rt1in, tag_rs2in, tag_rt2in, robDest1, robDest2;
	input clk, clearRSEntry, spec1, spec2, flush;
	input [1:0] load;
	input [41:0] CDBData;

	output reg [15:0] rsOut, rtOut;
	output reg [3:0] robTagOut;
	output reg stall;
	output reg issued;
	
	reg [46:0] resEntries [0:3];
	
	wire [3:0] busyBits;
	wire [1:0] index1, index2;
	wire [1:0] full; //00 - have free entry for both, 01 - only one free entry, 11 - no free entry
	reg [1:0] head;
	initial
	begin
		resEntries[0] = 47'b0;
		resEntries[1] = 47'b0;
		resEntries[2] = 47'b0;
		resEntries[3] = 47'b0;
		head = 2'b0;
		stall = 0;
	end

	assign busyBits = {resEntries[head+2'b11][45], resEntries[head+2'b10][45], resEntries[head+2'b01][45], resEntries[head][45]};
	allocateUnit au(index1, index2, full, busyBits, clk);
	
	always@(negedge clk)
	begin
		if(load[0] == 1 && (full == 2'b00 || full == 2'b01))
		begin
			resEntries[index1] = {spec1, 1'b1, robDest1, tag_rt1in, rt1in, tag_rs1in, rs1in, 1'b0};
			//stall = 0;
			if(tag_rs1in == 4'b0 && tag_rt1in == 4'b0)
				resEntries[index1][0] = 1;
			else
				resEntries[index1][0] = 0;
		end
		if(load[1] == 1 && full == 2'b00)
		begin
			resEntries[index2] = {spec2, 1'b1, robDest2, tag_rt2in, rt2in, tag_rs2in, rs2in, 1'b0};
			//stall = 0;
			if(tag_rs2in == 4'b0 && tag_rt2in == 4'b0)
				resEntries[index2][0] = 1;
			else
				resEntries[index2][0] = 0;
		end
		//else
			//stall = 1;
	end

	always@(full)
	begin
		if(full == 2'b11)
			stall = 1;
		else
			stall = 0;
	end

	/*always@(index2 or rt2in or rs2in)
	begin
		if(load[1] == 1 && full == 2'b00)
		begin
			resEntries[index2] = {1'b1, robDest2, tag_rt2in, rt2in, tag_rs2in, rs2in, 1'b0};
			stall = 0;
			if(tag_rs2in == 4'b0 && tag_rt2in == 4'b0)
				resEntries[index2][0] = 1;
			else
				resEntries[index2][0] = 0;
		end
		else
			stall = 1;
	end*/

	always@(flush)
	begin
		if(flush)
		begin
			if(resEntries[0][46] == 1)
				resEntries[0] = 47'b0;
			if(resEntries[1][46] == 1)
				resEntries[1] = 47'b0;
			if(resEntries[2][46] == 1)
				resEntries[2] = 47'b0;
			if(resEntries[3][46] == 1)
				resEntries[3] = 47'b0;
		end
	end

	reg [1:0] entryToBeCleared;
	always@(posedge clk)
	begin
		if(clearRSEntry)
		begin
			resEntries[entryToBeCleared][45] <= 1'b0;
			resEntries[entryToBeCleared][0] <= 1'b0;
		end
			
		#1 casex({resEntries[3][0], resEntries[2][0], resEntries[1][0], resEntries[0][0]})
		 4'bxxx1: begin
			rsOut <= resEntries[0][16:1];
			rtOut <= resEntries[0][36:21];
			robTagOut <= resEntries[0][44:41];
			entryToBeCleared <= 2'b00;
			issued <= 1;
		 end
		 4'bxx10: begin
			rsOut <= resEntries[1][16:1];
			rtOut <= resEntries[1][36:21];
			robTagOut <= resEntries[1][44:41];
			entryToBeCleared <= 2'b01;
			issued <= 1;
		 end
		 4'bx100: begin
			rsOut <= resEntries[2][16:1];
			rtOut <= resEntries[2][36:21];
			robTagOut <= resEntries[2][44:41];
			entryToBeCleared <= 2'b10;
			issued <= 1;
		 end
		 4'b1000: begin
			rsOut <= resEntries[3][16:1];
			rtOut <= resEntries[3][36:21];
			robTagOut <= resEntries[3][44:41];
			entryToBeCleared <= 2'b11;
			issued <= 1;
		 end
		 default: begin
			rsOut <= 16'b0;
			rtOut <= 16'b0;
			robTagOut <= 4'b0;
			issued <= 0;
		 end
		endcase
	end
	
	wire [15:0] oper01, oper02, oper11, oper12, oper21, oper22, oper31, oper32;
	reg [1:0] tmIndex;
	tagMatch tm1(oper01, resEntries[0][20:17], CDBData);
	tagMatch tm2(oper02, resEntries[0][40:37], CDBData);
	tagMatch tm3(oper11, resEntries[1][20:17], CDBData);
	tagMatch tm4(oper12, resEntries[1][40:37], CDBData);
	tagMatch tm5(oper21, resEntries[2][20:17], CDBData);
	tagMatch tm6(oper22, resEntries[2][40:37], CDBData);
	tagMatch tm7(oper31, resEntries[3][20:17], CDBData);
	tagMatch tm8(oper32, resEntries[3][40:37], CDBData);
	
	always@(oper01)
	begin
		resEntries[0][20:1] = {4'b0, oper01};
		tmIndex = 2'b0;
	end
	always@(oper02)
	begin
		resEntries[0][40:21] = {4'b0, oper02};
		tmIndex = 2'b0;
	end
	always@(oper11)
	begin
		resEntries[1][20:1] = {4'b0, oper11};
		tmIndex = 2'b01;
	end

	always@(oper12)
	begin
		resEntries[1][40:21] <= {4'b0, oper12};
		tmIndex = 2'b01;
	end
	
	always@(oper21)
	begin
		resEntries[2][20:1] <= {4'b0, oper21};
		tmIndex = 2'b10;
	end
	always@(oper22)
	begin
		resEntries[2][40:21] <= {4'b0, oper22};
		tmIndex = 2'b10;
	end

	always@(oper31)
	begin
		resEntries[3][20:1] <= {4'b0, oper31};
		tmIndex = 2'b11;
	end
	
	always@(oper32)
	begin
		resEntries[3][40:21] <= {4'b0, oper32};
		tmIndex = 2'b11;
	end

	always@(resEntries[tmIndex])
	begin
		if(resEntries[tmIndex][20:17] == 4'b0 &&  resEntries[tmIndex][40:37] == 4'b0)
			resEntries[tmIndex][0] = 1;
		else
			resEntries[tmIndex][0] = 0;
	end
	//integer i;
	always@(resEntries[0])
	begin
		$display($time, " RS MUL: resEntry 0 : operand1  = %d,  tag1 = %d, operand1  = %d,  tag1 = %d", resEntries[0][16:1], resEntries[0][20:17], resEntries[0][36:21], resEntries[0][40:37]);
	end
	/*always@(resEntries[1])
	begin
		$display($time, " resEntry 2 : operand1  = %d,  tag1 = %d, operand1  = %d,  tag1 = %d", resEntries[1][16:1], resEntries[1][20:17], resEntries[1][36:21], resEntries[1][40:37]);
	end
	always@(resEntries[2])
	begin
		$display($time, " resEntry 2 : operand1  = %d,  tag1 = %d, operand1  = %d,  tag1 = %d", resEntries[2][16:1], resEntries[2][20:17], resEntries[2][36:21], resEntries[2][40:37]);
	end*/
endmodule

/*here along with the tag and operand, funct is added*/
module ReservationStationInt(stall, issued, entryToBeClearedOut, robTagOut, rsOut, rtOut, funcOut, rs1in, rt1in, rs2in, rt2in, tag_rs1in, tag_rt1in, tag_rs2in, tag_rt2in, func1in, func2in, spec1, spec2, robDest1, robDest2, load, clk, CDBData, entryToBeClearedIn, clearRSEntry, flush);
	input [15:0] rs1in, rt1in, rs2in, rt2in;
	input [3:0] tag_rs1in, tag_rt1in, tag_rs2in, tag_rt2in, robDest1, robDest2;
	input clk, clearRSEntry, spec1, spec2, flush;
	input [1:0] load, func1in, func2in, entryToBeClearedIn;
	input [41:0] CDBData;

	output reg [15:0] rsOut, rtOut;
	output reg [3:0] robTagOut;
	output reg stall;
	output reg issued;
	output reg [1:0] funcOut, entryToBeClearedOut;
	
	reg [48:0] resEntries [0:3];
	
	wire [3:0] busyBits;
	wire [1:0] index1, index2;
	wire [1:0] full; //00 - have free entry for both, 01 - only one free entry, 11 - no free entry
	reg [1:0] head;

	initial
	begin
		resEntries[0] = 49'b0;
		resEntries[1] = 49'b0;
		resEntries[2] = 49'b0;
		resEntries[3] = 49'b0;
		head = 2'b0;
		stall = 0;
	end

	assign busyBits = {resEntries[head+2'b11][47], resEntries[head+2'b10][47], resEntries[head+2'b01][47], resEntries[head][47]};
	allocateUnit au(index1, index2, full, busyBits, clk);
	
	always@(negedge clk)
	begin
		if(load[0] == 1 && (full == 2'b00 || full == 2'b01) && (rt1in >= 0 && rs1in >= 0))
		begin
			resEntries[index1] = {spec1, 1'b1, func1in, robDest1, tag_rt1in, rt1in, tag_rs1in, rs1in, 1'b0};
			//stall = 0;
			head = head + 1;
			//$display($time, " !!!!!!!!!!index1 = %d rt1in = %d", index1, rt1in);
			if(tag_rs1in == 4'b0 && tag_rt1in == 4'b0)
				resEntries[index1][0] = 1;
			else
				resEntries[index1][0] = 0;
		end
		if(load[1] == 1 && full == 2'b00)
		begin
			resEntries[index2] = {spec2, 1'b1, func2in, robDest2, tag_rt2in, rt2in, tag_rs2in, rs2in, 1'b0};
			//stall = 0;
			head = head + 1;
			//$display($time, " !!!!!!!!!!index2 = %d rt2in = %d", index2, rt2in);
			if(tag_rs2in == 4'b0 && tag_rt2in == 4'b0)
				resEntries[index2][0] = 1;
			else
				resEntries[index2][0] = 0;
		end
		//else
			//stall = 1;
	end

	always@(flush)
	begin
		if(flush)
		begin
			if(resEntries[0][48] == 1)
				resEntries[0] = 49'b0;
			if(resEntries[1][48] == 1)
				resEntries[1] = 49'b0;
			if(resEntries[2][48] == 1)
				resEntries[2] = 49'b0;
			if(resEntries[3][48] == 1)
				resEntries[3] = 49'b0;
		end
	end

	always@(full)
	begin
		if(full == 2'b11)
			stall = 1;
		else
			stall = 0;
	end

	//reg [1:0] entryToBeCleared;
	always@(entryToBeClearedIn)
	begin
		if(clearRSEntry)
		begin
			resEntries[entryToBeClearedIn][47] <= 1'b0;
			resEntries[entryToBeClearedIn][0] <= 1'b0;
		end
		//$display($time, " entryToBeClearedIn :::::::::::::::::::: %b",entryToBeClearedIn);
	end
	always@(posedge clk)
	begin
		#1 casex({resEntries[3][0], resEntries[2][0], resEntries[1][0], resEntries[0][0]})
		 4'bxxx1: begin
			rsOut <= resEntries[0][16:1];
			rtOut <= resEntries[0][36:21];
			robTagOut <= resEntries[0][44:41];
			funcOut <= resEntries[0][46:45];
			entryToBeClearedOut <= 2'b00;
			//resEntries[0][47] <= 1'b0;
			//resEntries[0][0] <= 1'b0;
			issued <= 1;
		 end
		 4'bxx10: begin
			rsOut <= resEntries[1][16:1];
			rtOut <= resEntries[1][36:21];
			robTagOut <= resEntries[1][44:41];
			funcOut <= resEntries[1][46:45];
			entryToBeClearedOut <= 2'b01;
			//resEntries[1][47] <= 1'b0;
			//resEntries[1][0] <= 1'b0;
			issued <= 1;
		 end
		 4'bx100: begin
			rsOut <= resEntries[2][16:1];
			rtOut <= resEntries[2][36:21];
			robTagOut <= resEntries[2][44:41];
			funcOut <= resEntries[2][46:45];
			entryToBeClearedOut <= 2'b10;
			//resEntries[2][47] <= 1'b0;
			//resEntries[2][0] <= 1'b0;
			issued <= 1;
		 end
		 4'b1000: begin
			rsOut <= resEntries[3][16:1];
			rtOut <= resEntries[3][36:21];
			robTagOut <= resEntries[3][44:41];
			funcOut <= resEntries[3][46:45];
			entryToBeClearedOut <= 2'b11;
			//resEntries[3][47] <= 1'b0;
			//resEntries[3][0] <= 1'b0;
			issued <= 1;
		 end
		 default: begin
			rsOut <= 16'b0;
			rtOut <= 16'b0;
			robTagOut <= 4'b0;
			issued <= 0;
		 end
		endcase
	end
	
	wire [15:0] oper01, oper02, oper11, oper12, oper21, oper22, oper31, oper32;
	reg [1:0] tmIndex;
	tagMatch tm1(oper01, resEntries[0][20:17], CDBData);
	tagMatch tm2(oper02, resEntries[0][40:37], CDBData);
	tagMatch tm3(oper11, resEntries[1][20:17], CDBData);
	tagMatch tm4(oper12, resEntries[1][40:37], CDBData);
	tagMatch tm5(oper21, resEntries[2][20:17], CDBData);
	tagMatch tm6(oper22, resEntries[2][40:37], CDBData);
	tagMatch tm7(oper31, resEntries[3][20:17], CDBData);
	tagMatch tm8(oper32, resEntries[3][40:37], CDBData);
	
	always@(oper01)
	begin
		resEntries[0][20:1] = {4'b0, oper01};
		tmIndex = 2'b0;
	end
	always@(oper02)
	begin
		resEntries[0][40:21] = {4'b0, oper02};
		tmIndex = 2'b0;
	end
	always@(oper11)
	begin
		resEntries[1][20:1] = {4'b0, oper11};
		tmIndex = 2'b01;
	end

	always@(oper12)
	begin
		resEntries[1][40:21] <= {4'b0, oper12};
		tmIndex = 2'b01;
	end
	
	always@(oper21)
	begin
		resEntries[2][20:1] <= {4'b0, oper21};
		tmIndex = 2'b10;
	end
	always@(oper22)
	begin
		resEntries[2][40:21] <= {4'b0, oper22};
		tmIndex = 2'b10;
	end

	always@(oper31)
	begin
		resEntries[3][20:1] <= {4'b0, oper31};
		tmIndex = 2'b11;
	end
	
	always@(oper32)
	begin
		resEntries[3][40:21] <= {4'b0, oper32};
		tmIndex = 2'b11;
	end

	always@(resEntries[tmIndex])
	begin
		//$display($time, " RS_Int : tmIndex ::::::::: %b", tmIndex);
		if(resEntries[tmIndex][20:17] == 4'b0 &&  resEntries[tmIndex][40:37] == 4'b0)
			resEntries[tmIndex][0] = 1;
		else
			resEntries[tmIndex][0] = 0;
	end
	
	always@(resEntries[0])
	begin
		$display($time, " RS_Int :  resEntry 0 : operand1  = %d,  tag1 = %d, operand2  = %d,  tag2 = %d, busy = %b, ready = %b", resEntries[0][16:1], resEntries[0][20:17], resEntries[0][36:21], resEntries[0][40:37], resEntries[0][47], resEntries[0][0]);
	end
	always@(resEntries[1])
	begin
		$display($time, " RS_Int :  resEntry 1 : operand1  = %d,  tag1 = %d, operand2  = %d,  tag2 = %d, busy = %b, ready = %b", resEntries[1][16:1], resEntries[1][20:17], resEntries[1][36:21], resEntries[1][40:37], resEntries[1][47], resEntries[1][0]);
	end
	always@(resEntries[2])
	begin
		$display($time, " RS_Int :  resEntry 2 : operand1  = %d,  tag1 = %d, operand2  = %d,  tag2 = %d, busy = %b, ready = %b", resEntries[2][16:1], resEntries[2][20:17], resEntries[2][36:21], resEntries[2][40:37], resEntries[2][47], resEntries[2][0]);
	end
	always@(resEntries[3])
	begin
		$display($time, " RS_Int :  resEntry 3 : operand1  = %d,  tag1 = %d, operand2  = %d,  tag2 = %d, busy = %b, ready = %b", resEntries[3][16:1], resEntries[3][20:17], resEntries[3][36:21], resEntries[3][40:37], resEntries[3][47], resEntries[3][0]);
	end
endmodule

/*here along with the tag and operand, 16 bit immediate is added*/
module ReservationStationLS(stall, issued, entryToBeClearedOut, robTagOut, rsOut, rtOut, immOut, LorSout, rs1in, rt1in, rs2in, rt2in, tag_rs1in, tag_rt1in, tag_rs2in, tag_rt2in, imm1in, imm2in, spec1, spec2, robDest1, robDest2, load, LorS1, LorS2, clk, CDBData, entryToBeClearedIn, clearRSEntry, flush);
	input [15:0] rs1in, rt1in, rs2in, rt2in, imm1in, imm2in;
	input [3:0] tag_rs1in, tag_rt1in, tag_rs2in, tag_rt2in, robDest1, robDest2;
	input clk, LorS1, LorS2, clearRSEntry, spec1, spec2, flush; //LorS = 1 for load, 0 for store
	input [1:0] load, entryToBeClearedIn;
	input [41:0] CDBData;

	output reg [15:0] rsOut, rtOut, immOut;
	output reg [3:0] robTagOut;
	output reg stall, LorSout;
	output reg issued;
	output reg [1:0] funcOut, entryToBeClearedOut;
	
	reg [63:0] resEntries [0:3];
	
	wire [3:0] busyBits;
	wire [1:0] index1, index2;
	wire [1:0] full; //00 - have free entry for both, 01 - only one free entry, 11 - no free entry
	reg [1:0] head;

	initial
	begin
		resEntries[0] = 64'b0;
		resEntries[1] = 64'b0;
		resEntries[2] = 64'b0;
		resEntries[3] = 64'b0;
		head = 2'b0;
		stall = 0;
	end

	assign busyBits = {resEntries[head+2'b11][62], resEntries[head+2'b10][62], resEntries[head+2'b01][62], resEntries[head][62]};
	allocateUnit au(index1, index2, full, busyBits, clk);
	
	always@(negedge clk)
	begin
		if(load[0] == 1 && (full == 2'b00 || full == 2'b01) && (rt1in >= 0 && rs1in >= 0))
		begin
			resEntries[index1] = {spec1, 1'b1, LorS1, imm1in, robDest1, tag_rt1in, rt1in, tag_rs1in, rs1in, 1'b0};
			//stall = 0;
			head = head + 1;
			
			if(tag_rs1in == 4'b0 && tag_rt1in == 4'b0)
				resEntries[index1][0] = 1;
			else
				resEntries[index1][0] = 0;
		end
		if(load[1] == 1 && full == 2'b00)
		begin
			resEntries[index2] = {spec2, 1'b1, LorS2, imm2in, robDest2, tag_rt2in, rt2in, tag_rs2in, rs2in, 1'b0};
			//stall = 0;
			head = head + 1;
			
			if(tag_rs2in == 4'b0 && tag_rt2in == 4'b0)
				resEntries[index2][0] = 1;
			else
				resEntries[index2][0] = 0;
		end
		//else
			//stall = 1;
	end

	always@(full)
	begin
		if(full == 2'b11)
			stall = 1;
		else
			stall = 0;
	end

	always@(flush)
	begin
		if(flush)
		begin
			if(resEntries[0][63] == 1)
				resEntries[0] = 64'b0;
			if(resEntries[1][63] == 1)
				resEntries[1] = 64'b0;
			if(resEntries[2][63] == 1)
				resEntries[2] = 64'b0;
			if(resEntries[3][63] == 1)
				resEntries[3] = 64'b0;
		end
	end

	always@(entryToBeClearedIn)
	begin
		if(clearRSEntry)
		begin
			resEntries[entryToBeClearedIn][47] <= 1'b0;
			resEntries[entryToBeClearedIn][0] <= 1'b0;
		end
		//$display($time, " entryToBeClearedIn :::::::::::::::::::: %b",entryToBeClearedIn);
	end
	always@(posedge clk)
	begin
		/*if(clearRSEntry)
		begin
			resEntries[entryToBeClearedIn][62] <= 1'b0;
			resEntries[entryToBeClearedIn][0] <= 1'b0;
		end*/
		//issued = 0;
		#1 casex({resEntries[3][0], resEntries[2][0], resEntries[1][0], resEntries[0][0]})
		 4'bxxx1: begin
			rsOut <= resEntries[0][16:1];
			rtOut <= resEntries[0][36:21];
			robTagOut <= resEntries[0][44:41];
			immOut <= resEntries[0][60:45];
			LorSout <= resEntries[0][61];
			//resEntries[0][62] <= 1'b0;
			//resEntries[0][0] <= 1'b0;
			entryToBeClearedOut <= 2'b00;
			issued <= 1;
		 end
		 4'bxx10: begin
			rsOut <= resEntries[1][16:1];
			rtOut <= resEntries[1][36:21];
			robTagOut <= resEntries[1][44:41];
			immOut <= resEntries[1][60:45];
			LorSout <= resEntries[1][61];
			//resEntries[1][62] <= 1'b0;
			//resEntries[1][0] <= 1'b0;
			entryToBeClearedOut <= 2'b01;
			issued <= 1;
		 end
		 4'bx100: begin
			rsOut <= resEntries[2][16:1];
			rtOut <= resEntries[2][36:21];
			robTagOut <= resEntries[2][44:41];
			immOut <= resEntries[2][60:45];
			LorSout <= resEntries[2][61];
			//resEntries[2][62] <= 1'b0;
			//resEntries[2][0] <= 1'b0;
			entryToBeClearedOut <= 2'b10;
			issued <= 1;
		 end
		 4'b1000: begin
			rsOut <= resEntries[3][16:1];
			rtOut <= resEntries[3][36:21];
			robTagOut <= resEntries[3][44:41];
			immOut <= resEntries[3][60:45];
			LorSout <= resEntries[3][61];
			//resEntries[3][62] <= 1'b0;
			//resEntries[3][0] <= 1'b0;
			entryToBeClearedOut <= 2'b11;
			issued <= 1;
		 end
		 default: begin
			rsOut <= 16'b0;
			rtOut <= 16'b0;
			robTagOut <= 4'b0;
			immOut <= 16'b0;
			LorSout <= 1;
			issued <= 0;
			entryToBeClearedOut <= 2'bxx;
		 end
		endcase
	end
	
	wire [15:0] oper01, oper02, oper11, oper12, oper21, oper22, oper31, oper32;
	reg [1:0] tmIndex;
	tagMatch tm1(oper01, resEntries[0][20:17], CDBData);
	tagMatch tm2(oper02, resEntries[0][40:37], CDBData);
	tagMatch tm3(oper11, resEntries[1][20:17], CDBData);
	tagMatch tm4(oper12, resEntries[1][40:37], CDBData);
	tagMatch tm5(oper21, resEntries[2][20:17], CDBData);
	tagMatch tm6(oper22, resEntries[2][40:37], CDBData);
	tagMatch tm7(oper31, resEntries[3][20:17], CDBData);
	tagMatch tm8(oper32, resEntries[3][40:37], CDBData);
	
	always@(oper01)
	begin
		resEntries[0][20:1] = {4'b0, oper01};
		tmIndex = 2'b0;
	end
	always@(oper02)
	begin
		resEntries[0][40:21] = {4'b0, oper02};
		tmIndex = 2'b0;
	end
	always@(oper11)
	begin
		resEntries[1][20:1] = {4'b0, oper11};
		tmIndex = 2'b01;
	end

	always@(oper12)
	begin
		resEntries[1][40:21] <= {4'b0, oper12};
		tmIndex = 2'b01;
	end
	
	always@(oper21)
	begin
		resEntries[2][20:1] <= {4'b0, oper21};
		tmIndex = 2'b10;
	end
	always@(oper22)
	begin
		resEntries[2][40:21] <= {4'b0, oper22};
		tmIndex = 2'b10;
	end

	always@(oper31)
	begin
		resEntries[3][20:1] <= {4'b0, oper31};
		tmIndex = 2'b11;
	end
	
	always@(oper32)
	begin
		resEntries[3][40:21] <= {4'b0, oper32};
		tmIndex = 2'b11;
	end

	always@(resEntries[tmIndex])
	begin
		//$display($time, " RS_Int : tmIndex ::::::::: %b", tmIndex);
		if(resEntries[tmIndex][20:17] == 4'b0 &&  resEntries[tmIndex][40:37] == 4'b0)
			resEntries[tmIndex][0] = 1;
		else
			resEntries[tmIndex][0] = 0;
	end
	
	always@(resEntries[0])
	begin
		$display($time, " RS_LS :  resEntry 0 : operand1  = %d,  tag1 = %d, operand2  = %d,  tag2 = %d, busy = %b, ready = %b", resEntries[0][16:1], resEntries[0][20:17], resEntries[0][36:21], resEntries[0][40:37], resEntries[0][62], resEntries[0][0]);
	end
	always@(resEntries[1])
	begin
		$display($time, " RS_LS :  resEntry 1 : operand1  = %d,  tag1 = %d, operand2  = %d,  tag2 = %d, busy = %b, ready = %b", resEntries[1][16:1], resEntries[1][20:17], resEntries[1][36:21], resEntries[1][40:37], resEntries[1][62], resEntries[1][0]);
	end
	always@(resEntries[2])
	begin
		$display($time, " RS_LS :  resEntry 2 : operand1  = %d,  tag1 = %d, operand2  = %d,  tag2 = %d", resEntries[2][16:1], resEntries[2][20:17], resEntries[2][36:21], resEntries[2][40:37]);
	end
	always@(resEntries[3])
	begin
		$display($time, " RS_LS:  resEntry 3 : operand1  = %d,  tag1 = %d, operand2  = %d,  tag2 = %d", resEntries[3][16:1], resEntries[3][20:17], resEntries[3][36:21], resEntries[3][40:37]);
	end
endmodule

/*here along with the tag and operand, 16 bit immediate and PC is stored to find the branch target is added
resEntry[0] - ready; resEntry[16:1] - operand1; resEntry[20:17] - tag1; resEntry[36:21] - operand2; resEntry[40:37] - tag2 resEntry[44:41]-destROB, resEntry[60:45] - imm, resEntry[76:61] - PC, resEntry[77] - busy resEntry[78] - spec*/
module ReservationStation_Branch(stall, issued, robTagOut, rsOut, rtOut, immOut, PCOut, rs1in, rt1in, rs2in, rt2in, tag_rs1in, tag_rt1in, tag_rs2in, tag_rt2in, imm1in, imm2in, spec1, spec2, nextPC_selOut, PCin, robDest1, robDest2, load, nextPC_selIn, clk, CDBData, flush);
	input [15:0] rs1in, rt1in, rs2in, rt2in, imm1in, imm2in, PCin;
	input [3:0] tag_rs1in, tag_rt1in, tag_rs2in, tag_rt2in, robDest1, robDest2;
	input clk, spec1, spec2, flush, nextPC_selIn; //LorS = 1 for load, 0 for store
	input [1:0] load;
	input [41:0] CDBData;

	output reg [15:0] rsOut, rtOut, immOut, PCOut;
	output reg [3:0] robTagOut;
	output reg stall;
	output reg issued, nextPC_selOut;
	output reg [1:0] funcOut;
	
	reg [78:0] resEntries [0:3];
	
	wire [3:0] busyBits;
	wire [1:0] index1, index2;
	wire [1:0] full; //00 - have free entry for both, 01 - only one free entry, 11 - no free entry
	reg [1:0] head;

	initial
	begin
		resEntries[0] = 79'b0;
		resEntries[1] = 79'b0;
		resEntries[2] = 79'b0;
		resEntries[3] = 79'b0;
		head = 2'b0;
		stall = 0;
	end

	assign busyBits = {resEntries[head+2'b11][77], resEntries[head+2'b10][77], resEntries[head+2'b01][77], resEntries[head][77]};
	allocateUnit au(index1, index2, full, busyBits, clk);
	
	always@(negedge clk)
	begin
		if(load[0] == 1 && (full == 2'b00 || full == 2'b01) && (rt1in >= 0 && rs1in >= 0))
		begin
			resEntries[index1] = {spec1, 1'b1, PCin-2'b10, imm1in, robDest1, tag_rt1in, rt1in, tag_rs1in, rs1in, 1'b0};
			stall = 0;
			head = head + 1;
			
			if(tag_rs1in == 4'b0 && tag_rt1in == 4'b0)
				resEntries[index1][0] = 1;
			else
				resEntries[index1][0] = 0;
		end
		if(load[1] == 1 && full == 2'b00)
		begin
			resEntries[index2] = {spec2, 1'b1, PCin-1'b1, imm2in, robDest2, tag_rt2in, rt2in, tag_rs2in, rs2in, 1'b0};
			stall = 0;
			head = head + 1;
			
			if(tag_rs2in == 4'b0 && tag_rt2in == 4'b0)
				resEntries[index2][0] = 1;
			else
				resEntries[index2][0] = 0;
		end
		//else
		//	stall = 1;
	end

	always@(full)
	begin
		if(full == 2'b11)
			stall = 1;
		else
			stall = 0;
	end

	always@(flush)
	begin
		if(flush)
		begin
			if(resEntries[0][78] == 1)
				resEntries[0] = 79'b0;
			if(resEntries[1][78] == 1)
				resEntries[1] = 79'b0;
			if(resEntries[2][78] == 1)
				resEntries[2] = 79'b0;
			if(resEntries[3][78] == 1)
				resEntries[3] = 79'b0;
		end
	end

	always@(posedge clk)
	begin
		nextPC_selOut <= nextPC_selIn;
		//issued <= 0;
		#1 casex({resEntries[3][0], resEntries[2][0], resEntries[1][0], resEntries[0][0]})
		 4'bxxx1: begin
			rsOut <= resEntries[0][16:1];
			rtOut <= resEntries[0][36:21];
			robTagOut <= resEntries[0][44:41];
			immOut <= resEntries[0][60:45];
			PCOut <= resEntries[0][76:61];
			resEntries[0][77] <= 1'b0;
			resEntries[0][0] <= 1'b0;
			issued <= 1;
		 end
		 4'bxx10: begin
			rsOut <= resEntries[1][16:1];
			rtOut <= resEntries[1][36:21];
			robTagOut <= resEntries[1][44:41];
			immOut <= resEntries[1][60:45];
			PCOut <= resEntries[1][76:61];
			resEntries[1][77] <= 1'b0;
			resEntries[1][0] <= 1'b0;
			issued <= 1;
		 end
		 4'bx100: begin
			rsOut <= resEntries[2][16:1];
			rtOut <= resEntries[2][36:21];
			robTagOut <= resEntries[2][44:41];
			immOut <= resEntries[2][60:45];
			PCOut <= resEntries[2][76:61];
			resEntries[2][77] <= 1'b0;
			resEntries[2][0] <= 1'b0;
			issued <= 1;
		 end
		 4'b1000: begin
			rsOut <= resEntries[3][16:1];
			rtOut <= resEntries[3][36:21];
			robTagOut <= resEntries[3][44:41];
			immOut <= resEntries[3][60:45];
			PCOut <= resEntries[3][76:61];
			resEntries[3][77] <= 1'b0;
			resEntries[3][0] <= 1'b0;
			issued <= 1;
		 end
		 default: begin
			rsOut <= 16'b0;
			rtOut <= 16'b0;
			robTagOut <= 4'b0;
			immOut <= 16'b0;
			PCOut <= 16'b0;
			issued <= 0;
		 end
		endcase
	end
	
	wire [15:0] oper01, oper02, oper11, oper12, oper21, oper22, oper31, oper32;
	reg [1:0] tmIndex;
	tagMatch tm1(oper01, resEntries[0][20:17], CDBData);
	tagMatch tm2(oper02, resEntries[0][40:37], CDBData);
	tagMatch tm3(oper11, resEntries[1][20:17], CDBData);
	tagMatch tm4(oper12, resEntries[1][40:37], CDBData);
	tagMatch tm5(oper21, resEntries[2][20:17], CDBData);
	tagMatch tm6(oper22, resEntries[2][40:37], CDBData);
	tagMatch tm7(oper31, resEntries[3][20:17], CDBData);
	tagMatch tm8(oper32, resEntries[3][40:37], CDBData);
	
	always@(oper01)
	begin
		resEntries[0][20:1] = {4'b0, oper01};
		tmIndex = 2'b0;
	end
	always@(oper02)
	begin
		resEntries[0][40:21] = {4'b0, oper02};
		tmIndex = 2'b0;
	end
	always@(oper11)
	begin
		resEntries[1][20:1] = {4'b0, oper11};
		tmIndex = 2'b01;
	end

	always@(oper12)
	begin
		resEntries[1][40:21] <= {4'b0, oper12};
		tmIndex = 2'b01;
	end
	
	always@(oper21)
	begin
		resEntries[2][20:1] <= {4'b0, oper21};
		tmIndex = 2'b10;
	end
	always@(oper22)
	begin
		resEntries[2][40:21] <= {4'b0, oper22};
		tmIndex = 2'b10;
	end

	always@(oper31)
	begin
		resEntries[3][20:1] <= {4'b0, oper31};
		tmIndex = 2'b11;
	end
	
	always@(oper32)
	begin
		resEntries[3][40:21] <= {4'b0, oper32};
		tmIndex = 2'b11;
	end

	always@(resEntries[tmIndex])
	begin
		//$display($time, " RS_Int : tmIndex ::::::::: %b", tmIndex);
		if(resEntries[tmIndex][20:17] == 4'b0 &&  resEntries[tmIndex][40:37] == 4'b0)
			resEntries[tmIndex][0] = 1;
		else
			resEntries[tmIndex][0] = 0;
	end
	
	always@(resEntries[0])
	begin
		$display($time, " RS_Branch :  resEntry 0 : operand1  = %d,  tag1 = %d, operand2  = %d,  tag2 = %d", resEntries[0][16:1], resEntries[0][20:17], resEntries[0][36:21], resEntries[0][40:37]);
	end
	always@(resEntries[1])
	begin
		$display($time, " RS_Branch :  resEntry 1 : operand1  = %d,  tag1 = %d, operand2  = %d,  tag2 = %d", resEntries[1][16:1], resEntries[1][20:17], resEntries[1][36:21], resEntries[1][40:37]);
	end
	always@(resEntries[2])
	begin
		$display($time, " RS_Branch :  resEntry 2 : operand1  = %d,  tag1 = %d, operand2  = %d,  tag2 = %d", resEntries[2][16:1], resEntries[2][20:17], resEntries[2][36:21], resEntries[2][40:37]);
	end
	always@(resEntries[3])
	begin
		$display($time, " RS_Branch:  resEntry 3 : operand1  = %d,  tag1 = %d, operand2  = %d,  tag2 = %d", resEntries[3][16:1], resEntries[3][20:17], resEntries[3][36:21], resEntries[3][40:37]);
	end
endmodule

/*full = 00 means there is space for both instrctions. full = 01, there is space for only one instr, full = 11 no space for both*/
module allocateUnit(index1, index2, full, in, clk);
	input clk;
	input [3:0] in;
	output reg [1:0] index1, index2, full;
	always@(negedge clk)
	begin
		full = 2'b00;
		if(in[0] == 0)
		begin
			index1 = 2'b00;
			if(in[1] == 0)
				index2 = 2'b01;
			else if(in[2] == 0)
				index2 = 2'b10;
			else if(in[3] == 0)
				index2 = 2'b11;
			else
				full = 2'b01;
		end
		else if(in[1] == 0)
		begin
			index1 = 2'b01;
			if(in[2] == 0)
				index2 = 2'b10;
			else if(in[3] == 0)
				index2 = 2'b11;
			else
				full = 2'b01;
		end
		else if(in[2] == 0)
		begin
			index1 = 2'b10;
			if(in[3] == 0)
				index2 = 2'b11;
			else
				full = 2'b01;
		end
		else if(in[3] == 0)
		begin
			index1 = 2'b11;
			full = 2'b01;
		end
		else
			full = 2'b11;
	end
endmodule

/*a 20 bit value (CDBData) is written to CDB. CDBData[15:0] - data CDBData[19:16] - tag*/
module tagMatch(operand, tag, CDBData);
	input [41:0] CDBData;
	input [3:0] tag;
	//output reg match; // match = 1 implies a tag match
	output reg [15:0] operand;

	always@(*)
	begin
		if(tag == CDBData[19:16])
			operand <= CDBData[15:0];
		else if(tag == CDBData[40:37])
			operand <= CDBData[36:21];
	end
endmodule

/*sdb[i][32] = 0, store has only finished exec but not completed. 0 -> store fully completed*/
module StoreDataBuffer(full, ready, readData1, readData2, wIndex, readIndex1, readIndex2, wAddr, wData, store);
	input [2:0] readIndex1, readIndex2;
	input [15:0] wAddr, wData;
	output reg [31:0] readData1, readData2;
	output [2:0] wIndex;
	input store;

	reg [32:0]sdb [0:7];

	initial
	begin
		for(i=0; i<8; i=i+1)
			sdb[i] = 33'b0;
	end
	
	output reg [1:0] ready;
	output full; //1 indicates sdb is full
	allocateStore as(full, wIndex, {sdb[0][32], sdb[1][32], sdb[2][32], sdb[3][32], sdb[4][32], sdb[5][32], sdb[6][32], sdb[7][32]});

	always@(store)
	begin
		if(~full && store)
		begin
			sdb[wIndex] = {1'b1, wAddr, wData};
			//$display($time," SDB ::::::::::::::::: wAddr = %d wData = %d, wIndex = %d",wAddr, wData, wIndex);
		end
	end

	always@(readIndex1)
	begin
		if(sdb[readIndex1][32] == 1'b1)
		begin
			readData1 = sdb[readIndex1][31:0];
			sdb[readIndex1][32] = 1'b0;
			ready[0] = 1;
		end
		else
			ready[0] = 0;
	end

	always@(readIndex2)
	begin
		if(sdb[readIndex2][32] == 1'b1)
		begin
			readData2 = sdb[readIndex2][31:0];
			sdb[readIndex2][32] = 1'b0;
			ready[1] = 1;
		end
		else
			ready[1] = 0;
	end

	integer i;
	initial
	begin
		for(i=0; i<8; i=i+1)
			$display(" sdb %d	value = %d", i, sdb[i]);
		#300 for(i=0; i<8; i=i+1)
			$display(" sdb %d	value = %d", i, sdb[i]);
	end
	//always@(sdb[0])
		//$display(" -----------------------------sdb 0	addr = %d,  data = %d", sdb[0][31:16], sdb[0][15:0]);
	
endmodule

module allocateStore(full, out, in);
	input[7:0] in;
	output reg [2:0] out;
	output reg full;
	always@(in)
	begin
		full = 0;
		casex(in)
		 8'bxxxxxxx0: out = 3'b0;
		 8'bxxxxxx01: out = 3'b001;
		 8'bxxxxx011: out = 3'b010;
		 8'bxxxx0111: out = 3'b011;
		 8'bxxx01111: out = 3'b100;
		 8'bxx011111: out = 3'b101;
		 8'bx0111111: out = 3'b110;
		 8'b01111111: out = 3'b111;
		 default: full = 1;
		endcase
	end
endmodule
/*
datai refers to the whole of ROB corresponding to the tagi these 4 i/p & o/p are needed for sourceRead.
wbDatai has both dest addr and data
*/
module ReOrderBuffer1(stall, wbData1, wbData2, wbType1, wbType2, index1, index2, data1, data2, data3, data4, tag1, tag2, tag3, tag4, spec1, spec2, type1, type2, dest1, dest2, clk, wIndex1, wIndex2, wData1, wData2, correctionIndex, correction, flush);
	parameter ROB_DATA = 28;
	
	input [3:0] tag1, tag2, tag3, tag4, wIndex1, wIndex2;
	input clk, spec1, spec2, flush;
	input[15:0] wData1, wData2;
	//input [4:0] wDest1, wDest2;
	input [1:0] type1, type2;
	input [4:0] dest1, dest2;
	input [3:0] correctionIndex;
	input correction;
	 
	output reg [ROB_DATA-1:0] data1, data2, data3, data4;
	output reg [3:0] index1, index2;
	output reg [1:0] wbType1, wbType2;
	output reg [20:0] wbData1, wbData2;
	output reg stall;
	
	reg [27:0] robEntries[0:15];

	reg [3:0] head = 0;
	reg [3:0] tail = 0;

	integer i;
	initial
	begin
		head = 3'b001;
		tail = 3'b001;
		stall = 0;
		for(i=0; i<16; i=i+1)
			robEntries[i] = 28'b0;
		for(i=0; i<15; i=i+1)
			$display($time, " ROB : %d type = %d dest = %d data = %d busy = %b", i, robEntries[i][1:0], robEntries[i][6:2], robEntries[i][22:7], robEntries[i][27]);
		#200 for(i=0; i<15; i=i+1)
			$display($time, " ROB : %d type = %d dest = %d data = %d spec = %b busy = %d", i, robEntries[i][1:0], robEntries[i][6:2], robEntries[i][22:7], robEntries[i][26], robEntries[i][27]);
	end

	always@(head)
	begin
		if(head == 3'b000)
			head = 3'b001;
	end

	always@(tail)
	begin
		if(tail == 3'b000)
			tail = 3'b001;
	end	
	
	always@(tag1)
		data1 = robEntries[tag1];
	always@(tag2)
		data2 = robEntries[tag2];
	always@(tag3)
		data3 = robEntries[tag3];
	always@(tag4)
		data4 = robEntries[tag4];

	//this is updated in the decode stage for all instructions. value field is zero, since at that stage value wouldn't have been calculated. This is to make an entry in ROB while decoding
	always@(negedge clk) //recheck
	begin
		if(dest1 > 0)
		begin
		index1 = tail;
		if(robEntries[index1][27])
			stall = 1'b1;
		else
		begin	
			robEntries[index1] = {1'b1, spec1, 1'b0, 1'b0, 1'b0, 16'b0, dest1, type1};
			index2 = tail + 1; 
			tail = index2;
			stall = 1'b0;
			if(robEntries[index2][27])
				stall = 1'b1;
			else
			begin 
				robEntries[index2] = {1'b1, spec2, 1'b0, 1'b0, 1'b0, 16'b0, dest2, type2};
				stall = 1'b0;
				tail = tail + 1;
			end
		end
		//$display($time, " ROB : index1 = %d,  index2 = %d", index1, index2);
		end
	end

	reg [27:0] robEntryHead1;
	reg [27:0] robEntryHead2;
	always@(posedge clk)
	begin
		//$display($time, " ROB : head = %d spec = %b, ready = %b, finished = %b", head, robEntryHead1[26], robEntryHead1[23], robEntryHead1[24]);
		robEntryHead1 = robEntries[head];
		if(robEntryHead1[23] && robEntryHead1[24] && ~robEntryHead1[26])
		begin
			wbData1 = robEntryHead1[22:2];
			wbType1 = robEntryHead1[1:0];
			robEntryHead1[27] = 1'b1;
			head = head + 1;
			stall = 1'b0;
			//$display($time, " head = %d", head);
			robEntryHead2 = robEntries[head];
			if(robEntryHead2[23] && robEntryHead2[24] && ~robEntryHead2[26])
			begin
				wbData2 = robEntryHead2[22:2];
				wbType2 = robEntryHead2[1:0];
				robEntryHead2[27] = 1'b1;
				head = head + 1;
			end
			//else
			//	stall = 1'b1;
		end
		//else
		//	stall = 1'b1;
		//$display($time, " ROB : wbData1 = %d,  wbType1 = %d", wbData1, wbType1);
		//$display($time, " ROB : wbData2 = %d,  wbType2 = %d", wbData2, wbType2);
	end

	always@(wIndex1 or wData1)
	begin
		if(wData1 >= 0)
			robEntries[wIndex1][24:7] = {1'b1, 1'b1, wData1};
		//$display($time, " ROB : wIndex1 = %d,  wData1 = %d", wIndex1, wData1);
	end

	always@(wIndex2 or wData2)
	begin
		if(wData2 >= 0)
			robEntries[wIndex2][24:7] = {1'b1, 1'b1, wData2};
		//$display($time, " ROB : wIndex2 = %d,  wData2 = %d", wIndex2, wData2);
	end

	//to reset the speculative bits 
	integer k;
	always@(correctionIndex)
	begin
		if(correction)
		begin
			$display($time, " ROB : correctionIndex : %d",correctionIndex);
			robEntries[correctionIndex][24:23] = {1'b1, 1'b1};
			for(k=correctionIndex; k<tail; k = k+1)
				robEntries[k][26] = 0;
		end
	end

	integer j;
	always@(flush)
	begin
		if(flush)
		begin
			for(j = tail; j <= 0; j = j-1)
			begin
				if(robEntries[tail][26])
				begin
					robEntries[tail] = 28'b0;
					tail = tail - 1;
				end
					
			end
		end
	end
	//integer i;
	/*initial
	begin
		for(i=0; i<15; i=i+1)
			$display($time, "ROB : %d type = %d dest = %d data = %d", i, robEntries[i][1:0], robEntries[i][6:2], robEntries[i][22:7]);
		#80 for(i=1; i<16; i=i+1)
			$display($time, "ROB : %d type = %d dest = %d data = %d", i, registers[i][1:0], robEntries[i][6:2], robEntries[i][22:7]);
	end*/
endmodule

/*module ROB_test;
	reg [3:0] tag1, tag2, tag3, tag4, wIndex1, wIndex2;
	reg clk;
	reg [15:0] wData1, wData2;
	reg [1:0] type1, type2;
	reg [4:0] dest1, dest2;
	 
	wire [27:0] data1, data2, data3, data4;
	wire [3:0] index1, index2;
	wire [1:0] wbType1, wbType2;
	wire [20:0] wbData1, wbData2;
	wire stall;

	ReOrderBuffer1 rob(stall, wbData1, wbData2, wbType1, wbType2, index1, index2, data1, data2, data3, data4, tag1, tag2, tag3, tag4, type1, type2, dest1, dest2, clk, wIndex1, wIndex2, wData1, wData2);
	initial
	begin
		clk = 0;
		type1 = 2'b00;
		type2 = 2'b01;
		dest1 = 5'b00001;
		dest2 = 5'b00010;
		
		
		#5 type2 = 2'b00;
		dest1 = 5'b00011;
		dest2 = 5'b00100;
		
		#10 type1 = 2'b11; tag3 = 4'b0010; tag4 = 4'b0001;
		type2 = 2'b10;
		dest1 = 5'b00010;
		dest2 = 5'b00101;

		#10 tag1 = 4'b0001; tag2 = 4'b0011; wIndex1 = 4'b0001; wIndex2 = 4'b0010;
		wData1 = 16'h000A; wData2 = 16'h000B;

		#10 wIndex1 = 4'b0011; wIndex2 = 4'b0101;
		wData1 = 16'h000C; wData2 = 16'h000D;
	end
	always
		#5 clk = ~clk;
	initial
	begin
		$dumpfile("/home/jasmine/Desktop/SuperScalarProcessor/rob.vcd");
		$dumpon;
		$dumpvars;
		#80 $finish;
		#80 $dumpoff;
	end
endmodule*/
