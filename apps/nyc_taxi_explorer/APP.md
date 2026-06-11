APP NAME: NYC Taxi Explorer

Objective:
Explore NYC yellow taxi trip patterns using a polished dark-themed dashboard.
Zero setup required — reads from the built-in `samples` catalog available in every
Databricks workspace with Unity Catalog enabled. Use this app to verify the factory
is wired up correctly before building apps on your own data.

Data:
- samples.nyctaxi.trips

Schema notes:
- tpep_pickup_datetime (timestamp): trip start time — use for time-series and hour-of-day breakdowns
- tpep_dropoff_datetime (timestamp): trip end time
- trip_distance (double): miles traveled
- fare_amount (double): metered fare in USD
- tip_amount (double): tip in USD (credit card only; cash tips are not recorded)
- total_amount (double): total charged including taxes and fees
- passenger_count (long): number of passengers (1–6, exclude 0 and nulls)
- payment_type (long): 1=Credit card, 2=Cash, 3=No charge, 4=Dispute — filter to 1 and 2 only for fare analysis
- RatecodeID (long): 1=Standard, 2=JFK, 3=Newark — use for rate breakdown

KPIs / Metrics:
- Total trips: COUNT(*) after base filter
- Average fare: AVG(fare_amount) after base filter
- Average trip distance (mi): AVG(trip_distance) after base filter
- Average tip %: AVG(tip_amount / NULLIF(fare_amount, 0)) * 100 — only where payment_type = 1

Transformations:
- Base filter: WHERE fare_amount > 0 AND trip_distance > 0 AND passenger_count > 0 AND tpep_pickup_datetime >= '2016-01-01' AND tpep_pickup_datetime < '2016-02-01'
- Trips by day: group by DATE(tpep_pickup_datetime) → COUNT(*) as trip_count, order by date ASC
- Trips by hour: group by HOUR(tpep_pickup_datetime) → COUNT(*) as trip_count, AVG(fare_amount) as avg_fare, order by hour ASC
- Trips by payment type: group by payment_type (filter to 1 and 2) → COUNT(*) as trip_count, label as "Credit Card" / "Cash"
- Fare distribution: use trip_distance as x-axis, fare_amount as y-axis, sample 2,000 rows (LIMIT 2000, ORDER BY RAND())

UI Components:
- Row of 4 KPI cards: Total Trips | Avg Fare ($) | Avg Distance (mi) | Avg Tip %
- Line chart: trip_count over DATE(tpep_pickup_datetime) — title "Daily Trip Volume", filled area
- Bar chart: trip_count by HOUR(tpep_pickup_datetime) with a second y-axis line for avg_fare — title "Trips & Avg Fare by Hour of Day"
- Pie-style treemap: trip_count by payment_type label — title "Payment Type Split" (treemap, not pie)
- Scatter plot: trip_distance (x) vs fare_amount (y), 2,000-row sample — title "Distance vs Fare", opacity 0.4, color #00bcd4

Filters:
- None (date range is hardcoded in base filter to keep setup frictionless)

Design:
- Background: #0d1117
- Color scheme: teals and purples (primary #00bcd4, accent #7c4dff)
- Plotly template: plotly_dark
- KPI cards: large bold number, colored accent, subtitle describing the metric
- Chart titles bold, axis labels minimal
- Scatter plot points small (size=3), semi-transparent to show density
- App title: "NYC Taxi Explorer" with subtitle "samples.nyctaxi.trips · January 2016"

Constraints:
- Do NOT filter by pickup/dropoff borough or zone — those columns are not in this dataset
- The samples catalog is read-only; no writes, no caching tables
- None beyond GLOBAL_RULES
