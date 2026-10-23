"""Every random draw comes from the game's seed (master spec 7.1, D136).

Each task (a stream, a fixed-time operation) gets its own generator,
derived from the seed, the node's hostname (the seed is the same on every
scheduler node, capture W1 item 7), the task's identity and the second the
program started running: the same inputs give the same draws, and a
program that resumes after a restart does not repeat the draws it made
before.
"""

import hashlib
import random


def derive(seed, hostname, purpose, started):
    material = f"gm-scheduler|{int(seed)}|{hostname}|{purpose}|{int(started)}".encode()
    return random.Random(int.from_bytes(hashlib.sha256(material).digest(), "big"))
