#!/bin/sh
# Sealed check of docs-overview-backup-claimed (v0.6 master spec 6.3, 8.5,
# trap N5; capture W2 item 4). Run as root on the bastion, fed to `sh -s` by
# gmctl check, with FAULT_NODE and FAULT_CLAIMED. Live state: the served
# handout, /home/player/network-overview.md (the starter pack's copy in the
# players' home, the brick's live path), read as root. It reads only that
# the change is present (master spec 8.5): the true overview is sealed and
# never on a node, so the corrected entry is judged at the final answer
# against the answer key's overview_diff, never here.
#
# The node's entry is the handout's "### <node>" section, up to the next
# heading; its Backups are the nested items under its "- **Backups**:"
# bullet, up to the entry's next bullet. The claimed line is matched
# without regard to case on those items, and on no other line: the entry's
# Third parties or Background tasks may name the vault for what truly goes
# there (the nightly base backup).
# Exit 1: a Backups item of the entry carries the claim (the fault present;
# never cleared in play, the resolution being propose). Exit 0: none does
# (the handout regenerated without the fault). Exit 2: no handout, no entry
# for the node, or an entry without Backups.
set -u
HANDOUT=/home/player/network-overview.md
NODE=${FAULT_NODE:-}
CLAIMED=${FAULT_CLAIMED:-}

[ -n "$NODE" ] && [ -n "$CLAIMED" ] \
    || { echo "the network overview cannot be judged: FAULT_NODE and FAULT_CLAIMED are required"; exit 2; }
[ -r "$HANDOUT" ] || { echo "the network overview cannot be judged: no $HANDOUT on the bastion"; exit 2; }

# entry found|Backups found|items carrying the claim
counts=$(awk -v node="$NODE" -v claim="$CLAIMED" '
    BEGIN { claim = tolower(claim) }
    /^#/ { inside = ($0 == "### " node || $0 == "### `" node "`"); if (inside) entry = 1; backups = 0; next }
    !inside { next }
    /^- \*\*Backups\*\*:/ { backups = 1; found = 1; rest = substr($0, 16); if (index(tolower(rest), claim)) hits++; next }
    /^- / { backups = 0; next }
    backups && /^[ \t]+[-*] / && index(tolower($0), claim) { hits++ }
    END { printf "%d|%d|%d\n", entry, found, hits }' "$HANDOUT")
entry=${counts%%|*}
rest=${counts#*|}
found=${rest%%|*}
hits=${rest#*|}

if [ "${entry:-0}" -eq 0 ]; then
    echo "the network overview cannot be judged: $HANDOUT has no entry ### $NODE"
    exit 2
fi
if [ "${found:-0}" -eq 0 ]; then
    echo "the network overview cannot be judged: the entry of $NODE in $HANDOUT has no Backups"
    exit 2
fi
if [ "${hits:-0}" -gt 0 ]; then
    echo "the network overview handed out claims, under the Backups of $NODE: $CLAIMED"
    exit 1
fi
echo "the network overview handed out claims no \"$CLAIMED\" under the Backups of $NODE."
exit 0
