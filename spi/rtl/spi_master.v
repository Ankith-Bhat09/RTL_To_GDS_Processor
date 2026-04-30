module spi_master(
	input PCLK,
	input PRESETn,
	input miso,
	input [7:0]MADDR,
	input [31:0]MWDATA,                            
	input [7:0]SPICR_1,                 // 7-RESERVED 6-SPE, 5-SPTIE, 4-MSTR, 3-CPOL, 2-CPHASE, 1-SSOE, 0-LSBFE
	input [7:0]SPICR_2,                 // 7 to 1-RESERVED, 0-SPC0
	output reg [7:0]SPISR,        // 7-SPIF, 6-RESERVED, 5-SPTEF, 4-MODF, 3 to 0-RESERVED     
	output reg [31:0]MRDATA,
	output reg ss,
	output reg sclk,
	output reg mosi
    );
	reg [3:0] count1=4'b0,count2=4'b0; 
	reg [2:0] scount=3'b0;
	reg [7:0]SPIDR_W[0:3];
	reg [7:0]SPIDR_R[0:3];
	reg [7:0]temp;
	reg [3:0]dcount;

	localparam idle=3'b000, setup = 3'b001, write = 3'b010, read = 3'b011, delay = 3'b100, delay1 = 3'b101;

	reg [2:0]current_state,next_state;
	reg sclk_prev;

	wire rising_edge;
	wire falling_edge;
	wire sample_edge;
	wire shift_edge;
	wire leading_edge;
	wire trailing_edge;
	always @(posedge PCLK) begin
	    if (PRESETn) 
	    begin
	        sclk <= SPICR_1[3]; // CPOL
        	sclk_prev <= SPICR_1[3];
	    end
	    else
	    begin
	    	sclk_prev <=sclk;
		    if (current_state == write || current_state == read) begin
		        sclk <= ~sclk ; // Toggle sclk during write and read
		    end 
		    else
		    begin
		        sclk <= SPICR_1[3];
		    end
	    end
	end

	assign rising_edge   = (sclk_prev == 0 && sclk == 1);
	assign falling_edge  = (sclk_prev == 1 && sclk == 0);
	assign leading_edge  = (SPICR_1[3] == 0) ? rising_edge  : falling_edge;
	assign trailing_edge = (SPICR_1[3] == 0) ? falling_edge : rising_edge;
	assign sample_edge   = (SPICR_1[2] == 0) ? leading_edge  : trailing_edge;
	assign shift_edge    = (SPICR_1[2] == 0) ? trailing_edge : leading_edge;
