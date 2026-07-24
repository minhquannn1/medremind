import dayjs from 'dayjs';
import 'dayjs/locale/vi';
import isToday from 'dayjs/plugin/isToday';
import isSameOrBefore from 'dayjs/plugin/isSameOrBefore';
import isSameOrAfter from 'dayjs/plugin/isSameOrAfter';
import relativeTime from 'dayjs/plugin/relativeTime';
import customParseFormat from 'dayjs/plugin/customParseFormat';
import dayOfYear from 'dayjs/plugin/dayOfYear';

dayjs.extend(isToday);
dayjs.extend(isSameOrBefore);
dayjs.extend(isSameOrAfter);
dayjs.extend(relativeTime);
dayjs.extend(customParseFormat);
dayjs.extend(dayOfYear);

export const nowIso = () => dayjs().toISOString();
export const todayDate = () => dayjs().format('YYYY-MM-DD');

export function formatTime(hhmm: string): string {
  // hhmm = "08:30"
  return dayjs(hhmm, 'HH:mm').format('HH:mm');
}

export function formatDate(iso?: string | null, locale: string = 'vi'): string {
  if (!iso) return '—';
  return dayjs(iso).locale(locale).format('DD/MM/YYYY');
}

export function formatDateTime(iso?: string | null, locale: string = 'vi'): string {
  if (!iso) return '—';
  return dayjs(iso).locale(locale).format('DD/MM/YYYY HH:mm');
}

export function ageFromDob(dob?: string | null): number | null {
  if (!dob) return null;
  return dayjs().diff(dayjs(dob), 'year');
}

/** Build an ISO datetime for a given date + HH:mm time string. */
export function dateAtTime(date: dayjs.Dayjs, hhmm: string): dayjs.Dayjs {
  const [h, m] = hhmm.split(':').map(Number);
  return date.hour(h).minute(m).second(0).millisecond(0);
}

/** Bucket a HH:mm time into a part-of-day key. */
export function partOfDay(hhmm: string): 'morning' | 'noon' | 'evening' | 'night' {
  const h = Number(hhmm.split(':')[0]);
  if (h < 11) return 'morning';
  if (h < 14) return 'noon';
  if (h < 18) return 'evening';
  return 'night';
}

export { dayjs };
