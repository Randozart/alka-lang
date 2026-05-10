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

pub const Token = struct {
    tag: Tag,
    text: []const u8,
    line: usize,
};

pub const Tag = enum {
    invalid,
    eof,
    ident,
    number,
    string,
    l_paren,
    r_paren,
    l_brace,
    r_brace,
    l_bracket,
    r_bracket,
    comma,
    colon,
    semicolon,
    arrow,
    at,
    equals,

    // Keywords
    keyword_vessel,
    keyword_require,
    keyword_claim,
    keyword_flow,
    keyword_shift,
    keyword_fence,
    keyword_sync,
    keyword_pulse,
    keyword_stake,
    keyword_sense,
    keyword_yield,
    keyword_signal,
    keyword_recast,
    keyword_snap,
    keyword_revert,
    keyword_limit,
    keyword_as,
    keyword_to,
    keyword_max,
    keyword_bar,
    keyword_aperture,
    keyword_thermal,
    keyword_pci_id,
    keyword_block_device,
    keyword_dma_capable,
    keyword_isolated,
    keyword_real_time,
    keyword_veil,
    keyword_delegate,
    keyword_rhythm,
    keyword_distill,
    keyword_enqueue,
    keyword_molt,
    keyword_vouch,
    keyword_probe_bus,
    keyword_echo,
    keyword_stasis,
    keyword_transverse,
    keyword_search,
    keyword_fossilize,
    keyword_strike,
    keyword_quench,
    keyword_forge,
    keyword_void,
    keyword_abduct,
    keyword_snoop,
    keyword_scatter,
    keyword_whisper,
    keyword_ghost,
    keyword_hijack,
    keyword_drift,
    keyword_clone,
    keyword_crystallize,
    keyword_overclock,
    keyword_flux,
    keyword_audit,
    keyword_dry_run,
    keyword_mock,
    keyword_prove,
    keyword_watch,
    keyword_trace,
    keyword_guard,
    keyword_isolate,
    keyword_verify,
    keyword_ossify,
    keyword_bond,
    keyword_still,
    keyword_resonate,
    keyword_oscillate,
    keyword_imc_hijack,
};

const KeywordMap = std.ComptimeStringMap(Tag, .{
    .{ "Vessel", .keyword_vessel },
    .{ "REQUIRE", .keyword_require },
    .{ "CLAIM", .keyword_claim },
    .{ "FLOW", .keyword_flow },
    .{ "SHIFT", .keyword_shift },
    .{ "FENCE", .keyword_fence },
    .{ "SYNC", .keyword_sync },
    .{ "PULSE", .keyword_pulse },
    .{ "STAKE", .keyword_stake },
    .{ "SENSE", .keyword_sense },
    .{ "YIELD", .keyword_yield },
    .{ "SIGNAL", .keyword_signal },
    .{ "RECAST", .keyword_recast },
    .{ "SNAP", .keyword_snap },
    .{ "REVERT", .keyword_revert },
    .{ "LIMIT", .keyword_limit },
    .{ "AS", .keyword_as },
    .{ "TO", .keyword_to },
    .{ "MAX", .keyword_max },
    .{ "BAR", .keyword_bar },
    .{ "Aperture", .keyword_aperture },
    .{ "Thermal", .keyword_thermal },
    .{ "PCI_ID", .keyword_pci_id },
    .{ "BLOCK_DEVICE", .keyword_block_device },
    .{ "DMA_CAPABLE", .keyword_dma_capable },
    .{ "ISOLATED", .keyword_isolated },
    .{ "REAL_TIME", .keyword_real_time },
    .{ "VEIL", .keyword_veil },
    .{ "DELEGATE", .keyword_delegate },
    .{ "RHYTHM", .keyword_rhythm },
    .{ "DISTILL", .keyword_distill },
    .{ "ENQUEUE", .keyword_enqueue },
    .{ "MOLT", .keyword_molt },
    .{ "VOUCH", .keyword_vouch },
    .{ "PROBE_BUS", .keyword_probe_bus },
    .{ "ECHO", .keyword_echo },
    .{ "STASIS", .keyword_stasis },
    .{ "TRANSVERSE", .keyword_transverse },
    .{ "SEARCH", .keyword_search },
    .{ "FOSSILIZE", .keyword_fossilize },
    .{ "STRIKE", .keyword_strike },
    .{ "QUENCH", .keyword_quench },
    .{ "FORGE", .keyword_forge },
    .{ "VOID", .keyword_void },
    .{ "ABDUCT", .keyword_abduct },
    .{ "SNOOP", .keyword_snoop },
    .{ "SCATTER", .keyword_scatter },
    .{ "WHISPER", .keyword_whisper },
    .{ "GHOST", .keyword_ghost },
    .{ "HIJACK", .keyword_hijack },
    .{ "DRIFT", .keyword_drift },
    .{ "CLONE", .keyword_clone },
    .{ "CRYSTALLIZE", .keyword_crystallize },
    .{ "OVERCLOCK", .keyword_overclock },
    .{ "FLUX", .keyword_flux },
    .{ "AUDIT", .keyword_audit },
    .{ "DRY_RUN", .keyword_dry_run },
    .{ "MOCK", .keyword_mock },
    .{ "PROVE", .keyword_prove },
    .{ "WATCH", .keyword_watch },
    .{ "TRACE", .keyword_trace },
    .{ "GUARD", .keyword_guard },
    .{ "ISOLATE", .keyword_isolate },
    .{ "VERIFY", .keyword_verify },
    .{ "OSSIFY", .keyword_ossify },
    .{ "BOND", .keyword_bond },
    .{ "STILL", .keyword_still },
    .{ "RESONATE", .keyword_resonate },
    .{ "OSCILLATE", .keyword_oscillate },
    .{ "IMC_HIJACK", .keyword_imc_hijack },
});

