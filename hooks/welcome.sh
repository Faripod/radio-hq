#!/usr/bin/env bash
# SessionStart: the first run writes the default preferences and fetches the sound kit in the background;
# the first interactive session also gets a one-time hello with the voice in use.

. "$(dirname "$0")/../lib/common.sh"
cat >/dev/null
rhq_load_platform || exit 0

rhq_init_config
if ! ls "$RHQ_SOUNDS"/*.wav >/dev/null 2>&1; then
  nohup "$RHQ_ROOT/bin/radio-hq" sounds </dev/null >/dev/null 2>&1 &
fi

[ -f "$RHQ_HOME/.welcomed" ] && exit 0
rhq_is_headless && exit 0
touch "$RHQ_HOME/.welcomed"

speaker=$(rhq_voice "$RHQ_LANG" "$(rhq_get "$RHQ_CONFIG" voice_name auto)")
message=$(t "📻 radio-hq attivo: banner, effetto e voce (${speaker:-di sistema}) quando una sessione ti aspetta o finisce. Personalizza con /radio-hq:setup, zittisci la voce con \`! radio-hq off\`." \
            "📻 radio-hq is on: a banner, a sound and a voice (${speaker:-system}) when a session waits for you or finishes. Customize with /radio-hq:setup, mute the voice with \`! radio-hq off\`.")
case "$speaker" in
  *"(Premium)"*|*"(Enhanced)"*) ;;
  *) message="$message $(t "Per una voce più naturale chiedi a Claude di aiutarti a scaricarla (/radio-hq:setup)." \
                            "For a more natural voice ask Claude to help you download one (/radio-hq:setup).")" ;;
esac
jq -nc --arg m "$message" '{systemMessage: $m}'
