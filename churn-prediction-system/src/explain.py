from __future__ import annotations

import argparse
from pathlib import Path
from typing import Dict

import joblib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.inspection import permutation_importance

from src.config import CONFIG, PATHS
from src.features import split_features
from src.utils.io import ensure_dir, load_csv
from src.utils.logging import setup_logging


logger = setup_logging(name="explain")


def _shap_available() -> bool:
    try:
        import shap  # noqa: F401
    except ImportError:
        return False
    return True


def _plot_shap_summary(model, X: pd.DataFrame, output_path: Path) -> str:
    import shap

    explainer = shap.Explainer(model, X)
    shap_values = explainer(X)
    plt.figure()
    shap.summary_plot(shap_values, X, show=False)
    plt.savefig(output_path, bbox_inches="tight")
    plt.close()
    return str(output_path)


def _plot_permutation_importance(model, X: pd.DataFrame, y: pd.Series, output_path: Path) -> str:
    result = permutation_importance(model, X, y, n_repeats=10, random_state=CONFIG.random_seed)
    indices = np.argsort(result.importances_mean)[-15:]
    plt.figure()
    plt.barh(np.array(X.columns)[indices], result.importances_mean[indices])
    plt.title("Permutation Importance (Top 15)")
    plt.xlabel("Importance")
    plt.tight_layout()
    plt.savefig(output_path, bbox_inches="tight")
    plt.close()
    return str(output_path)


def explain(processed_path: Path, model_path: Path, output_dir: Path) -> Dict[str, str]:
    df = load_csv(processed_path)
    X, y = split_features(df)
    model = joblib.load(model_path)

    ensure_dir(output_dir)
    outputs: Dict[str, str] = {}

    if _shap_available():
        output_path = output_dir / "shap_summary.png"
        outputs["shap_summary"] = _plot_shap_summary(model, X, output_path)
    else:
        output_path = output_dir / "permutation_importance.png"
        outputs["permutation_importance"] = _plot_permutation_importance(model, X, y, output_path)

    logger.info("Explainability outputs: %s", outputs)
    return outputs


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Explain churn model")
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
        "--output-dir",
        type=Path,
        default=PATHS.figures_dir,
        help="Directory for explainability outputs",
    )
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    explain(args.processed_path, args.model_path, args.output_dir)


if __name__ == "__main__":
    main()
