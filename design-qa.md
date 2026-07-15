# Design QA

final result: passed

Scope: Flutter activity feed UI in `app/lib/screens/explore/explore_screen.dart`, plus the shared activity feed widgets used by `app/lib/screens/events/event_list_screen.dart`.

Reference: user-provided mobile screenshot showing `你的活动`, an empty personal activity state, `为你推荐 / 附近`, date-grouped event rows, square covers, organizer line, title, time, location, and optional price.

Checked locally: Flutter Web at `http://127.0.0.1:39017` with a 390x844 mobile viewport.

Findings:
- The activity tab now matches the reference structure: personal section, recommendation header, date groups, square covers, organizer/title/time/location/price rows.
- Existing event data is preserved; titles, covers, host metadata, venue, time, fee, and detail navigation still come from the current API payload.
- Tapping an event still opens the existing event detail page with the original报名 action.
- Recommendation ordering now prioritizes upcoming events, with past events retained after current/future events.

Remaining notes:
- The app's existing top channel tabs and bottom navigation remain visible because this is the production Flutter shell, not a standalone clone of the screenshot.
- The floating create button can overlay lower list content while scrolling, consistent with the current app shell behavior.
