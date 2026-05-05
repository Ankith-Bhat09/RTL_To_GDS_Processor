`timescale 1ns / 1ps

module tb_i2c_read;

    // ==========================================
    // 1. Signal Declarations
    // ==========================================
    reg PCLK;
    reg PRESETn;
    reg PSEL;
    reg PENABLE;
    reg PWRITE;
    reg [7:0] PADDR;
    reg [7:0] PWDATA;
    wire [7:0] PRDATA;

    wire i2c_scl;
    wire i2c_sda;

    // I2C Open-Drain Pull-ups
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

    // ==========================================
    // 3. System Clock Generation (100 MHz)
    // ==========================================
    initial begin
        PCLK = 0;
        forever #5 PCLK = ~PCLK; 
    end

    // ==========================================
    // 4. APB Bus Tasks
    // ==========================================
    task apb_write(input [7:0] addr, input [7:0] data);
        begin
            @(posedge PCLK);
            PSEL = 1; PWRITE = 1; PADDR = addr; PWDATA = data; PENABLE = 0;
            @(posedge PCLK);
            PENABLE = 1; 
            @(posedge PCLK);
            PSEL = 0; PENABLE = 0; PWRITE = 0;
        end
    endtask

    task apb_read(input [7:0] addr);
        begin
            @(posedge PCLK);
            PSEL = 1; PWRITE = 0; PADDR = addr; PENABLE = 0;
            @(posedge PCLK);
            PENABLE = 1;
            @(posedge PCLK);
            // PRDATA is valid here
            PSEL = 0; PENABLE = 0;
        end
    endtask

    // ==========================================
    // 5. Advanced Dummy Slave (For Reading)
    // ==========================================
    reg dummy_sda_pull = 0;
    assign i2c_sda = (dummy_sda_pull) ? 1'b0 : 1'bz;
    
    integer bit_count = 0;
    integer byte_count = 0;
    reg [7:0] dummy_tx_data = 8'hA5; // The byte the slave will send to the master

    always @(negedge i2c_scl) begin
        if (bit_count == 8) begin
            // --- 9th Clock Cycle: ACK Phase ---
            if (byte_count == 0) begin
                // Address phase just finished. Slave MUST send an ACK.
                dummy_sda_pull <= 1'b1; 
                $display("[%0t] Dummy Slave: ACKing the Slave Address", $time);
            end else begin
                // Data read phase just finished. MASTER sends the ACK. Slave must release SDA.
                dummy_sda_pull <= 1'b0; 
                $display("[%0t] Dummy Slave: Released SDA for Master to ACK", $time);
            end
            
            bit_count <= 0;
            byte_count <= byte_count + 1;
            
        end else begin
            // --- Clock Cycles 1-8: Data Phase ---
            if (byte_count > 0) begin
                // We are in the Read Data phase. Shift out bits of 8'hA5.
                // Open drain logic: If the bit is 0, pull SDA low. If 1, let it float.
                dummy_sda_pull <= (dummy_tx_data[7 - bit_count] == 1'b0) ? 1'b1 : 1'b0;
            end else begin
                // Address Phase. Just listen (release SDA)
                dummy_sda_pull <= 1'b0;
            end
            
            bit_count <= bit_count + 1;
        end
    end

    // ==========================================
    // 6. Main Test Sequence (READ)
    // ==========================================
    initial begin
        PRESETn = 0; PSEL = 0; PENABLE = 0; PWRITE = 0; PADDR = 8'h00; PWDATA = 8'h00;

        #50; PRESETn = 1; #50; // Release Reset

        $display("--- Initializing I2C Master READ Transfer ---");

        // 1. Slave Address: 0x5A
        apb_write(8'h08, 8'h5A); 
        
        // 2. Data Count: 1 byte to read
        apb_write(8'h04, 8'h01); 

        // 3. Control Register: START Read
        // Bits [7:6] = 00 (100kHz)
        // Bit [5] = 0 (No Rep Start)
        // Bit [4] = 1 (READ MODE) <--- THIS IS THE KEY CHANGE
        // Bit [1] = 1 (Enable)
        // Bit [0] = 1 (Reset Released)
        // Binary: 0001_0011 = Hex: 0x13
        apb_write(8'h00, 8'h13);
        
        $display("[%0t] Controller Configured for READ. Waiting for bus...", $time);

        // Wait for the transaction to complete (~250us)
        #250000;

        // 4. Check Status Register (0x0C)
        apb_read(8'h0C);
        $display("[%0t] Final Status Register: %h", $time, PRDATA);

        // 5. Read the Received Data (Address 0x14)
        apb_read(8'h14);
        $display("[%0t] Master Received Data: %h (Expected: a5)", $time, PRDATA);
        
        if (PRDATA === 8'hA5)
            $display("SUCCESS! Read transaction perfectly matched.");
        else
            $display("ERROR! Data mismatch.");

        $display("--- Testbench Completed ---");
        $finish;
    end

endmodule
