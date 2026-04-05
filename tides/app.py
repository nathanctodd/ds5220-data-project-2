import io
import logging
import os
from datetime import datetime, timezone
from decimal import Decimal

import boto3
import matplotlib
import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import pandas as pd
import requests
from boto3.dynamodb.conditions import Key

matplotlib.use("Agg")

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

NOAA_API     = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
STATION_ID   = os.environ.get("STATION_ID", "8518750")   # The Battery, NY
STATION_NAME = os.environ.get("STATION_NAME", "The Battery, NY")
TABLE_NAME   = os.environ["DYNAMODB_TABLE"]
S3_BUCKET    = os.environ["S3_BUCKET"]
AWS_REGION   = "us-east-1"


# ---------------------------------------------------------------------------
# Step 1 — Fetch latest water level from NOAA Tides & Currents
# ---------------------------------------------------------------------------
def fetch_tide() -> dict:
    params = {
        "station":   STATION_ID,
        "product":   "water_level",
        "datum":     "MLLW",
        "time_zone": "gmt",
        "units":     "metric",
        "format":    "json",
        "date":      "latest",
    }
    resp = requests.get(NOAA_API, params=params, timeout=15)
    resp.raise_for_status()
    data = resp.json()

    if "error" in data:
        raise RuntimeError(f"NOAA API error: {data['error']['message']}")

    reading = data["data"][0]
    return {
        "station_id":    STATION_ID,
        "timestamp":     datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "water_level_m": Decimal(str(round(float(reading["v"]), 3))),
        "sigma":         Decimal(str(round(float(reading["s"]), 3))),
        "quality":       reading.get("q", "unknown"),
        "station_name":  STATION_NAME,
    }


# ---------------------------------------------------------------------------
# Step 2 — Query DynamoDB for the most recent previous entry
# ---------------------------------------------------------------------------
def get_previous(table) -> dict | None:
    resp = table.query(
        KeyConditionExpression=Key("station_id").eq(STATION_ID),
        ScanIndexForward=False,
        Limit=1,
    )
    items = resp.get("Items", [])
    return items[0] if items else None


# ---------------------------------------------------------------------------
# Step 3 — Classify the tide direction
# ---------------------------------------------------------------------------
def tide_trend(current_m: Decimal, previous: dict | None) -> tuple[str, Decimal]:
    """Return (trend, delta_m).

    RISING  — level climbed more than 5 cm since last reading
    FALLING — level dropped more than 5 cm since last reading
    SLACK   — near the high or low turning point (< 5 cm change)
    """
    if previous is None:
        return "FIRST_ENTRY", Decimal("0")

    delta = current_m - Decimal(str(previous["water_level_m"]))

    if delta > Decimal("0.05"):
        trend = "RISING"
    elif delta < Decimal("-0.05"):
        trend = "FALLING"
    else:
        trend = "SLACK"

    return trend, delta


# ---------------------------------------------------------------------------
# Step 4 — Publish data.csv and plot.png to S3
# ---------------------------------------------------------------------------
def get_all_records(table) -> list:
    resp = table.query(
        KeyConditionExpression=Key("station_id").eq(STATION_ID),
        ScanIndexForward=True,
    )
    return resp.get("Items", [])


def publish_to_s3(s3_client, items: list) -> None:
    rows = [
        {
            "timestamp":     item["timestamp"],
            "water_level_m": float(item["water_level_m"]),
            "delta_m":       float(item.get("delta_m", 0)),
            "trend":         item.get("trend", ""),
            "station_id":    item["station_id"],
            "station_name":  item.get("station_name", STATION_NAME),
        }
        for item in items
    ]

    df = pd.DataFrame(rows)
    df["timestamp"] = pd.to_datetime(df["timestamp"])
    df = df.sort_values("timestamp")

    # ── data.csv ──────────────────────────────────────────────────────────
    s3_client.put_object(
        Bucket=S3_BUCKET,
        Key="data.csv",
        Body=df.to_csv(index=False).encode(),
        ContentType="text/csv",
    )

    # ── plot.png ──────────────────────────────────────────────────────────
    fig, ax = plt.subplots(figsize=(13, 5))

    ax.plot(df["timestamp"], df["water_level_m"],
            linewidth=1.5, color="#1565C0", label="Water level")
    ax.fill_between(df["timestamp"], df["water_level_m"],
                    alpha=0.15, color="#1565C0")

    ax.set_title(f"Tidal Water Level — {STATION_NAME}  (Station {STATION_ID})",
                 fontsize=13, pad=10)
    ax.set_xlabel("Time (UTC)")
    ax.set_ylabel("Water Level (m, MLLW)")
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%m/%d\n%H:%M"))
    ax.xaxis.set_major_locator(mdates.AutoDateLocator())
    ax.grid(True, alpha=0.3)

    n = len(df)
    ax.annotate(
        f"{n} readings  •  latest: {df['water_level_m'].iloc[-1]:.3f} m",
        xy=(0.01, 0.97), xycoords="axes fraction",
        va="top", fontsize=9, color="#555555",
    )

    plt.tight_layout()

    buf = io.BytesIO()
    plt.savefig(buf, format="png", dpi=150)
    buf.seek(0)
    plt.close()

    s3_client.put_object(
        Bucket=S3_BUCKET,
        Key="plot.png",
        Body=buf.read(),
        ContentType="image/png",
    )

    log.info("Published data.csv (%d rows) and plot.png to s3://%s", n, S3_BUCKET)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main():
    dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
    s3       = boto3.client("s3", region_name=AWS_REGION)
    table    = dynamodb.Table(TABLE_NAME)

    previous     = get_previous(table)
    entry        = fetch_tide()
    trend, delta = tide_trend(entry["water_level_m"], previous)

    entry["trend"]   = trend
    entry["delta_m"] = delta

    table.put_item(Item=entry)

    if trend == "FIRST_ENTRY":
        log.info("TIDE | station=%s | level=%.3f m | FIRST ENTRY",
                 STATION_ID, entry["water_level_m"])
    else:
        log.info("TIDE | station=%s | level=%.3f m | delta=%+.3f m | %s",
                 STATION_ID, entry["water_level_m"], delta, trend)

    publish_to_s3(s3, get_all_records(table))


if __name__ == "__main__":
    main()
