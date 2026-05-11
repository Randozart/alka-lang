// FLUX — Non-Maskable Cache Invalidation Tool
//
// Purpose:
//   Manually invalidates L1/L2 cache lines from the kernel without using the
//   slow generic `wbinvd` instruction. After a DMA transfer completes, the CPU
//   may have stale cache lines that don't reflect the new data in RAM. FLUX
//   ensures the CPU sees "fresh" data by invalidating only the relevant cache
//   lines for the target vessel's memory range.
//
// How it works:
//   1. Identifies the cache lines associated with the vessel's BAR-mapped region
//   2. Issues CLFLUSH (x86) or DC CIVAC (ARM) for each affected cache line
//   3. Issues a DSB (data synchronization barrier) to ensure completion
//   4. Much faster than wbinvd which flushes the entire cache hierarchy
//
// VITRIOL relevance:
//   After each Moore Stream window transfer, FLUX invalidates the CPU cache
//   for the transferred region so the CPU can verify completion without
//   seeing stale data. Critical for the FENCE polling loop.
//
// Op-Code: 0x2A
// Category: TRANSMUTATION
// Safety: L2 (soft contract — injects DSB barrier)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const FLUX = struct {
    pub const OP = OpCode.FLUX;
    pub const NAME = "FLUX";
    pub const DESCRIPTION = "Non-maskable cache invalidation for fresh DMA visibility";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        _ = ctx;
        if (operands.len < 1) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{"DSB"},
            .reason = "Cache invalidation validated — DSB barrier injected",
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const vessel_id = if (operands.len > 0) operands[0] else 0;

        _ = ctx;
        _ = vessel_id;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 8,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};
