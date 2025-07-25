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
