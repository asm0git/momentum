import {
  dateKey,
  makeDateTime,
  parseDateTime,
  type IcsDateTime,
} from './ics_datetime';

const MILLISECONDS_PER_WEEK = 604_800_000;

export interface MasterOccurrences {
  dates: IcsDateTime[];
  isRecurring: boolean;
}

export function masterOccurrences(
  start: IcsDateTime,
  ruleValue: string | null,
  recurrenceDates: IcsDateTime[],
  rangeEnd: Date,
): MasterOccurrences {
  const rule = parseRule(ruleValue);
  const candidates = (rule ? expandRule(start, rule, rangeEnd) : [start])
    .concat(recurrenceDates);
  return {
    dates: [...new Map(candidates.map((candidate) => [dateKey(candidate), candidate])).values()]
      .sort((left, right) => left.instant.getTime() - right.instant.getTime()),
    isRecurring: rule != null || recurrenceDates.length > 0,
  };
}

function parseRule(value: string | null): Map<string, string> | null {
  if (!value) return null;
  const rule = new Map<string, string>();
  for (const part of value.split(';')) {
    const separator = part.indexOf('=');
    if (separator > 0) {
      rule.set(part.slice(0, separator).toUpperCase(), part.slice(separator + 1));
    }
  }
  return rule.has('FREQ') ? rule : null;
}

type RuleFrequency = 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY';
type DateFields = [number, number, number, number, number, number];

interface RuleExpansion {
  start: IcsDateTime;
  frequency: RuleFrequency;
  interval: number;
  countLimit: number;
  until: Date | null;
  weekdays: string[];
  monthDays: number[];
  months: number[];
  rangeEnd: Date;
}

function expandRule(
  start: IcsDateTime,
  rule: Map<string, string>,
  rangeEnd: Date,
): IcsDateTime[] {
  const expansion = parseRuleExpansion(start, rule, rangeEnd);
  return expansion ? expandRuleOccurrences(expansion) : [start];
}

function parseRuleExpansion(
  start: IcsDateTime,
  rule: Map<string, string>,
  rangeEnd: Date,
): RuleExpansion | null {
  const frequency = parseRuleFrequency(rule.get('FREQ'));
  if (!frequency) return null;
  const interval = positiveRuleValue(rule, 'INTERVAL', 1);
  if (interval === null) return null;
  return {
    start,
    frequency,
    interval,
    countLimit: Math.max(0, numericRuleValue(rule, 'COUNT', 0)),
    until: parseRuleUntil(rule),
    weekdays: stringRuleList(rule, 'BYDAY'),
    monthDays: numericRuleList(rule, 'BYMONTHDAY'),
    months: numericRuleList(rule, 'BYMONTH'),
    rangeEnd,
  };
}

function positiveRuleValue(
  rule: Map<string, string>,
  name: string,
  fallback: number,
): number | null {
  const value = rule.get(name);
  if (value === undefined) return fallback;
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
}

function numericRuleValue(
  rule: Map<string, string>,
  name: string,
  fallback: number,
): number {
  return Number(rule.get(name) ?? fallback) || fallback;
}

function parseRuleUntil(rule: Map<string, string>): Date | null {
  const value = rule.get('UNTIL');
  if (!value) return null;
  return parseDateTime({ name: 'UNTIL', params: new Map(), value })?.instant ?? null;
}

function stringRuleList(rule: Map<string, string>, name: string): string[] {
  return (rule.get(name) ?? '').split(',').filter(Boolean);
}

function numericRuleList(rule: Map<string, string>, name: string): number[] {
  return (rule.get(name) ?? '').split(',').map(Number).filter(Boolean);
}

function parseRuleFrequency(value: string | undefined): RuleFrequency | null {
  const frequency = value?.toUpperCase();
  switch (frequency) {
    case 'DAILY':
    case 'WEEKLY':
    case 'MONTHLY':
    case 'YEARLY':
      return frequency as RuleFrequency;
    default:
      return null;
  }
}

