-- =====================================================================
-- DURHAM REGION TRANSIT: SCHEDULED SERVICE ANALYSIS (GTFS)
-- Works on any GTFS feed imported with sql/00_import_steps.md.
--
-- STEP 1: set the date to analyze (a normal weekday inside the feed's
-- service period) in the "params" line of EACH query below, YYYYMMDD.
-- Tip: SELECT MIN(start_date), MAX(end_date) FROM calendar;
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0.1  Helper view: stop times in seconds after midnight
--      GTFS times can be H:MM:SS or HH:MM:SS, and can pass 24:00:00
--      for trips that run after midnight.
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS st;
CREATE VIEW st AS
SELECT trip_id,
       stop_id,
       CAST(stop_sequence AS INTEGER) AS seq,
       CAST(substr(departure_time, 1, instr(departure_time, ':') - 1) AS INTEGER) * 3600
     + CAST(substr(departure_time, instr(departure_time, ':') + 1, 2) AS INTEGER) * 60
     + CAST(substr(departure_time, -2) AS INTEGER) AS dep_sec
FROM stop_times
WHERE departure_time IS NOT NULL AND departure_time <> '';


-- ---------------------------------------------------------------------
-- 0.2  Helper view: first departure of every trip
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS trip_start;
CREATE VIEW trip_start AS
SELECT s.trip_id, s.stop_id AS first_stop, s.dep_sec AS start_sec
FROM st s
JOIN (SELECT trip_id, MIN(seq) AS min_seq FROM st GROUP BY trip_id) m
  ON m.trip_id = s.trip_id AND m.min_seq = s.seq;


-- ---------------------------------------------------------------------
-- 1.1  Feed overview
-- ---------------------------------------------------------------------
SELECT (SELECT COUNT(*) FROM routes)     AS routes,
       (SELECT COUNT(*) FROM stops)      AS stops,
       (SELECT COUNT(*) FROM trips)      AS trips_all_service_days,
       (SELECT MIN(start_date) FROM calendar) AS feed_start,
       (SELECT MAX(end_date) FROM calendar)   AS feed_end;


-- ---------------------------------------------------------------------
-- 1.2  Services running on the analysis date
--      (calendar weekday pattern + calendar_dates exceptions)
-- ---------------------------------------------------------------------
WITH params(d) AS (SELECT '20260119'),
dow AS (SELECT CAST(strftime('%w', substr(d,1,4) || '-' || substr(d,5,2) || '-' || substr(d,7,2)) AS INTEGER) AS w, d FROM params),
active AS (
    SELECT c.service_id FROM calendar c, dow
    WHERE dow.d BETWEEN c.start_date AND c.end_date
      AND CASE dow.w WHEN 0 THEN c.sunday WHEN 1 THEN c.monday WHEN 2 THEN c.tuesday WHEN 3 THEN c.wednesday
                     WHEN 4 THEN c.thursday WHEN 5 THEN c.friday ELSE c.saturday END = '1'
    UNION SELECT service_id FROM calendar_dates, params WHERE date = d AND exception_type = '1'
    EXCEPT SELECT service_id FROM calendar_dates, params WHERE date = d AND exception_type = '2'
)
SELECT service_id FROM active;


-- ---------------------------------------------------------------------
-- 2.1  Trips, span of service and stops per route on the analysis date
-- ---------------------------------------------------------------------
WITH params(d) AS (SELECT '20260119'),
dow AS (SELECT CAST(strftime('%w', substr(d,1,4) || '-' || substr(d,5,2) || '-' || substr(d,7,2)) AS INTEGER) AS w, d FROM params),
active AS (
    SELECT c.service_id FROM calendar c, dow
    WHERE dow.d BETWEEN c.start_date AND c.end_date
      AND CASE dow.w WHEN 0 THEN c.sunday WHEN 1 THEN c.monday WHEN 2 THEN c.tuesday WHEN 3 THEN c.wednesday
                     WHEN 4 THEN c.thursday WHEN 5 THEN c.friday ELSE c.saturday END = '1'
    UNION SELECT service_id FROM calendar_dates, params WHERE date = d AND exception_type = '1'
    EXCEPT SELECT service_id FROM calendar_dates, params WHERE date = d AND exception_type = '2'
)
SELECT r.route_short_name AS route,
       r.route_long_name  AS name,
       COUNT(DISTINCT t.trip_id) AS trips,
       printf('%02d:%02d', MIN(ts.start_sec) / 3600, MIN(ts.start_sec) % 3600 / 60) AS first_departure,
       printf('%02d:%02d', MAX(ts.start_sec) / 3600, MAX(ts.start_sec) % 3600 / 60) AS last_departure,
       ROUND((MAX(ts.start_sec) - MIN(ts.start_sec)) / 3600.0, 1) AS span_hours
