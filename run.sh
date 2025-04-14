#!/bin/bash
#------------------------------------------------------------------------------
# Script: run.sh
# Description: Compiles the Verilog files using iverilog, runs the testbench,
#              captures output, and compares it to the expected results.
# Usage: ./run.sh <test_number>
#------------------------------------------------------------------------------

# Check if the test number is provided
if [ -z "$1" ]; then
  echo "Error: specify the test number"
  exit 1
fi

# Compile Verilog sources
if ! iverilog -o tb *.v; then
    echo "Error in compiling verilog sources"
    exit 1
fi

# Prepare and run the test
cp "test/teste$1.mem" memory.mem
./tb | grep '===' > saida.out
cp saida.out "test/saida$1.out"
cp saida.vcd "test/saida$1.vcd"

# Clean up temporary files
rm saida.out saida.vcd memory.mem
rm tb

# Compare the generated output with the expected output
if diff --strip-trailing-cr "test/saida$1.out" "test/saida$1.ok" >/dev/null; then
  echo "OK"
  exit 0
else
  echo "ERROR (Diff between .out and .ok)"
  exit 1
fi
