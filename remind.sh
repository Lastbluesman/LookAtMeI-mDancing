#!/bin/bash
set -e

BASE_DATE="2026-11-16"
FORCE_MODE="${1:-}"

TODAY=$(TZ=Europe/Moscow date +%Y-%m-%d)
NOW_HHMMSS=$(TZ=Europe/Moscow date +%H:%M:%S)
DOW=$(TZ=Europe/Moscow date +%u)
HOUR=$(TZ=Europe/Moscow date +%-H)
SEED=$(TZ=Europe/Moscow date +%Y%m%d)
DAY_NUM=$(TZ=Europe/Moscow date +%-d)
MONTH_NUM=$(TZ=Europe/Moscow date +%-m)

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

# --- Отправка ---

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
      local resp
      resp=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto" \
        -F "chat_id=${cid}" \
        -F "photo=${photo_url}" \
        -F "caption=${caption}" \
        -F "parse_mode=HTML")
      if ! echo "$resp" | grep -q '"ok":true'; then
        echo "sendPhoto failed for $cid, falling back to text"
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
          --data-urlencode "chat_id=${cid}" \
          --data-urlencode "text=${caption}" \
          --data-urlencode "parse_mode=HTML" >/dev/null
      fi
    fi
  done
}

pick() {
  local arr=("$@")
  echo "${arr[$((RANDOM % ${#arr[@]}))]}"
}

# --- Дата и день недели ---

DOW_NAMES=("Понедельник" "Вторник" "Среда" "Четверг" "Пятница" "Суббота" "Воскресенье")
MONTHS=("января" "февраля" "марта" "апреля" "мая" "июня" "июля" "августа" "сентября" "октября" "ноября" "декабря")
DAY_NAME="${DOW_NAMES[$((DOW-1))]}"
MONTH_NAME="${MONTHS[$((MONTH_NUM-1))]}"
DATE_STR="${DAY_NAME}, ${DAY_NUM} ${MONTH_NAME}"

# --- Пулы фраз ---

GREETINGS=(
  "☀️ Хорошего дня!"
  "🌅 Доброе утро, боец."
  "👋 Новый день — новые возможности."
  "☕ Утро. Кофе. Поехали."
  "🌞 Подъём — день уже начался."
  "🔥 Просыпайся, день ждёт."
  "🌤 С добрым утром. Ты справишься."
  "🎯 Утро. Ставим цели, идём вперёд."
  "🍳 Завтрак, кофе, план. Классика."
  "🚀 Поехали. День обещает быть интересным."
)

HYPE_WORK=(
  "Смена не убежит. Ты тоже."
  "Ну что, вперёд. Работа ждёт."
  "Держись, брат. Ты знаешь, что делать."
  "Смена длинная. Ты — сильный. Всё сходится."
  "Соберись. Вечером будет за что себя похвалить."
  "Помни: работу работу, а голову включай."
  "Смена сегодня, пиво вечером. Приоритеты расставлены."
  "Ты уже делал это раньше. Сделаешь и сейчас."
)

HYPE_OFF=(
  "Свобода! Не растранжирь её на диван целиком."
  "Три дня свободы. Начни с чего-то хорошего."
  "Выходной — это святое. Но и полезное никто не отменял."
  "Сделай сегодня хотя бы одно дело из списка. Остальное — потом."
  "Не обязательно быть продуктивным. Достаточно быть в порядке."
  "Выходной, а значит — ты сам решаешь, как его провести."
  "Позволь себе ничего не делать. Это тоже план."
  "Отдых — это не лень. Это инвестиция в следующую смену."
)

BEER_WORK=(
  "Смена 09:00–21:00. Вечером заслужил холодное пиво. 🍺"
  "Работай, а холодное пиво вечером никуда не денется. 🍺"
  "Смена длинная, но пиво уже в холодильнике. 🍺"
  "Главное — дожить до вечера. Холодное пиво ждёт. 🍺"
  "Сегодня смена. А вечером — пиво. Приоритеты ясны. 🍺"
  "Работа — не волк, а пиво — холодное. 🍺"
  "Пиво вечером будет вкуснее, если смена пройдёт нормально. 🍺"
  "Ты на смене. Пиво — дома. Оно ждёт. 🍺"
  "Держись. Награда в холодильнике. 🍺"
  "Одна мысль на весь день: холодное пиво вечером. 🍺"
)

