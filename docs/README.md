# Documentation Guide

This folder contains the public, handoff-oriented documentation for the IGZO DRAM controller repository. It is organized by the role each document plays in the design flow.

## Recommended Reading Order

1. [design/architecture_and_specs_v1.md](design/architecture_and_specs_v1.md)
   System architecture and the merged analog/digital specification. The analog and digital specs are combined here because the key design choice, 2-bit slice sensing followed by digital INT4 reconstruction, crosses the analog/digital boundary.

2. [interfaces/register_map_v1.md](interfaces/register_map_v1.md)
   SPI/CSR address map used for configuration, status, readback, debug, and bring-up.

3. [interfaces/pad_list_v1.md](interfaces/pad_list_v1.md)
   Public pad-level signal list for power, SPI, scan/debug, analog monitor, external current injection, and BEOL landing hooks.

4. [validation/mvt_definition_v1.md](validation/mvt_definition_v1.md)
   Minimum viable tapeout feature set. This document separates must-have silicon debug hooks from features that can be reduced if area or schedule pressure appears.

5. [validation/bringup_procedure_v1.md](validation/bringup_procedure_v1.md)
   Step-by-step post-silicon bring-up flow, starting from SPI identity checks and moving toward analog current-sense validation.

6. [integration/beol_landing_spec_v1.md](integration/beol_landing_spec_v1.md)
   Initial BEOL IGZO landing-pad and daisy-chain integration plan.

## Removed Legacy Material

The old `zh/` folder and phase-code execution reports were removed from the public documentation tree. They were either internal handoff notes, encoded poorly for GitHub display, or named by development phase rather than by reader intent. The public docs now favor stable topic names and direct handoff value.
