# CAN 2.0A Controller IP Core

This IP core implements the data link layer and physical signaling layer for Classical CAN 2.0A (11-bit identifiers), as specified by [ISO 11898-1:2003](https://www.iso.org/standard/33422.html).

Modules are subdivided according to the OSI sublayers for CAN:

- LLC: logical link control
- MAC: medium access control
- PLS: physical signaling

Implemented here as well are the two major supervisor entities for CAN:

- FCE: fault confinent entity (WIP)
- BFME: bus fault mangement entity (WIP)
