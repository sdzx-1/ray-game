# ray-game
Examples for typed-fsm, Requires the [latest zig compiler](https://ziglang.org/download/).

This project is an experiment: building a game with typed-fsm to showcase its advantages and practical usage.

The core idea is to integrate the game editor with the game itself, making it easy to modify the game interface directly.

This approach leads to complex states, but with typed-fsm, I can easily manage them all.

Some interesting highlights so far:
1. Generic states greatly simplify the program. For example, selecting targets with the mouse is a common operation—we abstracted it into a reusable "select" state and used it in at least 8 places.
2. Combining types to express action composition significantly improves the program's modularity. I discovered a way to combine state machine states—a new coding approach.


![editor_graph](data/graph.svg)

# discord
https://discord.gg/SWjPcCbT
