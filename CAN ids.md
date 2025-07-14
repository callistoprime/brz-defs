# CAN IDs identified in ECUs

To the best of my limited understanding as of whenever I last updated this, here's the CAN IDs that each ECU release either sends out, and/or listens for, on the CAN bus.

ECU column is of the format 4..B, using the first unique letter of the ZA1J_... code to define a confirmed range for this CAN ID; in programmer terms, this is base 36 { 0..9 , A..Z }; so, for example, ZA1J900C is '9', so probably ~2014 Zenki; ZA1JU00A is 'U', which is 2019 Kouki; ZA1JV00C00G is 'V', which is 2020 Kouki. Most CAN IDs are unchanged from the beginning of time, but at least one is found to have changed at different points in time.

Most of them are 'emitter' IDs; as in, the ECU constantly buffers the 'current state' of the engine in various internal memory addresses, and then transmits them on a timer to the CAN bus for the rest of the components to use.

Some of these appear to be 'command' IDs; as in, when you post a command onto the CAN bus in the right format, the ECU listens for and receives it, interprets it, and performs whatever change is directed by that. I identify these by seeing in the ECU software that the pointer to the outbound memory state buffer is zeroed out, indicating that nothing is sent from memory. This does not indicate that the ECU sends nothing - presumably it sends a command success/failure code! - but it does indicate that the ECU isn't generating and writing out data of its own accord without some outside intervention requesting it.

Last updated 07/13/2025. I will eventually verify these CAN IDs across the entirety of known ECU versions for gen1, but as of right now I've only inspected K, S, U, V and at minimum I need to inspect the remaining Kouki versions (N Q) before I proceed into the Zenki versions (7 9 A B D E F). If your car has an ECU that I didn't list in this paragraph, let me know; I'm definitely missing the 86 GRMN special edition and would love to study it further.

| ECUs | CAN ID | (dec) | Emitter? | Command? | Notes |
| ---- | ------ | ----- | -------- | -------- | ----- |
| B..U | 0x3D1  |       | x        |          |  |
| V    | 0x3D7  |       | x        |          | Replaces 0x3D1; appends one additional value. |

ECUs reviewed in full to provide the above table: \[none yet, WIP\]