pub const Lexer = struct {
    source: []const u8,
    pos: usize,
    line: usize,
    start: usize,

    pub fn init(source: []const u8) Lexer {
        return .{
            .source = source,
            .pos = 0,
            .line = 1,
            .start = 0,
        };
    }

    pub fn next(self: *Lexer) Token {
        self.skipWhitespace();
        self.start = self.pos;

        if (self.pos >= self.source.len) {
            return .{
                .tag = .eof,
                .text = "",
                .line = self.line,
            };
        }

        const c = self.source[self.pos];

        if (std.ascii.isAlnum(c) or c == '_') {
            return self.ident();
        }

        if (std.ascii.isDigit(c)) {
            return self.number();
        }

        self.pos += 1;

        switch (c) {
            '(' => return .{.tag = .l_paren, .text = "(", .line = self.line},
            ')' => return .{.tag = .r_paren, .text = ")", .line = self.line},
            '{' => return .{.tag = .l_brace, .text = "{", .line = self.line},
            '}' => return .{.tag = .r_brace, .text = "}", .line = self.line},
            '[' => return .{.tag = .l_bracket, .text = "[", .line = self.line},
            ']' => return .{.tag = .r_bracket, .text = "]", .line = self.line},
            ',' => return .{.tag = .comma, .text = ",", .line = self.line},
            ':' => return .{.tag = .colon, .text = ":", .line = self.line},
            ';' => return .{.tag = .semicolon, .text = ";", .line = self.line},
            '=' => return .{.tag = .equals, .text = "=", .line = self.line},
            '@' => return .{.tag = .at, .text = "@", .line = self.line},
            '-' => {
                if (self.peek() == '>') {
                    self.pos += 1;
                    return .{.tag = .arrow, .text = "->", .line = self.line};
                }
            },
            '"' => return self.string(),
            else => {},
        }

        return .{
            .tag = .invalid,
            .text = self.source[self.start..self.pos],
            .line = self.line,
        };
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (c == ' ' or c == '\t' or c == '\n') {
                if (c == '\n') self.line += 1;
                self.pos += 1;
            } else if (c == '/') {
                if (self.peek() == '/') {
                    while (self.pos < self.source.len and self.source[self.pos] != '\n') {
                        self.pos += 1;
                    }
                }
            } else {
                break;
            }
        }
    }

    fn peek(self: Lexer) u8 {
        if (self.pos + 1 >= self.source.len) return 0;
        return self.source[self.pos + 1];
    }

    fn ident(self: *Lexer) Token {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (std.ascii.isAlnum(c) or c == '_' or c == ':') {
                self.pos += 1;
            } else {
                break;
            }
        }

        const text = self.source[self.start..self.pos];
        const tag = KeywordMap.get(text) orelse .ident;

        return .{ .tag = tag, .text = text, .line = self.line };
    }

    fn number(self: *Lexer) Token {
        while (self.pos < self.source.len) {
            const c = self.source[self.pos];
            if (std.ascii.isDigit(c) or c == 'x' or c == 'a' or c == 'b' or c == 'c' or c == 'd' or c == 'e' or c == 'f' or c == 'A' or c == 'B' or c == 'C' or c == 'D' or c == 'E' or c == 'F') {
                self.pos += 1;
            } else {
                break;
            }
        }

        return .{
            .tag = .number,
            .text = self.source[self.start..self.pos],
            .line = self.line,
        };
    }

    fn string(self: *Lexer) Token {
        self.pos += 1;
        self.start = self.pos;

        while (self.pos < self.source.len and self.source[self.pos] != '"') {
            self.pos += 1;
        }

        const text = self.source[self.start..self.pos];
        if (self.pos < self.source.len) self.pos += 1;

        return .{ .tag = .string, .text = text, .line = self.line };
    }
};

