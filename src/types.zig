pub const UCICommand = enum {
    uci,
    isready,
    setoption,
    ucinewgame,
    position,
    go,
    stop,
    ponderhit,
    quit,
};
pub const DebugMode = enum { on, off };
