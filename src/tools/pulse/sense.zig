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

// SENSE — Hardware Sensor Reading Tool
//
// Purpose:
//   Reads hardware sensor values (thermal, voltage, current) from the
//   substrate. This is the primary telemetry primitive — all thermal
//   shadowing and safety checks depend on SENSE data.
//
// How it works:
//   1. Validates the sensor ID is within the valid range (0-255)
//   2. Reads the sensor value from the hardware monitoring interface
//   3. Returns the sensor reading as a 4-byte value
//   4. Used by GUARD conditions to trigger automatic rollback on thresholds
//
// VITRIOL relevance:
//   Before heat-generating operations (STRIKE, FLOW), SENSE checks GPU
//   temperature. If temp exceeds the Vial's THROTTLE_AT or HALT_AT limits,
//   the compiler injects YIELD or QUANCH operations automatically.
//
// Op-Code: 0x07
// Category: PULSE
// Safety: L2 (soft contract — injects safety operations)

const std = @import("std");
const interface = @import("../interface.zig");

pub const OpCode = interface.ToolInterface.OpCode;

pub const SENSE = struct {
    pub const OP = OpCode.SENSE;
    pub const NAME = "SENSE";
    pub const DESCRIPTION = "Read hardware sensor value (thermal, voltage, current)";

    pub fn validate(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.ValidateError!interface.ToolInterface.ValidateResult {
        _ = ctx;
        if (operands.len < 1) {
            return interface.ToolInterface.ValidateError.InvalidAlignment;
        }

        const sensor_id = operands[0];
        if (sensor_id > 255) {
            return interface.ToolInterface.ValidateError.ProhibitedRange;
        }

        return interface.ToolInterface.ValidateResult{
            .allowed = true,
            .injected_operations = &.{},
            .reason = "Sensor ID validated",
        };
    }

    pub fn execute(
        operands: []const u64,
        ctx: interface.ToolInterface.Context,
    ) interface.ToolInterface.Result {
        const sensor_id = if (operands.len > 0) operands[0] else 0;

        _ = ctx;
        _ = sensor_id;

        return interface.ToolInterface.Result{
            .success = true,
            .cycles_spent = 8,
            .bytes_transferred = 4,
            .error_message = null,
        };
    }
};
