module spi_controller(
    input PCLK,
    input PSEL,
	input PRESETn,
	input PWRITE,
	
	input [7:0] PADDR,
	input [31:0] PWDATA,     // to write the data
	input [31:0] MRDATA,     // to read the data
	
	input [7:0]SPISR,            // 7-SPIF, 6-RESERVED, 5-SPTEF, 4-MODF, 3 to 0-RESERVED     

    output wire clk,
    
	output reg [7:0]MADDR=0,
	output reg [31:0]MWDATA=0,                     
	output reg [31:0]PRDATA=0,
	
	output reg [7:0]SPICR_1,     // 7-RESERVED 6-SPE, 5-SPTIE, 4-MSTR, 3-CPOL, 2-CPHASE, 1-SSOE, 0-LSBFE
	output reg [7:0]SPICR_2,     // 7 to 1-RESERVED, 0-SPC0
	output reg [7:0]SPIBDR     // 7-RESERVED 6-SPPR2, 5-SPPR1, 4-SPPR0, 3-RESERVED, 2-SPR2, 1-SPR1, 0-SPR0   
    );
	 
    reg [1:0] current_state, next_state;
    reg clk_2;
    reg [31:0] counter = 4'd0;
    reg [31:0] divisor = 4'd0;
	assign clk = (divisor == 4'd1) ? PCLK : clk_2;
    always @(posedge PCLK) begin
        if (PRESETn || SPISR[0]==1) begin//****************************************************************run_time error here*********************************************//
            // Reset all registers and internal signals
            SPICR_1 <= 8'b0;
            SPICR_2 <= 8'b0;
            SPIBDR <= 8'b0;
            MADDR <= 32'b0;
            MWDATA <= 32'b0;
            PRDATA <= 32'b0;
        end else if (PSEL == 1'b1) begin
        if (PADDR[7:0] == 8'h00 && PWRITE == 1 && SPISR[5]==1) begin
                SPICR_1[7:0] <= PWDATA[7:0];          // REGISTER CONFIGURATION SPICR-1
                SPICR_2[7:0] <= PWDATA[15:8];         // REGISTER CONFIGURATION SPICR-2
                SPIBDR[7:0] <= PWDATA[23:16];         // BAUD RATE CONFIGURATION
        end else if (PADDR[7:0] == 8'h04 && PWRITE == 1 && SPISR[5]==1) begin
                MWDATA[31:0] <= PWDATA[31:0];
        end else if (PADDR[7:0] == 8'h08 && PWRITE == 0) begin
                PRDATA <= {24'b0, SPISR};
        end else if (PADDR[7:0] == 8'h0C && PWRITE == 0) begin
                 PRDATA <= MRDATA; 
        end else begin
            MADDR <= PADDR;
        end
    end
  end  
    always@(posedge PCLK)
    begin
        if (PRESETn) begin
            divisor <= 32'd0;
        end else begin
        if(SPIBDR[6:4]==3'b000 && SPIBDR[2:0]==3'b000)
            divisor <= 32'd1;
        else if(SPIBDR[6:4]==3'b000 && SPIBDR[2:0]==3'b001)
            divisor <= 32'd2;
        else if(SPIBDR[6:4]==3'b000 && SPIBDR[2:0]==3'b010)
            divisor <= 32'd10;
        else if(SPIBDR[6:4]==3'b000 && SPIBDR[2:0]==3'b011)
            divisor <= 32'd100000000;
        else
            divisor <= 32'd1;
  
        if(divisor>32'd1)
         begin
             counter <= counter + 32'd1;
             if(counter >= (divisor-1))
             counter <= 32'd0;
             clk_2 <= (counter<divisor/2)?1'b1:1'b0;
         end 
        else
         begin
            clk_2 <= 0;
         end
               
    end
  end    
endmodule