function expandRuleOccurrences({
  start,
  frequency,
  interval,
  countLimit,
  until,
  weekdays,
  monthDays,
  months,
  rangeEnd,
}: RuleExpansion): IcsDateTime[] {
  const fromDay = Date.UTC(start.fields[0], start.fields[1] - 1, start.fields[2]);
  const through = Math.min(rangeEnd.getTime(), until?.getTime() ?? Infinity);
  const output: IcsDateTime[] = [];
  output.push(start);
  let occurrences = 1;
  const maxDays = Math.min(100_000, Math.ceil((through - fromDay) / 86_400_000) + 1);
  for (let offset = 0; offset < maxDays; offset++) {
    const candidateDate = new Date(fromDay + offset * 86_400_000);
    const fields: DateFields = [
      candidateDate.getUTCFullYear(), candidateDate.getUTCMonth() + 1,
      candidateDate.getUTCDate(), start.fields[3], start.fields[4], start.fields[5],
    ];
    const candidate = makeDateTime(fields, start);
    const isStartDate = offset === 0;
    if (candidate.instant < start.instant || isStartDate) continue;
    if (matchesRuleDate(fields, start.fields, {
      frequency,
      interval,
      weekdays,
      monthDays,
      months,
    })) {
      occurrences++;
      if (countLimit > 0 && occurrences > countLimit) break;
      if ((!until || candidate.instant <= until) && candidate.instant <= rangeEnd) {
        output.push(candidate);
      }
    }
    if (countLimit > 0 && occurrences >= countLimit) break;
  }
  return output;
}

interface RuleDateFilters {
  frequency: RuleFrequency;
  interval: number;
  weekdays: string[];
  monthDays: number[];
  months: number[];
}

interface RuleDateMetrics {
  day: number;
  month: number;
  startMonth: number;
  startDay: number;
  weekday: number;
  startWeekday: number;
  daysSinceStart: number;
  weeksSinceStart: number;
  monthsSinceStart: number;
  yearsSinceStart: number;
}

interface OptionalRuleFilter {
  configured: boolean;
  matches: boolean;
}

interface DailyRuleContext {
  interval: number;
  daysSinceStart: number;
  weekdayFilter: OptionalRuleFilter;
  monthDayFilter: OptionalRuleFilter;
}

interface WeeklyRuleContext {
  interval: number;
  weeksSinceStart: number;
  weekday: number;
  startWeekday: number;
  weekdayFilter: OptionalRuleFilter;
  monthDayFilter: OptionalRuleFilter;
}

interface MonthlyRuleContext {
  interval: number;
  monthsSinceStart: number;
  day: number;
  startDay: number;
  weekdayFilter: OptionalRuleFilter;
  monthDayFilter: OptionalRuleFilter;
}

interface YearlyRuleContext {
  interval: number;
  yearsSinceStart: number;
  month: number;
  startMonth: number;
  day: number;
  startDay: number;
  hasMonthFilter: boolean;
  weekdayFilter: OptionalRuleFilter;
  monthDayFilter: OptionalRuleFilter;
}

function matchesRuleDate(
  fields: DateFields,
  initial: DateFields,
  filters: RuleDateFilters,
): boolean {
  const [year, month, day] = fields;
  const [startYear, startMonth, startDay] = initial;
  if (filters.months.length > 0 && !filters.months.includes(month)) return false;

  const current = new Date(Date.UTC(year, month - 1, day));
  const initialDate = new Date(Date.UTC(startYear, startMonth - 1, startDay));
  const metrics: RuleDateMetrics = {
    day,
    month,
    startMonth,
    startDay,
    weekday: current.getUTCDay(),
    startWeekday: initialDate.getUTCDay(),
    daysSinceStart: Math.floor(
      (current.getTime() - initialDate.getTime()) / 86_400_000,
    ),
    weeksSinceStart: Math.floor(
      (weekStart(current) - weekStart(initialDate)) / MILLISECONDS_PER_WEEK,
    ),
    monthsSinceStart: (year - startYear) * 12 + month - startMonth,
    yearsSinceStart: year - startYear,
  };
  const weekdayFilter = optionalRuleFilter(filters.weekdays, (item) =>
    matchesByDay(item, current),
  );
  const monthDayFilter = optionalRuleFilter(filters.monthDays, (value) =>
    day ===
    (value > 0
      ? value
      : new Date(Date.UTC(year, month, 0)).getUTCDate() + value + 1),
  );

  switch (filters.frequency) {
    case 'DAILY':
      return matchesDailyRule({
        interval: filters.interval,
        daysSinceStart: metrics.daysSinceStart,
        weekdayFilter,
        monthDayFilter,
      });
    case 'WEEKLY':
      return matchesWeeklyRule({
        interval: filters.interval,
        weeksSinceStart: metrics.weeksSinceStart,
        weekday: metrics.weekday,
        startWeekday: metrics.startWeekday,
        weekdayFilter,
        monthDayFilter,
      });
    case 'MONTHLY':
      return matchesMonthlyRule({
        interval: filters.interval,
        monthsSinceStart: metrics.monthsSinceStart,
        day: metrics.day,
        startDay: metrics.startDay,
        weekdayFilter,
        monthDayFilter,
      });
    case 'YEARLY':
      return matchesYearlyRule({
        interval: filters.interval,
        yearsSinceStart: metrics.yearsSinceStart,
        month: metrics.month,
        startMonth: metrics.startMonth,
        day: metrics.day,
        startDay: metrics.startDay,
        hasMonthFilter: filters.months.length > 0,
        weekdayFilter,
        monthDayFilter,
      });
    default:
      return assertNever(filters.frequency);
  }
}

