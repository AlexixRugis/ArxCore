#!/usr/bin/env python3
"""
UART Debug Tool for RISC-V Debug Module
Protocol: [CMD][ID][LEN][DATA] for requests
          [STATUS][ID][LEN][DATA] for responses
"""

import serial
import sys
import argparse
import time
import struct
from typing import Optional, List, Tuple
import threading
from enum import IntEnum

# ============================================================================
# Коды команд (соответствуют таблице из чата)
# ============================================================================
class Command(IntEnum):
    CMD_HALT          = 0x00
    CMD_RESUME        = 0x01
    CMD_READ_PROG     = 0x02
    CMD_WRITE_PROG    = 0x03
    CMD_READ_DATA     = 0x04
    CMD_WRITE_DATA    = 0x05
    CMD_SOFT_RST      = 0x06
    CMD_GET_STATE     = 0x07


# ============================================================================
# Коды статуса
# ============================================================================
class Status(IntEnum):
    STATUS_OK            = 0x00
    STATUS_ERROR_PARITY  = 0xFF
    STATUS_ERROR_ARGS    = 0xFE
    STATUS_ERROR_CMD     = 0xFD


# ============================================================================
# Класс исключения для ошибок протокола
# ============================================================================
class DebugProtocolError(Exception):
    pass


