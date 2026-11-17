#!/bin/bash
set -e

BASE_DATE="2026-11-16"
FORCE_MODE="${1:-}"

TODAY=$(TZ=Europe/Moscow date +%Y-%m-%d)
NOW_HHMMSS=$(TZ=Europe/Moscow date +%H:%M:%S)
DOW=$(TZ=Europe/Moscow date +%u)
HOUR=$(TZ=Europe/Moscow date +%-H)
SEED=$(TZ=Europe/Moscow date +%Y%m%d)

DAYS_SINCE=$(( ( $(date -d "$TODAY" +%s) - $(date -d "$BASE_DATE" +%s) ) / 86400 ))
CYCLE_POS=$(( (DAYS_SINCE % 6 + 6) % 6 ))
if [ $CYCLE_POS -lt 3 ]; then IS_WORK_DAY="yes"; else IS_WORK_DAY="no"; fi

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
  for cid in "${TELEGRAM_CHAT_ID}" "${TELEGRAM_TESTER_CHAT_ID}"; do
    if [ -n "$cid" ]; then
      curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${cid}" \
        --data-urlencode "text=$1" \
        --data-urlencode "parse_mode=HTML"
    fi
  done
}

send_photo() {
  local photo_url="$1"
  local caption="$2"
  for cid in "${TELEGRAM_CHAT_ID}" "${TELEGRAM_TESTER_CHAT_ID}"; do
    if [ -n "$cid" ]; then
      curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto" \
        -F "chat_id=${cid}" \
        -F "photo=${photo_url}" \
        -F "caption=${caption}" \
        -F "parse_mode=HTML"
    fi
  done
}

pick() {
  local arr=("$@")
  echo "${arr[$((RANDOM % ${#arr[@]}))]}"
}

# --- Пулы фраз ---

GREETINGS=(
  "☀️ Хорошего дня!"
  "🌅 Доброе утро, боец."
  "👋 Новый день — новые возможности."
  "☕ Утро. Кофе. Поехали."
  "🌞 Подъём — день уже начался."
  "🔥 Просыпайся, день ждёт."
)

BEER_WORK=(
  "Смена 09:00–21:00. Вечером заслужил холодное пиво. 🍺"
  "Работай, а холодное пиво вечером никуда не денется. 🍺"
  "Смена длинная, но пиво уже в холодильнике. 🍺"
  "Главное — дожить до вечера. Холодное пиво ждёт. 🍺"
  "Сегодня смена. А вечером — пиво. Приоритеты ясны. 🍺"
  "Работа — не волк, а пиво — холодное. 🍺"
)

BEER_OFF=(
  "День свободный. Холодное пиво уже ждёт. 🍺"
  "Выходной. Пиво — это план на день. 🍺"
  "Ничего не должен. Пиво открывается само. 🍺"
  "Сегодня можно и с утра, но лучше вечером. Пиво в холодильнике. 🍺"
  "Отдых — это святое. Пиво — его часть. 🍺"
  "День для себя. Начни с кофе, закончи пивом. 🍺"
)

AFTERNOON_OPENER=(
  "🌤 Дневной чек-ин."
  "🌥 Середина дня. Как ты?"
  "📋 Быстрая сверка на середину дня."
  "⏳ Половина дня позади."
  "🔎 Промежуточная проверка."
  "🎯 Дневной статус."
)

AFTERNOON_WORK=(
  "Середина смены. Что осталось до конца?"
  "Смена в разгаре. Как продвигается?"
  "До конца смены ещё есть время. Всё под контролем?"
  "Что-то подотстало? Можно наверстать."
  "Проверь: ничего важного не забыл?"
)

AFTERNOON_OFF=(
  "Середина свободного дня. Что уже сделал?"
  "День идёт. Что осталось из планов?"
  "Успеваешь? Или уже пиво?"
  "Что-то сделал полезное? Хорошо. Что осталось?"
  "Половина выходного позади. Как оно?"
)

BEER_AFTERNOON=(
  "Пиво холодное? 🍺"
  "Пиво ещё в холодильнике? Пусть охлаждается. 🍺"
  "Не забудь: пиво на вечер. 🍺"
  "Холодное пиво — ждёт своего часа. 🍺"
  "Пиво не убежит. 🍺"
)

EVENING_OPENER=(
  "🌙 Итоги дня."
  "🌃 День закрывается."
  "🌌 Вечер. Время подвести черту."
  "📊 Что было — то было. Итоги."
  "🕯 Тихо, спокойно, подводим итоги."
  "🎬 Конец дня. Разбор полётов."
)

EVENING_QUESTION=(
  "Как прошло?"
  "Что сегодня удалось?"
  "Доволен днём?"
  "Что получилось, что нет?"
  "Какие выводы?"
  "Оцени день по десятибалльной."
)

