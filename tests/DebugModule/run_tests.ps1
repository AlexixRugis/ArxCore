echo "PacketParser.sv TESTING"
iverilog -g2012 -o PacketParser_tb.vvp ./PacketParser_tb.sv ../../src/DebugModule/PacketParser.sv
if ($LASTEXITCODE -eq 0) {
    vvp PacketParser_tb.vvp
}
echo "PacketBuffer.sv TESTING"
iverilog -g2012 -o PacketBuffer_tb.vvp ./PacketBuffer_tb.sv ../../src/DebugModule/PacketBuffer.sv
if ($LASTEXITCODE -eq 0) {
    vvp PacketBuffer_tb.vvp
}
echo "DebugMemoryCopier.sv TESTING"
iverilog -g2012 -o DebugMemoryCopier_tb.vvp ./DebugMemoryCopier_tb.sv ../../src/DebugModule/DebugMemoryCopier.sv ../../src/DebugModule/ByteToWordAddrConverter.sv
if ($LASTEXITCODE -eq 0) {
    vvp DebugMemoryCopier_tb.vvp
}
echo "DebugModule.sv TESTING"
iverilog -g2012 -o DebugModule_tb.vvp ./DebugModule_tb.sv ../../src/DebugModule/DebugModule.sv ../../src/DebugModule/PacketBuffer.sv ../../src/DebugModule/PacketParser.sv ../../src/DebugModule/DebugMemoryCopier.sv ../../src/DebugModule/ByteToWordAddrConverter.sv ../../src/DebugModule/ResetController.sv
if ($LASTEXITCODE -eq 0) {
    vvp DebugModule_tb.vvp
}