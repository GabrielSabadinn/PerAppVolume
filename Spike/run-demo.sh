#!/bin/zsh
set -uo pipefail
cd "$(dirname "$0")"
GAIN="${1:-0.2}"
SECONDS_TO_RUN="${2:-15}"
LOG=~/Library/Logs/TapSpike.log
: > "$LOG"
afplay .build/tone.wav &
AFPLAY_PID=$!
sleep 2
echo "Tocando tom a 100%. Em instantes o TapSpike assume o afplay com ganho $GAIN; voce deve ouvir o volume cair."
open .build/TapSpike.app --args --bundle afplay --gain "$GAIN" --seconds "$SECONDS_TO_RUN"
for _ in $(seq 1 $((SECONDS_TO_RUN + 60))); do
  grep -q 'RESULT:' "$LOG" && break
  sleep 1
done
kill "$AFPLAY_PID" 2>/dev/null
echo "--- log"
grep -vE '^\S+ {2}pid=' "$LOG"