//**********************************************************************************//Left here
	always @(posedge PCLK)
	begin
	    if(PRESETn)
	    begin
	        current_state <= idle;
	    end
	    else
	    begin
	        current_state <= next_state;
	    end
	end

		always@(posedge PCLK)
		begin
			case(current_state)
				idle:
				begin
				    SPISR =8'h20;       //SPTEF=1
				    mosi <= 0;
				    ss = 1 ;
				    count1=4'b0;
				    count2=4'b0;
				    scount=3'b0;
				    dcount=4'b0;
				    if(PRESETn==1)           // active low signal
	                begin
	                    next_state<=idle;
	                end
	                
	                else if(SPICR_1[6]==1 && MWDATA)
	                begin
	                    SPIDR_W[0][7:0]<=0;
	                    SPIDR_W[1][7:0]<=0;
	                    SPIDR_W[2][7:0]<=0;
	                    SPIDR_W[3][7:0]<=0;
	                    
	                    next_state <= setup;
	                end
	                
	                else if(SPICR_1[6]==1 && ~SPICR_2[0])
	                begin                   
	                    SPIDR_R[0][7:0]<=0;
	                    SPIDR_R[1][7:0]<=0;
	                    SPIDR_R[2][7:0]<=0;
	                    SPIDR_R[3][7:0]<=0;  
	                    
	                    next_state <= setup;
	                end
	                
	                else
	                begin
	                    next_state <= idle;
	                end
	            end
	            
				setup:
				begin
				     if(SPICR_1[1]==1'b1)
				     begin
				        ss= 0;                              // slave select active low
				     end
				    
	                 if(SPICR_1[4]==1'b1 && SPICR_2[0]==1'b1 && SPISR[5]==1'b1)
	                 begin
	                    SPISR[7] = 1'b1;   // SPIF bit New Data is copied to spidr
	                    if(SPICR_1[0]==1)                      // lsb first
	                    begin
	                        temp = {MWDATA[0],MWDATA[1],MWDATA[2],MWDATA[3],MWDATA[4],MWDATA[5],MWDATA[6],MWDATA[7]};
	                        SPIDR_W[0][7:0]= temp;
	                        temp = {MWDATA[8],MWDATA[9],MWDATA[10],MWDATA[11],MWDATA[12],MWDATA[13],MWDATA[14],MWDATA[15]};
	                        SPIDR_W[1][7:0]= temp;
	                        temp = {MWDATA[16],MWDATA[17],MWDATA[18],MWDATA[19],MWDATA[20],MWDATA[21],MWDATA[22],MWDATA[23]};
	                        SPIDR_W[2][7:0]= temp;
	                        temp = {MWDATA[24],MWDATA[25],MWDATA[26],MWDATA[27],MWDATA[28],MWDATA[29],MWDATA[30],MWDATA[31]};
	                        SPIDR_W[3][7:0]= temp;
	                    end
	                    
	                    else if(SPICR_1[0]==0)                 //msb first
	                    begin
	                        SPIDR_W[3][7:0]<= MWDATA[7:0];
	                        SPIDR_W[2][7:0]<= MWDATA[15:8];
	                        SPIDR_W[1][7:0]<= MWDATA[23:16];
	                        SPIDR_W[0][7:0]<= MWDATA[31:24];
	                    end
	                
	                    next_state <= write;
	                 end
	                
	                 else if(SPICR_1[4] == 1'b0 && SPICR_2[0]==1'b0)
			         begin
				         next_state <= read;
			         end
			          
			         else if(SPICR_1[6]==0)
			         begin
		                 next_state <= idle;
			         end
				end
				
				write:
				begin
					if(scount<3'd4)
					begin
					   if(count1<4'd8)                             // 8bit BIT
					   begin
					       SPISR[5] = 1'b0;                       //SPTEF=0;
					       SPISR[7] = 1'b0;                       //SPIF = 0 Transfer not yet complete
						   if(shift_edge)
					       begin
							   mosi<=SPIDR_W[scount][4'h7-count1];
							   count1=count1+1'b1;
						   end
					   end
						
					   if(count1==4'd8)                      // 32 BIT
					   begin						
						  count1=0;
						  scount=scount+1;
						  next_state<=write;
					   end
				   end
					   
				   else if(scount==3'd4)
				   begin
				       scount=3'b0;
				       SPISR[0] = 1'b1; 
				       next_state<=idle;
				   end
					
		    	   else if(SPICR_1[6]==1'b0)
				   begin
				        next_state<=idle;
				   end
			    end
				
				read:
				begin
				    if(scount<3'd4)
				    begin
					    if(count2<4'd8)                            //32 BIT
					    begin
						   if(sample_edge)
					       begin
						   SPIDR_R[scount][4'h7-count2]<=miso;
						   count2=count2+1'b1;
						   end
					    end
					
					    if(count2==4'd8)
					    begin   
						   count2=0;
						   scount=scount+1;					
						   next_state<=read;
					    end
				     end
				
				if(scount==3'd4)
				begin
				     scount=3'b0;                        	
				     MRDATA[7:0]=SPIDR_R[3][7:0];
				     MRDATA[15:8]=SPIDR_R[2][7:0];
				     MRDATA[23:16]=SPIDR_R[1][7:0];
				     MRDATA[31:24]=SPIDR_R[0][7:0];
				     SPISR[6] = 1'b1;                  //SPTEF_R=1 
				     next_state<=delay;
				end
			end
			
			delay: begin                       //delay transitions so that there should be time to read data before reset everthing
			       if(dcount==4'b1010)begin
			        dcount=0;
			        next_state<=delay1;
			        end
			        else begin 
			        dcount = dcount+1;
			        next_state<=delay;
	                end
			       end
	 
			delay1: begin
			       SPISR[0] = 1'b1;
			       next_state<=idle;
			       end
			       
	    		default:
				begin
					next_state<=idle;
				end
			endcase
		end	
endmodule
