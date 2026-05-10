const std = @import("std");

pub const OpCode = enum(u8) {
    CLAIM = 0x01,
    STAKE = 0x02,
    FLOW = 0x03,
    SHIFT = 0x04,
    FENCE = 0x05,
    SYNC = 0x06,
    SENSE = 0x07,
    PULSE = 0x08,
    SIGNAL = 0x09,
    YIELD = 0x0A,
    RECAST = 0x0B,
    SNAP = 0x0C,
    REVERT = 0x0D,
    LIMIT = 0x0E,
    VEIL = 0x0F,
    DELEGATE = 0x10,
    RHYTHM = 0x11,
    DISTILL = 0x12,
    ENQUEUE = 0x13,
    MOLT = 0x14,
    VOUCH = 0x15,
    PROBE_BUS = 0x16,
    ECHO = 0x17,
    STASIS = 0x18,
    TRANSVERSE = 0x19,
    SEARCH = 0x1A,
    FOSSILIZE = 0x1B,
    STRIKE = 0x1C,
    QUENCH = 0x1D,
    FORGE = 0x1E,
    VOID = 0x1F,
    ABDUCT = 0x20,
    SNOOP = 0x21,
    SCATTER = 0x22,
    WHISPER = 0x23,
    GHOST = 0x24,
    HIJACK = 0x25,
    DRIFT = 0x26,
    CLONE = 0x27,
    CRYSTALLIZE = 0x28,
    OVERCLOCK = 0x29,
    FLUX = 0x2A,
    AUDIT = 0x2B,
    DRY_RUN = 0x2C,
    MOCK = 0x2D,
    PROVE = 0x2E,
    WATCH = 0x2F,
    TRACE = 0x30,
    GUARD = 0x31,
    ISOLATE = 0x32,
    VERIFY = 0x33,
    OSSIFY = 0x34,
    BOND = 0x35,
    STILL = 0x36,
    RESONATE = 0x37,
    OSCILLATE = 0x38,
    IMC_HIJACK = 0x39,
};

pub const Category = enum {
    CORE,
    TRANSMUTATION,
    DISSOLUTION,
    PULSE,
    SOLIDIFICATION,
    FORGING,
    CALCINATION,
    TESTING,
    MONITORING,
    SAFETY,
};

pub const Instruction = struct {
    op_code: OpCode,
    name: []const u8,
    category: Category,
    description: []const u8,
};

