# Durham Region Transit: Scheduled Service Analysis (GTFS)

![Tools: SQL + Python tests](https://img.shields.io/badge/Tools-SQL%20%2B%20Python%20tests-1F3A5F?style=flat-square) ![Domain: Public transit](https://img.shields.io/badge/Domain-Public%20transit-4A5568?style=flat-square) ![Data: Public (GTFS)](https://img.shields.io/badge/Data-Public%20%28GTFS%29-lightgrey?style=flat-square) ![Status: Results pending](https://img.shields.io/badge/Status-Results%20pending-orange?style=flat-square)

**How frequent is bus service across Durham Region, where are the gaps, and how much does service drop on weekends?**

Uses **real, public data**: Durham Region Transit's official GTFS schedule feed. As a dispatcher on a Durham Region paratransit contract, I see daily how the conventional network shapes demand for specialized and on-demand trips. This project measures that network directly.

**Tools:** SQL (SQLite: CTEs, window functions) · Python (tests) · Excel / Power BI for charts

---

## Questions

1. Which routes carry the most trips, and what hours do they run?
2. How often do buses come in the morning peak? How many routes run every 15 minutes or better?
3. Which stops are busiest, and how many stops see fewer than 10 buses a day?
4. How much service is cut on Saturdays and Sundays, route by route?

## What's in the repo

| Path | What it does |
|---|---|
| `sql/00_import_steps.md` | Where to download the DRT feed and how to load it into SQLite |
| `sql/01_service_analysis.sql` | All queries: service calendar, trips and span by route, peak headways, frequency bands, busiest and low-service stops, weekday vs weekend |
| `tests/test_queries.py` | Builds a small test feed with known answers and checks every query (`python tests/test_queries.py`) |

### How the analysis works
- **Which buses run on a given date** is worked out the way GTFS defines it: the weekly pattern in `calendar`, plus added or removed days in `calendar_dates` (holidays, for example).
- **Times** are converted to seconds after midnight. This handles `H:MM:SS`, `HH:MM:SS` and after-midnight times like `25:10:00`.
- **Headway** is the average gap between consecutive trip departures, per route and direction, from 07:00 to 09:00.
- Routes are grouped into **frequency bands**: every 15 minutes or better, 16–30, 31–60, or less than hourly.

## How to run it

1. Follow `sql/00_import_steps.md` to download the feed and build `drt.db`.
2. Set your analysis dates in `sql/01_service_analysis.sql`.
3. Run each query in DB Browser for SQLite and copy the results into the tables below.

---

## Results

*To be completed after running on the current DRT feed. Feed date: `____`; analysis weekday: `____`.*

| Metric | Value |
|---|---|
| Routes in feed | |
| Stops in feed | |
| Weekday trips | |
| Routes every 15 min or better (AM peak) | |
| Stops with fewer than 10 weekday departures | |
| Saturday service vs weekday (% of trips) | |
| Sunday service vs weekday (% of trips) | |

### Top 5 routes by weekday trips

| Route | Name | Trips | First | Last |
|---|---|---|---|---|
| | | | | |

### Findings
1. 
2. 
3. 

---

*Data: Durham Region Transit GTFS feed, via the Mobility Database / Transitland. Check the feed's licence terms before redistributing the raw files. This repo does not include them.*
