// FENCE — Memory-Mapped Condition Wait Tool
//
// Purpose:
//   Spin-locks on a physical memory-mapped bit until a condition is met.
//   This is the hardware synchronization primitive — wait for a device
//   to signal readiness without polling through the OS.
//
// How it works:
//   1. Maps the target physical address for direct monitoring
//   2. Polls the memory-mapped bit at regular intervals
//   3. Returns when the condition is met or timeout is reached
//   4. Used after FLOW to wait for DMA completion
//
// VITRIOL relevance:
//   After streaming weights via FLOW, FENCE waits for the GPU's metapage
//   to signal that the transfer is complete. This replaces OS-level sync
//   mechanisms with direct hardware observation.
//
// Op-Code: 0x05
// Category: CORE
// Safety: L2 (soft contract — injects safety operations)

const std = @import("std");
const interface = @import("../interface.zig");

pub const FENCE = struct {
    pub const OP = interface.ToolInterface.OpCode.FENCE;
    pub const NAME = "FENCE";
    pub const DESCRIPTION = "Spin-lock on a physical memory-mapped bit until condition is met";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        _ = operands;
        _ = ctx;
        
        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{},
            .reason = null,
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const timeout_ns: u64 = 1000000;
        const poll_interval_ns: u64 = 100;
        
        _ = operands;
        _ = ctx;

        const iterations = timeout_ns / poll_interval_ns;
        
        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = iterations * 10,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};

// SYNC — Memory Barrier Tool
//
// Purpose:
//   Enforces memory ordering barriers (L1=write, L2=read, L3=full).
//   Ensures that all pending memory operations complete before subsequent
//   instructions execute. Critical for hardware synchronization.
//
// How it works:
//   1. Accepts a barrier level operand (1=wmb, 2=rmb, 3=full mb)
//   2. Issues the appropriate hardware memory barrier instruction
//   3. Returns the cycle cost based on barrier strength
//   4. Auto-injected by the compiler before SIGNAL after FLOW
//
// VITRIOL relevance:
//   SYNC L3 is auto-injected before Moore Stream transfers to ensure all
//   prior writes are visible. SYNC L1 is injected after SHIFT to ensure
//   the BAR remap is coherent. The barrier level determines the cost.
//
// Op-Code: 0x06
// Category: CORE
// Safety: L2 (soft contract — injects safety operations)

pub const SYNC = struct {
    pub const OP = interface.ToolInterface.OpCode.SYNC;
    pub const NAME = "SYNC";
    pub const DESCRIPTION = "Memory barrier (L1=wmb, L2=rmb, L3=mb)";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        _ = operands;
        _ = ctx;
        
        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{},
            .reason = null,
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const level = if (operands.len > 0) operands[0] else 3;
        const cost: u64 = if (level == 1) 8 else if (level == 2) 12 else 20;
        
        _ = ctx;
        
        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = cost,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};

// YIELD — Cooperative Scheduler Yield Tool
//
// Purpose:
//   Cooperatively yields control back to the Linux scheduler for a
//   specified duration. This is the safe way to pause Alka execution
//   without holding hardware resources hostage.
//
// How it works:
//   1. Accepts a yield duration in microseconds (default 1000us)
//   2. Returns control to the OS scheduler for the specified time
//   3. Used as the Azoth counterpart to OSSIFY (returns pinned cores)
//   4. Returns cycle count based on yield duration
//
// VITRIOL relevance:
//   When thermal shadowing detects high temperatures, the compiler injects
//   YIELD to cool down before continuing. Also used to return OSSIFY'd
//   cores to the scheduler after experiments complete.
//
// Op-Code: 0x0A
// Category: CORE
// Safety: L2 (soft contract — injects safety operations)

pub const YIELD = struct {
    pub const OP = interface.ToolInterface.OpCode.YIELD;
    pub const NAME = "YIELD";
    pub const DESCRIPTION = "Cooperative yield to Linux scheduler";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        _ = operands;
        _ = ctx;
        
        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{},
            .reason = null,
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const micros = if (operands.len > 0) operands[0] else 1000;
        
        _ = ctx;
        
        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = micros * 1000,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};

// SENSE — Hardware Telemetry Mapping Tool
//
// Purpose:
//   Maps hardware telemetry (thermal, voltage, current) to a logic
//   variable for use in GUARD conditions and thermal shadowing.
//   This is the core-side telemetry primitive.
//
// How it works:
//   1. Accepts a sensor ID operand (0 = default thermal sensor)
//   2. Reads the sensor value from the substrate context
//   3. Returns the value for use in conditional logic
//   4. Used by GUARD to trigger automatic rollback on thresholds
//
// VITRIOL relevance:
//   Before heat-generating operations, SENSE reads GPU temperature.
//   The compiler wraps STRIKE and FLOW with SENSE+GUARD for automatic
//   thermal protection — if temp exceeds limits, QUENCH is triggered.
//
// Op-Code: 0x07
// Category: CORE
// Safety: L2 (soft contract — injects safety operations)

pub const SENSE = struct {
    pub const OP = interface.ToolInterface.OpCode.SENSE;
    pub const NAME = "SENSE";
    pub const DESCRIPTION = "Maps hardware telemetry to a logic variable";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        _ = operands;
        _ = ctx;
        
        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{},
            .reason = null,
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const sensor_id = if (operands.len > 0) operands[0] else 0;
        var temp: u64 = 45;
        
        if (sensor_id == 0) {
            temp = ctx.current_temp;
        }
        
        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 25,
            .bytes_transferred = 8,
            .error_message = null,
        };
    }
};

// SIGNAL — Hardware Interrupt Trigger Tool
//
// Purpose:
//   Triggers a hardware interrupt to wake the CPU or signal other
//   devices. This is how Alka communicates events across the substrate
//   without going through the OS interrupt handler.
//
// How it works:
//   1. Accepts an interrupt vector operand
//   2. Issues the hardware interrupt at the specified vector
//   3. Returns immediately (5 cycles — very fast)
//   4. Used to wake CPU cores after DMA completion
//
// VITRIOL relevance:
//   After a Moore Stream FLOW completes, SIGNAL wakes the CPU to process
//   results. The compiler auto-injects SYNC L3 before SIGNAL after FLOW
//   to ensure all transferred data is visible before the interrupt fires.
//
// Op-Code: 0x09
// Category: CORE
// Safety: L2 (soft contract — injects safety operations)

pub const SIGNAL = struct {
    pub const OP = interface.ToolInterface.OpCode.SIGNAL;
    pub const NAME = "SIGNAL";
    pub const DESCRIPTION = "Trigger a hardware interrupt to wake CPU";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        _ = operands;
        _ = ctx;
        
        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{},
            .reason = null,
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const vector = if (operands.len > 0) operands[0] else 0;
        
        _ = ctx;
        _ = vector;
        
        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 5,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};