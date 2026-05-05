APP NAME: DBU Spend Monitor

Objective:
Visualize DBU usage over time and by cluster.

Data:
- system.billing.usage

Metrics:
- total DBUs per day
- total DBUs per cluster

Transformations:
- group by usage_date -> sum(dbus)
- group by cluster_id -> sum(dbus)

UI:
- Line chart (DBUs over time)
- Bar chart (DBUs by cluster)

Filters:
- Date range

Constraints:
- Use Plotly for charts
- Convert to pandas only in UI layer
- No SQL outside data access module
