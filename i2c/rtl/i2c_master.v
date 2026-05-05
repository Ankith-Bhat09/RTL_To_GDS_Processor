`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////

module i2c_master(
    input PCLK,
    input wire [7:0] control_reg,       // from i2c_controller
    input wire [7:0] slave_addr,        // from i2c_controller
    input wire [7:0] data_in,           // from i2c_controller
    input wire [7:0] data_count,        // from i2c_controller

    input wire din_write,               // from i2c_controller
    input wire dout_read,               // from i2c_controller

    output reg [7:0] status_reg=0,      // to i2c_controller
    output reg [7:0] data_out=0,        // to i2c_controller

    inout i2c_sda,                      // i/o pin
    inout i2c_scl                       // i/o pin
    );

        localparam 
            IDLE = 0,
            START = 1,
            ADDR = 2,
            ACK = 3,
            WDATA = 4,
            RDATA = 5,
            WWACK = 6,
            RACK = 7,
            STOP = 8;
            
        localparam
            f100 = 75,
            f400 = 19,
            f1mhz = 15,
            f3mhz = 5;
        
    reg clk = 1;
    reg [7:0] ccount = 0;
    reg [19:0] DIV = 0;

    reg [3:0] state,n_state;
    reg sda,scl;
    reg [7:0] TX_reg =  8'h00; // transmit shift register
    reg [7:0] RX_reg =  8'h00; // recieve shift register
    reg [7:0] s_addr =  8'h00; // slave address + r/w bit
    reg [3:0] count =   0;   // tx/rx bit count
    reg [7:0] d_count = 8'h00;
    wire enable;
    wire reset;
    reg ena = 0;
    reg en  = 0;

    //status signals
    wire xrdy;  // recieve ready status signal
    wire Rrdy;
    reg xrdy_temp = 1;
    reg Rrdy_temp = 1;
    reg  xrdy_set = 1;
    reg  Rrdy_set = 0;

    reg NackSent=0; // not used
    reg NackRcvd = 0;


    wire rw;   // R/W status bit
    wire rep; // repeated start
    wire NackMod; // control signal to send NACK bit 

    assign i2c_scl = (scl)?1'b1:1'b0;
    assign i2c_sda = (state == ACK || state == RDATA || state == WWACK || n_state == ACK || n_state == WWACK) ? 1'bz : ( (sda)? 1'bZ : 1'b0 );		//Changed this for different data

    always@(posedge clk)
    begin
        if (en) scl <= ~scl;
        else scl <= 1;
    end

    always@(negedge PCLK)
    begin
        if(!reset)
        begin
            xrdy_set <= 1'b0;
            Rrdy_set <= 1'b0;
            data_out <= 8'h00;

            Rrdy_temp <= 1'b0;
            TX_reg <= 8'h00;
            xrdy_temp <= 1'b0;
        end
        else
        begin
            if(din_write)
            begin
                xrdy_set <= 1'b0;
            end
            else if(dout_read)
            begin
                Rrdy_set <= 1'b0;
            end
            if(state  == RACK && Rrdy_temp == 1'b1)//changed this for different data
            begin
                data_out <= RX_reg;
                Rrdy_set  <=  1'b1;             
                Rrdy_temp <= 1'b0; 
            end
            if(state == ACK || state == WWACK || state == START)		//changed this for different data
            begin
            if(xrdy_temp)
            begin        
                TX_reg <= data_in;
                xrdy_set <= 1'b1;
                xrdy_temp <= 1'b0;
            end
            end
            else 
            begin
                Rrdy_temp <= 1'b1;
                xrdy_temp <= 1'b1;
            end
        end
    end

    assign xrdy = (din_write)?1'b0:xrdy_set;
    assign Rrdy = (dout_read)?1'b0:Rrdy_set;

    // reset logic and state transition
    always@(posedge clk or negedge reset)
    begin
        if(!reset)
        begin
            state <= IDLE;
        end
        else
        begin
            state <= n_state;
        end
    end

    /////////////////////////////////////////////////////////////////////////////////

    assign reset =      control_reg[0];
    assign enable =     control_reg[1];
    assign NackMod =    control_reg[2]; // not used
    assign rw =         control_reg[4];
    assign rep =        control_reg[5];

    /////////////////////////////////FSM start/////////////////////////////////////
    always@(negedge clk)
    begin
        case(state)
                IDLE : begin
                    sda <= 1'b1;
                    en <= 0;
                    NackRcvd <= 1'b0;
                    count <= 4'b0000;  
                    ena <= 0;
                    if(enable && (~ena))
                        n_state <= START;
                    else
                        n_state <= IDLE;
                end
                START: begin 
                        sda <= 0;
                        en <= 1;
                        n_state <= ADDR;
                        d_count <= data_count - 1'b1;
                        NackRcvd <= 1'b0;
                        s_addr[7:1] <= slave_addr[6:0]; //copying slave addr???????????
                        s_addr[0] <= control_reg[4];  // rw bit         
                        RX_reg <= 8'b00;                
                    end
                ADDR: begin
                    if (i2c_scl == 0) begin
                        if (count < 8) begin
                            sda <= s_addr[4'h7-count];
                            count <= count + 1'b1;
                            n_state <= ADDR;
                        end
                        else if(count == 4'b1000) begin
                            n_state <= ACK;                    
                        end
                    end
                    else n_state <= ADDR;
                end
                ACK: begin
                    sda <= i2c_sda;             
                    if (i2c_sda == 1) n_state <= STOP;
                    else begin                  
                        if (s_addr[0] == 0)
                            n_state <= WDATA;
                        else if (s_addr[0] == 1)
                            n_state <= RDATA;
                    end
                    count <= 4'b0000;
                end
                WDATA: begin                 
                    if (scl == 0) begin
                        if (count < 8) begin
                            sda <= TX_reg[4'h7-count];
                            count <= count + 1'b1;
                            n_state <= WDATA;
                        end
                        else if (count == 8) begin
                            n_state <= WWACK;                                               
                        end
                    end
                    else 
                        n_state <= WDATA;
                end
                WWACK: begin
                    sda <= i2c_sda;
                    if (i2c_sda == 1) begin
                        n_state <= WDATA;
                        count <= 1'b0;
                        NackRcvd <= 1'b1;
                    end
                    else begin
                        if (d_count > 0) begin
                            n_state <= WDATA;
                            d_count <= d_count - 1'b1;
                            count <= 1'b0;
                        end
                        else if (d_count == 0 && rep == 0)
                            n_state <= STOP;
                        else if (d_count == 0 && rep == 1) begin
                            n_state <= START;
                            d_count <= 0;
                        end
                    end
                end    
                RDATA: begin
                    if (scl == 1) begin
                        if (count < 7) begin
                            RX_reg[4'h7-count] <= i2c_sda;
                            count <= count + 1'b1;
                            n_state <= RDATA;
                        end
                        else if (count == 7) begin
                            n_state <= RACK;
                            RX_reg[4'h7-count] <= i2c_sda;
                        end
                    end
                    else n_state <= RDATA;
                end
                RACK: begin 
                    if (scl == 0) begin
                        sda <= 0;
                        n_state <= RACK;
                    end
                    else if (scl == 1) begin
                        sda <= 0;
                        if (d_count != 8'h00) begin
                            n_state <= RDATA;
                            d_count <= d_count -1'b1; 
                            count <= 0;
                        end
                        else
                            n_state <= STOP;
                            d_count <= 0;
                    end
                    else 
                        n_state <= RACK;
                end
                        
                STOP: begin
                    count <= 4'b0000;
                    en <= 0;
                    ena <= 1;
                    sda <= 0;
                    if (scl == 1) begin
                        sda <= 1;
                        n_state <= IDLE;
                    end
                    else n_state <= STOP;
                end
                
                default: begin
                    n_state <= IDLE;
                    sda <= 1;
                    
                    count <= 4'b0000;
                    en <= 0;
                end
        endcase
    end
    /////////////////////////////////// FSM END//////////////////////////////////////////

    /////////////////////////// status update////////////////////////////////////////////
    //************************************
         always @(posedge PCLK) begin       
            case(state)
                0:status_reg <= {1'b0,NackRcvd,1'b0,1'b0,Rrdy,xrdy,rw,1'b0};
                1:status_reg <= {1'b0,NackRcvd,1'b0,1'b0,Rrdy,xrdy,rw,1'b1};
                2:status_reg <= {1'b0,NackRcvd,1'b0,1'b0,Rrdy,xrdy,rw,1'b1};
                3:status_reg <= {1'b0,NackRcvd,1'b0,1'b0,Rrdy,xrdy,rw,1'b1};
                4:status_reg <= {1'b0,NackRcvd,1'b0,1'b0,Rrdy,xrdy,rw,1'b1};
                5:status_reg <= {1'b0,NackRcvd,1'b0,1'b0,Rrdy,xrdy,rw,1'b1};
                6:status_reg <= {1'b0,NackRcvd,1'b0,1'b0,Rrdy,xrdy,rw,1'b1};
                7:status_reg <= {1'b0,NackRcvd,1'b0,1'b0,Rrdy,xrdy,rw,1'b1};
                8:status_reg <= {1'b1,NackRcvd,1'b0,1'b0,Rrdy,xrdy,rw,1'b1};
                //////////////// stop, nackrcvd, reserved,nacksnt,rrdy,xrdy,rw,busy         
                default: status_reg <= 8'h00;
            endcase
    //      end
         end
        always @(*) begin
            case(control_reg[7:6])
                2'b00:DIV <= f100;
                2'b01:DIV <= f400;
                2'b10:DIV <= f1mhz;
                2'b11:DIV <= f3mhz;
                default:DIV <= f100;
            endcase
        end
        
        always @(posedge PCLK) begin
            if (ccount < DIV) begin
                ccount <= ccount + 1'b1;
            end
            else begin
                clk <= ~clk ;
                ccount <= 8'b0;
            end
        end 
endmodule
