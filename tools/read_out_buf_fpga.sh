#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

msg() {
  echo >&2 -e "${1-}"
}

if [[ $# -ne 1 ]]; then
    echo "Usage: read_out_buf_fpga.sh <path-to-elf>"
    exit 1
fi

fw_path=$1

out_buf_info=$(riscv64-unknown-elf-readelf -s $fw_path | grep out_buf | awk '{print $2, $3}') 
read -r out_buf_addr out_buf_size <<< $out_buf_info

echo $out_buf_addr
echo $out_buf_size

mkdir -p ${script_dir}/tmp/
${script_dir}/uart_debug.py --port /dev/ttyUSB0 --baudrate 115200 --dump-memory ${script_dir}/tmp/mem_dump.hex --start=0x$out_buf_addr --len=$out_buf_size