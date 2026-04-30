`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////

module spi_top (
  input wire PRESETn,
  input wire PSEL,
	input wire PCLK,
	input wire PENABLE,
	input wire PWRITE,
	
	input wire [7:0] PADDR,
	input wire [31:0] PWDATA,
	input wire miso,
    
	output wire [31:0] PRDATA,
	output wire ss,
	output wire sclk,
	output wire mosi
    );
    wire clk;
    wire [31:0] MWDATA,MRDATA;  
    wire [7:0] MADDR;
    wire [7:0]SPICR_1,SPICR_2,SPIBDR,SPISR;

    spi_controller controller(
    .PCLK(PCLK),
    .PSEL(PSEL),
	.PRESETn(PRESETn),
	.PWRITE(PWRITE),
	.PADDR(PADDR),
	.PWDATA(PWDATA),
	.MRDATA(MRDATA), 
	.SPISR(SPISR),    
	.clk(clk),
	.MADDR(MADDR),
	.MWDATA(MWDATA),                     
	.PRDATA(PRDATA),
	.SPICR_1(SPICR_1),
	.SPICR_2(SPICR_2),
	.SPIBDR(SPIBDR)
    );
    
    spi_master master(
    .PCLK(clk),
    .PRESETn(PRESETn),
    .miso(miso),
    .MADDR(MADDR),
    .MWDATA(MWDATA),
    .SPICR_1(SPICR_1),                    // 7-6 RESERVED 5-SPIF, 4-SPE, 3-MSTR, 2-CPOL, 1-CPHASE, 0-LSBFE
    .SPICR_2(SPICR_2),                    // 7 to 1-RESERVED, 0-SPC0
    .SPISR(SPISR),                        // 7-3 RESERVED 2-TXCR 1-TXCW 0-SPTEF                
    .MRDATA(MRDATA),
    .ss(ss),
    .sclk(sclk),
    .mosi(mosi)  
    );   
endmodule
//////////////////////////////////////////////////////////////////////////////////