# ============================================================================
# Основной класс для работы с UART
# ============================================================================
class UARTDebugger:
    def __init__(self, port: str, baudrate: int = 115200, timeout: float = 2.0):
        """
        Инициализация UART соединения
        
        Args:
            port: COM порт (например, 'COM3' на Windows или '/dev/ttyUSB0' на Linux)
            baudrate: скорость UART
            timeout: таймаут в секундах
        """
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout
        self.ser = None
        self.next_id = 1
        
    def connect(self):
        """Открытие UART соединения"""
        try:
            self.ser = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_EVEN,
                stopbits=serial.STOPBITS_TWO,
                timeout=self.timeout
            )
            print(f"Connected to {self.port} at {self.baudrate} baud")
        except serial.SerialException as e:
            raise DebugProtocolError(f"Failed to connect: {e}")
    
    def disconnect(self):
        """Закрытие UART соединения"""
        if self.ser and self.ser.is_open:
            self.ser.close()
            print("Disconnected")
    
    def _next_id(self) -> int:
        """Генерация следующего ID пакета"""
        id_val = self.next_id
        self.next_id = (self.next_id + 1) & 0xFF
        return id_val
    
    def _send_packet(self, cmd: int, data: bytes = b'', packet_id: Optional[int] = None) -> int:
        """
        Отправка пакета
        
        Returns:
            ID отправленного пакета
        """
        if packet_id is None:
            packet_id = self._next_id()
        
        length = len(data)
        if length > 255:
            raise DebugProtocolError(f"Data too long: {length} > 255")
        
        # Формирование пакета: [CMD][ID][LEN][DATA]
        packet = bytes([cmd, packet_id, length]) + data
        
        self.ser.write(packet)
        #print(f"Sent: CMD=0x{cmd:02X}, ID=0x{packet_id:02X}, LEN={length}")
        #if length > 0:
        #    print(f"      Data: {' '.join([f'0x{b:02X}' for b in data])}")
        
        return packet_id
    
    def _receive_response(self, expected_id: Optional[int] = None) -> Tuple[int, int, bytes]:
        """
        Прием ответа
        
        Returns:
            (status, id, data)
        """
        # Чтение заголовка (3 байта)
        header = self.ser.read(3)
        if len(header) < 3:
            raise DebugProtocolError("Timeout waiting for response header")
        
        status, resp_id, length = header
        
        # Чтение данных
        data = b''
        if length > 0:
            data = self.ser.read(length)
            if len(data) < length:
                raise DebugProtocolError(f"Timeout waiting for response data: expected {length}, got {len(data)}")
        
        #print(f"Received: STATUS=0x{status:02X}, ID=0x{resp_id:02X}, LEN={length}")
        #if length > 0:
        #    print(f"         Data: {' '.join([f'0x{b:02X}' for b in data])}")
        
        # Проверка ID, если ожидается конкретный
        if expected_id is not None and resp_id != expected_id:
            print(f"Warning: Expected ID 0x{expected_id:02X}, got 0x{resp_id:02X}")
        
        # Проверка статуса
        if status != Status.STATUS_OK:
            print(f"Warning: Non-OK status: 0x{status:02X}")
        
        return status, resp_id, data
    
    def execute_command(self, cmd: int, data: bytes = b'', 
                       check_status: bool = True) -> Tuple[int, int, bytes]:
        packet_id = self._send_packet(cmd, data)
        status, resp_id, resp_data = self._receive_response(packet_id)
        
        if check_status and status != Status.STATUS_OK:
            print(f"Command failed with status 0x{status:02X}")
            
        return status, resp_id, resp_data
    
    # ========================================================================
    # Высокоуровневые команды
    # ========================================================================
    
    def halt(self) -> bool:
        """Остановка ядра"""
        status, _, _ = self.execute_command(Command.CMD_HALT, b'')
        return status == Status.STATUS_OK
    
    def resume(self) -> bool:
        """Возобновление выполнения"""
        status, _, _ = self.execute_command(Command.CMD_RESUME, b'')
        return status == Status.STATUS_OK
    
    def soft_rst(self) -> bool:
        """Сброс ядра"""
        status, _, _, = self.execute_command(Command.CMD_SOFT_RST, b'')
        return status == Status.STATUS_OK
    
    def get_state(self) -> Optional[dict]:
        """Получение текущего состояния ядра"""
        status, _, resp_data = self.execute_command(Command.CMD_GET_STATE, b'')
        if status != Status.STATUS_OK:
            return None
        if len(resp_data) != 1:
            return None
        return { 'is_halted' : bool(resp_data[0]) }
    
    # ========================================================================
    # Работа с программной памятью
    # ========================================================================
    
    def read_prog(self, address: int, size: int) -> Optional[bytes]:
        """Чтение из памяти программ"""
        if size < 1 or size > 255:
            raise ValueError(f"Invalid size: {size}")
        
        addr_bytes = struct.pack('>IB', address, size)
        
        status, _, resp_data = self.execute_command(Command.CMD_READ_PROG, addr_bytes)
        
        if status == Status.STATUS_OK:
            return resp_data
        return None
    
    def write_prog(self, address: int, data_bytes: bytes) -> bool:
        """Запись в память программ"""
        if len(data_bytes) < 1 or len(data_bytes) > 255:
            raise ValueError(f"Invalid data length: {len(data_bytes)}")
        
        addr_bytes = struct.pack('>I', address)
        data = addr_bytes + data_bytes
        
        status, _, _ = self.execute_command(Command.CMD_WRITE_PROG, data)
        return status == Status.STATUS_OK
    
    # ========================================================================
    # Работа с памятью данных
    # ========================================================================
    
    def read_data(self, address: int, size: int) -> Optional[bytes]:
        """Чтение из памяти данных"""
        if size < 1 or size > 255:
            raise ValueError(f"Invalid size: {size}")
        
        addr_bytes = struct.pack('>IB', address, size)
        
        status, _, resp_data = self.execute_command(Command.CMD_READ_DATA, addr_bytes)
        
        if status == Status.STATUS_OK:
            return resp_data
        return None
    
    def write_data(self, address: int, data_bytes: bytes) -> bool:
        """Запись в память данных"""
        if len(data_bytes) < 1 or len(data_bytes) > 255:
            raise ValueError(f"Invalid data length: {len(data_bytes)}")
        
        addr_bytes = struct.pack('>I', address)
        data = addr_bytes + data_bytes
        
        status, _, _ = self.execute_command(Command.CMD_WRITE_DATA, data)
        return status == Status.STATUS_OK
    
