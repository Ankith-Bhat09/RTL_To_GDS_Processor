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
    task apb_read(input [7:0] addr, output [31:0] data);
        begin
            @(posedge PCLK);
            PSEL = 1; PWRITE = 0; PADDR = addr;
            @(posedge PCLK);
            PENABLE = 1;
            @(posedge PCLK);
            data = PRDATA;
            PSEL = 0; PENABLE = 0;
        end
    endtask

    // --- Main Test Sequence ---
    initial begin
        // Initialize
        PRESETn = 0;
        miso = 0;
        PSEL = 0; PENABLE = 0;
       
        // 1. Reset Pulse (Note: Your RTL uses PRESETn as Active-High reset)
        $display("Applying Reset...");
        PRESETn = 1;
        repeat(5) @(posedge PCLK);
        PRESETn = 0;
        repeat(5) @(posedge PCLK);

        // 2. Configure SPI: BaudRate=0, SPICR_2=0x01 (SPC0=1), SPICR_1=0x52 (SPE=1, MSTR=1, SSOE=1)
        // This targets PADDR 0x00
        apb_write(8'h00, 32'h00000152);

        // 3. Start Transmission: Write to MWDATA (PADDR 0x04)

        apb_write(8'h04, 32'h12345678);

        // 4. Wait for Transmission to Start
        wait(ss == 0);
        wait(ss == 1);

        #100;
        $finish;
    end
endmodule
