const std = @import("std");
const alka_bin = @import("codegen/alka_bin.zig");
const alkac = @import("compiler/alkac.zig");
const instructions = @import("instructions/mod.zig");
const chain_validator = @import("compiler/chain_validator.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var server = LspServer.init(allocator);
    defer server.deinit();
    try server.run();
}

// ── JSON helpers ────────────────────────────────────────

fn makeObject(allocator: std.mem.Allocator, pairs: []const struct { key: []const u8, val: std.json.Value }) !std.json.Value {
    var obj = std.json.ObjectMap.init(allocator);
    for (pairs) |p| try obj.put(p.key, p.val);
    return std.json.Value{ .object = obj };
}

fn makeString(s: []const u8) std.json.Value { return .{ .string = s }; }
fn makeStringOwned(allocator: std.mem.Allocator, s: []const u8) !std.json.Value {
    const copy = try allocator.alloc(u8, s.len);
    @memcpy(copy, s);
    return std.json.Value{ .string = copy };
}
fn makeInt(n: i64) std.json.Value { return .{ .integer = n }; }
fn makeBool(b: bool) std.json.Value { return .{ .bool = b }; }
fn makeNull() std.json.Value { return .{ .null = {} }; }

fn writeJsonResponse(w: anytype, id: u64, result: std.json.Value) !void {
    var buf = std.ArrayList(u8).init(std.heap.page_allocator);
    defer buf.deinit();
    var obj = std.json.ObjectMap.init(std.heap.page_allocator);
    try obj.put("jsonrpc", std.json.Value{ .string = "2.0" });
    try obj.put("id", std.json.Value{ .integer = @as(i64, @intCast(id)) });
    try obj.put("result", result);
    try std.json.stringify(std.json.Value{ .object = obj }, .{}, buf.writer());
    try w.print("Content-Length: {}\r\n\r\n", .{buf.items.len});
    try w.writeAll(buf.items);
}

fn writeJsonNotification(w: anytype, method: []const u8, params: std.json.Value) !void {
    var buf = std.ArrayList(u8).init(std.heap.page_allocator);
    defer buf.deinit();
    var obj = std.json.ObjectMap.init(std.heap.page_allocator);
    try obj.put("jsonrpc", std.json.Value{ .string = "2.0" });
    try obj.put("method", std.json.Value{ .string = method });
    try obj.put("params", params);
    try std.json.stringify(std.json.Value{ .object = obj }, .{}, buf.writer());
    try w.print("Content-Length: {}\r\n\r\n", .{buf.items.len});
    try w.writeAll(buf.items);
}

// ── LSP Protocol ────────────────────────────────────────

const JsonRpcMessage = struct {
    id: ?u64,
    method: ?[]const u8,
    params: ?std.json.Value,
};

fn parseMessage(data: []const u8, allocator: std.mem.Allocator) !JsonRpcMessage {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, data, .{});
    defer parsed.deinit();
    const root = parsed.value;
    var msg = JsonRpcMessage{ .id = null, .method = null, .params = null };
    if (root.object.get("id")) |id_val| {
        msg.id = switch (id_val) { .integer => |n| @as(u64, @intCast(n)), else => null };
    }
    if (root.object.get("method")) |m| {
        msg.method = try allocator.dupe(u8, m.string);
    }
    if (root.object.get("params")) |p| {
        // params is a reference into parsed; we need to clone it
        const param_str = try std.json.stringifyAlloc(allocator, p, .{});
        defer allocator.free(param_str);
        const reparsed = try std.json.parseFromSlice(std.json.Value, allocator, param_str, .{});
        msg.params = reparsed.value;
    }
    return msg;
}

const Diagnostic = struct {
    range: Range,
    severity: u8,
    message: []const u8,
};

const Range = struct { start: Position, end: Position };
const Position = struct { line: u64, character: u64 };

// ── Workspace Context ─────────────────────────────────────

const DocumentState = struct {
    uri: []const u8,
    text: []const u8,
    diagnostics: std.ArrayList(Diagnostic),
};

