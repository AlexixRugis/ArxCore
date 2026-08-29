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
    echo "Usage: run_arx_core.sh <path-to-elf>"
    exit 1
fi

fw_path=$1

mkdir -p ${script_dir}/tmp/
riscv64-unknown-elf-objcopy -O binary $fw_path ${script_dir}/tmp/firmware.bin
xxd -p -c4 ${script_dir}/tmp/firmware.bin | sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/' > ${script_dir}/tmp/firmware.hex

vsim -c -do "do ${script_dir}/ArxCore_tb.do +FIRMWARE_PATH=${script_dir}/tmp/firmware.hex"