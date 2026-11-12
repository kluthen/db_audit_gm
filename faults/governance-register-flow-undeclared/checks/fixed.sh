#!/bin/sh
# Sealed check of governance-register-flow-undeclared (v0.5 master spec
# 13.4, 17.2, s6; capture W5 item 2). Run as root on the bastion, fed to
# `sh -s` by gmctl check, with FAULT_RECIPIENT (default Cold Storage). Live
# state: the served handout, /home/player/data-register.md (the starter
# pack's copy in the players' home), read as root. It reads only that the
# change is present (master spec 13.4): the true register is sealed and
# never on a node, so the corrected entries are judged at the final answer
# against the answer key's register_diff, never here.
#
# An entry is a "### <id>: <name>" section of the handout, up to the next
# heading; the recipient is matched without regard to case (its recipient
# line and, for cold storage, its copy line).
# Exit 1: no entry names the recipient (the fault present; never cleared in
# play, the resolution being propose). Exit 0: at least one entry names it
# (the handout regenerated without the fault). Exit 2: no handout, or no
# entry in it.
set -u
HANDOUT=/home/player/data-register.md
RECIPIENT=${FAULT_RECIPIENT:-Cold Storage}

[ -r "$HANDOUT" ] || { echo "the data register cannot be judged: no $HANDOUT on the bastion (the register absent is another fault)"; exit 2; }

# entries naming the recipient|entries
counts=$(awk -v who="$RECIPIENT" '
    BEGIN { who = tolower(who) }
    /^### / { close_entry(); open = 1; named = 0; entries++ }
    /^## / { close_entry() }
    open && index(tolower($0), who) { named = 1 }
    function close_entry() { if (open && named) hits++; open = 0; named = 0 }
    END { close_entry(); printf "%d|%d\n", hits, entries }' "$HANDOUT")
hits=${counts%|*}
entries=${counts#*|}

if [ "${entries:-0}" -eq 0 ]; then
    echo "the data register cannot be judged: $HANDOUT holds no entry (### <id>: <name>)"
    exit 2
fi
if [ "${hits:-0}" -eq 0 ]; then
    echo "the data register handed out names $RECIPIENT on none of its $entries entries: the flow to that processor is declared nowhere."
    exit 1
fi
echo "the data register handed out names $RECIPIENT on $hits of its $entries entries."
exit 0
