`timescale 1ns / 1ps

module spi_tb();
    // Inputs
    reg PRESETn, PSEL, PCLK, PENABLE, PWRITE;
    reg [7:0] PADDR;
    reg [31:0] PWDATA;
    reg miso;

    // Outputs
    wire [31:0] PRDATA;
    wire ss, sclk, mosi;

    // Internal variable for the APB read back
    reg [31:0] captured_data;

    // Instantiate UUT
    spi_top uut (
        .PRESETn(PRESETn), .PSEL(PSEL), .PCLK(PCLK), .PENABLE(PENABLE),
        .PWRITE(PWRITE), .PADDR(PADDR), .PWDATA(PWDATA), .miso(miso),
        .PRDATA(PRDATA), .ss(ss), .sclk(sclk), .mosi(mosi)
    );

    // 100MHz System Clock
    initial PCLK = 0;
    always #5 PCLK = ~PCLK;

    // --- APB Write Task ---
    task apb_write(input [7:0] addr, input [31:0] data);
        begin
            @(posedge PCLK);
            PSEL = 1; PWRITE = 1; PADDR = addr; PWDATA = data;
            @(posedge PCLK);
            PENABLE = 1;
            @(posedge PCLK);
            PSEL = 0; PENABLE = 0;
        end
    endtask

    // --- APB Read Task ---
    task apb_read(input [7:0] addr, output [31:0] out_data);
        begin
            @(posedge PCLK);
            PSEL = 1; PWRITE = 0; PADDR = addr;
            @(posedge PCLK);
            PENABLE = 1;
            @(posedge PCLK);
            out_data = PRDATA;
            PSEL = 0; PENABLE = 0;
        end
    endtask

    always @(negedge sclk) begin
        if (!ss) begin
            // Simply toggle miso to provide some data pattern (e.g., 101010...)
            miso <= ~miso; 
        end else begin
            miso <= 0;
        end
    end

    // --- Main Test Sequence ---
    initial begin
        // Initialize
        PRESETn = 0; miso = 0; PSEL = 0; PENABLE = 0;
        
        // 1. Reset (Active-High per RTL)
        $display("Applying Reset...");
        PRESETn = 1; repeat(5) @(posedge PCLK);
        PRESETn = 0; repeat(5) @(posedge PCLK);

        // 2. Configure for Read/Write: MSTR=1, SPE=1, SSOE=1 (SPICR_1 = 0x52)
        $display("Configuring SPI...");
        apb_write(8'h00, 32'h00000052); 

        // 3. Trigger Transaction by writing to MWDATA
        $display("Starting Transaction...");
        apb_write(8'h04, 32'hFFFFFFFF); 

        // 4. Wait for hardware to finish 
        // The slave model above is handling MISO automatically now
        wait(ss == 0);
        wait(ss == 1);

        // 5. Read back the captured MISO data from MRDATA (0x0C)
        #50;
        apb_read(8'h0C, captured_data);
        $display("Data received from Slave: %h", captured_data);

        #100;
        $finish;
    end
endmodule