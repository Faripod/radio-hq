#!/usr/bin/env bash
# Contract tests. Each folder in tests/cases feeds a recorded hook event to hooks/notify.sh in dry-run mode
# and compares the decisions (banner, sound, spoken line) with `expected`. Nothing is shown or played,
# so they run anywhere; a port to another OS is done when they pass unchanged.
#
# A case folder holds event.json and expected, plus optionally: config and state (key=value lines added
# on top of tests/config), tag (the session's category) and env (VAR=value lines for the hook).
# In event.json @FIXTURES@ stands for tests/fixtures.

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/radio-hq-tests.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0

check() {
  if [ "$2" = "$3" ]; then
    pass=$((pass + 1)); echo "ok    $1"
  else
    fail=$((fail + 1)); echo "FAIL  $1"; diff <(printf '%s\n' "$3") <(printf '%s\n' "$2") | sed 's/^/      /'
  fi
}

for dir in "$root"/tests/cases/*/; do
  name=$(basename "$dir")
  home="$tmp/$name"
  mkdir -p "$home/tags"
  cat "$root/tests/config" "$dir/config" > "$home/config" 2>/dev/null
  cp "$dir/state" "$home/state" 2>/dev/null
  session=$(jq -r '.session_id // ""' "$dir/event.json")
  [ -f "$dir/tag" ] && cp "$dir/tag" "$home/tags/$session"
  vars=()
  [ -f "$dir/env" ] && while IFS= read -r v; do [ -n "$v" ] && vars+=("$v"); done < "$dir/env"
  actual=$(sed "s|@FIXTURES@|$root/tests/fixtures|g" "$dir/event.json" \
    | env RADIO_HQ_HOME="$home" RADIO_HQ_DRY_RUN=1 RADIO_HQ_HEADLESS=0 RADIO_HQ_DND=0 "${vars[@]}" \
      bash "$root/hooks/notify.sh" 2>&1)
  check "$name" "$actual" "$(cat "$dir/expected")"
done

# preferences are rewritten in place: comments, order and a symlink to a versioned file survive
home="$tmp/put"; mkdir -p "$home/dotfiles"
printf '# comment\nlang=it\nradio=on\n' > "$home/dotfiles/config"
ln -s "$home/dotfiles/config" "$home/config"
RADIO_HQ_HOME="$home" bash -c '. "$1/lib/common.sh"; rhq_put "$RHQ_CONFIG" lang en; rhq_put "$RHQ_CONFIG" voice_name "Luca (Enhanced)"' _ "$root"
check "put keeps comments and order" "$(cat "$home/config")" $'# comment\nlang=en\nradio=on\nvoice_name=Luca (Enhanced)'
check "put keeps the symlink" "$([ -L "$home/config" ] && echo link)" "link"

# locks: a stale one (left by a crashed run) is taken over, a fresh one is respected
lock="$tmp/lock"
mkdir "$lock" && echo $(( $(date +%s) - 1000 )) > "$lock/since"
lock_result() { bash -c '. "$1/lib/common.sh"; rhq_lock "$2" 300 && echo taken || echo busy' _ "$root" "$lock"; }
check "stale lock is taken over" "$(lock_result)" "taken"
check "fresh lock is respected" "$(lock_result)" "busy"
rm -rf "$lock"; mkdir "$lock"
check "lock without timestamp starts ageing" "$(lock_result)$([ -s "$lock/since" ] && echo +since)" "busy+since"

echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
