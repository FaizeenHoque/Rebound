#!/usr/bin/env python3
"""Builds the level scenes from coordinate-based layouts.

The resulting .tscn files store the ASCII map as an exported string, so a
level can also be tweaked directly in the Godot inspector afterwards.
Run: python3 tools/build_levels.py [level numbers...]   (default: all)
"""
import os
import sys

OUT = os.path.join(os.path.dirname(__file__), "..", "scenes", "levels")


class Map:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.g = [["." for _ in range(w)] for _ in range(h)]
        self.hints = []
        self.waves = []

    def fill(self, x0, y0, x1, y1, ch="#"):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g[y][x] = ch

    def put(self, x, y, s):
        for i, ch in enumerate(s):
            self.g[y][x + i] = ch

    def border(self):
        self.fill(0, 0, self.w - 1, 0)
        self.fill(0, 0, 0, self.h - 1)
        self.fill(self.w - 1, 0, self.w - 1, self.h - 1)

    def hint(self, x, y, text):
        self.hints.append(f"{x},{y}|{text}")

    def wave(self, row, first_tick, interval, speed, bob=0):
        """Flying enemies entering from the right edge (see Level.waves)."""
        self.waves.append(f"{row}|{first_tick}|{interval}|{speed}|{bob}")

    def text(self):
        return "\n".join("".join(r) for r in self.g)


def first_fall():
    # Teaches: falling is not the end. The only way up to the exit is DOWN.
    m = Map(84, 23)
    m.border()
    m.fill(0, 18, 83, 22)                 # floor, top surface y=18
    m.put(2, 17, "P")
    m.fill(14, 16, 19, 17)                # 2-tile step
    m.put(25, 17, "^^^")                  # spikes on floor
    m.fill(37, 18, 41, 22, ".")           # pit (falls out of the world)
    m.put(47, 17, "^" * 11)               # spike bed under the platforms
    m.put(48, 15, "----")
    m.put(54, 15, "----")
    m.fill(64, 18, 67, 21, ".")           # the well: a safe drop...
    m.put(65, 21, "oo")                   # ...onto a spring
    m.fill(68, 11, 82, 21)                # exit plateau, unreachable by jumping
    m.put(76, 10, "E")
    m.hint(2, 11, "A/D OR ARROWS: MOVE")
    m.hint(18, 11, "SPACE: JUMP")
    m.hint(22, 12, "POINTY = OUCHIE")
    m.hint(31, 9, "FALLING IS NOT THE END")
    m.hint(31, 10, "YOU ALWAYS BOUNCE BACK")
    m.hint(56, 7, "THE WAY UP")
    m.hint(56, 8, "IS DOWN")
    m.hint(72, 5, "THE EXIT")
    return m


def meet_your_echo():
    m = Map(60, 23)
    m.border()
    m.fill(0, 18, 59, 22)
    m.put(2, 17, "^^")                    # optional spike pit beside the plate
    m.put(5, 17, "aa")                    # pressure plate (channel A)
    m.put(25, 17, "P")
    m.fill(34, 16, 36, 17)                # low wall to hop
    m.fill(44, 1, 44, 12)                 # wall above the door
    m.put(44, 13, "A")                    # door, rows 13..17
    m.put(53, 17, "E")
    m.hint(3, 10, "PLATES OPEN DOORS")
    m.hint(3, 11, "BUT ONLY WHILE HELD")
    m.hint(19, 8, "R: REBOUND (FAIL ON PURPOSE)")
    m.hint(19, 9, "YOUR ECHO REPEATS YOU")
    m.hint(36, 6, "TOO FAR TO DO ALONE...")
    m.hint(36, 7, "BUT YOU ARE NOT ALONE")
    return m


def bounce_back():
    m = Map(72, 31)
    m.border()
    m.fill(0, 26, 71, 30)                 # ground, top surface y=26
    m.put(8, 25, "P")
    m.put(2, 25, "oo")                    # bounce pad up to the walkway
    m.put(1, 17, "-" * 14)                # one-way ledge over the start room
    m.fill(15, 17, 50, 19)                # shelf: upper walkway (top y=17) / corridor ceiling
    m.put(30, 20, "A")                    # door A in the lower corridor
    m.put(37, 25, "^" * 7)                # spikes in the middle room
    m.put(39, 23, "---")                  # stepping platform
    m.put(50, 20, "B")                    # door B
    m.fill(50, 1, 50, 16)                 # wall between walkway and exit hall
    # upper walkway
    m.put(19, 16, "aa")                   # plate A
    m.fill(28, 15, 29, 16)                # small block to hop
    m.put(35, 16, "^^^")                  # spike gap
    m.put(45, 16, "bb")                   # plate B
    m.put(48, 16, "^^")                   # spikes to end the attempt
    # exit hall
    m.put(58, 25, "oo")
    m.fill(62, 16, 70, 17)                # exit ledge (top y=16)
    m.put(67, 15, "E")
    m.hint(5, 20, "ONE ECHO.")
    m.hint(5, 21, "TWO DOORS.")
    m.hint(19, 12, "PLAN YOUR FAILURE")
    m.hint(19, 13, "HOLD A... THEN HOLD B")
    m.hint(53, 11, "ALMOST OUT")
    return m


