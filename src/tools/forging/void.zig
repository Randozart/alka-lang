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

pub const VOID = struct {
    pub const OP = OpCode.VOID;
    pub const NAME = "VOID";
    pub const DESCRIPTION = "Secure substrate erase — overwrite with cryptographic pattern";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        _ = ctx;
        if (operands.len < 2) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        const addr = operands[0];
        const size = operands[1];

        if (addr == 0 or size == 0) {
            return interface.ToolInterface.ValidateError.ProhibitedRange;
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{ "SYNC", "VERIFY" },
            .reason = "Void target validated",
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const size = if (operands.len > 1) operands[1] else 0;

        _ = ctx;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = size / 64,
            .bytes_transferred = size,
            .error_message = null,
        };
    }
};
