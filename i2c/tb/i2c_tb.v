`timescale 1ns / 1ps
`include "../rtl/i2c_top.v"
module i2c_tb;
    reg PCLK;
    reg PRESETn;
    reg PSEL;
    reg PENABLE;
    reg PWRITE;
    reg [7:0] PADDR;
    reg [7:0] PWDATA;
    wire [7:0] PRDATA;
    reg [31:0] captured_data;

    wire i2c_scl;
    wire i2c_sda;
    integer bit_count = 0;
    integer ack_count = 0;
    // I2C Open-Drain Bus Pull-ups
    // These force the bus high when no one is pulling it to ground
    pullup(i2c_scl);
    pullup(i2c_sda);

    // ==========================================
    // 2. Instantiate the Unit Under Test (UUT)
    // ==========================================
    i2c_top uut (
        .PCLK(PCLK), 
        .PRESETn(PRESETn), 
        .PSEL(PSEL), 
        .PENABLE(PENABLE), 
        .PWRITE(PWRITE), 
        .PADDR(PADDR), 
        .PWDATA(PWDATA), 
        .PRDATA(PRDATA), 
        .i2c_scl(i2c_scl), 
        .i2c_sda(i2c_sda)
    );


    initial begin
        PCLK = 0;
        forever #5 PCLK = ~PCLK; // 10ns period -> 100MHz
    end


    task apb_write(input [7:0] addr, input [7:0] data);
        begin
            @(posedge PCLK);
            PSEL = 1;
            PWRITE = 1;
            PADDR = addr;
            PWDATA = data;
            
            
            @(posedge PCLK);
            PENABLE = 1; 
            
            @(posedge PCLK);
            PSEL = 0;
            PENABLE = 0;
            PWRITE = 0;
        end
    endtask

    task apb_read(input [7:0] addr,output [31:0] out_data);
        begin
            @(posedge PCLK);
            PSEL = 1;
            PWRITE = 0;
            PADDR = addr;
            PENABLE = 0;
            
            @(posedge PCLK);
            PENABLE = 1;
            
            @(posedge PCLK);
            // PRDATA is valid on this edge
            PSEL = 0;
            PENABLE = 0;
            out_data =PRDATA;
        end
    endtask

    // ==========================================
    // 5. Dummy I2C Slave (ACK Generator)
    // ==========================================
    reg dummy_sda_pull = 0;
    
    // Drive SDA low if dummy_sda_pull is 1
    assign i2c_sda = (dummy_sda_pull) ? 1'b0 : 1'bz;
    

    
    always @(negedge i2c_scl) begin
        // Reset bit count on a basic heuristic 
        // (In a real slave, you would strictly detect the START condition)
        if (bit_count == 8) begin
            // 9th Clock Cycle: Pull SDA low to send ACK
            dummy_sda_pull <= 1'b1; 
            bit_count <= 0;
	    ack_count <= ack_count +1;
            $display("[%0t] Dummy Slave: Sent ACK", $time);
        end else begin
            // Release SDA and count data bits
            dummy_sda_pull <= 1'b0;
            bit_count <= bit_count + 1;
        end
    end

    // ==========================================
    // 6. Main Test Sequence
    // ==========================================
    initial begin
        // Initialize APB Interface
        PRESETn = 0;
        PSEL    = 0;
        PENABLE = 0;
        PWRITE  = 0;
        PADDR   = 8'h00;
        PWDATA  = 8'h00;

        // Apply Reset
        #50;
        PRESETn = 1; // Release Reset
        #50;

        $display("--- Initializing I2C Master Write Transfer ---");

        // Step 1: Configure Target Slave Address (Register 0x08)
        // Let's target Slave Address 0x5A
        apb_write(8'h08, 8'h5A); 
        apb_write(8'h04, 8'h05); 
        apb_write(8'h10, 8'hEE);


        apb_write(8'h00, 8'h03);
        $display("[%0t] Controller Configured. I2C Bus active...", $time);
	wait(ack_count == 2);
        apb_write(8'h10, 8'h11);
	wait(ack_count == 3);
        apb_write(8'h10, 8'hEE);
        // Step 5: Wait for the I2C transaction to complete
        // A 100kHz clock has a 10us period. 
        // 1 full byte write requires ~20 clock cycles (Start + Addr + ACK + Data + ACK + Stop)
        // 20 * 10us = 200us. Wait 250us to be safe.
	#200000;
        $finish;
    end


endmodule
