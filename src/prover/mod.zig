// Alka Proof Engine — Z3-based formal verification
//
// Usage:
//   alka --prove recipe.alka vial.alkavl
//
// The proof engine checks at compile time:
//   1. No double-CLAIM of the same vessel
//   2. FLOW/REFRACT sizes respect aperture MAX_WINDOW
//   3. Thermal LIMIT precedes heat-generating operations (FLOW, REFRACT, STRIKE)
//   4. FENCE has a matching SIGNAL before it
//   5. PCI vendor/device IDs match the Vial
//
// If Z3 is not installed, the engine prints the SMT-LIB for manual inspection.
// Install Z3: sudo apt install z3

pub const smt = @import("smt.zig");
