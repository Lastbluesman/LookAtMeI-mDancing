#!/bin/bash
set -e

BASE_DATE="2026-11-10"   # опорный день: рабочий, cycle day 0
MODE="$1"

if [ -z "$MODE" ]; then
  echo "Usage: $0 <day_checkin|evening_checkin|friday_football|sunday_football>"
  exit 1
fi

TODAY=$(date +%Y-%m-%d)
DAYS_SINCE=$(( ( $(date +%s) - $(date -d "$BASE_DATE" +%s) ) / 86400 ))
CYCLE_POS=$(( (DAYS_SINCE % 6 + 6) % 6 ))   # 0,1,2 — работа; 3,4,5 — выходные

if [ $CYCLE_POS -lt 3 ]; then IS_WORK_DAY="yes"; else IS_WORK_DAY="no"; fi
echo "Today: $TODAY | cycle_pos: $CYCLE_POS | work_day: $IS_WORK_DAY | mode: $MODE"

send_message() {
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=$1" \
    --data-urlencode "parse_mode=HTML"
}

case "$MODE" in
  day_checkin)
    if [ "$IS_WORK_DAY" = "yes" ]; then
      send_message "📋 <b>Дневной чек-ин</b> (рабочая смена).

Что сделано? Что осталось? 1–2 реалистичные задачи на остаток дня.

И не забывай: <b>стоматолог</b> всё ещё не записан."
    else
      send_message "📋 <b>Дневной чек-ин</b> (выходной).

Что сделано? Что осталось? Проверь план на тренировку и личные дела.

<b>Стоматолог</b> — в силе."
    fi
    ;;
  evening_checkin)
    if [ "$IS_WORK_DAY" = "yes" ]; then
      send_message "🌙 <b>Вечерний чек-ин</b>. Смена закончилась — коротко.

Самочувствие? Что перенести на завтра? Восстановление в порядке?

<b>Стоматолог</b> — записал?"
    else
      send_message "🌙 <b>Вечерний чек-ин</b>.

Итоги дня: что сделано, что нет и почему. План на завтра.

<b>Стоматолог</b> — записал?"
    fi
    ;;
  friday_football)
    if [ "$IS_WORK_DAY" = "yes" ]; then
      send_message "⚽ <b>Футбол сегодня в 19:00</b>, выходить ~18:20.

Пятница рабочая, но по опыту тебя отпускают. Если вдруг нет — скажи, скорректируем."
    else
      send_message "⚽ <b>Футбол сегодня в 19:00</b>, выходить ~18:20. Выходной — вперёд."
    fi
    ;;
  sunday_football)
    if [ "$IS_WORK_DAY" = "yes" ]; then
      send_message "ℹ️ Сегодня воскресенье, но <b>рабочая смена</b>. Футбол пропускаем.

Если хочешь компенсировать — Full Body в другой выходной. Без фанатизма."
    else
      send_message "⚽ <b>Футбол сегодня 14:00–16:00</b>. Подъём в 12:00.

Учти дорогу и сборы."
    fi
    ;;
esac