function assertNever(value: never): never {
  throw new Error(`Unsupported recurrence frequency: ${String(value)}`);
}

function optionalRuleFilter<T>(
  values: T[],
  matches: (value: T) => boolean,
): OptionalRuleFilter {
  return { configured: values.length > 0, matches: values.some(matches) };
}

function matchesDailyRule(context: DailyRuleContext): boolean {
  const { interval, daysSinceStart, weekdayFilter, monthDayFilter } = context;
  return daysSinceStart % interval === 0 &&
    (!weekdayFilter.configured || weekdayFilter.matches) &&
    (!monthDayFilter.configured || monthDayFilter.matches);
}

function matchesWeeklyRule(context: WeeklyRuleContext): boolean {
  const {
    interval,
    weeksSinceStart,
    weekday,
    startWeekday,
    weekdayFilter,
    monthDayFilter,
  } = context;
  const matchesRequestedWeekday = weekdayFilter.configured
    ? weekdayFilter.matches
    : weekday === startWeekday;
  return weeksSinceStart >= 0 && weeksSinceStart % interval === 0 &&
    matchesRequestedWeekday &&
    (!monthDayFilter.configured || monthDayFilter.matches);
}

function matchesMonthlyRule(context: MonthlyRuleContext): boolean {
  const {
    interval,
    monthsSinceStart,
    day,
    startDay,
    weekdayFilter,
    monthDayFilter,
  } = context;
  if (monthsSinceStart < 0 || monthsSinceStart % interval !== 0) return false;
  return monthDayFilter.configured
    ? monthDayFilter.matches
    : weekdayFilter.configured
      ? weekdayFilter.matches
      : day === startDay;
}

function matchesYearlyRule(context: YearlyRuleContext): boolean {
  const {
    interval,
    yearsSinceStart,
    month,
    startMonth,
    day,
    startDay,
    hasMonthFilter,
    weekdayFilter,
    monthDayFilter,
  } = context;
  if (yearsSinceStart % interval !== 0) return false;
  if (!hasMonthFilter && month !== startMonth) return false;
  return monthDayFilter.configured
    ? monthDayFilter.matches
    : weekdayFilter.configured
      ? weekdayFilter.matches
      : day === startDay;
}

function weekStart(date: Date): number {
  const result = new Date(date);
  result.setUTCDate(result.getUTCDate() - ((result.getUTCDay() + 6) % 7));
  return result.getTime();
}

function matchesByDay(token: string, date: Date): boolean {
  const match = token.match(/^([+-]?\d+)?(MO|TU|WE|TH|FR|SA|SU)$/i);
  if (!match) return false;
  const weekdays = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];
  if (weekdays[date.getUTCDay()] !== match[2].toUpperCase()) return false;
  if (!match[1]) return true;
  const ordinal = Number(match[1]);
  if (ordinal > 0) return Math.floor((date.getUTCDate() - 1) / 7) + 1 === ordinal;
  const lastDay = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0)).getUTCDate();
  return -Math.floor((lastDay - date.getUTCDate()) / 7) - 1 === ordinal;
}