def run_tests(debugger: UARTDebugger):        
    print("\n--- Test 1: HALT ---")
    if debugger.halt():
        print("Core halted successfully")
    else:
        print("Failed to halt core")
        
    print("\n--- Test 2: GET STATE ---")
    state = debugger.get_state()
    if state and state["is_halted"]:
        print("State is halted")
    else:
        print("Failed to get core state")
    
    # prog memory tests
    print("\n--- Test 3: READ MEMORY CHUNK ---")
    read_data = debugger.read_prog(0x0000, 251)
    if read_data:
        print(f"Read from 0x0020: {' '.join([f'0x{b:02X}' for b in read_data])}")
    
    print("\n--- Test 4: READ MEMORY WORD ---")
    read_data = debugger.read_prog(0x0020, 4)
    if read_data:
        print(f"Read from 0x0020: {' '.join([f'0x{b:02X}' for b in read_data])}")
    
    print("\n--- Test 5: WRITE MEMORY NON ALIGNED ---")
    test_data = bytes([0x11, 0x22, 0x33, 0x44, 0x55, 0x66])
    if debugger.write_prog(0x0023, test_data):
        print(f"Written {len(test_data)} bytes to 0x0023")
    
    print("\n--- Test 6: READ MEMORY NON ALIGNED ---")
    read_data = debugger.read_prog(0x0023, 6)
    if read_data:
        print(f"Read from 0x0023: {' '.join([f'0x{b:02X}' for b in read_data])}")
        if read_data == test_data:
            print("Data matches!")
            
    # data memory tests
    print("\n--- Test 7: READ DATA MEMORY CHUNK ---")
    read_data = debugger.read_data(0x0320, 126)
    if read_data:
        print(f"Read from 0x0020: {' '.join([f'0x{b:02X}' for b in read_data])}")
    
    print("\n--- Test 8: READ DATA MEMORY WORD ---")
    read_data = debugger.read_data(0x0020, 4)
    if read_data:
        print(f"Read from 0x0020: {' '.join([f'0x{b:02X}' for b in read_data])}")
    
    print("\n--- Test 9: WRITE DATA MEMORY NON ALIGNED ---")
    test_data = bytes([0x11, 0x22, 0x33, 0x44, 0x55, 0x66] * 41)
    if debugger.write_data(0x0320, test_data):
        print(f"Written {len(test_data)} bytes to 0x0023")
    
    print("\n--- Test 10: READ DATA MEMORY NON ALIGNED ---")
    read_data = debugger.read_data(0x0320, 126)
    if read_data:
        print(f"Read from 0x0023: {' '.join([f'0x{b:02X}' for b in read_data])}")
        if read_data == test_data:
            print("Data matches!")
    
    print("\n--- Test 11: RESUME ---")
    if debugger.resume():
        print("Core resumed successfully")
        
    print("\n--- Test 12: GET STATE ---")
    state = debugger.get_state()
    if state and not state["is_halted"]:
        print("State is running")
    else:
        print("Failed to get core state")
        
    print("\n--- Test 13: SOFT RST ---")
    if debugger.soft_rst():
        print("Core reset successfully")

# ============================================================================
# Функции для работы с HEX форматом
# ============================================================================
def parse_hex_file(filename: str) -> bytes:
    """
    Парсинг простого HEX файла с байтами через пробел
    Формат: только байты в hex через пробел, игнорируем всё кроме hex чисел
    
    Пример:
        00 11 22 33 44 55 66 77
        88 99 AA BB CC DD EE FF
    """
    all_bytes = []
    
    try:
        with open(filename, 'r') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                
                # Разбиваем строку на части
                for token in line.split():
                    # Пропускаем комментарии
                    if token.startswith('#'):
                        break
                    
                    # Парсим hex байт
                    try:
                        byte_val = int(token, 16)
                        if 0 <= byte_val <= 255:
                            all_bytes.append(byte_val)
                        else:
                            raise DebugProtocolError(f"Invalid byte value at line {line_num}: {token}")
                    except ValueError:
                        # Игнорируем не-hex токены (могут быть комментариями)
                        pass
            
    except FileNotFoundError:
        raise DebugProtocolError(f"File not found: {filename}")
    except Exception as e:
        raise DebugProtocolError(f"Failed to parse file: {e}")
    
    return bytes(all_bytes)

def write_hex_file(filename: str, data: bytes, start_addr: int, bytes_per_line: int = 16) -> None:
    """
    Запись данных в простой HEX формат (байты через пробел)
    """
    with open(filename, 'w') as f:
        f.write(f"# Dump from memory\n")
        f.write(f"# Format: hex bytes separated by spaces\n")
        f.write(f"# Start addr: {start_addr} Length : {len(data)}\n\n")
        
        # Записываем байты
        for i in range(0, len(data), bytes_per_line):
            chunk = data[i:min(len(data), i + bytes_per_line)]
            line = ' '.join([f"{b:02X}" for b in chunk])
            f.write(line + "\n")
        
        f.write("\n# End of dump\n")