pub const instruction_set: []const Instruction = &[_]Instruction{
    // CORE (0x01-0x0E, 0x10, 0x12-0x17, 0x19-0x1A)
    .{ .op_code = .CLAIM, .name = "CLAIM", .category = .CORE, .description = "Stake hardware node" },
    .{ .op_code = .STAKE, .name = "STAKE", .category = .CORE, .description = "Claim memory region" },
    .{ .op_code = .FLOW, .name = "FLOW", .category = .CORE, .description = "DMA transfer" },
    .{ .op_code = .SHIFT, .name = "SHIFT", .category = .CORE, .description = "Remap BAR window" },
    .{ .op_code = .FENCE, .name = "FENCE", .category = .CORE, .description = "Wait for condition" },
    .{ .op_code = .SYNC, .name = "SYNC", .category = .CORE, .description = "Memory barrier" },
    .{ .op_code = .SENSE, .name = "SENSE", .category = .CORE, .description = "Read sensor" },
    .{ .op_code = .PULSE, .name = "PULSE", .category = .CORE, .description = "Timing signal" },
    .{ .op_code = .SIGNAL, .name = "SIGNAL", .category = .CORE, .description = "Trigger interrupt" },
    .{ .op_code = .YIELD, .name = "YIELD", .category = .CORE, .description = "Cooperative yield" },
    .{ .op_code = .RECAST, .name = "RECAST", .category = .CORE, .description = "FPGA reconfigure" },
    .{ .op_code = .SNAP, .name = "SNAP", .category = .CORE, .description = "Serialize state" },
    .{ .op_code = .REVERT, .name = "REVERT", .category = .CORE, .description = "Restore state" },
    .{ .op_code = .LIMIT, .name = "LIMIT", .category = .CORE, .description = "Hard contract" },
    .{ .op_code = .DELEGATE, .name = "DELEGATE", .category = .CORE, .description = "CPU bypass" },
    .{ .op_code = .DISTILL, .name = "DISTILL", .category = .CORE, .description = "Algorithmic synthesis" },
    .{ .op_code = .ENQUEUE, .name = "ENQUEUE", .category = .CORE, .description = "Command ring" },
    .{ .op_code = .MOLT, .name = "MOLT", .category = .CORE, .description = "Full state dump" },
    .{ .op_code = .VOUCH, .name = "VOUCH", .category = .CORE, .description = "Attestation" },
    .{ .op_code = .PROBE_BUS, .name = "PROBE_BUS", .category = .CORE, .description = "Forensic audit" },
    .{ .op_code = .ECHO, .name = "ECHO", .category = .CORE, .description = "Non-intrusive introspection" },
    .{ .op_code = .TRANSVERSE, .name = "TRANSVERSE", .category = .CORE, .description = "Bit-level swizzling" },
    .{ .op_code = .SEARCH, .name = "SEARCH", .category = .CORE, .description = "Physical signature scanning" },

    // TRANSMUTATION (0x20-0x22, 0x2A)
    .{ .op_code = .ABDUCT, .name = "ABDUCT", .category = .TRANSMUTATION, .description = "Physical page stealing" },
    .{ .op_code = .SNOOP, .name = "SNOOP", .category = .TRANSMUTATION, .description = "Cache-coherent monitoring" },
    .{ .op_code = .SCATTER, .name = "SCATTER", .category = .TRANSMUTATION, .description = "Vectored I/O (scatter-gather)" },
    .{ .op_code = .FLUX, .name = "FLUX", .category = .TRANSMUTATION, .description = "Cache invalidation" },

    // DISSOLUTION (0x0F, 0x1C, 0x23-0x25)
    .{ .op_code = .VEIL, .name = "VEIL", .category = .DISSOLUTION, .description = "Hide from OS" },
    .{ .op_code = .STRIKE, .name = "STRIKE", .category = .DISSOLUTION, .description = "Rowhammer/bit flipping" },
    .{ .op_code = .WHISPER, .name = "WHISPER", .category = .DISSOLUTION, .description = "Side-channel extraction" },
    .{ .op_code = .GHOST, .name = "GHOST", .category = .DISSOLUTION, .description = "Configuration space masking" },
    .{ .op_code = .HIJACK, .name = "HIJACK", .category = .DISSOLUTION, .description = "IRQ stealing" },

    // PULSE (0x11, 0x18, 0x26)
    .{ .op_code = .RHYTHM, .name = "RHYTHM", .category = .PULSE, .description = "Timing constraint" },
    .{ .op_code = .STASIS, .name = "STASIS", .category = .PULSE, .description = "Bus-level locking" },
    .{ .op_code = .DRIFT, .name = "DRIFT", .category = .PULSE, .description = "Cross-device sync" },

    // SOLIDIFICATION (0x1B, 0x14, 0x27)
    .{ .op_code = .FOSSILIZE, .name = "FOSSILIZE", .category = .SOLIDIFICATION, .description = "Substrate persistence" },
    .{ .op_code = .CLONE, .name = "CLONE", .category = .SOLIDIFICATION, .description = "Full silicon snapshot" },

    // FORGING (0x0B, 0x1E, 0x28)
    .{ .op_code = .FORGE, .name = "FORGE", .category = .FORGING, .description = "Bitstream injection" },
    .{ .op_code = .CRYSTALLIZE, .name = "CRYSTALLIZE", .category = .FORGING, .description = "JIT-to-FPGA" },

    // CALCINATION (0x1D, 0x1F, 0x29)
    .{ .op_code = .QUENCH, .name = "QUENCH", .category = .CALCINATION, .description = "Emergency power-state reset" },
    .{ .op_code = .VOID, .name = "VOID", .category = .CALCINATION, .description = "Secure substrate erase" },
    .{ .op_code = .OVERCLOCK, .name = "OVERCLOCK", .category = .CALCINATION, .description = "Sub-driver tuning" },

    // TESTING (0x2B-0x2E)
    .{ .op_code = .AUDIT, .name = "AUDIT", .category = .TESTING, .description = "Post-instruction residue check" },
    .{ .op_code = .DRY_RUN, .name = "DRY_RUN", .category = .TESTING, .description = "Simulate without executing" },
    .{ .op_code = .MOCK, .name = "MOCK", .category = .TESTING, .description = "Use mock hardware for testing" },
    .{ .op_code = .PROVE, .name = "PROVE", .category = .TESTING, .description = "Formal verification of invariants" },

    // MONITORING (0x2F-0x30)
    .{ .op_code = .WATCH, .name = "WATCH", .category = .MONITORING, .description = "Real-time hardware state monitoring" },
    .{ .op_code = .TRACE, .name = "TRACE", .category = .MONITORING, .description = "Instruction execution trace" },

    // SAFETY (0x31-0x33)
    .{ .op_code = .GUARD, .name = "GUARD", .category = .SAFETY, .description = "Runtime safety sentinel" },
    .{ .op_code = .ISOLATE, .name = "ISOLATE", .category = .SAFETY, .description = "Complete hardware isolation" },
    .{ .op_code = .VERIFY, .name = "VERIFY", .category = .SAFETY, .description = "Cryptographic state verification" },

    // SUBSTRATE ORCHESTRATION (0x34-0x39)
    .{ .op_code = .OSSIFY, .name = "OSSIFY", .category = .CORE, .description = "Pin CPU core to Alka, bypass scheduler" },
    .{ .op_code = .BOND, .name = "BOND", .category = .CORE, .description = "Create RAM-to-GPU direct tunnel" },
    .{ .op_code = .STILL, .name = "STILL", .category = .CORE, .description = "Manual DRAM refresh control" },
    .{ .op_code = .RESONATE, .name = "RESONATE", .category = .PULSE, .description = "Coordinate reset for pure execution window" },
    .{ .op_code = .OSCILLATE, .name = "OSCILLATE", .category = .PULSE, .description = "Dual-bank refresh coordination" },
    .{ .op_code = .IMC_HIJACK, .name = "IMC_HIJACK", .category = .DISSOLUTION, .description = "Direct memory controller access" },
};

pub fn getInstructionByName(name: []const u8) ?*const Instruction {
    for (instruction_set) |instr| {
        if (std.mem.eql(u8, instr.name, name)) {
            return &instr;
        }
    }
    return null;
}

pub fn getInstructionByCode(code: OpCode) ?*const Instruction {
    for (instruction_set) |instr| {
        if (instr.op_code == code) {
            return &instr;
        }
    }
    return null;
}