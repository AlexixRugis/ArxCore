#! /usr/bin/python3
import argparse

def parse_hex_file(filename: str) -> bytes:
    all_bytes = []
    
    try:
        with open(filename, 'r') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line or line.startswith('#'):
                    continue

                for token in line.split():
                    if token.startswith('#'):
                        break
                    
                    try:
                        byte_val = int(token, 16)
                        if 0 <= byte_val <= 255:
                            all_bytes.append(byte_val)
                        else:
                            raise RuntimeError(f"Invalid byte value at line {line_num}: {token}")
                    except ValueError:
                        pass
            
    except FileNotFoundError:
        raise RuntimeError(f"File not found: {filename}")
    except Exception as e:
        raise RuntimeError(f"Failed to parse file: {e}")
    
    return bytes(all_bytes)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
                    prog='parse_hex_to_ascii.py',
                    description='Prints ASCII string from hex dump')
    parser.add_argument('filename')
    args = parser.parse_args()

    data = parse_hex_file(args.filename)
    print(data.decode('ascii'))