# ============================================================================
# Функции для работы с файлами и памятью
# ============================================================================
def upload_firmware(debugger: UARTDebugger, filename: str, start_addr: int):
    """Загрузка прошивки в память программ"""
    print(f"Uploading firmware from {filename} to 0x{start_addr:08X}...")
    
    data = parse_hex_file(filename)
    
    if not data:
        print("Error: No data found in file")
        return False
    
    print(f"Total bytes to upload: {len(data)}")
    
    state = debugger.get_state()
    if not state:
        print("Error: can't get core state")
        return False
    
    if not state["is_halted"]:
        if not debugger.halt():
            print("Error: can't halt core")
            return False
    
    for i in range(0, len(data), 250):
        chunk = data[i:min(len(data), i+250)]
        addr = start_addr + i
        
        if not debugger.write_prog(addr, chunk):
            print(f"Error writing at address 0x{addr:08X}")
            return False
        
        print(f"  Progress: {i + len(chunk)}/{len(data)} bytes (0x{addr:08X})")
    
    if not state["is_halted"]:
        print("Note: core stay halted")
    
    print("Firmware uploaded successfully")
    return True

def dump_firmware(debugger: UARTDebugger, filename: str, start_addr: int, length: int):
    """Дамп памяти программ в файл"""
    print(f"Dumping firmware to {filename} (0x{start_addr:08X}, {length} bytes)...")
    
    all_data = bytearray()
    remaining = length
    current_addr = start_addr
    
    state = debugger.get_state()
    if not state:
        print("Error: can't get core state")
        return False
    
    if not state["is_halted"]:
        if not debugger.halt():
            print("Error: can't halt core")
            return False
    
    while remaining > 0:
        chunk_size = min(remaining, 250)
        data = debugger.read_prog(current_addr, chunk_size)
        
        if data is None:
            print(f"Error reading at address 0x{current_addr:08X}")
            return False
        
        if data:
            all_data.extend(data)
            print(f"  Read {len(data)} bytes from 0x{current_addr:08X}")
        
        remaining -= chunk_size
        current_addr += chunk_size
        
    if not state["is_halted"]:
        if not debugger.resume():
            print("Error: can't resume core")
            return False
    
    write_hex_file(filename, bytes(all_data), start_addr, 4)
    print(f"Dump saved to {filename} ({len(all_data)} bytes)")
    return True

def upload_memory(debugger: UARTDebugger, filename: str, start_addr: int):
    """Загрузка данных в память данных"""
    print(f"Uploading data memory from {filename} to 0x{start_addr:08X}...")
    
    data = parse_hex_file(filename)
    
    if not data:
        print("Error: No data found in file")
        return False
    
    print(f"Total bytes to upload: {len(data)}")
    
    state = debugger.get_state()
    if not state:
        print("Error: can't get core state")
        return False
    
    if not state["is_halted"]:
        if not debugger.halt():
            print("Error: can't halt core")
            return False
    
    for i in range(0, len(data), 250):
        chunk = data[i:min(len(data), i+250)]
        addr = start_addr + i
        
        if not debugger.write_data(addr, chunk):
            print(f"Error writing at address 0x{addr:08X}")
            return False
        
        print(f"  Progress: {i + len(chunk)}/{len(data)} bytes (0x{addr:08X})")
        
    if not state["is_halted"]:
        print("Note: core stay halted")
    
    print("Data memory uploaded successfully")
    return True

def dump_memory(debugger: UARTDebugger, filename: str, start_addr: int, length: int):
    """Дамп памяти данных в файл"""
    print(f"Dumping data memory to {filename} (0x{start_addr:08X}, {length} bytes)...")
    
    all_data = bytearray()
    remaining = length
    current_addr = start_addr
    
    state = debugger.get_state()
    if not state:
        print("Error: can't get core state")
        return False
    
    if not state["is_halted"]:
        if not debugger.halt():
            print("Error: can't halt core")
            return False
    
    while remaining > 0:
        chunk_size = min(remaining, 250)
        data = debugger.read_data(current_addr, chunk_size)
        
        if data is None:
            print(f"Error reading at address 0x{current_addr:08X}")
            return False
        
        if data:
            all_data.extend(data)
            print(f"  Read {len(data)} bytes from 0x{current_addr:08X}")
        
        remaining -= chunk_size
        current_addr += chunk_size
        
    if not state["is_halted"]:
        if not debugger.resume():
            print("Error: can't resume core")
            return False
    
    write_hex_file(filename, bytes(all_data), start_addr, 4)
    print(f"Dump saved to {filename} ({len(all_data)} bytes)")
    return True