FROM trips t
JOIN active a      ON a.service_id = t.service_id
JOIN routes r      ON r.route_id = t.route_id
JOIN trip_start ts ON ts.trip_id = t.trip_id
GROUP BY r.route_id
ORDER BY trips DESC;


-- ---------------------------------------------------------------------
-- 2.2  Average AM-peak headway per route and direction (07:00-09:00)
--      Headway = average minutes between consecutive trip starts.
-- ---------------------------------------------------------------------
WITH params(d) AS (SELECT '20260119'),
dow AS (SELECT CAST(strftime('%w', substr(d,1,4) || '-' || substr(d,5,2) || '-' || substr(d,7,2)) AS INTEGER) AS w, d FROM params),
active AS (
    SELECT c.service_id FROM calendar c, dow
    WHERE dow.d BETWEEN c.start_date AND c.end_date
      AND CASE dow.w WHEN 0 THEN c.sunday WHEN 1 THEN c.monday WHEN 2 THEN c.tuesday WHEN 3 THEN c.wednesday
                     WHEN 4 THEN c.thursday WHEN 5 THEN c.friday ELSE c.saturday END = '1'
    UNION SELECT service_id FROM calendar_dates, params WHERE date = d AND exception_type = '1'
    EXCEPT SELECT service_id FROM calendar_dates, params WHERE date = d AND exception_type = '2'
),
peak AS (
    SELECT r.route_short_name AS route, COALESCE(t.direction_id, '0') AS dir, ts.start_sec,
           LAG(ts.start_sec) OVER (PARTITION BY r.route_id, COALESCE(t.direction_id, '0') ORDER BY ts.start_sec) AS prev_sec
    FROM trips t
    JOIN active a      ON a.service_id = t.service_id
    JOIN routes r      ON r.route_id = t.route_id
    JOIN trip_start ts ON ts.trip_id = t.trip_id
    WHERE ts.start_sec BETWEEN 7 * 3600 AND 9 * 3600
)
SELECT route, dir,
       COUNT(*) AS peak_trips,
       ROUND(AVG((start_sec - prev_sec) / 60.0), 0) AS avg_headway_min
FROM peak
GROUP BY route, dir
ORDER BY avg_headway_min IS NULL, avg_headway_min;


-- ---------------------------------------------------------------------
-- 2.3  Frequency bands: how many routes run every 15 min or better?
-- ---------------------------------------------------------------------
WITH params(d) AS (SELECT '20260119'),
dow AS (SELECT CAST(strftime('%w', substr(d,1,4) || '-' || substr(d,5,2) || '-' || substr(d,7,2)) AS INTEGER) AS w, d FROM params),
active AS (
    SELECT c.service_id FROM calendar c, dow
    WHERE dow.d BETWEEN c.start_date AND c.end_date
      AND CASE dow.w WHEN 0 THEN c.sunday WHEN 1 THEN c.monday WHEN 2 THEN c.tuesday WHEN 3 THEN c.wednesday
                     WHEN 4 THEN c.thursday WHEN 5 THEN c.friday ELSE c.saturday END = '1'
    UNION SELECT service_id FROM calendar_dates, params WHERE date = d AND exception_type = '1'
    EXCEPT SELECT service_id FROM calendar_dates, params WHERE date = d AND exception_type = '2'
),
peak AS (
    SELECT r.route_id, COALESCE(t.direction_id, '0') AS dir, ts.start_sec,
           LAG(ts.start_sec) OVER (PARTITION BY r.route_id, COALESCE(t.direction_id, '0') ORDER BY ts.start_sec) AS prev_sec
    FROM trips t
    JOIN active a      ON a.service_id = t.service_id
    JOIN routes r      ON r.route_id = t.route_id
    JOIN trip_start ts ON ts.trip_id = t.trip_id
    WHERE ts.start_sec BETWEEN 7 * 3600 AND 9 * 3600
),
route_hw AS (
    SELECT route_id, MIN(avg_hw) AS best_headway FROM (
        SELECT route_id, dir, AVG((start_sec - prev_sec) / 60.0) AS avg_hw FROM peak GROUP BY route_id, dir
    ) GROUP BY route_id
)
SELECT CASE WHEN best_headway IS NULL THEN '5 One trip or none in peak'
            WHEN best_headway <= 15 THEN '1 Every 15 min or better'
            WHEN best_headway <= 30 THEN '2 Every 16-30 min'
            WHEN best_headway <= 60 THEN '3 Every 31-60 min'
            ELSE '4 Less than hourly' END AS frequency_band,
       COUNT(*) AS routes
FROM route_hw
GROUP BY frequency_band
ORDER BY frequency_band;


