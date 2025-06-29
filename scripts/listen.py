import can
from datetime import datetime

# Use the new preferred interface method
bus = can.Bus(interface='socketcan', channel='can0')

print("Listening on can0... (Press Ctrl+C to stop)")

try:
    while True:
        msg = bus.recv(timeout=1.0)
        if msg:
            timestamp = datetime.fromtimestamp(msg.timestamp)
            print(f"[{timestamp}] ID: {hex(msg.arbitration_id)} "
                  f"Data: {msg.data.hex()} DLC: {msg.dlc}")
except KeyboardInterrupt:
    print("\nExiting.")
finally:
    bus.shutdown()

