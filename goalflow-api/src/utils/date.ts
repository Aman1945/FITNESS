import { DateTime } from 'luxon';

/**
 * All scheduling is computed in the USER'S timezone and stored in UTC.
 * `scheduledDate` is the UTC instant of local midnight, so a day-bucket query is
 * a plain range scan and never depends on the device clock.
 */

export function nowIn(tz: string): DateTime {
  return DateTime.now().setZone(tz);
}

/** UTC Date representing local midnight of the given day. */
export function localDayStart(dt: DateTime): Date {
  return dt.startOf('day').toUTC().toJSDate();
}

export function dayKey(dt: DateTime): string {
  return dt.toFormat('yyyy-LL-dd');
}

/** Combine a local calendar day with an "HH:mm" string. */
export function atLocalTime(day: DateTime, hhmm: string): DateTime {
  const [h, m] = hhmm.split(':').map((n) => parseInt(n, 10));
  return day.set({
    hour: Number.isFinite(h) ? h : 9,
    minute: Number.isFinite(m) ? m : 0,
    second: 0,
    millisecond: 0,
  });
}

/** Luxon weekday is 1..7 (Mon..Sun); the app uses 0..6 (Sun..Sat). */
export function weekdayIndex(dt: DateTime): number {
  return dt.weekday % 7;
}

/** Monday-start week containing `dt`. */
export function weekBounds(dt: DateTime): { start: DateTime; end: DateTime } {
  const start = dt.startOf('week');
  return { start, end: start.plus({ days: 6 }).endOf('day') };
}

export function eachDay(from: DateTime, to: DateTime): DateTime[] {
  const days: DateTime[] = [];
  let cur = from.startOf('day');
  const last = to.startOf('day');
  while (cur <= last) {
    days.push(cur);
    cur = cur.plus({ days: 1 });
  }
  return days;
}

export function clamp01(n: number): number {
  if (!Number.isFinite(n)) return 0;
  return Math.min(1, Math.max(0, n));
}

export function pct(n: number): number {
  return Math.round(clamp01(n) * 100);
}

/** True when `time` ("HH:mm") falls inside a possibly overnight quiet window. */
export function isWithinQuietHours(time: string, start: string, end: string): boolean {
  const toMin = (s: string) => {
    const [h, m] = s.split(':').map(Number);
    return h * 60 + m;
  };
  const t = toMin(time);
  const s = toMin(start);
  const e = toMin(end);
  return s <= e ? t >= s && t < e : t >= s || t < e;
}
