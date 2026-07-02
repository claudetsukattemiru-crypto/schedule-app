const STORAGE_KEY = 'scheduleEvents';
const WEEKDAY_MAP = { '月': 1, '火': 2, '水': 3, '木': 4, '金': 5, '土': 6, '日': 0 };

function mondayOfWeek(date) {
  const d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const diff = (d.getDay() + 6) % 7;
  d.setDate(d.getDate() - diff);
  return d;
}

function addDays(date, days) {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}

function matchLocation(text) {
  const m = text.match(/場所(?:は|が)?\s*([^\s、,。.]+?)(?:で|$|(?=[\s、,。.]))/);
  if (!m || !m[1]) return null;
  return { location: m[1], span: m[0], index: m.index };
}

function matchAbsoluteDate(text, now) {
  const m = text.match(/(\d{1,2})月(\d{1,2})日/);
  if (!m) return null;
  const month = parseInt(m[1], 10) - 1;
  const day = parseInt(m[2], 10);
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  let date = new Date(now.getFullYear(), month, day);
  if (date < today) date = new Date(now.getFullYear() + 1, month, day);
  return { date, span: m[0], index: m.index };
}

function matchRelativeDay(text, now) {
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const table = [
    { words: ['今日'], offset: 0 },
    { words: ['明後日', 'あさって'], offset: 2 },
    { words: ['明日', 'あした'], offset: 1 },
    { words: ['昨日'], offset: -1 },
  ];
  for (const entry of table) {
    for (const word of entry.words) {
      const index = text.indexOf(word);
      if (index !== -1) return { date: addDays(today, entry.offset), span: word, index };
    }
  }
  return null;
}

function matchWeekWeekday(text, now) {
  const m = text.match(/(今週|来週|再来週)\s*の?\s*(月|火|水|木|金|土|日)曜日?/);
  if (!m) return null;
  const weekOffset = { '今週': 0, '来週': 1, '再来週': 2 }[m[1]];
  const monday = mondayOfWeek(now);
  const targetDow = WEEKDAY_MAP[m[2]];
  const mondayBasedTarget = targetDow === 0 ? 6 : targetDow - 1;
  const date = addDays(monday, weekOffset * 7 + mondayBasedTarget);
  return { date, span: m[0], index: m.index };
}

function matchBareWeekday(text, now) {
  const m = text.match(/(月|火|水|木|金|土|日)曜日?/);
  if (!m) return null;
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const targetDow = WEEKDAY_MAP[m[1]];
  const diff = (targetDow - today.getDay() + 7) % 7;
  return { date: addDays(today, diff), span: m[0], index: m.index };
}

function matchExplicitTime(text) {
  const m = text.match(/(午前|午後)?\s*(\d{1,2})時\s*(?:(\d{1,2})分)?/);
  if (!m) return null;
  let hour = parseInt(m[2], 10);
  const minute = m[3] ? parseInt(m[3], 10) : 0;
  if (m[1] === '午後' && hour < 12) hour += 12;
  if (m[1] === '午前' && hour === 12) hour = 0;
  return { hour, minute, span: m[0], index: m.index, warning: null };
}

function matchVagueTime(text) {
  const table = [
    { word: '正午', hour: 12, minute: 0, warning: null },
    { word: '朝', hour: 9, minute: 0, warning: '「朝」を9:00と推定しました' },
    { word: '昼', hour: 12, minute: 0, warning: '「昼」を12:00と推定しました' },
    { word: '夜', hour: 19, minute: 0, warning: '「夜」を19:00と推定しました' },
  ];
  for (const entry of table) {
    const index = text.indexOf(entry.word);
    if (index !== -1) return { hour: entry.hour, minute: entry.minute, span: entry.word, index, warning: entry.warning };
  }
  return null;
}

function removeSpan(text, index, span) {
  return text.slice(0, index) + text.slice(index + span.length);
}

function cleanTitle(text) {
  const boundary = '(?:の|に|は|で|を|と|から|まで|、|,|。|\\.)';
  const re = new RegExp(`^(?:${boundary}\\s*)+|(?:\\s*${boundary})+$`, 'g');
  return text.replace(re, '').trim();
}

