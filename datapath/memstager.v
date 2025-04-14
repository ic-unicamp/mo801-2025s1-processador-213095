//------------------------------------------------------------------------------
// Module: memstager
// Description:
//   This module handles both memory load and store data modification for a 
//   RISC-V processor. It exists because frankly I have no  idea which module
//   should be responsible for it. It implements:
//     - A load unit that extracts and appropriately extends a byte, halfword,
//       or full word from a 32-bit memory word (data_in) based on the lower two
//       bits of the effective address and the load type (funct3).
//     - A store unit that, during a read-modify-write operation, updates a 
//       32-bit word by inserting a byte or halfword (from write_data) into the 
//       correct position determined by the address offset.
//   Supported load types (funct3):
//      3'b000 : LB  (Load Byte, sign-extended)
//      3'b001 : LH  (Load Half, sign-extended)
//      3'b010 : LW  (Load Word, no modification)
//      3'b100 : LBU (Load Byte Unsigned, zero-extended)
//      3'b101 : LHU (Load Half Unsigned, zero-extended)
//   Supported store types (funct3):
//      3'b000 : SB  (Store Byte)
//      3'b001 : SH  (Store Halfword)
//      3'b010 : SW  (Store Word)
//------------------------------------------------------------------------------
module memstager (
    input  [31:0] data_in,         // 32-bit memory word read (for load, store merge)
    input  [31:0] write_data,      // Data from register (to store)
    input  [1:0]  address_offset,  // Lower two bits of effective address (used for alignment)
    input  [2:0]  funct3,          // Operation specifier (load or store type)
    output [31:0] load_data,       // Processed load data output
    output reg [31:0] store_data   // Data word to be written in store operations
);
    localparam [2:0]
        OFFSET_1 = 2'b00,
        OFFSET_2 = 2'b01,
        OFFSET_3 = 2'b10;

    localparam [3:0]
        FUNCT3_LB  = 3'b000,
        FUNCT3_LH  = 3'b001,
        FUNCT3_LW  = 3'b010,
        FUNCT3_LBU = 3'b100,
        FUNCT3_LHU = 3'b101,
        FUNCT3_SB  = 3'b000,
        FUNCT3_SH  = 3'b001,
        FUNCT3_SW  = 3'b010;
    //--------------------------------------------------------------------------
    // LOAD UNIT
    //--------------------------------------------------------------------------
    // This section extracts the required portion of the data_in word and applies 
    // the appropriate extension (sign or zero) based on the load operation (funct3).

    // Extract a byte from data_in based on address_offset:
    //   address_offset selects one of the 4 bytes in the 32-bit word.
    wire [7:0] byte_data;
    assign byte_data = (address_offset == OFFSET_1) ? data_in[7:0]   :
                       (address_offset == OFFSET_2) ? data_in[15:8]  :
                       (address_offset == OFFSET_3) ? data_in[23:16] :
                                                      data_in[31:24];

    // Extract a halfword from data_in:
    // For halfword loads, a properly aligned address should be either 0 or 2.
    // In misaligned cases, default to using the lower half.
    wire [15:0] half_data;
    assign half_data = (address_offset == OFFSET_1) ? data_in[15:0]  :
                       (address_offset == OFFSET_3) ? data_in[31:16] :
                                                      data_in[15:0];

    // Final load_data assignment using a priority chain:
    //   - LB:  Sign-extend byte_data to 32 bits.
    //   - LH:  Sign-extend half_data to 32 bits.
    //   - LW:  Pass data_in directly.
    //   - LBU: Zero-extend byte_data.
    //   - LHU: Zero-extend half_data.
    //   - Default: Pass data_in.
    assign load_data = (funct3 == FUNCT3_LB) ?  {{24{byte_data[7]}}, byte_data}  :
                       (funct3 == FUNCT3_LH) ?  {{16{half_data[15]}}, half_data} :
                       (funct3 == FUNCT3_LW) ?  data_in                          :
                       (funct3 == FUNCT3_LBU) ? {24'b0, byte_data}               :
                       (funct3 == FUNCT3_LHU) ? {16'b0, half_data}               :
                                                data_in;                          

    //--------------------------------------------------------------------------
    // STORE UNIT
    //--------------------------------------------------------------------------
    // This section prepares the memory data to be written for store instructions.
    // It calculates the proper position for the byte or halfword from write_data,
    // and merges it with the original memory word (data_in) using a mask.


    // Calculate the shift amount for the target byte (address_offset * 8)
    // and create a mask that zeros out that byte in the original data_in.
    wire [4:0] byte_shift = {address_offset, 3'b000};  // Multiplication by 8
    wire [31:0] sb_mask   = ~(32'hFF << byte_shift);     // Mask for target byte
    wire [31:0] sb_data   = (write_data & 32'h000000FF) << byte_shift; // Shifted byte

    // For halfword, the significant bit of address_offset indicates the halfword:
    // if address_offset[1]==0, use lower 16 bits; if 1, use upper 16 bits.
    // Compute shift amount as address_offset[1] * 16.
    wire [4:0] half_shift = {1'b0, address_offset[1], 4'b000};  // 0 or 16
    wire [31:0] sh_mask   = ~(32'hFFFF << half_shift);          // Mask for target halfword
    wire [31:0] sh_data   = (write_data & 32'h0000FFFF) << half_shift; // Shifted halfword

    // A case statement selects the final store_data based on the store instruction type:
    //   - SB: Combine data_in with shifted byte data.
    //   - SH: Combine data_in with shifted halfword data.
    //   - SW: Directly use write_data as the memory word.
    //   - Default: Undefined operation.
    always @(*) begin
        case (funct3)
            FUNCT3_SB: // SB - Store Byte
                store_data = (data_in & sb_mask) | sb_data;
            FUNCT3_SH: // SH - Store Halfword
                store_data = (data_in & sh_mask) | sh_data;
            FUNCT3_SW: // SW - Store Word
                store_data = write_data;
            default: 
                store_data = 32'bx;
        endcase
    end
endmodule
