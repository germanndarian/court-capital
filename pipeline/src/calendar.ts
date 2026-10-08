// Edition dates live in Zürich time. GitHub's cron runs in UTC, so every decision about
// "today" goes through these helpers.

export const TIME_ZONE = "Europe/Zurich";
const FIRST_VOLUME_YEAR = 2026;

export interface LocalNow {
  /** YYYY-MM-DD in Zürich */
  date: string;
  /** 1 = Monday … 7 = Sunday */
  weekday: number;
  hour: number;
  minute: number;
}

const partsFormatter = new Intl.DateTimeFormat("en-GB", {
  timeZone: TIME_ZONE,
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  weekday: "short",
  hourCycle: "h23",
});

const WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

export function zurichNow(now: Date = new Date()): LocalNow {
  const parts = Object.fromEntries(partsFormatter.formatToParts(now).map((p) => [p.type, p.value]));
  return {
    date: `${parts.year}-${parts.month}-${parts.day}`,
    weekday: WEEKDAYS.indexOf(parts.weekday ?? "") + 1,
    hour: Number(parts.hour),
    minute: Number(parts.minute),
  };
}

/** The Zürich calendar date of a moment, as YYYY-MM-DD. */
export function zurichDate(moment: Date): string {
  return zurichNow(moment).date;
}

function toUTC(date: string): Date {
  const [year, month, day] = date.split("-").map(Number);
  return new Date(Date.UTC(year!, month! - 1, day!));
}

function fromUTC(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/** 1 = Monday … 7 = Sunday, for a YYYY-MM-DD date. */
export function weekdayOf(date: string): number {
  const day = toUTC(date).getUTCDay();
  return day === 0 ? 7 : day;
}

export function isWeekday(date: string): boolean {
  return weekdayOf(date) <= 5;
}

export function addDays(date: string, days: number): string {
  const d = toUTC(date);
  d.setUTCDate(d.getUTCDate() + days);
  return fromUTC(d);
}

export function previousWeekday(date: string): string {
  let day = addDays(date, -1);
  while (!isWeekday(day)) day = addDays(day, -1);
  return day;
}

/** Weekdays from 1 January of the date's year up to and including the date (No. CC = 7 October 2026). */
export function editionNumber(date: string): number {
  const year = date.slice(0, 4);
  let count = 0;
  for (let day = `${year}-01-01`; day <= date; day = addDays(day, 1)) {
    if (isWeekday(day)) count++;
  }
  return count;
}

export function volume(date: string): number {
  return Number(date.slice(0, 4)) - FIRST_VOLUME_YEAR + 1;
}

const longFormatter = new Intl.DateTimeFormat("en-GB", {
  timeZone: "UTC",
  weekday: "long",
  day: "numeric",
  month: "long",
  year: "numeric",
});

const weekdayFormatter = new Intl.DateTimeFormat("en-GB", { timeZone: "UTC", weekday: "long" });

/** "Thursday, 8 October 2026" */
export function longDate(date: string): string {
  const parts = Object.fromEntries(longFormatter.formatToParts(toUTC(date)).map((p) => [p.type, p.value]));
  return `${parts.weekday}, ${parts.day} ${parts.month} ${parts.year}`;
}

/** "Wednesday" */
export function weekdayName(date: string): string {
  return weekdayFormatter.format(toUTC(date));
}
