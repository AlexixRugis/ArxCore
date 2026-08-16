echo "IALU.sv TESTING"
iverilog -g2012 -o IALU_tb.vvp ../src/include/IALUTypes.sv ./IALU_tb.sv ../src/IALU.sv
if ($LASTEXITCODE -eq 0) {
    vvp IALU_tb.vvp
}