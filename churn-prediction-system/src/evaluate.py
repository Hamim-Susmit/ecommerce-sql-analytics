from __future__ import annotations

import argparse
from pathlib import Path
from typing import Dict

import joblib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.calibration import calibration_curve
from sklearn.metrics import ConfusionMatrixDisplay
from sklearn.model_selection import train_test_split

from src.config import CONFIG, PATHS
from src.features import split_features
from src.utils.io import ensure_dir, load_csv, load_json
from src.utils.logging import setup_logging
from src.utils.metrics import classification_metrics, confusion_at_threshold, top_k_recall


logger = setup_logging(name="evaluate")


def _plot_roc_pr(y_true: np.ndarray, y_prob: np.ndarray, figures_dir: Path) -> Dict[str, str]:
    from sklearn.metrics import PrecisionRecallDisplay, RocCurveDisplay

    ensure_dir(figures_dir)

    roc_path = figures_dir / "roc_curve.png"
    pr_path = figures_dir / "pr_curve.png"

    RocCurveDisplay.from_predictions(y_true, y_prob)
    plt.title("ROC Curve")
    plt.savefig(roc_path, bbox_inches="tight")
    plt.close()

    PrecisionRecallDisplay.from_predictions(y_true, y_prob)
    plt.title("Precision-Recall Curve")
    plt.savefig(pr_path, bbox_inches="tight")
    plt.close()

    return {"roc_curve": str(roc_path), "pr_curve": str(pr_path)}


def _plot_calibration(y_true: np.ndarray, y_prob: np.ndarray, figures_dir: Path) -> str:
    ensure_dir(figures_dir)
    prob_true, prob_pred = calibration_curve(y_true, y_prob, n_bins=10)
    plt.figure()
    plt.plot(prob_pred, prob_true, marker="o")
    plt.plot([0, 1], [0, 1], linestyle="--", color="gray")
    plt.title("Calibration Curve")
    plt.xlabel("Predicted")
    plt.ylabel("Observed")
    path = figures_dir / "calibration_curve.png"
    plt.savefig(path, bbox_inches="tight")
    plt.close()
    return str(path)


def _plot_confusion(y_true: np.ndarray, y_prob: np.ndarray, threshold: float, figures_dir: Path) -> str:
    ensure_dir(figures_dir)
    y_pred = (y_prob >= threshold).astype(int)
    disp = ConfusionMatrixDisplay.from_predictions(y_true, y_pred)
    disp.ax_.set_title("Confusion Matrix")
    path = figures_dir / "confusion_matrix.png"
    plt.savefig(path, bbox_inches="tight")
    plt.close()
    return str(path)


def evaluate(processed_path: Path, model_path: Path, metadata_path: Path, report_path: Path) -> None:
    df = load_csv(processed_path)
    X, y = split_features(df)
    _, X_val, _, y_val = train_test_split(
        X,
        y,
        train_size=CONFIG.train_size,
        stratify=y,
        random_state=CONFIG.random_seed,
    )
    model = joblib.load(model_path)
    metadata = load_json(metadata_path)
    threshold = float(metadata.get("threshold", 0.5))

    y_prob = model.predict_proba(X_val)[:, 1]
    metrics = classification_metrics(y_val.to_numpy(), y_prob, threshold=threshold)
    confusion = confusion_at_threshold(y_val.to_numpy(), y_prob, threshold)
    topk = top_k_recall(y_val.to_numpy(), y_prob)

    figs = {}
    figs.update(_plot_roc_pr(y_val.to_numpy(), y_prob, PATHS.figures_dir))
    figs["calibration"] = _plot_calibration(y_val.to_numpy(), y_prob, PATHS.figures_dir)
    figs["confusion_matrix"] = _plot_confusion(y_val.to_numpy(), y_prob, threshold, PATHS.figures_dir)

    report_lines = [
        "# Evaluation Summary",
        f"Model: {metadata.get('model_name', 'unknown')}",
        f"Threshold: {threshold:.3f}",
        "\n## Metrics",
        pd.DataFrame([metrics]).to_markdown(index=False),
        "\n## Confusion Matrix",
        pd.DataFrame([confusion]).to_markdown(index=False),
        f"\nTop-10% Recall: {topk:.3f}",
        "\n## Figures",
    ]
    report_lines.extend([f"- {key}: {value}" for key, value in figs.items()])

    ensure_dir(report_path.parent)
    report_path.write_text("\n".join(report_lines))
    logger.info("Saved evaluation report to %s", report_path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Evaluate churn model")
    parser.add_argument(
        "--processed-path",
        type=Path,
        default=PATHS.data_processed / CONFIG.processed_filename,
        help="Path to processed CSV",
    )
    parser.add_argument(
        "--model-path",
        type=Path,
        default=PATHS.models_dir / "model.joblib",
        help="Path to model",
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
        default=PATHS.reports_dir / "evaluation_summary.md",
        help="Path to evaluation report",
    )
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    evaluate(args.processed_path, args.model_path, args.metadata_path, args.report_path)


if __name__ == "__main__":
    main()
