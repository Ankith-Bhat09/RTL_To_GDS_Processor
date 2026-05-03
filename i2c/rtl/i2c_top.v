`timescale 1ns / 1ps
`include "../rtl/i2c_master.v"
`include "../rtl/i2c_controller.v"
////////////////////////////////////////////////////////////////////////////

module i2c_top(
    input wire PCLK,                   
    input wire PRESETn,                  
    input wire PSEL,              
    input wire PENABLE,
    input wire PWRITE,            
    input wire [7:0] PADDR,       
    input wire [7:0] PWDATA,
    output [7:0]PRDATA,
    inout i2c_scl,
    inout i2c_sda
    );
    
    wire [7:0] data_out;
    wire [7:0] status_reg;
    wire din_write;  
    wire [7:0] control_reg;
    wire [7:0] slave_addr;
    wire [7:0] data_in;
    wire [7:0] data_count;
    wire dout_read;
    
    i2c_controller controller(
    .PCLK(PCLK),
    .PRESETn(PRESETn),
    .PSEL(PSEL),
    .PENABLE(PENABLE),
    .PWRITE(PWRITE),
    .PADDR(PADDR),
    .PWDATA(PWDATA),
    .data_out(data_out),
    .status_reg(status_reg),
    .din_write(din_write),
    .dout_read(dout_read),
    .PRDATA(PRDATA),
    .control_reg(control_reg),
    .slave_addr(slave_addr),
    .data_in(data_in),
    .data_count(data_count)
    );
    
    i2c_master master(
    .PCLK(PCLK),
    .control_reg(control_reg),
    .slave_addr(slave_addr),
    .data_in(data_in),
    .data_count(data_count),
    .din_write(din_write),
    .dout_read(dout_read),
    .status_reg(status_reg),
    .data_out(data_out),
    .i2c_sda(i2c_sda),
    .i2c_scl(i2c_scl)
    );
endmodule
