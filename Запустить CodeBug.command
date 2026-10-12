#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if curl --fail --silent http://127.0.0.1:8000/api/health | python3 -c 'import json,sys; assert json.load(sys.stdin).get("version")=="3.0.0"' 2>/dev/null; then
  open http://127.0.0.1:8000
  exit 0
fi
if curl --fail --silent http://127.0.0.1:8000/api/health >/dev/null; then
  echo 'На порту 8000 работает другая версия CodeBug. Закрой старое окно сервера и запусти этот файл снова.'
  exit 1
fi
if [ ! -x backend/.venv/bin/python ]; then
  python3 -m venv backend/.venv
fi
backend/.venv/bin/python -m pip install -q -r backend/requirements.txt
if [ ! -f build/web/index.html ]; then
  flutter pub get
  flutter build web --release
fi
backend/.venv/bin/python -m uvicorn app:app --app-dir backend --host 127.0.0.1 --port 8000 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT INT TERM
for attempt in {1..60}; do
  if curl --fail --silent http://127.0.0.1:8000/api/health >/dev/null; then
    open http://127.0.0.1:8000
    echo 'CodeBug запущен. Оставь это окно открытым. Остановка: Ctrl+C.'
    wait "$server_pid"
    exit 0
  fi
  kill -0 "$server_pid" 2>/dev/null || { echo 'Не удалось запустить сервер.'; exit 1; }
  sleep 1
done
echo 'Сервер не успел запуститься.'
exit 1
