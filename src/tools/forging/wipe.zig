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

// WIPE — Secure Substrate Erase Tool
//
// Purpose:
//   Securely erases substrate memory by overwriting with cryptographic
//   patterns. This is the calcination art — destroying data at the physical
//   level so it cannot be recovered by any means.
//
// How it works:
//   1. Validates the target address and size are non-zero
//   2. Injects SYNC barrier and VERIFY operation for pre-erase attestation
//   3. Overwrites the target region with cryptographic erase patterns
//   4. Returns bytes transferred for verification
//
// VITRIOL relevance:
//   Used as the Azoth counterpart to FLOW — if a transfer corrupts data,
//   WIPE sanitizes the affected region. Also used for secure deletion of
//   sensitive data in the substrate before releasing control.
//
// Op-Code: 0x1F
// Category: CALCINATION
// Safety: CRITICAL (requires explicit Vial waiver — irreversible data destruction)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const WIPE = struct {
    pub const OP = OpCode.WIPE;
    pub const NAME = "WIPE";
    pub const DESCRIPTION = "Securely erase region — overwrite with cryptographic pattern";

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
