#!/usr/bin/env bash
# file: ntp_drift_check.sh
# usage: bash ntp_drift_check.sh [threshold_seconds] [time_source_url]
# ex:    bash ntp_drift_check.sh 2 https://www.cloudflare.com

set -euo pipefail
THRESHOLD="${1:-2}"                        # аларма при > 2 секунди
URL="${2:-https://google.com}"             # източник на време (HTTP Date)

# вземи "истинско" време от Date header (UTC)
date_hdr=$(curl -sI --max-time 3 "$URL" | awk -F': ' 'tolower($1)=="date"{print $2; exit}')
if [[ -z "$date_hdr" ]]; then
  echo "ERR: no Date header from $URL" >&2; exit 3
fi

srv_epoch=$(date -u -d "$date_hdr" +%s 2>/dev/null || true)
if [[ -z "$srv_epoch" ]]; then
  # macOS busybox fallbacks
  srv_epoch=$(python3 - <<PY
import email, time
print(int(time.mktime(email.utils.parsedate("$date_hdr"))))
PY
)
fi

loc_epoch=$(date -u +%s)
drift=$(( loc_epoch - srv_epoch ))
abs_drift=${drift#-}

echo "source=$URL server_epoch=$srv_epoch local_epoch=$loc_epoch drift_sec=$drift threshold=$THRESHOLD"
if (( abs_drift > THRESHOLD )); then
  echo "ALERT: time drift ${drift}s > ${THRESHOLD}s"
  exit 2
fi
echo "OK: drift ${drift}s ≤ ${THRESHOLD}s"
