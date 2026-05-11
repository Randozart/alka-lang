// Copyright 2026 Randy Smits-Schreuder Goedheijt
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Runtime Exception for Use as a Language:
// When the Work or any Derivative Work thereof is used to generate code
// ("generated code"), such generated code shall not be subject to the
// terms of this License, provided that the generated code itself is not
// a Derivative Work of the Work. This exception does not apply to code
// that is itself a compiler, interpreter, or similar tool that incorporates
// or embeds the Work.

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const VEIL = struct {
    pub const OP = OpCode.VEIL;
    pub const NAME = "VEIL";
    pub const DESCRIPTION = "Mask device from OS enumeration by clearing PCI config space visibility bits";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        _ = ctx;
        if (operands.len < 1) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        const mode = operands[0];
        if (mode > 3) {
            return interface.ToolInterface.ValidateError.ProhibitedRange;
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{ "GHOST 0x00", "SYNC" },
            .reason = "Veil mode validated",
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const mode = if (operands.len > 0) operands[0] else 0;
        const cycles: u64 = switch (mode) {
            0 => 16,
            1 => 32,
            2 => 48,
            else => 64,
        };

        _ = ctx;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = cycles,
            .bytes_transferred = 0,
            .error_message = null,
        };
    }
};