pub const Instr = union(enum) {
    claim: struct { target: []const u8 },
    flow: struct { src: Expression, dst: Expression, size: Expression },
    shift: struct { vessel: []const u8, offset: Expression },
    fence: struct { vessel: []const u8, condition: Comparison },
    sync: struct { level: u3 },
    pulse: struct { target: []const u8, freq: Expression },
    stake: struct { addr: Expression, len: Expression },
    sense: struct { sensor: []const u8, as: []const u8 },
    yield: struct { micros: u64 },
    signal: struct { vector: u32 },
    recast: struct { vessel: []const u8, bitstream: []const u8 },
    snap: struct { vessel: []const u8, as: []const u8 },
    revert: struct { vessel: []const u8, to: []const u8 },
    limit: struct { vessel: []const u8, property: []const u8, value: Expression },
    require: struct { vial: []const u8 },
    generic: struct { name: []const u8, operands: std.ArrayList(Expression) },
};

pub const Expression = union(enum) {
    literal: u64,
    identifier: []const u8,
    indexed: struct { base: []const u8, index: Expression },
    memory_size: struct { value: u64, unit: []const u8 },
};

pub const Comparison = struct {
    lhs: Expression,
    rhs: Expression,
    op: enum { eq, neq, gt, gte, lt, lte },
};

pub const Program = struct {
    instructions: std.ArrayList(Instr),
    requires: std.ArrayList([]const u8),
};

pub const VesselDef = struct {
    name: []const u8,
    pci_id: ?struct { vendor: u16, device: u16 },
    apertures: std.ArrayList(ApertureDef),
    thermal: ?ThermalDef,
    block_device: ?[]const u8,
    dma_capable: ?bool,
    isolated: ?bool,
    real_time: ?bool,
};

pub const ApertureDef = struct {
    name: []const u8,
    bar: u8,
    max_window: ?u64,
    size: ?u64,
    aperture_type: ?[]const u8,
};

pub const ThermalDef = struct {
    halt_at: ?u64,
    throttle_at: ?u64,
    poll: ?[]const u8,
};

pub const Vial = struct {
    vessels: std.StringArrayHashMap(VesselDef),
};