BEER_OFF=(
  "День свободный. Холодное пиво уже ждёт. 🍺"
  "Выходной. Пиво — это план на день. 🍺"
  "Ничего не должен. Пиво открывается само. 🍺"
  "Сегодня можно и с утра, но лучше вечером. Пиво в холодильнике. 🍺"
  "Отдых — это святое. Пиво — его часть. 🍺"
  "День для себя. Начни с кофе, закончи пивом. 🍺"
  "Пиво в выходной — это не привычка, это ритуал. 🍺"
  "Холодное пиво сегодня ощущается особенно правильно. 🍺"
  "Свободный день. Пиво заслужил просто за то, что дожил. 🍺"
  "Выходной без пива — деньги на ветер. 🍺"
)

AFTERNOON_OPENER=(
  "🌤 Дневной чек-ин."
  "🌥 Середина дня. Как ты?"
  "📋 Быстрая сверка на середину дня."
  "⏳ Половина дня позади."
  "🔎 Промежуточная проверка."
  "🎯 Дневной статус."
  "☕ Пауза на 30 секунд. Как дела?"
  "📞 Друг звонит узнать, как ты."
)

AFTERNOON_WORK=(
  "Середина смены. Что осталось до конца?"
  "Смена в разгаре. Как продвигается?"
  "До конца смены ещё есть время. Всё под контролем?"
  "Что-то подотстало? Можно наверстать."
  "Проверь: ничего важного не забыл?"
  "Если устал — это нормально. Дыши."
  "Не забудь поесть по-человечески. Не только кофе."
  "Половина смены. Держи темп."
)

AFTERNOON_OFF=(
  "Середина свободного дня. Что уже сделал?"
  "День идёт. Что осталось из планов?"
  "Успеваешь? Или уже пиво?"
  "Что-то сделал полезное? Хорошо. Что осталось?"
  "Половина выходного позади. Как оно?"
  "Не торопись. У тебя ещё весь день."
  "Если ничего не сделал — тоже вариант. Не кори себя."
  "Свободный полдень. Как хочешь его провести?"
)

BEER_AFTERNOON=(
  "Пиво холодное? 🍺"
  "Пиво ещё в холодильнике? Пусть охлаждается. 🍺"
  "Не забудь: пиво на вечер. 🍺"
  "Холодное пиво — ждёт своего часа. 🍺"
  "Пиво не убежит. 🍺"
  "Проверь, что пиво в холодильнике. Это важно. 🍺"
  "До вечера далеко, но пиво уже ждёт. 🍺"
  "Мысль на вторую половину дня: пиво. 🍺"
)

EVENING_OPENER=(
  "🌙 Итоги дня."
  "🌃 День закрывается."
  "🌌 Вечер. Время подвести черту."
  "📊 Что было — то было. Итоги."
  "🕯 Тихо, спокойно, подводим итоги."
  "🎬 Конец дня. Разбор полётов."
  "🍺 Вечер. Пиво. Разговор."
  "🌆 День закончился. Как он прошёл?"
)

EVENING_QUESTION=(
  "Как прошло?"
  "Что сегодня удалось?"
  "Доволен днём?"
  "Что получилось, что нет?"
  "Какие выводы?"
  "Оцени день по десятибалльной."
  "Что бы сделал иначе?"
  "Что сегодня тебя порадовало?"
)

BEER_EVENING_WORK=(
  "Смена подходит к концу — холодное пиво заслужено. 🍺"
  "Работа сделана, пиво — награда. 🍺"
  "Всё, рабочий день закрыт. Пиво. 🍺"
  "Ты дожил. Пиво ждёт. 🍺"
  "Смена закончилась, начинается пиво. 🍺"
  "Всё, отбой по работе. Открывай. 🍺"
  "Смена позади. Пиво — впереди. 🍺"
  "Ты выжил. Это уже повод. 🍺"
)

BEER_EVENING_OFF=(
  "Пиво холодное? Тогда почему ещё не открыл. 🍺"
  "Выходной день — пиво заслужено. 🍺"
  "Вечер выходного. Пиво. И никаких дел. 🍺"
  "Расслабься, ты в выходном. Пиво уже холодное. 🍺"
  "Пиво? Пиво. 🍺"
  "Идеальный вечер: пиво и ничего не делать. 🍺"
  "Выходной вечер — это святое. Пиво открывай. 🍺"
  "Если не знаешь, что делать — открой пиво. 🍺"
)

