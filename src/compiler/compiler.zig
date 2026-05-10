const std = @import("std");
const parser = @import("../parser/parser.zig");

pub const ValidationError = error{
    UnknownVessel,
    UnknownAperture,
    ApertureOverflow,
    ThermalLimitExceeded,
    UnclaimedResource,
    DoubleStake,
};

pub fn validate(program: parser.Program, vial: parser.Vial) !void {
    for (program.instructions.items) |instr| {
        switch (instr) {
            .claim => |c| {
                if (vial.vessels.get(c.target) == null) {
                    std.debug.print("Error: Unknown vessel '{s}'\n", .{c.target});
                    return error.UnknownVessel;
                }
            },
            .flow => |f| {
                try validateFlow(f, vial);
            },
            .shift => |s| {
                try validateShift(s, vial);
            },
            .fence => |fc| {
                if (vial.vessels.get(fc.vessel) == null) {
                    return error.UnknownVessel;
                }
            },
            .sync => {},
            .pulse => |p| {
                if (vial.vessels.get(p.target) == null) {
                    return error.UnknownVessel;
                }
            },
            .stake => {},
            .sense => |s| {
                if (vial.vessels.get(s.sensor) == null) {
                    return error.UnknownVessel;
                }
            },
            .yield => {},
            .signal => {},
            .recast => |r| {
                if (vial.vessels.get(r.vessel) == null) {
                    return error.UnknownVessel;
                }
            },
            .snap => |s| {
                if (vial.vessels.get(s.vessel) == null) {
                    return error.UnknownVessel;
                }
            },
            .revert => |r| {
                if (vial.vessels.get(r.vessel) == null) {
                    return error.UnknownVessel;
                }
            },
            .limit => |l| {
                try validateLimit(l, vial);
            },
            .require => {},
        }
    }

    std.debug.print("Validation passed.\n", .{});
}

fn validateFlow(flow: parser.Instr.Flow, vial: parser.Vial) !void {
    _ = flow;
    _ = vial;
}

fn validateShift(shift: parser.Instr.Shift, vial: parser.Vial) !void {
    const vessel = vial.vessels.get(shift.vessel) orelse return error.UnknownVessel;

    const offset = switch (shift.offset) {
        .literal => |v| v,
        .memory_size => |m| m.value * switch (m.unit[0]) {
            'M' => 1024 * 1024,
            'G' => 1024 * 1024 * 1024,
            else => 1,
        },
        else => 0,
    };

    for (vessel.apertures.items) |ap| {
        if (ap.max_window) |max| {
            if (offset > max) {
                std.debug.print("Error: Shift offset {} exceeds max window {}\n", .{ offset, max });
                return error.ApertureOverflow;
            }
        }
    }
}

fn validateLimit(limit: parser.Instr.Limit, vial: parser.Vial) !void {
    const vessel = vial.vessels.get(limit.vessel) orelse return error.UnknownVessel;

    if (std.mem.eql(u8, limit.property, "THERMAL") or std.mem.eql(u8, limit.property, "MAX")) {
        if (vessel.thermal) |thermal| {
            const value = switch (limit.value) {
                .literal => |v| v,
                .memory_size => |m| m.value,
                else => 0,
            };

            if (thermal.halt_at) |halt| {
                if (value > halt) {
                    std.debug.print("Error: Limit {} exceeds thermal halt {}\n", .{ value, halt });
                    return error.ThermalLimitExceeded;
                }
            }
        }
    }
}