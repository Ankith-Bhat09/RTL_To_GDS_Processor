`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////

module i2c_controller(
    input wire PCLK,                    // from processor
    input wire PRESETn,                 // from processor
    input wire PSEL,                    // from processor
    input wire PENABLE,                 // from processor 
    input wire PWRITE,                  // from processor 
    input wire [7:0] PADDR,             // from processor
    input wire [31:0] PWDATA,           // from processor
    
    input wire [7:0] data_out,          // from i2c_master
    input wire [7:0] status_reg,        // from i2c master
    
    output reg din_write=0,
    output reg dout_read = 0,    
        
    output reg [31:0] PRDATA = 0,       // to processor
    output reg [7:0] control_reg = 0,   // to i2c master
    output reg [7:0] slave_addr,        // to i2c master
    output reg [7:0] data_in,           // to i2c master
    output reg [7:0] data_count         // to i2c master
    );

    always @(negedge PCLK) 
    begin
        if(!PRESETn)    // The preset negetive edge bug was fixed
        begin
           PRDATA <= 8'h00; 
           control_reg <= 8'h00;
           slave_addr  <= 8'h00;
           data_in     <= 8'h00;
           data_count  <= 8'h00;
           din_write   <= 1'b0;
           dout_read   <= 1'b0;
        end

        else if (PSEL ==1'b1)
            begin
                if(PADDR == 8'h00 && PWRITE == 1 ) begin // control reg access
                    control_reg <= PWDATA[7:0];
                    din_write <= 1'b0;  
                    dout_read <= 1'b0;               
                end 
                                
                else if (PADDR[7:0] == 8'h04 && PWRITE == 1) begin // data count reg access
                    data_count <= PWDATA[7:0];
                    din_write <= 1'b0; 
                    dout_read <= 1'b0;               
                end 
                                
                else if (PADDR[7:0] == 8'h08 && PWRITE == 1) begin // slave addr reg access
                    slave_addr <= PWDATA[7:0]; 
                    din_write <= 1'b0;
                    dout_read <= 1'b0;               
                end 
                                
                else if (PADDR[7:0] == 8'h0c && PWRITE == 0) begin // status reg access
                    PRDATA[7:0] <= status_reg;   // read    
                    din_write <= 1'b0;
                    dout_read <= 1'b0;                      
                end 
            
                else if (PADDR[7:0] == 8'h10 && PWRITE == 1) begin // data in reg access
                    data_in <= PWDATA[7:0]; // write
                    din_write <= 1'b1;  
                    dout_read <= 1'b0;                          
                end 
                
                else if (PADDR[7:0] == 8'h14 && PWRITE == 0) begin // data out reg access
                    PRDATA[7:0] <= data_out; // read
                    din_write <= 1'b0;
                    dout_read <= 1'b1;              
                end 

                else begin
                           PRDATA[7:0] <= 8'h00;
                           din_write <= 1'b0;
                           dout_read <= 1'b0;   
                end

            end
    end 
endmodule
