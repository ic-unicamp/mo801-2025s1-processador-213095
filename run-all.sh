#!/bin/bash
#------------------------------------------------------------------------------
# Script: run-all.sh
# Description: Loops through test files (00 to 99) and, if found, invokes run.sh
#              for each test.
#------------------------------------------------------------------------------
for a in $(seq -w 00 99); do
  if [ -f "test/teste${a}.mem" ]; then
    printf "Test ${a}: "
    ./run.sh "${a}"
  fi
done
