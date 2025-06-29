import can

bus = can.Bus(interface='socketcan', channel='can0')

msg = can.Message(arbitration_id=0x123, data=[0xDE, 0xAD, 0xBE, 0xEF], is_extended_id=False)
bus.send(msg)

bus.shutdown()
