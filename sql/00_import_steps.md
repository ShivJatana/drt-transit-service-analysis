# Step 0: Download the DRT feed and build the database

## 1. Download the GTFS feed
Durham Region Transit publishes its schedule as a **GTFS** feed: a ZIP file of text tables (routes, stops, trips, stop times, calendars).

- **Mobility Database** (official DRT feed): <https://mobilitydatabase.org/feeds/gtfs/mdb-726> → **Download Latest**
- or **Transitland**: <https://www.transit.land/feeds/f-dpz-durhamregiontransit>

Unzip it. You need these files: `routes.txt`, `stops.txt`, `trips.txt`, `stop_times.txt`, `calendar.txt`, `calendar_dates.txt`.

## 2. Import into SQLite
1. Open **DB Browser for SQLite** → **New Database** → save as `drt.db` (close the "Edit table definition" pop-up).
2. **File → Import → Table from CSV file…** and select the six `.txt` files.
   - Tick **Column names in first line**, with the separator set to **comma**.
   - Keep each table name the same as the file name (`routes`, `stops`, …).
3. **Write Changes** (Ctrl+S).

The import stores every column as text. The queries handle that: they convert times and sequence numbers themselves.

## 3. Pick your analysis dates
Run:

```sql
SELECT MIN(start_date), MAX(end_date) FROM calendar;
```

Then, in `01_service_analysis.sql`, replace `20260119` (weekday), `20260124` (Saturday) and `20260125` (Sunday) with normal dates inside that range, avoiding holidays.

> If the feed has no `calendar.txt` (some feeds use only `calendar_dates.txt`), create an empty table first:
> `CREATE TABLE calendar(service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date);`
