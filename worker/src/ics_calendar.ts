import {
  fetchCalendarIcsText,
  invalidCalendarIcsError,
  type CalendarIcsProvider,
} from './ics_feed_transport';
import { parseCalendarIcs, type IcsCalendarEvent } from './ics_calendar_parser';

export {
  CalendarIcsError,
  calendarIcsValidationError,
  normalizeCalendarIcsUrl,
  type CalendarIcsFailureStage,
  type CalendarIcsProvider,
} from './ics_feed_transport';
export { parseCalendarIcs, type IcsCalendarEvent } from './ics_calendar_parser';

export async function fetchCalendarIcsEvents(
  provider: CalendarIcsProvider,
  inputUrl: string,
  allowedCanvasHost: string,
): Promise<IcsCalendarEvent[]> {
  const response = await fetchCalendarIcsText(provider, inputUrl, allowedCanvasHost);
  try {
    return parseCalendarIcs(response.text);
  } catch (cause) {
    throw invalidCalendarIcsError(provider, response, cause);
  }
}