pub fn parseAlka(source: []const u8, arena: *std.heap.ArenaAllocator) !Program {
    var lexer = Lexer.init(source);
    var tokens = std.ArrayList(Token).init(arena.allocator());
    var token = lexer.next();

    while (token.tag != .eof) {
        try tokens.append(token);
        token = lexer.next();
    }

    try tokens.append(token);

    var pos: usize = 0;
    var program = Program{
        .instructions = std.ArrayList(Instr).init(arena.allocator()),
        .requires = std.ArrayList([]const u8).init(arena.allocator()),
    };

    while (pos < tokens.len) {
        const t = tokens.items[pos];
        switch (t.tag) {
            .keyword_require => {
                pos += 1;
                const vial_token = tokens.items[pos];
                if (vial_token.tag == .string or vial_token.tag == .ident) {
                    try program.requires.append(vial_token.text);
                }
            },
            .keyword_claim => {
                pos += 1;
                const target = tokens.items[pos];
                try program.instructions.append(.{ .claim = .{ .target = target.text } });
            },
            .keyword_flow => {
                const src = try parseExpr(tokens, &pos, arena);
                pos += 1;
                const arrow = tokens.items[pos];
                if (arrow.tag != .arrow) return error.ExpectedArrow;
                pos += 1;
                const dst = try parseExpr(tokens, &pos, arena);
                pos += 1;
                const size = try parseExpr(tokens, &pos, arena);
                try program.instructions.append(.{ .flow = .{ .src = src, .dst = dst, .size = size } });
            },
            .keyword_shift => {
                pos += 1;
                const vessel = tokens.items[pos];
                pos += 1;
                const at = tokens.items[pos];
                if (at.tag != .at) return error.ExpectedAt;
                pos += 1;
                const offset = try parseExpr(tokens, &pos, arena);
                try program.instructions.append(.{ .shift = .{ .vessel = vessel.text, .offset = offset } });
            },
            .keyword_fence => {
                pos += 1;
                const vessel = tokens.items[pos];
                pos += 1;
                _ = tokens.items[pos];
                pos += 1;
                const value = try parseExpr(tokens, &pos, arena);
                try program.instructions.append(.{ .fence = .{ .vessel = vessel.text, .condition = .{ .lhs = .{ .identifier = vessel.text }, .rhs = value, .op = .eq } } });
            },
            .keyword_sync => {
                pos += 1;
                const level = tokens.items[pos];
                const lvl: u3 = switch (level.text[0]) {
                    'L' => try std.fmt.parseInt(u3, level.text[1..], 10),
                    else => 3,
                };
                try program.instructions.append(.{ .sync = .{ .level = lvl } });
            },
            .keyword_pulse => {
                pos += 1;
                const target = tokens.items[pos];
                pos += 1;
                const freq = try parseExpr(tokens, &pos, arena);
                try program.instructions.append(.{ .pulse = .{ .target = target.text, .freq = freq } });
            },
            .keyword_stake => {
                const addr = try parseExpr(tokens, &pos, arena);
                pos += 1;
                const len = try parseExpr(tokens, &pos, arena);
                try program.instructions.append(.{ .stake = .{ .addr = addr, .len = len } });
            },
            .keyword_sense => {
                pos += 1;
                const sensor = tokens.items[pos];
                pos += 1;
                const as_tok = tokens.items[pos];
                if (as_tok.tag != .keyword_as) return error.ExpectedAs;
                pos += 1;
                const as = tokens.items[pos];
                try program.instructions.append(.{ .sense = .{ .sensor = sensor.text, .as = as.text } });
            },
            .keyword_yield => {
                pos += 1;
                const micros = try parseExpr(tokens, &pos, arena);
                try program.instructions.append(.{ .yield = .{ .micros = switch (micros) {
                    .literal => |v| v,
                    else => 0,
                } } });
            },
            .keyword_signal => {
                pos += 1;
                const vector = tokens.items[pos];
                try program.instructions.append(.{ .signal = .{ .vector = try std.fmt.parseInt(u32, vector.text, 10) } });
            },
            .keyword_limit => {
                pos += 1;
                const vessel = tokens.items[pos];
                pos += 1;
                const property = tokens.items[pos];
                pos += 1;
                _ = tokens.items[pos];
                pos += 1;
                const value = try parseExpr(tokens, &pos, arena);
                try program.instructions.append(.{ .limit = .{ .vessel = vessel.text, .property = property.text, .value = value } });
            },
            .keyword_snap => {
                pos += 1;
                const vessel = tokens.items[pos];
                pos += 1;
                _ = tokens.items[pos];
                pos += 1;
                const as = tokens.items[pos];
                try program.instructions.append(.{ .snap = .{ .vessel = vessel.text, .as = as.text } });
            },
            .keyword_revert => {
                pos += 1;
                const vessel = tokens.items[pos];
                pos += 1;
                _ = tokens.items[pos];
                pos += 1;
                const to = tokens.items[pos];
                try program.instructions.append(.{ .revert = .{ .vessel = vessel.text, .to = to.text } });
            },
            else => {
                const instr_name = tokens.items[pos].text;
                var operands = std.ArrayList(Expression).init(arena);
                while (pos.* + 1 < tokens.len and (tokens.items[pos.* + 1].tag == .number or tokens.items[pos.* + 1].tag == .ident)) {
                    pos.* += 1;
                    const expr = try parseExpr(tokens, pos, arena);
                    try operands.append(expr);
                }
                try program.instructions.append(.{ .generic = .{ .name = instr_name, .operands = operands } });
            },
        }
        pos += 1;
    }

    return program;
}