-- ---------------------------------------------------------------------
-- 3.1  Busiest stops: scheduled departures and routes on the analysis date
-- ---------------------------------------------------------------------
WITH params(d) AS (SELECT '20260119'),
dow AS (SELECT CAST(strftime('%w', substr(d,1,4) || '-' || substr(d,5,2) || '-' || substr(d,7,2)) AS INTEGER) AS w, d FROM params),
active AS (
    SELECT c.service_id FROM calendar c, dow
    WHERE dow.d BETWEEN c.start_date AND c.end_date
      AND CASE dow.w WHEN 0 THEN c.sunday WHEN 1 THEN c.monday WHEN 2 THEN c.tuesday WHEN 3 THEN c.wednesday
                     WHEN 4 THEN c.thursday WHEN 5 THEN c.friday ELSE c.saturday END = '1'
    UNION SELECT service_id FROM calendar_dates, params WHERE date = d AND exception_type = '1'
    EXCEPT SELECT service_id FROM calendar_dates, params WHERE date = d AND exception_type = '2'
)
SELECT s.stop_id, s.stop_name,
       COUNT(*) AS departures,
       COUNT(DISTINCT t.route_id) AS routes
FROM st
JOIN trips t  ON t.trip_id = st.trip_id
JOIN active a ON a.service_id = t.service_id
JOIN stops s  ON s.stop_id = st.stop_id
GROUP BY s.stop_id
ORDER BY departures DESC
LIMIT 15;


-- ---------------------------------------------------------------------
-- 3.2  Low-service stops: fewer than 10 departures on the analysis date
--      (candidates for on-demand service or schedule review)
-- ---------------------------------------------------------------------
WITH params(d) AS (SELECT '20260119'),
dow AS (SELECT CAST(strftime('%w', substr(d,1,4) || '-' || substr(d,5,2) || '-' || substr(d,7,2)) AS INTEGER) AS w, d FROM params),
active AS (
    SELECT c.service_id FROM calendar c, dow
    WHERE dow.d BETWEEN c.start_date AND c.end_date
      AND CASE dow.w WHEN 0 THEN c.sunday WHEN 1 THEN c.monday WHEN 2 THEN c.tuesday WHEN 3 THEN c.wednesday
                     WHEN 4 THEN c.thursday WHEN 5 THEN c.friday ELSE c.saturday END = '1'
    UNION SELECT service_id FROM calendar_dates, params WHERE date = d AND exception_type = '1'
    EXCEPT SELECT service_id FROM calendar_dates, params WHERE date = d AND exception_type = '2'
),
stop_deps AS (
    SELECT st.stop_id, COUNT(*) AS departures
    FROM st
    JOIN trips t  ON t.trip_id = st.trip_id
    JOIN active a ON a.service_id = t.service_id
    GROUP BY st.stop_id
)
SELECT CASE WHEN departures < 10 THEN '1 Under 10'
            WHEN departures < 30 THEN '2 10-29'
            WHEN departures < 60 THEN '3 30-59'
            ELSE '4 60 or more' END AS departures_per_day,
       COUNT(*) AS stops
FROM stop_deps
GROUP BY departures_per_day
ORDER BY departures_per_day;


-- ---------------------------------------------------------------------
-- 3.3  Weekday vs Saturday vs Sunday: trips per route
--      Edit the three dates (a Monday, Saturday and Sunday in the feed).
-- ---------------------------------------------------------------------
WITH params(label, d) AS (VALUES ('Weekday', '20260119'), ('Saturday', '20260124'), ('Sunday', '20260125')),
dow AS (SELECT label, d, CAST(strftime('%w', substr(d,1,4) || '-' || substr(d,5,2) || '-' || substr(d,7,2)) AS INTEGER) AS w FROM params),
active AS (
    SELECT dow.label, c.service_id FROM calendar c, dow
    WHERE dow.d BETWEEN c.start_date AND c.end_date
      AND CASE dow.w WHEN 0 THEN c.sunday WHEN 1 THEN c.monday WHEN 2 THEN c.tuesday WHEN 3 THEN c.wednesday
                     WHEN 4 THEN c.thursday WHEN 5 THEN c.friday ELSE c.saturday END = '1'
    UNION SELECT p.label, cd.service_id FROM calendar_dates cd JOIN params p ON cd.date = p.d WHERE cd.exception_type = '1'
    EXCEPT SELECT p.label, cd.service_id FROM calendar_dates cd JOIN params p ON cd.date = p.d WHERE cd.exception_type = '2'
)
SELECT r.route_short_name AS route,
       SUM(a.label = 'Weekday')  AS weekday_trips,
       SUM(a.label = 'Saturday') AS saturday_trips,
       SUM(a.label = 'Sunday')   AS sunday_trips
FROM trips t
JOIN active a ON a.service_id = t.service_id
JOIN routes r ON r.route_id = t.route_id
GROUP BY r.route_id
ORDER BY weekday_trips DESC;