const WorkspaceContext = struct {
    allocator: std.mem.Allocator,
    documents: std.StringArrayHashMap(DocumentState),

    fn init(allocator: std.mem.Allocator) WorkspaceContext {
        return .{ .allocator = allocator, .documents = std.StringArrayHashMap(DocumentState).init(allocator) };
    }

    fn deinit(self: *WorkspaceContext) void {
        var it = self.documents.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.uri);
            self.allocator.free(entry.value_ptr.text);
            entry.value_ptr.diagnostics.deinit();
        }
        self.documents.deinit();
    }

    fn openDocument(self: *WorkspaceContext, uri: []const u8, text: []const u8) !void {
        const uri_copy = try self.allocator.dupe(u8, uri);
        const text_copy = try self.allocator.dupe(u8, text);
        var diagnostics = std.ArrayList(Diagnostic).init(self.allocator);

        const parsed = try alkac.parseProgram(text, self.allocator);
        for (parsed.instructions.items, 0..) |instr, i| {
            if (instructions.getInstructionByName(instr.name) == null) {
                try diagnostics.append(.{
                    .range = .{ .start = .{ .line = @intCast(i), .character = 0 }, .end = .{ .line = @intCast(i), .character = @intCast(instr.name.len) } },
                    .severity = 1,
                    .message = try std.fmt.allocPrint(self.allocator, "Unknown instruction: {s}", .{instr.name}),
                });
            }
        }

        const cfg = chain_validator.ChainConfig{};
        const chain_result = try chain_validator.validateChain(parsed.instructions.items, self.allocator, cfg);
        for (chain_result.errors, 0..) |err_msg, i| {
            try diagnostics.append(.{
                .range = .{ .start = .{ .line = @intCast(i), .character = 0 }, .end = .{ .line = @intCast(i), .character = 20 } },
                .severity = 1,
                .message = err_msg,
            });
        }
        for (chain_result.warnings, 0..) |warn_msg, i| {
            try diagnostics.append(.{
                .range = .{ .start = .{ .line = @intCast(i), .character = 0 }, .end = .{ .line = @intCast(i), .character = 20 } },
                .severity = 2,
                .message = warn_msg,
            });
        }

        try self.documents.put(uri_copy, .{ .uri = uri_copy, .text = text_copy, .diagnostics = diagnostics });
    }

    fn updateDocument(self: *WorkspaceContext, uri: []const u8, text: []const u8) !void {
        if (self.documents.getPtr(uri)) |doc| {
            self.allocator.free(doc.text);
            doc.text = try self.allocator.dupe(u8, text);
            doc.diagnostics.clearRetainingCapacity();

            const parsed = try alkac.parseProgram(text, self.allocator);
            for (parsed.instructions.items, 0..) |instr, i| {
                if (instructions.getInstructionByName(instr.name) == null) {
                    try doc.diagnostics.append(.{
                        .range = .{ .start = .{ .line = @intCast(i), .character = 0 }, .end = .{ .line = @intCast(i), .character = @intCast(instr.name.len) } },
                        .severity = 1,
                        .message = try std.fmt.allocPrint(self.allocator, "Unknown instruction: {s}", .{instr.name}),
                    });
                }
            }

            const cfg = chain_validator.ChainConfig{};
            const chain_result = try chain_validator.validateChain(parsed.instructions.items, self.allocator, cfg);
            for (chain_result.errors, 0..) |err_msg, i| {
                try doc.diagnostics.append(.{
                    .range = .{ .start = .{ .line = @intCast(i), .character = 0 }, .end = .{ .line = @intCast(i), .character = 20 } },
                    .severity = 1,
                    .message = err_msg,
                });
            }
            for (chain_result.warnings, 0..) |warn_msg, i| {
                try doc.diagnostics.append(.{
                    .range = .{ .start = .{ .line = @intCast(i), .character = 0 }, .end = .{ .line = @intCast(i), .character = 20 } },
                    .severity = 2,
                    .message = warn_msg,
                });
            }
        }
    }
};

// ── LSP Server ────────────────────────────────────────────

