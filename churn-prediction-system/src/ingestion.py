from __future__ import annotations

import argparse
from pathlib import Path
from typing import Tuple

import numpy as np
import pandas as pd

from src.config import CONFIG, PATHS
from src.utils.io import ensure_dir, load_csv, save_csv
from src.utils.logging import setup_logging


logger = setup_logging(name="ingestion")


def _standardize_columns(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df.columns = [col.strip().replace(" ", "_") for col in df.columns]
    return df


def _generate_synthetic_data(path: Path, rows: int = 5000) -> pd.DataFrame:
    logger.warning("Raw data not found. Generating synthetic dataset at %s", path)
    rng = np.random.default_rng(CONFIG.random_seed)
    df = pd.DataFrame(
        {
            "customer_id": [f"C{idx:05d}" for idx in range(rows)],
            "tenure": rng.integers(0, 72, size=rows),
            "monthly_charges": rng.normal(70, 30, size=rows).clip(15, 150),
            "total_charges": rng.normal(2000, 1500, size=rows).clip(0, 10000),
            "contract": rng.choice(["Month-to-month", "One year", "Two year"], size=rows),
            "internet_service": rng.choice(["DSL", "Fiber optic", "No"], size=rows),
            "payment_method": rng.choice(
                ["Electronic check", "Mailed check", "Bank transfer", "Credit card"], size=rows
            ),
            "senior_citizen": rng.choice([0, 1], size=rows, p=[0.84, 0.16]),
        }
    )
    churn_propensity = (
        0.2
        + 0.3 * (df["contract"] == "Month-to-month").astype(float)
        + 0.2 * (df["internet_service"] == "Fiber optic").astype(float)
        + 0.2 * (df["tenure"] < 12).astype(float)
    )
    df[CONFIG.label_column] = rng.binomial(1, churn_propensity.clip(0, 0.9))
    ensure_dir(path.parent)
    df.to_csv(path, index=False)
    return df


def ingest(raw_path: Path, processed_path: Path) -> Tuple[pd.DataFrame, pd.DataFrame]:
    if raw_path.exists():
        df_raw = load_csv(raw_path)
    else:
        df_raw = _generate_synthetic_data(raw_path)
    df_raw = _standardize_columns(df_raw)
    df_processed = df_raw.copy()
    save_csv(df_processed, processed_path)
    try:
        parquet_path = processed_path.with_suffix(".parquet")
        df_processed.to_parquet(parquet_path, index=False)
        logger.info("Saved processed data to %s", parquet_path)
    except Exception as exc:  # noqa: BLE001 - optional parquet dependency
        logger.warning("Parquet save skipped: %s", exc)
    logger.info("Saved processed data to %s", processed_path)
    return df_raw, df_processed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Ingest churn dataset")
    parser.add_argument(
        "--raw-path",
        type=Path,
        default=PATHS.data_raw / CONFIG.raw_filename,
        help="Path to raw CSV",
    )
    parser.add_argument(
        "--processed-path",
        type=Path,
        default=PATHS.data_processed / CONFIG.processed_filename,
        help="Path to processed CSV",
    )
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    ingest(args.raw_path, args.processed_path)


if __name__ == "__main__":
    main()
