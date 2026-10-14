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
  return {
    start,
    frequency,
    interval: Math.max(1, numericRuleValue(rule, 'INTERVAL', 1)),
    countLimit: Math.max(0, numericRuleValue(rule, 'COUNT', 0)),
    until: parseRuleUntil(rule),
    weekdays: stringRuleList(rule, 'BYDAY'),
    monthDays: numericRuleList(rule, 'BYMONTHDAY'),
    months: numericRuleList(rule, 'BYMONTH'),
    rangeEnd,
  };
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

function matchesRuleDate(
  fields: DateFields,
  initial: DateFields,
  filters: RuleDateFilters,
): boolean {
  const [year, month, day] = fields;
  const [startYear, startMonth, startDay] = initial;
  const current = new Date(Date.UTC(year, month - 1, day));
  const initialDate = new Date(Date.UTC(startYear, startMonth - 1, startDay));
  const { frequency, interval, weekdays, monthDays, months } = filters;
  const hasWeekdayFilter = weekdays.length > 0;
  const hasMonthDayFilter = monthDays.length > 0;
  const hasMonthFilter = months.length > 0;
  const context: RuleDateContext = {
    day,
    month,
    startMonth,
    startDay,
    weekday: current.getUTCDay(),
    startWeekday: initialDate.getUTCDay(),
    interval,
    daysSinceStart: Math.floor((current.getTime() - initialDate.getTime()) / 86_400_000),
    weeksSinceStart: Math.floor(
      (weekStart(current) - weekStart(initialDate)) / MILLISECONDS_PER_WEEK,
    ),
    monthsSinceStart: (year - startYear) * 12 + month - startMonth,
    yearsSinceStart: year - startYear,
    hasWeekdayFilter,
    hasMonthDayFilter,
    hasMonthFilter,
    matchesWeekdayFilter: hasWeekdayFilter &&
      weekdays.some((item) => matchesByDay(item, current)),
    matchesMonthDayFilter: hasMonthDayFilter && monthDays.some((value) =>
      day === (value > 0 ? value : new Date(Date.UTC(year, month, 0)).getUTCDate() + value + 1),
    ),
    isAllowedMonth: months.length === 0 || months.includes(month),
  };

  return matchesFrequencyRule(frequency, context);
}

interface RuleDateContext {
  day: number;
  month: number;
  startMonth: number;
  startDay: number;
  weekday: number;
  startWeekday: number;
  interval: number;
  daysSinceStart: number;
  weeksSinceStart: number;
  monthsSinceStart: number;
  yearsSinceStart: number;
  hasWeekdayFilter: boolean;
  hasMonthDayFilter: boolean;
  hasMonthFilter: boolean;
  matchesWeekdayFilter: boolean;
  matchesMonthDayFilter: boolean;
  isAllowedMonth: boolean;
}

function matchesFrequencyRule(
  frequency: RuleFrequency,
  context: RuleDateContext,
): boolean {
  if (!context.isAllowedMonth) return false;
  switch (frequency) {
    case 'DAILY': {
      return matchesDailyRule(context);
    }
    case 'WEEKLY': {
      return matchesWeeklyRule(context);
    }
    case 'MONTHLY': {
      return matchesMonthlyRule(context);
    }
    case 'YEARLY': {
      return matchesYearlyRule(context);
    }
  }
}

function matchesDailyRule({
  interval,
  daysSinceStart,
  hasWeekdayFilter,
  hasMonthDayFilter,
  matchesWeekdayFilter,
  matchesMonthDayFilter,
}: RuleDateContext): boolean {
  return daysSinceStart % interval === 0 &&
    (!hasWeekdayFilter || matchesWeekdayFilter) &&
    (!hasMonthDayFilter || matchesMonthDayFilter);
}

function matchesWeeklyRule({
  interval,
  weeksSinceStart,
  weekday,
  startWeekday,
  hasWeekdayFilter,
  hasMonthDayFilter,
  matchesWeekdayFilter,
  matchesMonthDayFilter,
}: RuleDateContext): boolean {
  const matchesRequestedWeekday = hasWeekdayFilter
    ? matchesWeekdayFilter
    : weekday === startWeekday;
  return weeksSinceStart >= 0 && weeksSinceStart % interval === 0 &&
    matchesRequestedWeekday && (!hasMonthDayFilter || matchesMonthDayFilter);
}

function matchesMonthlyRule({
  interval,
  monthsSinceStart,
  day,
  startDay,
  hasWeekdayFilter,
  hasMonthDayFilter,
  matchesWeekdayFilter,
  matchesMonthDayFilter,
}: RuleDateContext): boolean {
  if (monthsSinceStart < 0 || monthsSinceStart % interval !== 0) return false;
  return hasMonthDayFilter
    ? matchesMonthDayFilter
    : hasWeekdayFilter
      ? matchesWeekdayFilter
      : day === startDay;
}

function matchesYearlyRule({
  interval,
  yearsSinceStart,
  month,
  startMonth,
  day,
  startDay,
  hasWeekdayFilter,
  hasMonthDayFilter,
  hasMonthFilter,
  matchesWeekdayFilter,
  matchesMonthDayFilter,
}: RuleDateContext): boolean {
  if (yearsSinceStart % interval !== 0) return false;
  if (!hasMonthFilter && month !== startMonth) return false;
  return hasMonthDayFilter
    ? matchesMonthDayFilter
    : hasWeekdayFilter
      ? matchesWeekdayFilter
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
