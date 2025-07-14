# CAN IDs identified in ECUs

To the best of my limited understanding as of whenever I last updated this, here's the CAN IDs that each ECU release either sends out, and/or listens for, on the CAN bus.

ECU column is of the format 4..B, using the first unique letter of the ZA1J_... code to define a confirmed range for this CAN ID; in programmer terms, this is base 36 { 0..9 , A..Z }; so, for example, ZA1J900C is '9', so probably ~2014 Zenki; ZA1JU00A is 'U', which is 2019 Kouki; ZA1JV00C00G is 'V', which is 2020 Kouki. Most CAN IDs are unchanged from the beginning of time, but at least one is found to have changed at different points in time.

Most of them are 'emitter' IDs; as in, the ECU constantly buffers the 'current state' of the engine in various internal memory addresses, and then transmits them on a timer to the CAN bus for the rest of the components to use.

0x111 (command) disappeared at the same time as 0x3D1 (emitter) appeared; 0x3D1 was later updated to 0x3D7 with an additional value. All other IDs are present in all revisions of the ECU 7..V, indicated with '*' below.

Some of these appear to be 'command' IDs, 0x7__ in their entirety; as in, when you post a command onto the CAN bus in the right format, the ECU listens for and receives it, interprets it, and performs whatever change is directed by that. I identify these by seeing in the ECU software that the pointer to the outbound memory state buffer is zeroed out, indicating that nothing is sent from memory. This does not indicate that the ECU sends nothing - presumably it sends a command success/failure code! - but it does indicate that the ECU isn't generating and writing out data of its own accord without some outside intervention requesting it.

Last updated 07/14/2025. I'm definitely missing the 86 GRMN special edition and would love to study it further; it has an additional sensor for the manifold and I'd like to know where they put that in the CAN arrays.

WIP: Emitter/Command are not ready.

| ECUs | CAN ID | (dec) | Emitter? | Command? | Notes |
| ---- | ------ | ----- | -------- | -------- | ----- |
| 7..B | 0x111  |       |          | x        | Replaced by 0x3D1 in D. |
| D..U | 0x3D1  |       | x        |          | Replaced by 0x3D7 in V. Contains ambient temp. |
| V    | 0x3D7  |       | x        |          | Adds one additional value to the end of 0x3D1. |
| *    | 0xD0   |       | x        |          |  |
| *    | 0xD1   |       | x        |          |  |
| *    | 0xD2   |       | x        |          |  |
| *    | 0xD3   |       | x        |          |  |
| *    | 0xD4   |       | x        |          |  |
| *    | 0x140  |       | x        |          |  |
| *    | 0x141  |       | x        |          |  |
| *    | 0x142  |       | x        |          |  |
| *    | 0x144  |       | x        |          |  |
| *    | 0x148  |       | x        |          |  |
| *    | 0x149  |       | x        |          |  |
| *    | 0x14A  |       | x        |          |  |
| *    | 0x152  |       | x        |          |  |
| *    | 0x280  |       | x        |          |  |
| *    | 0x282  |       | x        |          |  |
| *    | 0x360  |       | x        |          |  |
| *    | 0x361  |       | x        |          |  |
| *    | 0x368  |       | x        |          |  |
| *    | 0x370  |       | x        |          |  |
| *    | 0x372  |       | x        |          |  |
| *    | 0x4C1  |       | x        |          |  |
| *    | 0x63B  |       | x        |          |  |
| *    | 0x720  |       |          | x        |  |
| *    | 0x771  |       |          | x        |  |
| *    | 0x772  |       |          | x        |  |
| *    | 0x773  |       |          | x        |  |
| *    | 0x774  |       |          | x        |  |
| *    | 0x775  |       |          | x        |  |
| *    | 0x7DF  |       |          | x        |  |
| *    | 0x7E0  |       |          | x        |  |
| *    | 0x7E8  |       |          | x        |  |

ECUs reviewed to provide the above table: 700A, A01G, B00C, D00C, K00G, S10C, U01A, V00C
