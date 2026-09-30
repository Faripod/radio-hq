# macOS side of radio-hq. A port to another OS provides the same functions in lib/platform/<os>.sh
# (see PORTING.md); everything else is shared.

# nearest claude ancestor decides: print mode (claude -p) means nobody is watching
rhq_is_headless() {
  local pid=$PPID comm args
  while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
    comm=$(ps -o comm= -p "$pid" 2>/dev/null) || return 1
    case "${comm##*/}" in
      claude|claude.exe)
        args=" $(ps -o args= -p "$pid" 2>/dev/null) "
        case "$args" in *" -p "*|*" --print "*) return 0 ;; esac
        return 1 ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
  return 1
}

# Focus / Do Not Disturb is on when it holds at least one assertion
rhq_dnd() {
  jq -e '[.data[]?.storeAssertionRecords[]?] | length > 0' \
    "$HOME/Library/DoNotDisturb/DB/Assertions.json" >/dev/null 2>&1
}

# rhq_banner title subtitle message group
rhq_banner() {
  if command -v terminal-notifier >/dev/null; then
    # clicking brings back the terminal the session runs in
    terminal-notifier -title "$1" -subtitle "$2" -message "$3" -group "$4" \
      -activate "${__CFBundleIdentifier:-com.apple.Terminal}" >/dev/null 2>&1
  else
    osascript -e 'on run argv' \
      -e 'display notification (item 3 of argv) with title (item 1 of argv) subtitle (item 2 of argv)' \
      -e 'end run' "$1" "$2" "$3" >/dev/null 2>&1
  fi
}

# rhq_play file [seconds]; 0 or empty plays the whole file
rhq_play() {
  if [ -n "$2" ] && [ "$2" != 0 ]; then afplay -t "$2" "$1" 2>/dev/null; else afplay "$1" 2>/dev/null; fi
}

# used until the kit is downloaded
rhq_fallback_sound() {
  case "$1" in
    wait) echo /System/Library/Sounds/Submarine.aiff ;;
    *)    echo /System/Library/Sounds/Glass.aiff ;;
  esac
}

# rhq_to_wav in out: any audio file to mono 16-bit WAV
rhq_to_wav() { afconvert -f WAVE -d LEI16@44100 -c 1 "$1" "$2" 2>/dev/null; }

# "locale<TAB>name" for every installed voice of a language (it, en, ...), best first:
# Premium, then Enhanced, then the rest; the main locale (it_IT, en_US) first within each group
rhq_voices() {
  local main
  case "$1" in en) main=en_US ;; *) main="$1_$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" ;; esac
  say -v '?' | sed -E 's/^(.*[^ ]) +([a-z]{2,3}_[A-Z0-9]{2,3}) +#.*/\2	\1/' | grep "^$1_" \
    | awk -F'\t' -v main="$main" '{ r = ($2 ~ /\(Premium\)/) ? 0 : ($2 ~ /\(Enhanced\)/) ? 1 : 2
                                    print r "\t" ($1 == main ? 0 : 1) "\t" NR "\t" $0 }' \
    | sort -t "$(printf '\t')" -k1,1n -k2,2n -k3,3n | cut -f4-
}

rhq_voice_installed() { say -v '?' | grep -qF "$1 "; }

# rhq_voice lang configured: the configured voice if installed, else the best one for the language.
# Rocko comes with every Mac and is preferred over the robotic defaults.
rhq_voice() {
  local names best
  [ -n "$2" ] && [ "$2" != auto ] && rhq_voice_installed "$2" && { echo "$2"; return; }
  names=$(rhq_voices "$1" | cut -f2)
  best=$(grep -E '\((Premium|Enhanced)\)' <<< "$names" | head -1)
  [ -z "$best" ] && best=$(grep '^Rocko (' <<< "$names" | head -1)
  [ -z "$best" ] && best=$(head -1 <<< "$names")
  echo "$best"
}

# rhq_say_to_file voice text out.wav (mono 16-bit, what lib/radio.py expects)
rhq_say_to_file() {
  say ${1:+-v "$1"} --file-format=WAVE --data-format=LEI16@22050 -o "$3" "$2" 2>/dev/null
}

rhq_say() { say ${1:+-v "$1"} "$2" 2>/dev/null; }

# a python3 that will not pop up the Command Line Tools installer
rhq_python() {
  local py
  py=$(command -v python3) || return 1
  [ "$py" = /usr/bin/python3 ] && ! xcode-select -p >/dev/null 2>&1 && return 1
  echo "$py"
}
