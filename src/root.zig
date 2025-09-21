//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

/// A 64-bit Steam ID
pub const SteamId = u64;

/// Represents a Steam ID with its components
pub const SteamIdComponents = struct {
    /// The account ID portion (32 bits)
    account_id: u32,

    /// The instance ID portion (20 bits)
    instance_id: u20,

    /// The type ID portion (4 bits)
    type_id: u4,

    /// The universe ID portion (8 bits)
    universe_id: u8,
};

pub fn parseSteamId(id: SteamId) SteamIdComponents {
    return .{
        .account_id = @intCast(id & 0xFFFF_FFFF),
        .instance_id = @intCast((id >> 32) & 0xFFFF_F),
        .type_id = @intCast((id >> 52) & 0xF),
        .universe_id = @intCast((id >> 56) & 0xFF),
    };
}

pub fn makeSteamId(components: SteamIdComponents) SteamId {
    return @as(SteamId, components.account_id) | (@as(SteamId, components.instance_id) << 32) | (@as(SteamId, components.type_id) << 52) | (@as(SteamId, components.universe_id) << 56);
}

pub fn isValid(id: SteamId) bool {
    const components = parseSteamId(id);
    return components.universe_id != 0;
}

pub fn getAccountId(id: SteamId) u32 {
    return @intCast(id & 0xFFFF_FFFF);
}

pub fn getInstanceId(id: SteamId) u20 {
    return @intCast((id >> 32) & 0xFFFF_F);
}

pub fn getTypeId(id: SteamId) u4 {
    return @intCast((id >> 52) & 0xF);
}

pub fn getUniverseId(id: SteamId) u8 {
    return @intCast((id >> 56) & 0xFF);
}

/// Converts a SteamID3 string (like [U:1:12345]) to a 64-bit Steam ID
pub fn fromSteamId3(steam_id3: []const u8) !SteamId {
    // [U:1:12345]
    if (steam_id3.len < 5 or steam_id3[0] != '[' or steam_id3[steam_id3.len - 1] != ']') {
        return error.InvalidSteamId3Format;
    }

    var colon_positions: [2]usize = .{ 0, 0 };
    var colon_count: usize = 0;

    for (steam_id3, 0..) |char, i| {
        if (char == ':' and colon_count < 2) {
            colon_positions[colon_count] = i;
            colon_count += 1;
        }
    }

    if (colon_count != 2) {
        return error.InvalidSteamId3Format;
    }

    const type_str = steam_id3[1..colon_positions[0]];
    const universe_str = steam_id3[colon_positions[0] + 1 .. colon_positions[1]];
    const account_str = steam_id3[colon_positions[1] + 1 .. steam_id3.len - 1];

    var type_id: u4 = undefined;
    if (std.mem.eql(u8, type_str, "U")) {
        type_id = 1; // User type
    } else if (std.mem.eql(u8, type_str, "G")) {
        type_id = 2; // Group type
    } else if (std.mem.eql(u8, type_str, "A")) {
        type_id = 3; // App type
    } else if (std.mem.eql(u8, type_str, "M")) {
        type_id = 4; // Multiseat type
    } else if (std.mem.eql(u8, type_str, "I")) {
        type_id = 5; // Invalid type
    } else if (std.mem.eql(u8, type_str, "P")) {
        type_id = 6; // Partner type
    } else if (std.mem.eql(u8, type_str, "C")) {
        type_id = 7; // Clan type
    } else if (std.mem.eql(u8, type_str, "g")) {
        type_id = 8; // Game Server type
    } else if (std.mem.eql(u8, type_str, "T")) {
        type_id = 9; // Anonymous type
    } else {
        return error.InvalidSteamId3Type;
    }
    
    const universe_id = try std.fmt.parseInt(u8, universe_str, 10);
    const account_id = try std.fmt.parseInt(u32, account_str, 10);
    const instance_id: u20 = 0;

    return makeSteamId(.{
        .account_id = account_id,
        .instance_id = instance_id,
        .type_id = type_id,
        .universe_id = universe_id,
    });
}

pub fn toSteamId3(id: SteamId) [32]u8 {
    const components = parseSteamId(id);

    // Determine type character
    var type_char: u8 = 0;
    switch (components.type_id) {
        1 => type_char = 'U',
        2 => type_char = 'G',
        3 => type_char = 'A',
        4 => type_char = 'M',
        5 => type_char = 'I',
        6 => type_char = 'P',
        7 => type_char = 'C',
        8 => type_char = 'g',
        9 => type_char = 'T',
        else => type_char = 'U', // Default to user type
    }

    // Format as string: [U:1:12345]
    var buffer: [32]u8 = undefined;
    std.fmt.bufPrint(buffer[0..], "[{c}:{d}:{d}]", .{
        type_char,
        components.universe_id,
        components.account_id,
    }) catch unreachable;

    return buffer;
}

test "steam id components" {
    const id: SteamId = 76561197970669109;
    const components = parseSteamId(id);

    try std.testing.expect(components.account_id == 10403381);
    try std.testing.expect(components.instance_id == 1);
    try std.testing.expect(components.type_id == 1); // U
    try std.testing.expect(components.universe_id == 1);
}

test "steam id round trip" {
    const original: SteamId = 76561197970669109;
    const components = parseSteamId(original);
    const reconstructed = makeSteamId(components);

    try std.testing.expect(original == reconstructed);
}

test "steam id validity" {
    const valid_id: SteamId = 76561197970669109;
    const invalid_id: SteamId = 0;

    try std.testing.expect(isValid(valid_id) == true);
    try std.testing.expect(isValid(invalid_id) == false);
}
