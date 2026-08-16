echo "Processor.sv debug port TESTING"
iverilog -g2012 -o ProcessorDebugPort_tb.vvp ./ProcessorDebugPort_tb.sv ../../src/Processor.sv
if ($LASTEXITCODE -eq 0) {
    vvp ProcessorDebugPort_tb.vvp
}