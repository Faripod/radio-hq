#!/usr/bin/env bash
# Notification / PreToolUse(AskUserQuestion|ExitPlanMode) / Stop: whenever an interactive session waits
# for you or finishes a turn, a silent banner, a sound effect and a radio voice reading the session name.
# Headless runs (claude -p) stay silent.
# RADIO_HQ_DRY_RUN=1 prints the decisions instead of acting on them (tests/run.sh);
# RADIO_HQ_HEADLESS and RADIO_HQ_DND (0|1) override the detection; RADIO_HQ_LOG=<file> traces each event.

# shellcheck disable=SC2154  # event, tool, cwd, session, transcript and detail are set by an eval
. "$(dirname "$0")/../lib/common.sh"
dry=${RADIO_HQ_DRY_RUN:-}
rhq_load_platform || [ -n "$dry" ] || exit 0
command -v jq >/dev/null || exit 0
input=$(cat)

headless() { if [ -n "$RADIO_HQ_HEADLESS" ]; then [ "$RADIO_HQ_HEADLESS" = 1 ]; else rhq_is_headless; fi; }
dnd()      { if [ -n "$RADIO_HQ_DND" ]; then [ "$RADIO_HQ_DND" = 1 ]; else rhq_dnd; fi; }
log()      { [ -n "$RADIO_HQ_LOG" ] && printf '%s %s\n' "$(date +%T)" "$*" >> "$RADIO_HQ_LOG"; }

if headless; then log "headless, skipped"; exit 0; fi

eval "$(printf '%s' "$input" | jq -r '
  def clip: gsub("[\\s`*#>]+"; " ") | ltrimstr(" ") | .[0:140];
  @sh "event=\(.hook_event_name // "")",
  @sh "tool=\(.tool_name // "")",
  @sh "cwd=\(.cwd // "")",
  @sh "session=\(.session_id // "")",
  @sh "transcript=\(.transcript_path // "")",
  @sh "detail=\((.tool_input.questions[0].question // .message // .last_assistant_message // "") | clip)"
' 2>/dev/null)"

# session name as shown in the agent view: /rename wins, then the agent name, then the automatic title
name=""
if [ -f "$transcript" ]; then
  name=$(grep -h -E '"type":"(custom-title|agent-name|ai-title)"' "$transcript" 2>/dev/null \
    | jq -rs '(map(select(.type=="custom-title"))|last|.customTitle)
              // (map(select(.type=="agent-name"))|last|.agentName)
              // (map(select(.type=="ai-title"))|last|.aiTitle) // ""' 2>/dev/null)
fi

# what a permission prompt is about: the last tool call in the transcript
last_tool() {
  [ -f "$transcript" ] || return
  tail -n 60 "$transcript" | grep '"type":"tool_use"' | tail -1 | jq -r '
    [.message.content[]? | select(.type=="tool_use")] | last
    | "\(.name): \(.input.description // .input.command // .input.file_path // .input.url // "")"
    | gsub("\\s+"; " ") | .[0:140]' 2>/dev/null
}

case "$event" in
  Notification)
    what=$(t "Aspetta un tuo ok" "Waiting for your OK")
    said=$(t "in attesa di istruzioni" "awaiting instructions")
    kind="wait"
    line=$(last_tool); [ -n "$line" ] && detail=$line ;;
  PreToolUse)
    kind="wait"
    if [ "$tool" = ExitPlanMode ]; then
      what=$(t "Piano da approvare" "Plan to approve")
      said=$(t "piano pronto, attendo conferma" "plan ready, awaiting approval")
      detail=""
    else
      what=$(t "Ti sta facendo una domanda" "Asking you a question")
      said=$(t "domanda in attesa, passo" "question pending, over")
    fi ;;
  Stop)
    what=$(t "Ha finito" "Finished")
    said=$(t "terminata, passo" "done, over")
    kind="done" ;;
  *) exit 0 ;;
esac

repo=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
repo=$(basename "${repo:-${cwd:-?}}")

category=$(rhq_category "$session" "$cwd")
audio=on
[ "$category" != none ] && [ "$(rhq_get "$RHQ_STATE" "$category" on)" != on ] && audio=off
dnd && audio=off
voice=$(rhq_get "$RHQ_STATE" voice on)
log "$event category=$category audio=$audio voice=$voice"

title=${name:-claude · $repo}
subtitle="$what · $repo"
[ "$category" != none ] && subtitle="$subtitle · $(rhq_category_label "$category")"
message=${detail:-$what}

# the radio reads the first four words of the name
spoken=$(printf '%s' "${name:-$repo}" | awk '{ for (i = 1; i <= NF && i <= 4; i++) printf "%s%s", (i > 1 ? " " : ""), $i }')
line="$spoken, $said"
sound=$(rhq_get "$RHQ_CONFIG" "sound_$kind" "$([ $kind = wait ] && echo alert-signal || echo tank-gear-shift)")

if [ -n "$dry" ]; then
  printf 'title=%s\nsubtitle=%s\nmessage=%s\n' "$title" "$subtitle" "$message"
  [ "$audio" = on ] && printf 'sound=%s\n' "$sound" || echo "sound=-"
  [ "$audio" = on ] && [ "$voice" = on ] && printf 'say=%s\n' "$line" || echo "say=-"
  exit 0
fi

rhq_banner "$title" "$subtitle" "$message" "claude-$session"
[ "$audio" = on ] || exit 0

IFS=$'\t' read -r sound_file seconds < <(rhq_sound_file "$sound")
if [ ! -f "$sound_file" ]; then
  # first run offline or kit not fetched yet: a system sound now, the kit next time
  sound_file=$(rhq_fallback_sound "$kind"); seconds=0
  ("$RHQ_ROOT/bin/radio-hq" sounds >/dev/null 2>&1 &)
fi

# render the voice before queueing, so it follows the effect without a gap
got=no
lock="${TMPDIR:-/tmp}/radio-hq.lock"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/radio-hq.XXXXXX")
trap 'rm -rf "$tmp"; [ "$got" = yes ] && rm -rf "$lock"' EXIT
if [ "$voice" = on ]; then
  speaker=$(rhq_voice "$RHQ_LANG" "$(rhq_get "$RHQ_CONFIG" voice_name auto)")
  if [ "$(rhq_get "$RHQ_CONFIG" radio on)" = on ] && py=$(rhq_python); then
    rhq_say_to_file "$speaker" "$line" "$tmp/dry.wav" && "$py" "$RHQ_ROOT/lib/radio.py" "$tmp/dry.wav" "$tmp/radio.wav" 2>/dev/null
  fi
fi

# one announcement at a time across sessions; a lock older than 30 s belongs to a crashed run
for _ in $(seq 1 150); do
  if mkdir "$lock" 2>/dev/null; then got=yes; date +%s > "$lock/since"; break; fi
  since=$(cat "$lock/since" 2>/dev/null || date +%s)
  [ $(( $(date +%s) - since )) -gt 30 ] && rm -rf "$lock"
  sleep 0.2
done

rhq_play "$sound_file" "$seconds"
[ "$voice" = on ] || exit 0
# a clean voice when the radio effect is off or failed, so no announcement is lost
if [ -s "$tmp/radio.wav" ]; then rhq_play "$tmp/radio.wav"; else rhq_say "$speaker" "$line"; fi
exit 0