fn parseExpr(tokens: []const Token, pos: *usize, arena: *std.heap.ArenaAllocator) !Expression {
    const t = tokens[pos.*];

    switch (t.tag) {
        .number => {
            if (std.mem.indexOf(u8, t.text, "MB")) |_| {
                const num = try std.fmt.parseInt(u64, t.text[0..t.text.len-2], 10);
                return .{ .memory_size = .{ .value = num, .unit = "MB" } };
            } else if (std.mem.indexOf(u8, t.text, "GB")) |_| {
                const num = try std.fmt.parseInt(u64, t.text[0..t.text.len-2], 10);
                return .{ .memory_size = .{ .value = num, .unit = "GB" } };
            } else if (t.text[0] == '0' and t.text.len > 2 and t.text[1] == 'x') {
                return .{ .literal = try std.fmt.parseInt(u64, t.text[2..], 16) };
            }
            return .{ .literal = try std.fmt.parseInt(u64, t.text, 10) };
        },
        .ident => {
            if (tokens[pos.* + 1].tag == .l_bracket) {
                const base = t.text;
                pos.* += 2;
                const index = try parseExpr(tokens, pos, arena);
                if (tokens[pos.*].tag == .r_bracket) pos.* += 1;
                return .{ .indexed = .{ .base = base, .index = index } };
            }
            return .{ .identifier = t.text };
        },
        else => return .{ .literal = 0 },
    }
}

