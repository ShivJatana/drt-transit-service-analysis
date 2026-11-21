"""Test for sql/01_service_analysis.sql.

Builds a tiny GTFS-style feed in memory (all columns stored as text, like a
DB Browser CSV import), runs every query, and checks the answers we know:
  - Route 900 runs every 10 min, 06:00-22:00, both directions on weekdays,
    every 20 min on Saturday and every 30 min on Sunday.
  - Route 410 runs 5 weekday trips, including one after midnight (25:10).
  - Feb 16, 2026 is a holiday: weekday service removed, Sunday service added.
Usage:  python tests/test_queries.py
"""
import os, re, sqlite3, sys
db = sqlite3.connect(":memory:")
db.executescript("""
CREATE TABLE routes(route_id, route_short_name, route_long_name, route_type);
CREATE TABLE stops(stop_id, stop_name, stop_lat, stop_lon);
CREATE TABLE trips(route_id, service_id, trip_id, direction_id);
CREATE TABLE stop_times(trip_id, arrival_time, departure_time, stop_id, stop_sequence);
CREATE TABLE calendar(service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date);
CREATE TABLE calendar_dates(service_id, date, exception_type);
""")
db.executemany("INSERT INTO routes VALUES (?,?,?,?)", [("R1", "900", "Test frequent route", "3"), ("R2", "410", "Test rural route", "3")])
db.executemany("INSERT INTO stops VALUES (?,?,?,?)", [(f"S{i}", f"Stop {i}", "43.8", "-79.0") for i in range(1, 5)])
db.executemany("INSERT INTO calendar VALUES (?,?,?,?,?,?,?,?,?,?)", [
    ("WK", "1", "1", "1", "1", "1", "0", "0", "20260101", "20260331"),
    ("SA", "0", "0", "0", "0", "0", "1", "0", "20260101", "20260331"),
    ("SU", "0", "0", "0", "0", "0", "0", "1", "20260101", "20260331")])
db.executemany("INSERT INTO calendar_dates VALUES (?,?,?)", [("WK", "20260216", "2"), ("SU", "20260216", "1")])  # holiday Monday runs Sunday service
trips, stimes = [], []
def add_trip(tid, route, svc, dirn, start_min, stops):
    trips.append((route, svc, tid, dirn))
    for k, s in enumerate(stops):
        m = start_min + 5 * k
        t = f"{m // 60}:{m % 60:02d}:00"  # H:MM:SS on purpose (no leading zero)
        stimes.append((tid, t, t, s, str(k + 1)))
# Route 900: every 10 min 06:00-22:00 weekday both directions; every 20 on Sat; every 30 on Sun
n = 0
for svc, step in (("WK", 10), ("SA", 20), ("SU", 30)):
    for m in range(360, 1321, step):
        for d, stops in (("0", ["S1", "S2", "S3"]), ("1", ["S3", "S2", "S1"])):
            n += 1; add_trip(f"T{n}", "R1", svc, d, m, stops)
# Route 410: weekdays only, 4 trips (07:00, 08:00, 12:00, 17:00), one direction, includes a 25:10 late trip
for m in (420, 480, 720, 1020, 1510):
    n += 1; add_trip(f"T{n}", "R2", "WK", "0", m, ["S2", "S4"])
db.executemany("INSERT INTO trips VALUES (?,?,?,?)", trips)
db.executemany("INSERT INTO stop_times VALUES (?,?,?,?,?)", stimes)
SQL_FILE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "sql", "01_service_analysis.sql")
sql = open(SQL_FILE).read()
out = []
for block in re.split(r";\s*\n", sql):
    st = "\n".join(l for l in block.splitlines() if not l.strip().startswith("--")).strip()
    if not st:
        continue
    cur = db.execute(st)
    if cur.description:
        title = next((l.strip("- ").strip() for l in block.splitlines() if re.match(r"--\s*\d+\.\d+", l.strip())), "")
        rows = cur.fetchall()
        out.append((title, [d[0] for d in cur.description], rows))
        print("\n##", title, [d[0] for d in cur.description])
        for r in rows[:8]:
            print(r)
res = {t.split()[0]: rows for t, _, rows in out}
# Known answers for Monday 2026-01-19
assert res["2.1"][0][0] == "900" and res["2.1"][0][2] == 194, res["2.1"]          # 97 departures x 2 directions
assert res["2.1"][0][3] == "06:00" and res["2.1"][0][4] == "22:00"
assert res["2.1"][1][0] == "410" and res["2.1"][1][2] == 5 and res["2.1"][1][4] == "25:10", res["2.1"]
hw = {(r[0], r[1]): r for r in res["2.2"]}
assert hw[("900", "0")][3] == 10 and hw[("410", "0")][3] == 60, res["2.2"]
assert dict(res["2.3"]) == {"1 Every 15 min or better": 1, "3 Every 31-60 min": 1}, res["2.3"]
wk = {r[0]: r for r in res["3.3"]}
assert wk["900"][1:] == (194, 98, 66) and wk["410"][1:] == (5, 0, 0), res["3.3"]
print("\nALL ASSERTIONS PASSED")
