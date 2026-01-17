from __future__ import annotations

import argparse
from pathlib import Path
from typing import Dict

import numpy as np
import pandas as pd

from src.config import CONFIG, PATHS
from src.features import split_features
from src.utils.io import ensure_dir, load_csv, load_json
from src.utils.logging import setup_logging


logger = setup_logging(name="monitor")


def _psi(expected: np.ndarray, actual: np.ndarray, bins: int = 10) -> float:
    expected = expected[~np.isnan(expected)]
    actual = actual[~np.isnan(actual)]
    if len(expected) == 0 or len(actual) == 0:
        return 0.0
    quantiles = np.linspace(0, 1, bins + 1)
    breakpoints = np.unique(np.quantile(expected, quantiles))
    if len(breakpoints) < 3:
        return 0.0
    expected_counts, _ = np.histogram(expected, bins=breakpoints)
    actual_counts, _ = np.histogram(actual, bins=breakpoints)
    expected_perc = expected_counts / max(1, expected_counts.sum())
    actual_perc = actual_counts / max(1, actual_counts.sum())
    expected_perc = np.where(expected_perc == 0, 1e-6, expected_perc)
    actual_perc = np.where(actual_perc == 0, 1e-6, actual_perc)
    return float(np.sum((actual_perc - expected_perc) * np.log(actual_perc / expected_perc)))


def _categorical_shift(expected: pd.Series, actual: pd.Series) -> float:
    expected_dist = expected.value_counts(normalize=True)
    actual_dist = actual.value_counts(normalize=True)
    aligned = expected_dist.index.union(actual_dist.index)
    expected_dist = expected_dist.reindex(aligned, fill_value=0)
    actual_dist = actual_dist.reindex(aligned, fill_value=0)
    return float(np.abs(expected_dist - actual_dist).sum())


def monitor(new_data_path: Path, metadata_path: Path, report_path: Path) -> None:
    new_df = load_csv(new_data_path)
    metadata = load_json(metadata_path)

    reference_stats = metadata.get("reference_stats")
    if reference_stats is None:
        raise ValueError("Reference stats not found in metadata.json. Train the model first.")

    new_df = new_df.copy()
    if CONFIG.label_column in new_df.columns:
        new_df = new_df.drop(columns=[CONFIG.label_column])

    drift_metrics: Dict[str, float] = {}
    for col, stats in reference_stats.items():
        if col not in new_df.columns:
            continue
        if stats.get("type") == "numeric":
            drift_metrics[col] = _psi(np.array(stats["values"]), new_df[col].to_numpy())
        else:
            drift_metrics[col] = _categorical_shift(pd.Series(stats["values"]), new_df[col])

    report_lines = ["# Drift Report", f"Reference rows: {metadata.get('training_rows')}"]
    report_lines.append(pd.DataFrame([drift_metrics]).to_markdown(index=False))

    ensure_dir(report_path.parent)
    report_path.write_text("\n".join(report_lines))
    logger.info("Saved drift report to %s", report_path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Monitor data drift")
    parser.add_argument(
        "--new-data-path",
        type=Path,
        default=PATHS.data_processed / CONFIG.processed_filename,
        help="Path to new batch CSV",
    )
    parser.add_argument(
        "--metadata-path",
        type=Path,
        default=PATHS.models_dir / "metadata.json",
        help="Path to metadata",
    )
    parser.add_argument(
        "--report-path",
        type=Path,
        default=PATHS.reports_dir / "drift_report.md",
        help="Path to drift report",
    )
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    monitor(args.new_data_path, args.metadata_path, args.report_path)


if __name__ == "__main__":
    main()