function parseJapaneseDateTime(rawText, now = new Date()) {
  let working = rawText;
  const warnings = [];

  const locationResult = matchLocation(working);
  let location = null;
  if (locationResult) {
    location = locationResult.location;
    working = removeSpan(working, locationResult.index, locationResult.span);
  }

  const dateResult = matchAbsoluteDate(working, now)
    || matchRelativeDay(working, now)
    || matchWeekWeekday(working, now)
    || matchBareWeekday(working, now);

  let date;
  if (dateResult) {
    date = dateResult.date;
    working = removeSpan(working, dateResult.index, dateResult.span);
  } else {
    date = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    warnings.push('日付を特定できなかったため、今日の日付を仮設定しています');
  }

  const timeResult = matchExplicitTime(working) || matchVagueTime(working);
  let hour = null;
  let minute = null;
  let isAllDay = true;
  if (timeResult) {
    hour = timeResult.hour;
    minute = timeResult.minute;
    isAllDay = false;
    if (timeResult.warning) warnings.push(timeResult.warning);
    working = removeSpan(working, timeResult.index, timeResult.span);
  }

  let title = cleanTitle(working);
  if (!title) {
    title = '(無題の予定)';
    warnings.push('タイトルを抽出できませんでした');
  }

  const startAt = new Date(date);
  if (!isAllDay) startAt.setHours(hour, minute, 0, 0);

  return { date, hour, minute, isAllDay, title, location, warnings, startAt };
}

function loadEvents() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

function saveEvents(events) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(events));
}

function formatEventDateTime(ev) {
  const d = new Date(ev.startAt);
  const dateStr = new Intl.DateTimeFormat('ja-JP', { month: 'numeric', day: 'numeric', weekday: 'short' }).format(d);
  if (ev.isAllDay) return `${dateStr} 終日`;
  const timeStr = new Intl.DateTimeFormat('ja-JP', { hour: '2-digit', minute: '2-digit', hour12: false }).format(d);
  return `${dateStr} ${timeStr}`;
}

const micBtn = document.getElementById('mic-btn');
const micStatus = document.getElementById('mic-status');
const transcriptEl = document.getElementById('transcript');
const confirmSection = document.getElementById('confirm-section');
const confirmTitle = document.getElementById('confirm-title');
const warningsList = document.getElementById('warnings-list');
const confirmForm = document.getElementById('confirm-form');
const fieldTitle = document.getElementById('field-title');
const fieldLocation = document.getElementById('field-location');
const fieldDate = document.getElementById('field-date');
const fieldAllDay = document.getElementById('field-allday');
const fieldTime = document.getElementById('field-time');
const timeRow = document.getElementById('time-row');
const cancelBtn = document.getElementById('cancel-btn');
const manualAddBtn = document.getElementById('manual-add-btn');
const eventList = document.getElementById('event-list');
const emptyMessage = document.getElementById('empty-message');
const listTitle = document.getElementById('list-title');
const clearFilterBtn = document.getElementById('clear-filter-btn');
const calendarSection = document.getElementById('calendar-section');
const calGrid = document.getElementById('calendar-grid');
const calMonthLabel = document.getElementById('cal-month-label');
const calPrevBtn = document.getElementById('cal-prev');
const calNextBtn = document.getElementById('cal-next');
const calTodayBtn = document.getElementById('cal-today-btn');

let events = loadEvents();
let editingId = null;
let pendingSource = 'manual';
let pendingRawTranscript = null;
let currentMonthDate = startOfMonth(new Date());
let selectedDate = null;

function startOfMonth(date) {
  return new Date(date.getFullYear(), date.getMonth(), 1);
}

function isSameDay(a, b) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

function eventsOnDate(date) {
  return events.filter((ev) => isSameDay(new Date(ev.startAt), date));
}

const MONTH_COLORS = [
  '#cf9d95', // 1月/7月 赤(くすみ)
  '#d9ad84', // 2月/8月 オレンジ(くすみ)
  '#d6c787', // 3月/9月 黄(くすみ)
  '#a3b896', // 4月/10月 緑(くすみ)
  '#93acc0', // 5月/11月 青(くすみ)
  '#b29bb8', // 6月/12月 紫(くすみ)
];

