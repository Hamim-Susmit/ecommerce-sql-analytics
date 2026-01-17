from __future__ import annotations

import argparse
from pathlib import Path
from typing import Dict, List

import pandas as pd

from src.config import CONFIG, PATHS
from src.utils.io import ensure_dir, load_csv
from src.utils.logging import setup_logging


logger = setup_logging(name="validate")


def validate_schema(df: pd.DataFrame, required_columns: List[str]) -> Dict[str, str]:
    issues: Dict[str, str] = {}
    missing = [col for col in required_columns if col not in df.columns]
    if missing:
        issues["missing_columns"] = f"Missing required columns: {missing}"
    if CONFIG.label_column not in df.columns:
        issues["missing_label"] = f"Missing label column: {CONFIG.label_column}"
    return issues


def validate_missingness(df: pd.DataFrame, threshold: float = 0.3) -> Dict[str, float]:
    missing = df.isna().mean()
    return missing[missing > threshold].to_dict()


def data_report(df: pd.DataFrame) -> str:
    report = [
        "## Data Report",
        f"Rows: {len(df)}",
        f"Columns: {len(df.columns)}",
        "\n### Missingness (top 5)",
        df.isna().mean().sort_values(ascending=False).head(5).to_markdown(),
    ]
    return "\n".join(report)


def validate_file(path: Path, report_path: Path) -> None:
    df = load_csv(path)
    required_columns = [CONFIG.label_column]
    issues = validate_schema(df, required_columns)
    if len(df.columns) < 2:
        issues["feature_columns"] = "Dataset must include at least one feature column."
    missing_warnings = validate_missingness(df)
    report = data_report(df)

    if issues:
        for key, value in issues.items():
            logger.error("Validation issue [%s]: %s", key, value)
        raise ValueError("Schema validation failed")

    if missing_warnings:
        logger.warning("High missingness detected: %s", missing_warnings)
    logger.info("Validation passed for %s", path)
    logger.info("\n%s", report)
    ensure_dir(report_path.parent)
    report_path.write_text(report)
    logger.info("Saved data report to %s", report_path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Validate churn dataset")
    parser.add_argument(
        "--processed-path",
        type=Path,
        default=PATHS.data_processed / CONFIG.processed_filename,
        help="Path to processed CSV",
    )
    parser.add_argument(
        "--report-path",
        type=Path,
        default=PATHS.reports_dir / "evaluation_summary.md",
        help="Path to data report",
    )
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    validate_file(args.processed_path, args.report_path)


if __name__ == "__main__":
    main()