const LspServer = struct {
    allocator: std.mem.Allocator,
    ctx: WorkspaceContext,
    stdin: std.fs.File,
    stdout: std.fs.File,

    fn init(allocator: std.mem.Allocator) LspServer {
        return .{
            .allocator = allocator,
            .ctx = WorkspaceContext.init(allocator),
            .stdin = std.io.getStdIn(),
            .stdout = std.io.getStdOut(),
        };
    }

    fn deinit(self: *LspServer) void {
        self.ctx.deinit();
    }

    fn run(self: *LspServer) !void {
        while (true) {
            const msg = self.readMessage() catch |err| {
                if (err == error.EndOfStream) return;
                continue;
            };
            defer self.allocator.free(msg);
            const parsed = parseMessage(msg, self.allocator) catch continue;
            defer {
                if (parsed.method) |m| self.allocator.free(m);
                // params is leaked for simplicity — short-lived server
            }
            const method = parsed.method orelse continue;

            if (std.mem.eql(u8, method, "initialize")) {
                try self.handleInitialize(parsed.id orelse 0);
            } else if (std.mem.eql(u8, method, "shutdown")) {
                try writeJsonResponse(self.stdout.writer(), parsed.id orelse 0, makeNull());
                return;
            } else if (std.mem.eql(u8, method, "exit")) {
                return;
            } else if (std.mem.eql(u8, method, "textDocument/didOpen")) {
                try self.handleDidOpen(parsed.params);
            } else if (std.mem.eql(u8, method, "textDocument/didChange")) {
                try self.handleDidChange(parsed.params);
            } else if (std.mem.eql(u8, method, "textDocument/hover")) {
                try self.handleHover(parsed.id orelse return, parsed.params);
            } else if (std.mem.eql(u8, method, "textDocument/inlayHint")) {
                try self.handleInlayHint(parsed.id orelse return, parsed.params);
            } else if (std.mem.eql(u8, method, "textDocument/completion")) {
                try self.handleCompletion(parsed.id orelse return);
            }
        }
    }

    fn readMessage(self: *LspServer) ![]u8 {
        var content_length: usize = 0;
        while (true) {
            const line = self.readLine();
            if (line.len == 0) break;
            if (std.mem.startsWith(u8, line, "Content-Length: ")) {
                content_length = try std.fmt.parseInt(usize, line[16..], 10);
            }
            self.allocator.free(line);
        }
        if (content_length == 0) return error.EndOfStream;
        const buf = try self.allocator.alloc(u8, content_length);
        errdefer self.allocator.free(buf);
        const n = try self.stdin.read(buf);
        if (n != content_length) return error.EndOfStream;
        return buf;
    }

    fn readLine(self: *LspServer) []u8 {
        var buf = std.ArrayList(u8).init(self.allocator);
        var byte: [1]u8 = undefined;
        while (true) {
            const n = self.stdin.read(&byte) catch break;
            if (n == 0) break;
            if (byte[0] == '\n') break;
            if (byte[0] != '\r') buf.append(byte[0]) catch break;
        }
        return buf.toOwnedSlice() catch &[_]u8{};
    }

    fn handleInitialize(self: *LspServer, id: u64) !void {
        const caps = try makeObject(self.allocator, &.{
            .{ .key = "textDocumentSync", .val = makeInt(1) },
            .{ .key = "hoverProvider", .val = makeBool(true) },
            .{ .key = "inlayHintProvider", .val = makeBool(true) },
            .{ .key = "completionProvider", .val = try makeObject(self.allocator, &.{
                .{ .key = "triggerCharacters", .val = blk: {
                    var a = std.ArrayList(std.json.Value).init(self.allocator);
                    try a.append(makeString("."));
                    break :blk std.json.Value{ .array = a };
                } },
            }) },
        });
        const info = try makeObject(self.allocator, &.{
            .{ .key = "name", .val = makeString("alka-lsp") },
            .{ .key = "version", .val = makeString("0.1.0") },
        });
        const result = try makeObject(self.allocator, &.{
            .{ .key = "capabilities", .val = caps },
            .{ .key = "serverInfo", .val = info },
        });
        try writeJsonResponse(self.stdout.writer(), id, result);
    }

    fn handleDidOpen(self: *LspServer, params: ?std.json.Value) !void {
        const p = params orelse return;
        const uri = p.object.get("textDocument").?.object.get("uri").?.string;
        const text = p.object.get("textDocument").?.object.get("text").?.string;
        try self.ctx.openDocument(uri, text);
        try self.pushDiagnostics(uri);
    }

    fn handleDidChange(self: *LspServer, params: ?std.json.Value) !void {
        const p = params orelse return;
        const uri = p.object.get("textDocument").?.object.get("uri").?.string;
        const changes = p.object.get("contentChanges").?.array;
        if (changes.items.len > 0) {
            const text = changes.items[0].object.get("text").?.string;
            try self.ctx.updateDocument(uri, text);
            try self.pushDiagnostics(uri);
        }
    }

    fn pushDiagnostics(self: *LspServer, uri: []const u8) !void {
        const doc = self.ctx.documents.get(uri) orelse return;
        var diag_items = std.ArrayList(std.json.Value).init(self.allocator);
        for (doc.diagnostics.items) |d| {
            const diag = try makeObject(self.allocator, &.{
                .{ .key = "range", .val = try makeObject(self.allocator, &.{
                    .{ .key = "start", .val = try makeObject(self.allocator, &.{
                        .{ .key = "line", .val = makeInt(@as(i64, @intCast(d.range.start.line))) },
                        .{ .key = "character", .val = makeInt(@as(i64, @intCast(d.range.start.character))) },
                    }) },
                    .{ .key = "end", .val = try makeObject(self.allocator, &.{
                        .{ .key = "line", .val = makeInt(@as(i64, @intCast(d.range.end.line))) },
                        .{ .key = "character", .val = makeInt(@as(i64, @intCast(d.range.end.character))) },
                    }) },
                }) },
                .{ .key = "severity", .val = makeInt(d.severity) },
                .{ .key = "message", .val = makeString(d.message) },
                .{ .key = "source", .val = makeString("alka-lsp") },
            });
            try diag_items.append(diag);
        }
        const params = try makeObject(self.allocator, &.{
            .{ .key = "uri", .val = makeString(uri) },
            .{ .key = "diagnostics", .val = std.json.Value{ .array = diag_items } },
        });
        try writeJsonNotification(self.stdout.writer(), "textDocument/publishDiagnostics", params);
    }

    fn handleHover(self: *LspServer, id: u64, params: ?std.json.Value) !void {
        const p = params orelse return;
        const uri = p.object.get("textDocument").?.object.get("uri").?.string;
        const pos = p.object.get("position").?.object;
        const line = @as(u64, @intCast(pos.get("line").?.integer));
        const character = @as(u64, @intCast(pos.get("character").?.integer));
        const doc = self.ctx.documents.get(uri) orelse {
            try writeJsonResponse(self.stdout.writer(), id, makeNull());
            return;
        };
        var line_iter = std.mem.tokenizeScalar(u8, doc.text, '\n');
        var current: u64 = 0;
        var target_line: []const u8 = "";
        while (line_iter.next()) |l| : (current += 1) {
            if (current == line) { target_line = l; break; }
        }
        if (target_line.len == 0 or character >= target_line.len) {
            try writeJsonResponse(self.stdout.writer(), id, makeNull());
            return;
        }
        var start = character;
        var end = character;
        while (start > 0) { const c = target_line[start - 1]; if (c == ' ' or c == '\t') break; start -= 1; }
        while (end < target_line.len) { const c = target_line[end]; if (c == ' ' or c == '\t') break; end += 1; }
        const word = target_line[start..end];
        const upper = try std.ascii.allocUpperString(self.allocator, word);
        defer self.allocator.free(upper);

        if (instructions.getInstructionByName(upper)) |inst| {
            var buf = std.ArrayList(u8).init(self.allocator);
            defer buf.deinit();
            const w = buf.writer();
            try w.print("**{s}** (0x{x})\n\n{s}\n\n---\nCategory: {s}", .{
                upper, @intFromEnum(inst.op_code), inst.description, @tagName(inst.category),
            });
            const contents = try makeObject(self.allocator, &.{
                .{ .key = "kind", .val = makeString("markdown") },
                .{ .key = "value", .val = makeString(buf.items) },
            });
            const result = try makeObject(self.allocator, &.{
                .{ .key = "contents", .val = contents },
            });
            try writeJsonResponse(self.stdout.writer(), id, result);
        } else {
            try writeJsonResponse(self.stdout.writer(), id, makeNull());
        }
    }

    fn handleInlayHint(self: *LspServer, id: u64, params: ?std.json.Value) !void {
        const p = params orelse return;
        const uri = p.object.get("textDocument").?.object.get("uri").?.string;
        const doc = self.ctx.documents.get(uri) orelse {
            try writeJsonResponse(self.stdout.writer(), id, makeNull());
            return;
        };

        var hints = std.ArrayList(std.json.Value).init(self.allocator);
        var line_iter = std.mem.tokenizeScalar(u8, doc.text, '\n');
        var line_no: u64 = 0;

        while (line_iter.next()) |raw_line| : (line_no += 1) {
            const trimmed = std.mem.trim(u8, raw_line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '/') continue;

            var parts = std.mem.tokenizeScalar(u8, trimmed, ' ');
            const raw_name = parts.next() orelse continue;

            var lookup = raw_name;
            if (std.mem.startsWith(u8, lookup, "!!")) {
                lookup = std.mem.trimLeft(u8, lookup[2..], " \t");
                if (lookup.len == 0) {
                    lookup = parts.next() orelse continue;
                }
            }
            if (std.mem.endsWith(u8, lookup, "!")) lookup = lookup[0 .. lookup.len - 1];

            const inst = instructions.getInstructionByName(lookup) orelse continue;
            const opcode = @intFromEnum(inst.op_code);

            // Build label and tooltip as owned strings
            const label = try std.fmt.allocPrint(self.allocator, "⚗ {s}", .{inst.description});
            const tooltip_text = try std.fmt.allocPrint(self.allocator, "{s}\n\nOpcode: 0x{x}\nCategory: {s}", .{ inst.description, opcode, @tagName(inst.category) });

            const hint = try makeObject(self.allocator, &.{
                .{ .key = "position", .val = try makeObject(self.allocator, &.{
                    .{ .key = "line", .val = makeInt(@as(i64, @intCast(line_no))) },
                    .{ .key = "character", .val = makeInt(0) },
                }) },
                .{ .key = "label", .val = try makeStringOwned(self.allocator, label) },
                .{ .key = "kind", .val = makeInt(1) },
                .{ .key = "paddingLeft", .val = makeBool(true) },
                .{ .key = "tooltip", .val = try makeStringOwned(self.allocator, tooltip_text) },
            });
            try hints.append(hint);
        }

        const result = try makeObject(self.allocator, &.{
            .{ .key = "hints", .val = std.json.Value{ .array = hints } },
        });
        try writeJsonResponse(self.stdout.writer(), id, result);
    }

    fn handleCompletion(self: *LspServer, id: u64) !void {
        var item_list = std.ArrayList(std.json.Value).init(self.allocator);
        for ([_][]const u8{ "REQUIRE", "!!" }) |label| {
            const item = try makeObject(self.allocator, &.{
                .{ .key = "label", .val = makeString(label) },
                .{ .key = "kind", .val = makeInt(9) },
                .{ .key = "detail", .val = makeString("Directive") },
            });
            try item_list.append(item);
        }
        for (instructions.instruction_set) |inst| {
            const item = try makeObject(self.allocator, &.{
                .{ .key = "label", .val = makeString(inst.name) },
                .{ .key = "kind", .val = makeInt(14) },
                .{ .key = "detail", .val = makeString(inst.description) },
            });
            try item_list.append(item);
        }
        const result = try makeObject(self.allocator, &.{
            .{ .key = "isIncomplete", .val = makeBool(false) },
            .{ .key = "items", .val = std.json.Value{ .array = item_list } },
        });
        try writeJsonResponse(self.stdout.writer(), id, result);
    }
};