BEER_EVENING_WORK=(
  "Смена подходит к концу — холодное пиво заслужено. 🍺"
  "Работа сделана, пиво — награда. 🍺"
  "Всё, рабочий день закрыт. Пиво. 🍺"
  "Ты дожил. Пиво ждёт. 🍺"
  "Смена закончилась, начинается пиво. 🍺"
)

BEER_EVENING_OFF=(
  "Пиво холодное? Тогда почему ещё не открыл. 🍺"
  "Выходной день — пиво заслужено. 🍺"
  "Вечер выходного. Пиво. И никаких дел. 🍺"
  "Расслабься, ты в выходном. Пиво уже холодное. 🍺"
  "Пиво? Пиво. 🍺"
)

TIPS=(
  "💡 Совет: не забивай себе весь вечер делами. Оставь час на себя."
  "💡 Напоминание: сон — часть тренировки."
  "💡 Микросовет: если что-то тянется месяц — либо делай, либо вычеркни."
  "💡 Мысль: усталость — это не повод, а сигнал."
  "💡 Идея: одну задачу — сделай сегодня. Одну — перенеси осознанно."
  "💡 Совет: 20 минут тишины дают больше, чем 2 часа соцсетей."
  "💡 Напоминание: ты не обязан быть продуктивным 24/7."
  "💡 Мысль на вечер: завтра новый день, не тяни туда хвосты."
)

# --- Логика контента ---

FOOTBALL="none"
if [ "$DOW" = "5" ]; then
  FOOTBALL="friday"
elif [ "$DOW" = "7" ] && [ "$IS_WORK_DAY" = "no" ]; then
  FOOTBALL="sunday"
fi

if [ "$IS_WORK_DAY" = "yes" ]; then
  BLOCK="рабочая смена, день $(( CYCLE_POS + 1 )) из 3"
else
  BLOCK="выходной, день $(( CYCLE_POS - 2 )) из 3"
fi

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

TOMORROW_DAY=$(date -d "$TODAY + 1 day" +%d)
if [ "$TOMORROW_DAY" = "01" ]; then
  MONTH_END="

🔧 <b>Конец месяца</b>: сделай любой коммит в репозиторий, чтобы GitHub не отключил расписание."
else
  MONTH_END=""
fi

# --- Сборка ---

case "$MODE" in
  morning)
    # 1) Сначала получаем шутку. Если API лёг — используем запасную.
    JOKE=$(curl -s --max-time 10 "https://rzhunemogu.ru/api/randjson?CType=1" \
      | jq -r '.content // empty' 2>/dev/null || echo "")
    if [ -z "$JOKE" ]; then
      JOKE="Шутка не загрузилась, но это тоже своего рода шутка. 😄"
    fi

    MSG="$(pick "${GREETINGS[@]}")
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

$(pick "${BEER_WORK[@]}")"
    else
      MSG="${MSG}

$(pick "${BEER_OFF[@]}")"
    fi

    MSG="${MSG}

😄 <b>Шутка дня:</b>
${JOKE}

$(pick "${TIPS[@]}")

<i>⏰ ${NOW_HHMMSS} МСК</i>"

    send_message "${MSG}"
    ;;

    afternoon)
    # Получаем факт о котах
    CAT_FACT=$(curl -s --max-time 10 "https://meowfacts.herokuapp.com/?lang=rus" \
      | jq -r '.data[0] // empty' 2>/dev/null || echo "")

    if [ -z "$CAT_FACT" ]; then
      CAT_FACT="Факт не загрузился, но коты всё равно замечательные. 🐱"
    fi

    MSG="$(pick "${AFTERNOON_OPENER[@]}")"

    if [ "$IS_WORK_DAY" = "yes" ]; then
      MSG="${MSG}
$(pick "${AFTERNOON_WORK[@]}")"
    else
      MSG="${MSG}
$(pick "${AFTERNOON_OFF[@]}")"
    fi

    if [ "$FOOTBALL" = "friday" ] || [ "$FOOTBALL" = "sunday" ]; then
      MSG="${MSG}

⚽ Сегодня футбол — не забудь форму."
    fi

    MSG="${MSG}

🐱 <b>Факт дня:</b>
${CAT_FACT}

$(pick "${BEER_AFTERNOON[@]}")

<i>⏰ ${NOW_HHMMSS} МСК</i>"

    send_message "${MSG}"
    ;;

  evening)
    MSG="$(pick "${EVENING_OPENER[@]}")

$(pick "${EVENING_QUESTION[@]}")"

    if [ "$IS_WORK_DAY" = "yes" ]; then
      MSG="${MSG}

$(pick "${BEER_EVENING_WORK[@]}")"
    else
      MSG="${MSG}

$(pick "${BEER_EVENING_OFF[@]}")"
    fi

    MSG="${MSG}

Завтра — ${TOMORROW}.${TOMORROW_FOOTBALL}

$(pick "${TIPS[@]}")

<i>⏰ ${NOW_HHMMSS} МСК</i>${MONTH_END}"

       send_photo "https://cataas.com/cat" "${MSG}""
    ;;
esac