pub fn parseVial(source: []const u8, arena: *std.heap.ArenaAllocator) !Vial {
    var lexer = Lexer.init(source);
    var tokens = std.ArrayList(Token).init(arena.allocator());
    var token = lexer.next();

    while (token.tag != .eof) {
        try tokens.append(token);
        token = lexer.next();
    }

    try tokens.append(token);

    var vial = Vial{
        .vessels = std.StringArrayHashMap(VesselDef).init(arena.allocator()),
    };

    var pos: usize = 0;
    while (pos < tokens.len) {
        const t = tokens.items[pos];
        if (t.tag == .keyword_vessel) {
            pos += 1;
            const name_tok = tokens.items[pos];
            var vessel = VesselDef{
                .name = name_tok.text,
                .pci_id = null,
                .apertures = std.ArrayList(ApertureDef).init(arena.allocator()),
                .thermal = null,
                .block_device = null,
                .dma_capable = null,
                .isolated = null,
                .real_time = null,
            };

            pos += 1;
            if (tokens.items[pos].tag == .l_brace) pos += 1;

            while (pos < tokens.len and tokens.items[pos].tag != .r_brace) {
                const field = tokens.items[pos];
                pos += 1;

                switch (field.tag) {
                    .keyword_pci_id => {
                        pos += 1;
                        const id = tokens.items[pos];
                        var parts = std.mem.split(u8, id.text, ":");
                        const vendor = try std.fmt.parseInt(u16, parts.next().?, 16);
                        const device = try std.fmt.parseInt(u16, parts.next().?, 16);
                        vessel.pci_id = .{ .vendor = vendor, .device = device };
                    },
                    .keyword_block_device => {
                        pos += 1;
                        const dev = tokens.items[pos];
                        vessel.block_device = dev.text;
                    },
                    .keyword_dma_capable => {
                        pos += 1;
                        const val = tokens.items[pos];
                        vessel.dma_capable = std.mem.eql(u8, val.text, "true");
                    },
                    .keyword_isolated => {
                        pos += 1;
                        const val = tokens.items[pos];
                        vessel.isolated = std.mem.eql(u8, val.text, "true");
                    },
                    .keyword_real_time => {
                        pos += 1;
                        const val = tokens.items[pos];
                        vessel.real_time = std.mem.eql(u8, val.text, "true");
                    },
                    .keyword_aperture => {
                        pos += 1;
                        const ap_name = tokens.items[pos];
                        pos += 1;
                        if (tokens.items[pos].tag == .l_brace) pos += 1;

                        var aperture = ApertureDef{
                            .name = ap_name.text,
                            .bar = 0,
                            .max_window = null,
                            .size = null,
                            .aperture_type = null,
                        };

                        while (pos < tokens.len and tokens.items[pos].tag != .r_brace) {
                            const ap_field = tokens.items[pos];
                            pos += 1;

                            if (std.mem.eql(u8, ap_field.text, "BAR")) {
                                const bar_val = tokens.items[pos];
                                aperture.bar = try std.fmt.parseInt(u8, bar_val.text, 10);
                            } else if (std.mem.eql(u8, ap_field.text, "MAX_WINDOW")) {
                                const max_val = tokens.items[pos];
                                if (std.mem.indexOf(u8, max_val.text, "MB")) |_| {
                                    aperture.max_window = try std.fmt.parseInt(u64, max_val.text[0..max_val.text.len-2], 10) * 1024 * 1024;
                                } else {
                                    aperture.max_window = try std.fmt.parseInt(u64, max_val.text, 10);
                                }
                            } else if (std.mem.eql(u8, ap_field.text, "SIZE")) {
                                const size_val = tokens.items[pos];
                                if (std.mem.indexOf(u8, size_val.text, "MB")) |_| {
                                    aperture.size = try std.fmt.parseInt(u64, size_val.text[0..size_val.text.len-2], 10) * 1024 * 1024;
                                } else {
                                    aperture.size = try std.fmt.parseInt(u64, size_val.text, 10);
                                }
                            } else if (std.mem.eql(u8, ap_field.text, "TYPE")) {
                                aperture.aperture_type = tokens.items[pos].text;
                            }
                            pos += 1;
                        }
                        try vessel.apertures.append(aperture);
                    },
                    .keyword_thermal => {
                        pos += 1;
                        if (tokens.items[pos].tag == .l_brace) pos += 1;

                        var thermal = ThermalDef{
                            .halt_at = null,
                            .throttle_at = null,
                            .poll = null,
                        };

                        while (pos < tokens.len and tokens.items[pos].tag != .r_brace) {
                            const th_field = tokens.items[pos];
                            pos += 1;

                            if (std.mem.eql(u8, th_field.text, "HALT_AT")) {
                                const val = tokens.items[pos];
                                thermal.halt_at = try std.fmt.parseInt(u64, val.text[0..val.text.len-1], 10);
                            } else if (std.mem.eql(u8, th_field.text, "THROTTLE_AT")) {
                                const val = tokens.items[pos];
                                thermal.throttle_at = try std.fmt.parseInt(u64, val.text[0..val.text.len-1], 10);
                            } else if (std.mem.eql(u8, th_field.text, "POLL")) {
                                thermal.poll = tokens.items[pos].text;
                            }
                            pos += 1;
                        }
                        vessel.thermal = thermal;
                    },
                    else => {},
                }
            }

            try vial.vessels.put(vessel.name, vessel);
            if (pos < tokens.len and tokens.items[pos].tag == .r_brace) pos += 1;
        }
        pos += 1;
    }

    return vial;
}