import itertools

# Polynomial for CRC-15: x^15 + x^14 + x^10 + x^8 + x^7 + x^4 + x^3 + 1
CRC15_POLY = 0x4599
CRC_INIT = 0x0000


def int_to_bits(value, width):
    return [(value >> i) & 1 for i in reversed(range(width))]


def compute_crc(frame_bits):
    crc = CRC_INIT
    for bit in frame_bits:
        crc_bit = (crc >> 14) & 1
        crc = ((crc << 1) & 0x7FFF) | bit
        if crc_bit:
            crc ^= CRC15_POLY
    return crc


def bit_stuff(bits):
    stuffed = []
    count = 1
    last_bit = bits[0]
    stuffed.append(last_bit)
    for bit in bits[1:]:
        if bit == last_bit:
            count += 1
            if count == 5:
                stuffed.append(bit)
                stuffed.append(1 - bit)  # Stuffed bit
                count = 1
            else:
                stuffed.append(bit)
        else:
            stuffed.append(bit)
            count = 1
        last_bit = bit
    return stuffed


def generate_can_frame(id_11bit, data_len, data_payload):
    assert 0 <= id_11bit < (1 << 11)
    assert 0 <= data_len <= 8
    assert 0 <= data_payload < (1 << (8 * data_len))

    # --- Fields ---
    sof = [0]  # Dominant
    arb = int_to_bits(id_11bit, 11) + [0, 0]  # RTR = 0, IDE = 0
    ctrl = int_to_bits(data_len, 4) + [1, 1]  # r0, r1 (reserved dominant)
    data = int_to_bits(data_payload, 8 * data_len)

    # Prepare bits for CRC calculation (from SOF through data field)
    crc_input = arb + ctrl + data
    crc = compute_crc(crc_input)
    crc_bits = int_to_bits(crc, 15)

    # Rest of frame
    crc_delim = [1]  # recessive
    ack = [1]  # transmitter sends recessive
    ack_delim = [1]  # recessive
    eof = [1] * 7  # recessive
    ifs = [1] * 3  # recessive

    raw_frame = sof + crc_input + crc_bits + crc_delim + ack + ack_delim + eof

    # Bit stuffing
    stuffed_frame = bit_stuff(raw_frame)

    full_frame = stuffed_frame + ifs
    return full_frame, crc


# --- Test ---
if __name__ == "__main__":
    ID = 0x123
    DLC = 4
    DATA = 0xDEADBEEF
    EXPECTED_CRC = 0x4E6B

    bitstream, computed_crc = generate_can_frame(ID, DLC, DATA)

    print("Computed CRC: 0x{:04X}".format(computed_crc))
    print("Expected CRC: 0x{:04X}".format(EXPECTED_CRC))
    print("CRC Match:", computed_crc == EXPECTED_CRC)

    print("\nBitstream (with stuffing):")
    print("".join(str(b) for b in bitstream))
