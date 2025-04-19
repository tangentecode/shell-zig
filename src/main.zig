const std = @import("std");
const mem = std.mem;

// Define I/O
const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();

pub fn main() anyerror!void {

    // Initialize gpa allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try stdout.writeAll("\x1B[2J\x1B[H"); // Ansi Escape Code for clearing the terminal

    while (true) {
        try stdout.print("{s} >> ", .{try getCwd(allocator)});
        const cmd: ?[]u8 = try stdin.readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize));
        defer if (cmd) |c| allocator.free(c);

        // Handle EOF as exit
        if (cmd == null) std.process.exit(0);

        try parseCmd(allocator, cmd.?);
    }
}

pub fn parseCmd(allocator: std.mem.Allocator, raw_cmd: []const u8) !void {
    var iter = mem.splitAny(u8, raw_cmd, " ");

    const cmd: ?[]const u8 = iter.next() orelse return;
    if (cmd.?.len == 0) return;
    // Get arguments
    var args = std.ArrayList([]const u8).init(allocator);
    defer args.deinit();
    while (iter.next()) |arg| {
        try args.append(arg);
    }

    // Call corresponding function
    if (mem.eql(u8, cmd.?, "print")) {
        try cmdPrint(allocator, args.items);
    } else if (mem.eql(u8, cmd.?, "exit")) {
        try cmdExit();
    } else if (mem.eql(u8, cmd.?, "clear")) {
        try cmdClear();
    } else if (mem.eql(u8, cmd.?, "cwd")) {
        try cmdCwd(allocator);
    } else if (mem.eql(u8, cmd.?, "help")) {
        try cmdHelp();
    } else if (mem.eql(u8, cmd.?, "cd")) {
        try cmdCd(args.items);
    } else if (mem.eql(u8, cmd.?, "ls")) {
        try cmdLs();
    } else {
        try stdout.print("Error: Command '{s}' not found\n", .{cmd.?});
    }
}

pub fn getCwd(allocator: std.mem.Allocator) ![]const u8 {
    return try std.fs.cwd().realpathAlloc(allocator, ".");
}

pub fn cmdPrint(allocator: std.mem.Allocator, args: []const []const u8) !void {

    // Require at least one argument (the quoted text)
    if (args.len == 0) {
        try stdout.writeAll("Usage: print 'text to print'\n");
        return;
    }

    // Join all args with spaces (reconstruct the original string)
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    // Check if the entire input is properly quoted
    const full_input: []u8 = try std.mem.join(allocator, " ", args);
    defer allocator.free(full_input);

    if (!std.mem.startsWith(u8, full_input, "'") or !std.mem.endsWith(u8, full_input, "'")) {
        try stdout.writeAll("Error: Text must be enclosed in single quotes\n");
        try stdout.writeAll("Usage: print 'text to print'\n");
        return;
    }

    // Strip the surrounding quotes
    const stripped: []u8 = full_input[1 .. full_input.len - 1];
    try stdout.print("{s}\n", .{stripped});
}

pub fn cmdCwd(allocator: std.mem.Allocator) !void {
    try stdout.print("{s}\n", .{try getCwd(allocator)});
}

pub fn cmdCd(args: []const []const u8) !void {
    if (args.len == 0) {
        try stdout.writeAll("Usage: cd /path/do/directory\n");
        return;
    }

    std.posix.chdir(args[0]) catch |err| {
        try stdout.print("Unexpected Error: {}\n", .{err});
        return;
    };
}

pub fn cmdLs() !void {
    var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        try stdout.print("{s}\n", .{entry.name});
    }
}

pub fn cmdHelp() !void {
    const help_text =
        "Available commands:\n" ++
        "exit                   | Exit the command line immediately (Alternative exit via CTRL+D)\n" ++
        "clear                  | Removes current command histoy\n" ++
        "print 'example'        | Writes the user-provided text\n" ++
        "cwd                    | Print current working directory\n" ++
        "cd                     | Change working directory\n" ++
        "ls                     | List all items in current directory\n";
    try stdout.print("{s}", .{help_text});
}

pub fn cmdExit() noreturn {
    std.process.exit(0); // Status code 0 indicating sucess;
}

pub fn cmdClear() !void {
    try stdout.writeAll("\x1B[2J\x1B[H"); // Ansi Escape Code for clearing the terminal
}