function renderCalendar() {
  calendarSection.style.setProperty('--month-color', MONTH_COLORS[currentMonthDate.getMonth() % 6]);
  calMonthLabel.textContent = new Intl.DateTimeFormat('ja-JP', { year: 'numeric', month: 'long' }).format(currentMonthDate);

  const year = currentMonthDate.getFullYear();
  const month = currentMonthDate.getMonth();
  const firstDow = new Date(year, month, 1).getDay();
  const numDays = new Date(year, month + 1, 0).getDate();
  const totalCells = Math.ceil((firstDow + numDays) / 7) * 7;
  const today = new Date();

  calGrid.innerHTML = '';
  for (let i = 0; i < totalCells; i++) {
    const dayNum = i - firstDow + 1;
    if (dayNum < 1 || dayNum > numDays) {
      const filler = document.createElement('div');
      filler.className = 'day-cell empty';
      calGrid.appendChild(filler);
      continue;
    }

    const cellDate = new Date(year, month, dayNum);
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'day-cell';
    if (isSameDay(cellDate, today)) btn.classList.add('today');
    if (cellDate.getDay() === 0) btn.classList.add('sunday');
    if (cellDate.getDay() === 6) btn.classList.add('saturday');
    if (selectedDate && isSameDay(cellDate, selectedDate)) btn.classList.add('selected');

    const numberSpan = document.createElement('span');
    numberSpan.textContent = String(dayNum);
    btn.appendChild(numberSpan);

    const dayEvents = eventsOnDate(cellDate);
    if (dayEvents.length > 0) {
      const dotsContainer = document.createElement('span');
      dotsContainer.className = 'event-dots';
      const dotCount = Math.min(dayEvents.length, 4);
      for (let d = 0; d < dotCount; d++) {
        const dot = document.createElement('span');
        dot.className = 'event-dot';
        dotsContainer.appendChild(dot);
      }
      btn.appendChild(dotsContainer);
    }

    btn.addEventListener('click', () => {
      selectedDate = cellDate;
      renderCalendar();
      renderEvents();
    });

    calGrid.appendChild(btn);
  }
}

function renderAll() {
  renderCalendar();
  renderEvents();
}

