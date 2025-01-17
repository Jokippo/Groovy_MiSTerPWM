//
// ddram.v
// Copyright (c) 2019 Sorgelig
//
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version. 
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
// ------------------------------------------
//
// 24b version

module ddram
(
        input         DDRAM_CLK,
        input         DDRAM_BUSY,
        output  [7:0] DDRAM_BURSTCNT,
        output [28:0] DDRAM_ADDR,
        input  [63:0] DDRAM_DOUT,
        input         DDRAM_DOUT_READY,
        output        DDRAM_RD,
        output [63:0] DDRAM_DIN,
        output  [7:0] DDRAM_BE,
        output        DDRAM_WE,
        
        input  [27:1] mem_addr,
        output [63:0] mem_dout,
        input         mem_dout_ch,   
        input  [63:0] mem_din,
        input         mem_rd,
        input         mem_rd_ch,        
        input  [7:0]  mem_burst,
        input         mem_wr,           
        output        mem_busy,
        output        mem_dready,
        
                        
        output [959:0] mem960_dout
                                        
);

reg  [7:0] ram_burst;
reg [63:0] ram_out;
reg[959:0] ram_out960[2] = '{2{0}};
reg [63:0] ram_data;
reg [27:1] ram_address;

reg        ram_read = 0;
reg        ram_write = 0;
reg  [7:0] ram_be = 8'hFF;
reg        ram_ch = 0;
reg  [7:0] ram_index = 0;

reg data_ready = 0;
reg write_req = 0;
reg read_req = 0;

reg [2:0] state = 3'b000;

always @(posedge DDRAM_CLK) begin                                       
        
        reg old_rd, old_we;
        
        old_rd       <= mem_rd; 
        old_we       <= mem_wr;  
   
        if (mem_wr && !old_we) write_req <= 1; 
        if (mem_rd && !old_rd) read_req <= 1; 
        
        data_ready <= 0;        
        
        if(!DDRAM_BUSY) begin    
                ram_write <= 0;
                ram_read  <= 0;
                
                case(state)
                        3'b000: 
                        begin                                
                          if (write_req && !read_req) begin                                                 
                            ram_data      <= mem_din; 
                            ram_address   <= mem_addr; 
                            ram_write     <= 1;                                          
                            state         <= 3'b001;                       
                          end                            
                           else if (read_req && !write_req) begin                           
                            ram_address   <= mem_addr;                                                                                     
                            ram_ch        <= mem_rd_ch;
                            ram_read      <= 1;                     
                            ram_burst     <= mem_burst;                                                                             
                            state         <= 3'b010;
                           end                                                                                                            
                        end      
                        3'b001:        
                        begin                                   
                           write_req                        <= 0;
                           state               <= 3'b000;                                                                       
                        end                     
                        3'b010:         
                        begin  
                          if (DDRAM_DOUT_READY) begin
                           ram_out                    <= DDRAM_DOUT;
                           ram_out960[ram_ch][63:0]   <= DDRAM_DOUT;       
                           if (ram_burst > 8'd1) begin
                             state                    <= 3'b100;   
                             ram_index                <= 8'd2;                              
                            end else begin
                             state                    <= 3'b000;
                             data_ready               <= 1;                
                             read_req                 <= 0;              
                            end                                               
                          end
                        end
                        3'b100:         
                        begin  
                          if (DDRAM_DOUT_READY) begin
                            ram_out960[ram_ch][((ram_index-1) << 6) +:64] <= DDRAM_DOUT;
                            if (ram_index == ram_burst) begin
                              state                   <= 3'b000;
                              data_ready              <= 1;                
                              read_req                <= 0;               
                            end else begin
                              ram_index <= ram_index + 8'd1;
                            end                             
                          end    
                        end                               
                endcase
        end 
   
end

assign DDRAM_BURSTCNT = DDRAM_WE ? 8'd1 : ram_burst;
assign DDRAM_BE       = ram_read ? 8'hFF : ram_be;
//assign DDRAM_ADDR     = {4'b0011, ram_address[27:3]}; // RAM at 0x30000000
assign DDRAM_ADDR     = {6'b000111, ram_address[25:3]}; // RAM at 0x1C000000 (Faster!)
assign DDRAM_RD       = ram_read;
assign DDRAM_DIN      = ram_data;
assign DDRAM_WE       = ram_write;

assign mem_dout         = ram_out;
assign mem960_dout      = ram_out960[mem_dout_ch];
assign mem_dready       = data_ready;
assign mem_busy         = write_req || read_req;


endmodule