def incoming():
    # Flyers come in from the right, where the plate is. The run that becomes
    # your echo has to dodge (or stomp) them while holding it, and the echo
    # replays exactly that while you run left for the door.
    m = Map(40, 23)
    m.border()
    m.fill(0, 18, 39, 22)                 # floor, top surface y=18
    m.put(3, 17, "E")
    m.fill(8, 1, 8, 12)                   # wall above the door
    m.put(8, 13, "A")                     # door A, rows 13..17
    m.put(20, 17, "P")
    m.put(33, 17, "aa")                   # plate A, right in the flight path
    m.wave(17, 0, 210, 55)                # low lane only: the gentle flyer intro
    m.hint(12, 4, "THEY COME FROM THE RIGHT")
    m.hint(12, 5, "LAND ON THEM TO BOUNCE")
    m.hint(12, 8, "YOUR ECHO DODGES")
    m.hint(12, 9, "WHAT YOU DODGED")
    return m


def spring_loaded():
    # The plate is on a high ledge you can only reach with the spring: the
    # echo works vertically too. No flyers yet; they arrive in Incoming.
    m = Map(56, 23)
    m.border()
    m.fill(0, 18, 55, 22)                 # floor, top surface y=18
    m.put(4, 17, "oo")                    # spring up to the ledge
    m.put(1, 9, "-" * 11)                 # one-way ledge (top y=9)
    m.put(1, 8, "aa")                     # plate A on the ledge
    m.put(14, 17, "P")
    m.put(24, 17, "^^^^")                 # spikes to hop
    m.fill(40, 1, 40, 12)                 # wall above the door
    m.put(40, 13, "A")                    # door A, rows 13..17
    m.put(50, 17, "E")
    m.hint(13, 4, "UP IS THE WAY")
    m.hint(13, 5, "TO HOLD THE DOOR")
    m.hint(29, 10, "STILL TOO FAR?")
    m.hint(29, 11, "GOOD. YOU KNOW WHAT TO DO")
    return m


def crossfire():
    # Two plates, two doors, and flyers sweeping the floor. Your echo has to
    # hold A while you pass door A, then move to B while you wait between
    # the doors, dodging.
    m = Map(50, 23)
    m.border()
    m.fill(0, 18, 49, 22)                 # floor, top surface y=18
    m.put(3, 17, "P")
    m.put(6, 17, "aa")                    # plate A
    m.put(16, 17, "bb")                   # plate B
    m.fill(34, 1, 34, 12)
    m.put(34, 13, "A")                    # door A
    m.fill(40, 1, 40, 12)
    m.put(40, 13, "B")                    # door B
    m.put(46, 17, "E")
    m.wave(17, 30, 160, 70)               # low lane
    m.hint(5, 8, "HOLD A. THEN HOLD B.")
    m.hint(5, 9, "DON'T STOP DODGING.")
    m.hint(21, 4, "ONE ECHO. TWO DOORS.")
    m.hint(21, 5, "INCOMING FIRE.")
    return m


def last_bounce():
    # Finale: everything at once. Spring up to the plate and hold it through
    # the ledge flyers; then run the floor flyers, through the held door, and
    # bounce up to the exit.
    m = Map(48, 23)
    m.border()
    m.fill(0, 18, 47, 22)                 # floor, top surface y=18
    m.put(4, 17, "oo")                    # spring up to the ledge
    m.put(1, 9, "-" * 11)                 # one-way ledge
    m.put(1, 8, "aa")                     # plate A on the ledge
    m.put(16, 17, "P")
    m.fill(28, 1, 28, 12)
    m.put(28, 13, "A")                    # door A
    m.put(33, 17, "oo")                   # spring up to the exit
    m.fill(37, 10, 46, 17)                # exit block (top y=10)
    m.put(42, 9, "E")
    m.wave(8, 40, 200, 90)                # ledge-height lane
    m.wave(17, 150, 220, 75)              # floor lane: the fastest in the game
    m.hint(13, 4, "EVERYTHING YOU LEARNED")
    m.hint(13, 5, "ALL AT ONCE")
    m.hint(36, 4, "ONE LAST BOUNCE")
    return m


HEADER = """[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://scenes/levels/level_base.tscn" id="1_base"]

"""


def write(num, title, m):
    hints = ", ".join('"%s"' % h for h in m.hints)
    waves = ", ".join('"%s"' % w for w in m.waves)
    body = (
        HEADER
        + f'[node name="Level{num}" instance=ExtResource("1_base")]\n'
        + f"level_number = {num}\n"
        + f'level_title = "{title}"\n'
        + f'map = "{m.text()}"\n'
        + f"hints = PackedStringArray({hints})\n"
        + (f"waves = PackedStringArray({waves})\n" if m.waves else "")
    )
    with open(os.path.join(OUT, f"level_{num}.tscn"), "w") as f:
        f.write(body)
    print(f"level_{num}: {m.w}x{m.h}")
    print(m.text())


LEVELS = {
    1: ("FIRST FALL", first_fall),
    2: ("MEET YOUR ECHO", meet_your_echo),
    3: ("SPRING LOADED", spring_loaded),
    4: ("BOUNCE BACK", bounce_back),
    5: ("INCOMING", incoming),
    6: ("CROSSFIRE", crossfire),
    7: ("LAST BOUNCE", last_bounce),
}

if __name__ == "__main__":
    for num in [int(a) for a in sys.argv[1:]] or LEVELS:
        title, build = LEVELS[num]
        write(num, title, build())