TIPS=(
  "💡 Не забивай весь вечер делами. Оставь час на себя."
  "💡 Сон — часть тренировки. Не жертвуй им."
  "💡 Если что-то тянется месяц — либо делай, либо вычеркни."
  "💡 Усталость — это не повод, а сигнал."
  "💡 Одну задачу — сделай сегодня. Одну — перенеси осознанно."
  "💡 20 минут тишины дают больше, чем 2 часа соцсетей."
  "💡 Ты не обязан быть продуктивным 24/7."
  "💡 Завтра новый день, не тяни туда хвосты."
  "💡 Сделал — отметь. Не сделал — забудь. Не тащи."
  "💡 Дыши глубже. Это бесплатно и работает."
  "💡 Вода. Просто выпей стакан воды."
  "💡 10 минут на воздухе > час в телефоне."
  "💡 Если перегруз — это сигнал, а не повод терпеть."
  "💡 Кофе после 16:00 — плохая идея."
  "💡 Улыбнись. Даже если никто не видит."
)

QUIPS=(
  "Кстати, ты вообще молодец, что до этого дожил."
  "Если что — я в тебя верю. Не подведи."
  "Улыбнись хотя бы раз сегодня. Хотя бы мне."
  "Ты там как, вообще? Работаешь или страдаешь?"
  "Ты заслужил перерыв. Даже если не сделал ничего."
  "Напоминаю: ты не робот. Хотя иногда полезно."
  "Если всё идёт не по плану — это повод его поменять."
  "Не буду грузить. Просто напомнил, что ты красавчик."
  "Холодное пиво не бесконечное. Но пока есть."
  "Держись. Или не держись — главное не сдавайся."
  "Всё получится. Или не всё. Но что-то — точно."
  "Ты справляешься лучше, чем тебе кажется."
)

# --- Внешние данные ---

JOKE=$(curl -s --max-time 10 "https://rzhunemogu.ru/api/randjson?CType=1" \
  | jq -r '.content // empty' 2>/dev/null || echo "")
[ -z "$JOKE" ] && JOKE="Шутка не загрузилась, но это тоже своего рода шутка. 😄"
if [ ${#JOKE} -gt 240 ]; then JOKE="${JOKE:0:240}…"; fi

CAT_FACT=$(curl -s --max-time 10 "https://meowfacts.herokuapp.com/?lang=rus" \
  | jq -r '.data[0] // empty' 2>/dev/null || echo "")
[ -z "$CAT_FACT" ] && CAT_FACT="Факт не загрузился, но коты всё равно замечательные. 🐱"
if [ ${#CAT_FACT} -gt 180 ]; then CAT_FACT="${CAT_FACT:0:180}…"; fi

TIP="$(pick "${TIPS[@]}")"
QUIP="$(pick "${QUIPS[@]}")"

CAT_ID=$(curl -s --max-time 10 "https://cataas.com/cat?json=true" \
  | jq -r '._id // .id // empty' 2>/dev/null || echo "")
if [ -n "$CAT_ID" ]; then
  CAT_URL="https://cataas.com/cat/${CAT_ID}"
else
  CAT_URL="https://cataas.com/cat?r=${RANDOM}"
fi
echo "Cat URL: $CAT_URL"

# --- Контекст цикла ---

if [ "$IS_WORK_DAY" = "yes" ]; then
  SHIFTS_LEFT=$(( 2 - CYCLE_POS ))
  if [ $SHIFTS_LEFT -eq 0 ]; then
    CYCLE_CONTEXT="Последняя смена из трёх. После неё — 3 выходных."
  elif [ $SHIFTS_LEFT -eq 1 ]; then
    CYCLE_CONTEXT="Смена 2/3. Ещё одна — и на выходные."
  else
    CYCLE_CONTEXT="Смена 1/3. Впереди ещё две смены."
  fi
else
  OFF_LEFT=$(( 5 - CYCLE_POS ))
  if [ $OFF_LEFT -eq 0 ]; then
    CYCLE_CONTEXT="Последний выходной. Завтра снова на работу."
  elif [ $OFF_LEFT -eq 1 ]; then
    CYCLE_CONTEXT="Второй выходной. Остался ещё один день свободы."
  else
    CYCLE_CONTEXT="Первый выходной. Впереди ещё два дня."
  fi
fi

# --- Футбольная сводка ---

TOMORROW_POS=$(( (CYCLE_POS + 1) % 6 ))

FOOTBALL_LINE=""
case "$DOW" in
  5) FOOTBALL_LINE="⚽ <b>Сегодня футбол в 19:00.</b> Выходить ~18:20." ;;
  6)
    if [ $TOMORROW_POS -ge 3 ]; then
      FOOTBALL_LINE="⚽ Завтра футбол 14:00–16:00."
    else
      FOOTBALL_LINE="⚽ Завтра воскресенье, но рабочая смена — футбол пропускаешь."
    fi
    ;;
  7)
    if [ "$IS_WORK_DAY" = "no" ]; then
      FOOTBALL_LINE="⚽ <b>Сегодня футбол 14:00–16:00.</b> Подъём в 12:00."
    else
      FOOTBALL_LINE="⚽ Сегодня футбол пропускаешь (смена). Следующий — в пятницу."
    fi
    ;;
  4) FOOTBALL_LINE="⚽ Завтра футбол в 19:00. Готовь форму." ;;
  1) FOOTBALL_LINE="⚽ До футбола в пятницу — 4 дня." ;;
  2) FOOTBALL_LINE="⚽ До футбола в пятницу — 3 дня." ;;
  3) FOOTBALL_LINE="⚽ До футбола в пятницу — 2 дня." ;;
