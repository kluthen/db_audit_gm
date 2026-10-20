#!/bin/sh
# Public validator of the db_audit_gm bastion (master spec 9.2, 8.1).
# DO NOT TAMPER. Root-owned, read-only. Run as `player`:
#   players:  gm-validate
#   GM:       /opt/gm/validator/validate.sh, executed as player
#
# Rules (the bastion's own invariants, nothing on the database side):
#   - sshd is running and listening on port 22;
#   - /etc/ssh/sshd_config is root-owned, not writable by others, and still
#     allows `player` in with a password;
#   - the player's home is a directory owned by `player`, and writable;
#   - ~/.ssh/id_ed25519 is the player's own, mode 0600, and loads as a key;
#   - ~/.pgpass is the player's own, mode 0600, with a line for `dba`.
#
# Output and exit code:
#   0  green: one line `GREEN: ...`
#   1  red:   one line `RED <rule>: ...` per broken rule
#   2  error: `ERROR: ...` (run as the wrong user); the result is unknown
set -u
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
LC_ALL=C.UTF-8
export LC_ALL

HOME_DIR=/home/player
SSHD_CONFIG=/etc/ssh/sshd_config
KEY=$HOME_DIR/.ssh/id_ed25519
PGPASS=$HOME_DIR/.pgpass

red=0
say_red() { red=$((red + 1)); printf 'RED %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*"; exit 2; }

[ "$(id -un)" = player ] || fail "run me as player (players: gm-validate; GM: docker exec -u player)"

# owned_private <rule> <path>: a regular file owned by player, mode 0600
owned_private() {
    if [ -L "$2" ] || [ ! -f "$2" ]; then
        say_red "$1: $2 is missing or not a regular file"
        return 1
    fi
    st=$(stat -c '%U %a' "$2")
    if [ "$st" != "player 600" ]; then
        say_red "$1: $2 is '$st', expected owner player and mode 600"
        return 1
    fi
    return 0
}

# --- sshd --------------------------------------------------------------------
if ! pgrep -x sshd >/dev/null 2>&1; then
    say_red "sshd: not running"
elif ! awk '$2 ~ /:0016$/ && $4 == "0A" { f = 1 } END { exit !f }' /proc/net/tcp /proc/net/tcp6 2>/dev/null; then
    say_red "sshd: not listening on port 22"
fi

# --- sshd_config -----------------------------------------------------------------
if [ ! -f "$SSHD_CONFIG" ]; then
    say_red "sshd_config: $SSHD_CONFIG is missing"
else
    st=$(stat -c '%U %A' "$SSHD_CONFIG")
    case $st in
        'root -rw-r--r--' | 'root -r--r--r--') ;;
        *) say_red "sshd_config: $SSHD_CONFIG is '$st', expected root-owned and read-only for others (DO NOT TAMPER)" ;;
    esac
    grep -Eq '^[[:space:]]*AllowUsers[[:space:]]+player[[:space:]]*$' "$SSHD_CONFIG" \
        && grep -Eq '^[[:space:]]*PasswordAuthentication[[:space:]]+yes[[:space:]]*$' "$SSHD_CONFIG" \
        || say_red "sshd_config: password login for player is no longer configured (DO NOT TAMPER)"
fi

# --- home --------------------------------------------------------------------------
if [ -L "$HOME_DIR" ] || [ ! -d "$HOME_DIR" ]; then
    say_red "home: $HOME_DIR is missing or not a directory"
elif [ "$(stat -c '%U' "$HOME_DIR")" != player ]; then
    say_red "home: $HOME_DIR is not owned by player"
else
    probe=$HOME_DIR/.gm-validate.$$
    if (: > "$probe") 2>/dev/null; then
        rm -f "$probe"
    else
        say_red "home: cannot write in $HOME_DIR (is the disk full?)"
    fi
fi

# --- inner-hop key -----------------------------------------------------------------
if owned_private ssh-key "$KEY"; then
    ssh-keygen -y -f "$KEY" >/dev/null 2>&1 \
        || say_red "ssh-key: $KEY does not load as a private key (DO NOT TAMPER)"
fi

# --- ~/.pgpass -----------------------------------------------------------------------
if owned_private pgpass "$PGPASS"; then
    grep -Eq '^[^#][^:]*:[^:]*:[^:]*:dba:.' "$PGPASS" \
        || say_red "pgpass: $PGPASS has no line for the role dba (DO NOT TAMPER)"
fi

if [ "$red" -gt 0 ]; then
    exit 1
fi
printf 'GREEN: sshd up, sshd_config intact, home writable, inner-hop key and ~/.pgpass in place\n'
exit 0
