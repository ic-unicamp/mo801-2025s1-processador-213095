//------------------------------------------------------------------------------
// Module: tb
// Description: Testbench that instantiates the core (DUT) and memory modules,
//              generates the clock, applies reset, and monitors simulation events.
//------------------------------------------------------------------------------
module tb();

    // Testbench signals
    // Note that the reset is negative (resetn), meaning it is active low.
    // All registers are 32 bits wide, and the address is also 32 bits.
    // The code has 32 registers. All these values are hard-coded
    reg clk, resetn;
    wire we;
    wire [31:0] address, data_out, data_in;

    //--------------------------------------------------------------------------
    // Instantiate Core
    //--------------------------------------------------------------------------
    // This is the Device Under Test (DUT). It receives the clock and reset,
    // and interfaces with memory through address, data, and write-enable signals.
    core dut(
        .clk(clk),
        .resetn(resetn),
        .address(address),
        .data_out(data_out),
        .data_in(data_in),
        .we(we)
    );

    //--------------------------------------------------------------------------
    // Instantiate Memory
    //--------------------------------------------------------------------------
    // The memory module interfaces with the core. Data travels between the
    // core and memory; note that data_in for memory comes from data_out of core.
    memory m(
        .clk(clk),
        .address(address),
        .data_in(data_out),
        .data_out(data_in),
        .we(we)
    );

    //--------------------------------------------------------------------------
    // Clock Generator
    //--------------------------------------------------------------------------
    // Generates a clock signal that toggles every 1 time unit. Using the strict
    // comparison (===) ensures we check for the exact value of 1'b0.
    always #1 clk = (clk === 1'b0);

    //--------------------------------------------------------------------------
    // Simulation Control
    //--------------------------------------------------------------------------
    // Initial block to start simulation:
    //  - Sets up dumping of waveform data.
    //  - Applies a reset pulse.
    //  - Starts simulation and finishes after 4000 time units.
    initial begin
        $dumpfile("saida.vcd");
        $dumpvars(0, tb);
        resetn = 1'b0;      // Assert reset (active low)
        #11 resetn = 1'b1;  // Deassert reset after 11 time units
        $display("*** Starting simulation. ***");
        #4000 $finish;      // End simulation after 4000 time units
    end

    //--------------------------------------------------------------------------
    // Address Monitor
    //--------------------------------------------------------------------------
    // Monitors the 'address' signal:
    //  - If address reaches 4092 (0xFFC), display a message and end the simulation.
    //  - Otherwise, when the high-order bit (bit 11) of the address is set and 
    //    write enable (we) is high, display the memory write transaction.
    always @(posedge clk) begin
        if (address == 'hFFC) begin
            $display("Address reached 4092 (0xFFC). Stopping simulation.");
            $finish;
        end
        else if (address[11] == 1) begin
            if (we == 1) begin
                $display("=== M[0x%h] <- 0x%h", address, data_out);
            end
        end
    end

endmodule