esac

# --- Завтра и конец месяца ---

if [ $TOMORROW_POS -lt 3 ]; then TOMORROW="рабочая смена"; else TOMORROW="выходной"; fi

TOMORROW_DOW=$(( (DOW % 7) + 1 ))
TOMORROW_FOOTBALL=""
if [ "$TOMORROW_DOW" = "5" ]; then
  TOMORROW_FOOTBALL="
⚽ Завтра футбол в 19:00."
elif [ "$TOMORROW_DOW" = "7" ] && [ $TOMORROW_POS -ge 3 ]; then
  TOMORROW_FOOTBALL="
⚽ Завтра футбол 14:00–16:00."
fi

TOMORROW_DAY=$(date -d "$TODAY + 1 day" +%d)
if [ "$TOMORROW_DAY" = "01" ]; then
  MONTH_END="

🔧 <b>Конец месяца</b>: сделай коммит в репозиторий, чтобы GitHub не отключил расписание."
else
  MONTH_END=""
fi

# --- Сборка сообщений ---

case "$MODE" in
  morning)
    if [ "$IS_WORK_DAY" = "yes" ]; then HYPE="$(pick "${HYPE_WORK[@]}")"; BEER="$(pick "${BEER_WORK[@]}")"
    else HYPE="$(pick "${HYPE_OFF[@]}")"; BEER="$(pick "${BEER_OFF[@]}")"; fi

    MSG="$(pick "${GREETINGS[@]}")

📅 ${DATE_STR}
${CYCLE_CONTEXT}

${HYPE}

${FOOTBALL_LINE}

${BEER}

😄 <b>Шутка дня:</b>
${JOKE}

🐱 <b>Факт о котах:</b>
${CAT_FACT}

${TIP}

<i>${QUIP}</i>

⏰ ${NOW_HHMMSS} МСК"

    send_photo "${CAT_URL}" "${MSG}"
    ;;

  afternoon)
    if [ "$IS_WORK_DAY" = "yes" ]; then
      MID="$(pick "${AFTERNOON_WORK[@]}")"
      BEER="$(pick "${BEER_AFTERNOON[@]}")"
    else
      MID="$(pick "${AFTERNOON_OFF[@]}")"
      BEER="$(pick "${BEER_AFTERNOON[@]}")"
    fi

    MSG="$(pick "${AFTERNOON_OPENER[@]}")

📅 ${DATE_STR} — ${CYCLE_CONTEXT}

${MID}

${FOOTBALL_LINE}

${BEER}

😄 <b>Шутка дня:</b>
${JOKE}

🐱 <b>Факт о котах:</b>
${CAT_FACT}

${TIP}

<i>${QUIP}</i>

⏰ ${NOW_HHMMSS} МСК"

    send_photo "${CAT_URL}" "${MSG}"
    ;;

  evening)
    if [ "$IS_WORK_DAY" = "yes" ]; then BEER="$(pick "${BEER_EVENING_WORK[@]}")"
    else BEER="$(pick "${BEER_EVENING_OFF[@]}")"; fi

    MSG="$(pick "${EVENING_OPENER[@]}")

$(pick "${EVENING_QUESTION[@]}")

📅 ${DATE_STR} — ${CYCLE_CONTEXT}
Завтра — ${TOMORROW}.${TOMORROW_FOOTBALL}

${BEER}

😄 <b>Шутка дня:</b>
${JOKE}

🐱 <b>Факт о котах:</b>
${CAT_FACT}

${TIP}

<i>${QUIP}</i>

⏰ ${NOW_HHMMSS} МСК${MONTH_END}"

    send_photo "${CAT_URL}" "${MSG}"
    ;;
esac
