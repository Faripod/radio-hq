# Shared by the hooks and the radio-hq command: where settings live, how they are read and written,
# which category a session belongs to, and the two languages.

RHQ_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
RHQ_HOME=${RADIO_HQ_HOME:-$HOME/.config/radio-hq}
RHQ_CONFIG=$RHQ_HOME/config   # preferences, safe to version (a symlink is kept)
RHQ_STATE=$RHQ_HOME/state     # switches flipped by `radio-hq on|off|work|personal`
RHQ_TAGS=$RHQ_HOME/tags       # one file per session id holding its category
RHQ_SOUNDS=$RHQ_HOME/sounds   # the kit, downloaded from Mixkit on first run
RHQ_KIT=$RHQ_ROOT/sounds/kit.tsv
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

rhq_platform() {
  case "$(uname -s)" in
    Darwin) echo macos ;;
    *)      echo unsupported ;;
  esac
}

rhq_load_platform() {
  local file
  file="$RHQ_ROOT/lib/platform/$(rhq_platform).sh"
  [ -f "$file" ] && . "$file"
}

# value of a key in a key=value file, or the default
rhq_get() {
  local v
  v=$(grep -E "^$2=" "$1" 2>/dev/null | tail -1 | cut -d= -f2-)
  printf '%s' "${v:-$3}"
}

# rewrites one key in place, keeping comments, order and a symlinked file
rhq_put() {
  local target tmp
  target=$(readlink -f "$1" 2>/dev/null || printf '%s' "$1")
  mkdir -p "$(dirname "$target")"
  tmp=$(mktemp "$(dirname "$target")/.radio-hq.XXXXXX")
  K=$2 V=$3 awk 'index($0, ENVIRON["K"] "=") == 1 { if (!done) print ENVIRON["K"] "=" ENVIRON["V"]; done = 1; next }
                 { print }
                 END { if (!done) print ENVIRON["K"] "=" ENVIRON["V"] }' "$target" 2>/dev/null > "$tmp"
  mv "$tmp" "$target"
}

rhq_init_config() {
  mkdir -p "$RHQ_HOME" "$RHQ_TAGS"
  [ -f "$RHQ_CONFIG" ] && return
  cat > "$RHQ_CONFIG" <<'EOF'
# radio-hq preferences. /radio-hq:setup changes them for you; editing by hand is fine too.

# it | en
lang=it
# auto = the best installed voice for the language, or an exact name from `say -v '?'`
voice_name=auto
# on = walkie-talkie voice, off = clean voice
radio=on
# a name from the kit (`radio-hq sounds`) or the path of an audio file
sound_wait=alert-signal
sound_done=tank-gear-shift
# work | personal: category of the sessions you have not tagged
default_category=work
# folders, separated by ':', whose sessions have no category and always sound (e.g. ~/notes)
always_on_dirs=
EOF
}

RHQ_LANG=$(rhq_get "$RHQ_CONFIG" lang it)

# t "italiano" "english"
t() { if [ "$RHQ_LANG" = en ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

# accepts both languages, answers in English (the stored form)
rhq_category_key() {
  case "$1" in
    work|lavoro)        echo work ;;
    personal|personale) echo personal ;;
    none|nessuno)       echo none ;;
  esac
}

rhq_category_label() {
  case "$1" in
    work)     t lavoro work ;;
    personal) t personale personal ;;
    *)        t nessuna none ;;
  esac
}

# the session tag wins, then always_on_dirs (no category), then default_category
rhq_category() {
  local tag dir dirs
  tag=$(cat "$RHQ_TAGS/$1" 2>/dev/null)
  [ -n "$tag" ] && { echo "$tag"; return; }
  dirs=$(rhq_get "$RHQ_CONFIG" always_on_dirs "")
  local IFS=:
  for dir in $dirs; do
    dir=${dir/#\~/$HOME}
    dir=${dir%/}
    [ -n "$dir" ] || continue
    case "$2" in "$dir"|"$dir"/*) echo none; return ;; esac
  done
  rhq_get "$RHQ_CONFIG" default_category work
}

# rhq_lock dir max_age: takes the lock, clearing one older than max_age seconds (left by a crashed run)
rhq_lock() {
  local since
  if mkdir "$1" 2>/dev/null; then date +%s > "$1/since"; return 0; fi
  since=$(cat "$1/since" 2>/dev/null)
  # a lock without its timestamp starts ageing now
  [ -n "$since" ] || { date +%s > "$1/since"; return 1; }
  [ $(( $(date +%s) - since )) -gt "$2" ] || return 1
  rm -rf "$1"
  mkdir "$1" 2>/dev/null && date +%s > "$1/since"
}

# kit.tsv row for a sound name: name, Mixkit id, seconds to play (0 = all), label
rhq_kit_row() { awk -F'\t' -v n="$1" '$1 == n' "$RHQ_KIT"; }

# "<file>\t<seconds>" for a kit name or a path
rhq_sound_file() {
  case "$1" in
    */*) printf '%s\t0' "${1/#\~/$HOME}" ;;
    *)   printf '%s\t%s' "$RHQ_SOUNDS/$1.wav" "$(rhq_kit_row "$1" | cut -f3)" ;;
  esac
}
