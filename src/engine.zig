const std = @import("std");
const build_options = @import("build_options");

const types = @import("types.zig");
const position = @import("position.zig");

pub const Engine = struct {
    /// Tunable options for how the engine should behave.
    options: std.StringHashMap(Option),
    /// The current game position.
    position: position.Position,
    /// Boolean for whether the engine should stop searching.
    stop: bool,

    /// Create a new Engine. Set default options.
    pub fn new(allocator: std.mem.Allocator) !Engine {
        var options = std.StringHashMap(Option).init(allocator);
        try options.put("Foo", Option.new("1", "0", "2"));
        return Engine{
            .options = options,
            .position = position.Position.new(),
            .stop = false,
        };
    }

    pub fn run(self: *Engine) !void {
        const stdin = std.io.getStdIn().reader();

        // Loop to listen for UCI commands.
        var input_buffer: [1024]u8 = undefined;
        while (true) {
            // Read the command line.
            const line = try stdin.readUntilDelimiter(&input_buffer, '\n');

            // Tokenize it and find the appropriate UCI command.
            var tokens = std.mem.tokenizeAny(u8, line, &std.ascii.whitespace);
            var maybe_command: ?types.UCICommand = null;
            while (tokens.next()) |token| {
                maybe_command = std.meta.stringToEnum(types.UCICommand, token);
                if (maybe_command) |_| break;
            }

            // Only continue now if a valid UCI command was found.
            // Otherwise, we just ignore and continue waiting.
            if (maybe_command) |command| {
                switch (command) {
                    .uci => try self.uci(),
                    .isready => try self.isready(),
                    .setoption => try self.setoption(&tokens),
                    .ucinewgame => self.ucinewgame(),
                    // Avoid collisions with position member variable here
                    .position => self.position_command(&tokens),
                    // For go, spawn the handler in a separate thread
                    .go => self.go(&tokens),
                    // Avoid collisions with stop member variable here
                    .stop => self.stop_command(),
                    .ponderhit => self.ponderhit(),
                    .quit => return,
                }
            }
        }

        // As this is an event loop, it should never be allowed to terminate.
        unreachable;
    }

    fn uci(self: *const Engine) !void {
        const stdout = std.io.getStdOut().writer();
        try stdout.print(
            "id name Rosalie {s}\nid author Josiah Voight\n",
            .{build_options.version},
        );
        var options_iterator = self.options.iterator();
        while (options_iterator.next()) |entry| {
            const option = entry.value_ptr.*;
            try stdout.print(
                "option name {s} type spin default {s} min {s} max {s}\n",
                .{ entry.key_ptr.*, option.default, option.min, option.max },
            );
        }
        try stdout.writeAll("uciok\n");
    }

    fn isready(self: *const Engine) !void {
        _ = self;
        try std.io.getStdOut().writeAll("readyok\n");
    }

    fn setoption(self: *Engine, tokens: *std.mem.TokenIterator(u8, .any)) !void {
        // Iterate through remaining tokens. In the spirit of UCI, we allow
        // any number of "throwaway tokens" to be passed here.
        // The actual values for "name" and "value" will be the tokens
        // directly following the keywords.
        var next_token_is_name: bool = false;
        var next_token_is_value: bool = false;
        var maybe_name: ?[]const u8 = null;
        var maybe_value: ?[]const u8 = null;
        while (tokens.next()) |token| {
            if (maybe_name != null and maybe_value != null) {
                break;
            } else if (next_token_is_name) {
                next_token_is_name = false;
                maybe_name = token;
            } else if (next_token_is_value) {
                next_token_is_value = false;
                maybe_value = token;
            } else if (std.mem.eql(u8, token, "name")) {
                next_token_is_name = true;
            } else if (std.mem.eql(u8, token, "value")) {
                next_token_is_value = true;
            }
        }

        // Check that we got both "name" and "value". If we did,
        // set the option. Otherwise, just ignore this command.
        if (maybe_name) |name| {
            if (maybe_value) |value| {
                if (self.options.getPtr(name)) |option| {
                    try option.set(value);
                }
            }
        }
    }

    fn ucinewgame(self: *Engine) void {
        _ = self;
        // TODO: Implement handling for ucinewgame command here.
        // This should involve clearing any current state, resetting
        // the search process, and setting position to default FEN.
    }

    fn position_command(self: *Engine, tokens: *std.mem.TokenIterator(u8, .any)) void {
        _ = self;
        _ = tokens;
        // TODO: Implement a FEN parser here. (or call one somewhere else)
    }

    /// Begin searching for the best move.
    fn go(self: *Engine, tokens: *std.mem.TokenIterator(u8, .any)) void {
        _ = self;
        _ = tokens;
        // TODO: Implement search functionality here.
    }

    fn stop_command(self: *Engine) void {
        self.stop = true;
    }

    fn ponderhit(self: *const Engine) void {
        _ = self;
        // TODO: Implement switch from ponder to normal search here.
    }
};

/// Engine options that can be changed with the setoption command.
const Option = struct {
    default: []const u8,
    min: []const u8,
    max: []const u8,
    value: []const u8,

    pub fn new(default: []const u8, min: []const u8, max: []const u8) Option {
        return Option{ .default = default, .min = min, .max = max, .value = default };
    }

    pub fn set(self: *Option, new_value: []const u8) !void {
        const new_value_int = try std.fmt.parseInt(i32, new_value, 10);
        const min_int = try std.fmt.parseInt(i32, self.min, 10);
        const max_int = try std.fmt.parseInt(i32, self.max, 10);

        // If new value out of bounds, set to closer bound.
        // Otherwise, just set the option to the new value.
        if (new_value_int >= max_int) {
            self.value = self.max;
        } else if (new_value_int <= min_int) {
            self.value = self.min;
        } else {
            self.value = new_value;
        }
    }
};