def main():
    parser = argparse.ArgumentParser(
        prog="CLI for DebugModule.sv",
        description="Helps you to upload firmware and debug it on custom soft processor.",
        epilog="I hope there are no bugs"
    )
    
    parser.add_argument('--port', type=str, default="COM13", help='UART port (e.g., COM3 or /dev/ttyUSB0, default: COM13)')
    parser.add_argument('--baudrate', type=int, default=115200, help='UART baudrate (default: 115200)')
    
    parser.add_argument('--reset', action='store_true', help='Soft reset the core')
    parser.add_argument('--halt', action='store_true', help='Halt the core')
    parser.add_argument('--resume', action='store_true', help='Resume core execution')
    parser.add_argument('--run-tests', action='store_true', help='Run protocol tests (WARNING: changes memory state)')
    
    parser.add_argument('--upload-firmware', metavar='filename.hex', 
                       help='Upload firmware to program memory (HEX format)')
    parser.add_argument('--dump-firmware', metavar='filename.hex',
                       help='Dump program memory to file (HEX format)')
    
    parser.add_argument('--upload-memory', metavar='filename.hex',
                       help='Upload data to data memory (HEX format)')
    parser.add_argument('--dump-memory', metavar='filename.hex',
                       help='Dump data memory to file (HEX format)')
    
    parser.add_argument('--start', type=lambda x: int(x, 0), default=0,
                       help='Start address for dump/upload (hex or decimal, default: 0)')
    parser.add_argument('--len', type=lambda x: int(x, 0), 
                       help='Length in bytes for dump operation (required for dump commands)')
    
    args = parser.parse_args()
    
    commands = [args.reset, args.halt, args.resume, args.run_tests,
                args.upload_firmware, args.dump_firmware,
                args.upload_memory, args.dump_memory]
    
    if sum(map(bool, commands)) != 1:
        parser.print_help()
        sys.exit(1)
    
    if (args.dump_firmware or args.dump_memory) and args.len is None:
        print("Error: --len parameter is required for dump operations")
        sys.exit(1)
    
    debugger = UARTDebugger(args.port, args.baudrate)
    
    try:
        debugger.connect()
        
        success = True
        
        if args.reset:
            print("\n--- Soft Reset ---")
            if debugger.soft_rst():
                print("Core reset successfully")
            else:
                print("Failed to reset core")
                success = False
        
        if args.halt:
            print("\n--- Halt ---")
            if debugger.halt():
                print("Core halted successfully")
            else:
                print("Failed to halt core")
                success = False
        
        if args.resume:
            print("\n--- Resume ---")
            if debugger.resume():
                print("Core resumed successfully")
            else:
                print("Failed to resume core")
                success = False
                
        if args.run_tests:
            print("\n--- Running protocol tests ---")
            run_tests(debugger)
        
        if args.upload_firmware:
            print("\n--- Upload Firmware ---")
            if not upload_firmware(debugger, args.upload_firmware, args.start):
                success = False
        
        if args.dump_firmware:
            print("\n--- Dump Firmware ---")
            if not dump_firmware(debugger, args.dump_firmware, args.start, args.len):
                success = False
        
        if args.upload_memory:
            print("\n--- Upload Data Memory ---")
            if not upload_memory(debugger, args.upload_memory, args.start):
                success = False
        
        if args.dump_memory:
            print("\n--- Dump Data Memory ---")
            if not dump_memory(debugger, args.dump_memory, args.start, args.len):
                success = False
        
        if not success:
            sys.exit(1)
        
    except DebugProtocolError as e:
        print(f"Protocol error: {e}")
        sys.exit(1)
    except serial.SerialException as e:
        print(f"Serial error: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nInterrupted by user")
        sys.exit(1)
    finally:
        debugger.disconnect()


if __name__ == "__main__":
    main()