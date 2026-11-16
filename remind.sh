#!/bin/bash
set -e

BASE_DATE="2026-11-16"   # позиция 0 цикла = первый рабочий день
FORCE_MODE="${1:-}"

TODAY=$(TZ=Europe/Moscow date +%Y-%m-%d)
DOW=$(TZ=Europe/Moscow date +%u)
HOUR=$(TZ=Europe/Moscow date +%-H)
SEED=$(TZ=Europe/Moscow date +%Y%m%d)

DAYS_SINCE=$(( ( $(date -d "$TODAY" +%s) - $(date -d "$BASE_DATE" +%s) ) / 86400 ))
CYCLE_POS=$(( (DAYS_SINCE % 6 + 6) % 6 ))
if [ $CYCLE_POS -lt 3 ]; then IS_WORK_DAY="yes"; else IS_WORK_DAY="no"; fi

# Три рандомных слота на день (детерминированно по дате)
MORNING_H=$(echo "$SEED 1"   | awk '{srand($1+$2); print 8+int(rand()*3)}')
AFTERNOON_H=$(echo "$SEED 2" | awk '{srand($1+$2); print 13+int(rand()*3)}')
EVENING_H=$(echo "$SEED 3"   | awk '{srand($1+$2); print 20+int(rand()*2)}')

echo "Today: $TODAY | MSK hour: $HOUR | dow: $DOW | cycle_pos: $CYCLE_POS | work: $IS_WORK_DAY"
echo "Slots (MSK): morning=$MORNING_H afternoon=$AFTERNOON_H evening=$EVENING_H"

if [ -n "$FORCE_MODE" ]; then
  MODE="$FORCE_MODE"
elif [ "$HOUR" -eq "$MORNING_H" ]; then
  MODE="morning"
elif [ "$HOUR" -eq "$AFTERNOON_H" ]; then
  MODE="afternoon"
elif [ "$HOUR" -eq "$EVENING_H" ]; then
  MODE="evening"
else
  echo "Not a reminder hour. Skipping."
  exit 0
fi

send_message() {
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=$1" \
    --data-urlencode "parse_mode=HTML"
}

# Футбол сегодня
FOOTBALL="none"
if [ "$DOW" = "5" ]; then
  FOOTBALL="friday"
elif [ "$DOW" = "7" ] && [ "$IS_WORK_DAY" = "no" ]; then
  FOOTBALL="sunday"
fi

# Позиция в блоке 3/3
if [ "$IS_WORK_DAY" = "yes" ]; then
  BLOCK="рабочая смена, день $(( CYCLE_POS + 1 )) из 3"
else
  BLOCK="выходной, день $(( CYCLE_POS - 2 )) из 3"
fi

# Завтра
TOMORROW_POS=$(( (CYCLE_POS + 1) % 6 ))
if [ $TOMORROW_POS -lt 3 ]; then TOMORROW="рабочая смена"; else TOMORROW="выходной"; fi

TOMORROW_DOW=$(( (DOW % 7) + 1 ))
TOMORROW_FOOTBALL=""
if [ "$TOMORROW_DOW" = "5" ]; then
  TOMORROW_FOOTBALL="
⚽ Завтра футбол в 19:00."
elif [ "$TOMORROW_DOW" = "7" ] && [ "$TOMORROW_POS" -ge 3 ]; then
  TOMORROW_FOOTBALL="
⚽ Завтра футбол 14:00–16:00."
fi

# Конец месяца
TOMORROW_DAY=$(date -d "$TODAY + 1 day" +%d)
if [ "$TOMORROW_DAY" = "01" ]; then
  MONTH_END="

🔧 <b>Конец месяца</b>: сделай любой коммит в репозиторий, чтобы GitHub не отключил расписание."
else
  MONTH_END=""
fi

case "$MODE" in
  morning)
    MSG="☀️ <b>Хорошего дня!</b>
Сегодня — ${BLOCK}."

    if [ "$FOOTBALL" = "friday" ]; then
      MSG="${MSG}

⚽ <b>Футбол в 19:00</b> — выходить ~18:20. Обычно тебя отпускают."
    elif [ "$FOOTBALL" = "sunday" ]; then
      MSG="${MSG}

⚽ <b>Футбол 14:00–16:00</b> — подъём в 12:00."
    fi

    if [ "$IS_WORK_DAY" = "yes" ]; then
      MSG="${MSG}

Смена 09:00–21:00. Вечером заслужил холодное пиво. 🍺"
    else
      MSG="${MSG}

День свободный. Холодное пиво уже ждёт. 🍺"
    fi

    send_message "${MSG}"
    ;;

  afternoon)
    if [ "$IS_WORK_DAY" = "yes" ]; then
      MSG="🌤 <b>Дневной чек-ин.</b>
Середина смены. Как продвигается? Что осталось до конца дня?"
    else
      MSG="🌤 <b>Дневной чек-ин.</b>
Середина дня. Что уже сделано, что осталось?"
    fi

    if [ "$FOOTBALL" = "friday" ] || [ "$FOOTBALL" = "sunday" ]; then
      MSG="${MSG}

⚽ Сегодня футбол — не забудь форму."
    fi

    MSG="${MSG}

Пиво холодное? 🍺"

    send_message "${MSG}"
    ;;

  evening)
    MSG="🌙 <b>Итоги дня.</b>
Как прошло? Завтра — ${TOMORROW}.${TOMORROW_FOOTBALL}"

    if [ "$IS_WORK_DAY" = "yes" ]; then
      MSG="${MSG}

Смена подходит к концу — холодное пиво заслужено. 🍺"
    else
      MSG="${MSG}

Пиво холодное? Тогда почему ещё не открыл. 🍺"
    fi

    MSG="${MSG}${MONTH_END}"

    send_message "${MSG}"
    ;;
esac