function toDateInputValue(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function toTimeInputValue(hour, minute) {
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

function updateTimeRowState() {
  const disabled = fieldAllDay.checked;
  fieldTime.disabled = disabled;
  timeRow.classList.toggle('disabled', disabled);
}

function openConfirmForm({ title, location, date, hour, minute, isAllDay, warnings, source, rawTranscript, id }) {
  editingId = id || null;
  pendingSource = source;
  pendingRawTranscript = rawTranscript || null;

  confirmTitle.textContent = editingId ? '予定を編集' : '内容を確認';
  fieldTitle.value = title || '';
  fieldLocation.value = location || '';
  fieldDate.value = toDateInputValue(date);
  fieldAllDay.checked = !!isAllDay;
  fieldTime.value = isAllDay ? '' : toTimeInputValue(hour ?? 9, minute ?? 0);
  updateTimeRowState();

  warningsList.innerHTML = '';
  (warnings || []).forEach((w) => {
    const li = document.createElement('li');
    li.textContent = w;
    warningsList.appendChild(li);
  });

  confirmSection.hidden = false;
  confirmSection.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function closeConfirmForm() {
  confirmSection.hidden = true;
  confirmForm.reset();
  editingId = null;
  pendingRawTranscript = null;
}

function renderEvents() {
  const filtered = selectedDate ? eventsOnDate(selectedDate) : events;
  const visible = [...filtered].sort((a, b) => new Date(a.startAt) - new Date(b.startAt));

  if (selectedDate) {
    listTitle.textContent = `${new Intl.DateTimeFormat('ja-JP', { month: 'numeric', day: 'numeric', weekday: 'short' }).format(selectedDate)}の予定`;
    clearFilterBtn.hidden = false;
  } else {
    listTitle.textContent = '予定一覧';
    clearFilterBtn.hidden = true;
  }

  eventList.innerHTML = '';
  emptyMessage.hidden = visible.length > 0;
  emptyMessage.textContent = selectedDate ? 'この日の予定はありません' : 'まだ予定がありません';

  visible.forEach((ev) => {
    const li = document.createElement('li');
    li.className = 'event-item';

    const main = document.createElement('div');
    main.className = 'event-main';
    main.innerHTML = `
      <div class="event-datetime">${formatEventDateTime(ev)}</div>
      <div class="event-title">${escapeHtml(ev.title)}</div>
      ${ev.location ? `<div class="event-location">📍 ${escapeHtml(ev.location)}</div>` : ''}
      <div class="event-source">${ev.sourceType === 'voice' ? '🎤 音声入力' : '手動入力'}</div>
    `;
    main.addEventListener('click', () => {
      const d = new Date(ev.startAt);
      openConfirmForm({
        id: ev.id,
        title: ev.title,
        location: ev.location,
        date: d,
        hour: d.getHours(),
        minute: d.getMinutes(),
        isAllDay: ev.isAllDay,
        warnings: [],
        source: ev.sourceType,
        rawTranscript: ev.rawTranscript,
      });
    });

    const del = document.createElement('button');
    del.className = 'event-delete';
    del.type = 'button';
    del.textContent = '×';
    del.addEventListener('click', () => {
      if (confirm('この予定を削除しますか？')) {
        events = events.filter((e) => e.id !== ev.id);
        saveEvents(events);
        renderAll();
      }
    });

    li.appendChild(main);
    li.appendChild(del);
    eventList.appendChild(li);
  });
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

confirmForm.addEventListener('submit', (e) => {
  e.preventDefault();
  const [y, m, d] = fieldDate.value.split('-').map(Number);
  const isAllDay = fieldAllDay.checked;
  const startAt = new Date(y, m - 1, d);
  if (!isAllDay && fieldTime.value) {
    const [hh, mm] = fieldTime.value.split(':').map(Number);
    startAt.setHours(hh, mm, 0, 0);
  }

  const now = new Date().toISOString();
  const location = fieldLocation.value.trim() || null;
  if (editingId) {
    events = events.map((ev) => ev.id === editingId ? {
      ...ev,
      title: fieldTitle.value.trim(),
      location,
      startAt: startAt.toISOString(),
      isAllDay,
      updatedAt: now,
    } : ev);
  } else {
    events.push({
      id: crypto.randomUUID(),
      title: fieldTitle.value.trim(),
      location,
      startAt: startAt.toISOString(),
      isAllDay,
      sourceType: pendingSource,
      rawTranscript: pendingRawTranscript,
      createdAt: now,
      updatedAt: now,
    });
  }

  saveEvents(events);
  renderAll();
  closeConfirmForm();
});

cancelBtn.addEventListener('click', closeConfirmForm);
fieldAllDay.addEventListener('change', updateTimeRowState);

calPrevBtn.addEventListener('click', () => {
  currentMonthDate = new Date(currentMonthDate.getFullYear(), currentMonthDate.getMonth() - 1, 1);
  selectedDate = null;
  renderAll();
});

calNextBtn.addEventListener('click', () => {
  currentMonthDate = new Date(currentMonthDate.getFullYear(), currentMonthDate.getMonth() + 1, 1);
  selectedDate = null;
  renderAll();
});

calTodayBtn.addEventListener('click', () => {
  const today = new Date();
  currentMonthDate = startOfMonth(today);
  selectedDate = today;
  renderAll();
});

clearFilterBtn.addEventListener('click', () => {
  selectedDate = null;
  renderEvents();
});

manualAddBtn.addEventListener('click', () => {
  openConfirmForm({
    title: '',
    location: '',
    date: new Date(),
    hour: 9,
    minute: 0,
    isAllDay: false,
    warnings: [],
    source: 'manual',
    rawTranscript: null,
  });
});

const SpeechRecognitionImpl = window.SpeechRecognition || window.webkitSpeechRecognition;
let recognition = null;
let isListening = false;

if (!SpeechRecognitionImpl) {
  micBtn.disabled = true;
  micStatus.textContent = 'このブラウザは音声入力に対応していません（Chromeをお試しください）';
} else {
  recognition = new SpeechRecognitionImpl();
  recognition.lang = 'ja-JP';
  recognition.interimResults = true;
  recognition.maxAlternatives = 1;
  recognition.continuous = true;

  const MAX_LISTEN_MS = 30000;
  let autoStopTimer = null;
  let finalTranscript = '';

  recognition.addEventListener('start', () => {
    isListening = true;
    finalTranscript = '';
    micBtn.classList.add('listening');
    micBtn.textContent = '🔴 聞き取り中…（タップで終了）';
    micStatus.textContent = '';
    transcriptEl.textContent = '';
    autoStopTimer = setTimeout(() => recognition.stop(), MAX_LISTEN_MS);
  });

  recognition.addEventListener('result', (event) => {
    let interim = '';
    for (let i = event.resultIndex; i < event.results.length; i++) {
      const segment = event.results[i][0].transcript;
      if (event.results[i].isFinal) {
        finalTranscript += segment;
      } else {
        interim += segment;
      }
    }
    transcriptEl.textContent = finalTranscript + interim;
  });

  recognition.addEventListener('error', (event) => {
    micStatus.textContent = `音声認識エラー: ${event.error}`;
  });

  recognition.addEventListener('end', () => {
    isListening = false;
    micBtn.classList.remove('listening');
    micBtn.textContent = '🎤 話して予定を追加';
    clearTimeout(autoStopTimer);

    const text = finalTranscript.trim();
    if (text) {
      const result = parseJapaneseDateTime(text, new Date());
      openConfirmForm({
        title: result.title,
        location: result.location,
        date: result.date,
        hour: result.hour,
        minute: result.minute,
        isAllDay: result.isAllDay,
        warnings: result.warnings,
        source: 'voice',
        rawTranscript: text,
      });
    }
  });

  micBtn.addEventListener('click', () => {
    if (isListening) {
      recognition.stop();
    } else {
      recognition.start();
    }
  });
}

renderAll();
