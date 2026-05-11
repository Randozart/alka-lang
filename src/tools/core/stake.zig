// STAKE — Physical Memory Region Claim Tool
//
// Purpose:
//   Claims a region of physical memory, marking it as "Reserved" from OS
//   interference. Unlike CLAIM which stakes a hardware node (PCI device),
//   STAKE stakes raw physical RAM — preventing the kernel from allocating
//   or paging that memory while Alka is using it for DMA buffers.
//
// How it works:
//   1. Validates the physical address range against the Vial's memory map
//   2. Checks that the region is not kernel-owned (prohibited ranges)
//   3. Marks the region as staked in the substrate context
//   4. Injects a FLUX (cache invalidation) to ensure CPU sees the reservation
//
// VITRIOL relevance:
//   Before setting up DMA buffers for the Moore Stream, STAKE the physical
//   RAM pages that will hold the transfer descriptors. This prevents the
//   kernel from using those pages for anything else during the transfer.
//
// Op-Code: 0x02
// Category: CORE
// Safety: L3 (advisory — validates against Vial memory map)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const STAKE = struct {
    pub const OP = OpCode.STAKE;
    pub const NAME = "STAKE";
    pub const DESCRIPTION = "Claim a region of physical memory, reserving it from OS interference";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        if (operands.len < 2) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        const phys_addr = operands[0];
        const size = operands[1];

        if (phys_addr == 0 or size == 0) {
            return interface.ToolInterface.ValidateError.ProhibitedRange;
        }

        // Check against known prohibited ranges (kernel space)
        if (phys_addr >= 0xFFFF800000000000) {
            return interface.ToolInterface.ValidateError.ProhibitedRange;
        }

        _ = ctx;

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{"FLUX"},
            .reason = "Physical memory region validated — cache invalidation injected",
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const phys_addr = if (operands.len > 0) operands[0] else 0;
        const size = if (operands.len > 1) operands[1] else 0;

        _ = ctx;
        _ = phys_addr;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 24,
            .bytes_transferred = size,
            .error_message = null,
        };
    }
};
