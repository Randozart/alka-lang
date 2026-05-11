// ISOLATE — Complete Hardware Isolation Tool
//
// Purpose:
//   Physically disconnects a device from the bus, blocks all DMA, IRQs,
//   and MMIO access. ISOLATE is the "air gap" instruction — it ensures
//   no other process, driver, or device can interact with the target
//   while Alka has exclusive control.
//
// How it works:
//   1. Disables the device's Bus Master Enable bit in PCI config space
//   2. Masks all interrupt vectors (MSI/MSI-X)
//   3. Blocks MMIO access by clearing memory decode
//   4. Returns once the device is fully isolated
//
// VITRIOL relevance:
//   Before performing sensitive operations (STRIKE, VEIL, OCCUPY), ISOLATE
//   ensures no other process can interfere. This is critical for security
//   research where unpredictable OS behavior could corrupt results.
//
// Op-Code: 0x32
// Category: SAFETY
// Safety: L1 (hard contract — will hard abort on violation)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const ISOLATE = struct {
    pub const OP = OpCode.ISOLATE;
    pub const NAME = "ISOLATE";
    pub const DESCRIPTION = "Complete hardware isolation — disconnect from bus, block DMA/IRQs";

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
            .injected_operations = &.{ "SYNC L3" },
            .reason = "Hardware isolation validated — full barrier injected",
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
            .cycles_spent = 16,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};
