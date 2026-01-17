from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, Tuple

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.base import clone

from src.config import CONFIG, PATHS
from src.features import build_preprocess_pipeline, split_features
from src.utils.io import ensure_dir, load_csv, save_json
from src.utils.logging import setup_logging
from src.utils.metrics import classification_metrics


logger = setup_logging(name="train")


def _expected_value(y_true: np.ndarray, y_prob: np.ndarray, threshold: float) -> float:
    churn_loss = CONFIG.churn_loss
    retention_cost = CONFIG.retention_offer_cost
    y_pred = (y_prob >= threshold).astype(int)
    tp = ((y_pred == 1) & (y_true == 1)).sum()
    fp = ((y_pred == 1) & (y_true == 0)).sum()
    value = tp * (churn_loss - retention_cost) - fp * retention_cost
    return float(value)


def _find_best_threshold(y_true: np.ndarray, y_prob: np.ndarray) -> Tuple[float, float]:
    thresholds = np.linspace(0.1, 0.9, 81)
    scores = [(_expected_value(y_true, y_prob, thr), thr) for thr in thresholds]
    best_value, best_thr = max(scores, key=lambda item: item[0])
    return best_thr, best_value


def _train_models(X_train: pd.DataFrame, y_train: pd.Series) -> Dict[str, Pipeline]:
    preprocessor, _ = build_preprocess_pipeline(X_train)
    models: Dict[str, Pipeline] = {}

    models["logistic_regression"] = Pipeline(
        steps=[
            ("preprocess", clone(preprocessor)),
            (
                "model",
                LogisticRegression(max_iter=1000, class_weight="balanced", random_state=CONFIG.random_seed),
            ),
        ]
    )

    models["gradient_boosting"] = Pipeline(
        steps=[
            ("preprocess", clone(preprocessor)),
            (
                "model",
                GradientBoostingClassifier(random_state=CONFIG.random_seed),
            ),
        ]
    )
    for name, pipeline in models.items():
        logger.info("Training %s", name)
        pipeline.fit(X_train, y_train)
    return models


def train(processed_path: Path, model_path: Path, metadata_path: Path) -> Dict[str, str]:
    df = load_csv(processed_path)
    X, y = split_features(df)
    X_train, X_val, y_train, y_val = train_test_split(
        X,
        y,
        train_size=CONFIG.train_size,
        stratify=y,
        random_state=CONFIG.random_seed,
    )

    models = _train_models(X_train, y_train)
    results: Dict[str, float] = {}
    for name, pipeline in models.items():
        y_prob = pipeline.predict_proba(X_val)[:, 1]
        metrics = classification_metrics(y_val.to_numpy(), y_prob, threshold=0.5)
        results[name] = metrics["roc_auc"]
        logger.info("%s validation ROC-AUC: %.4f", name, metrics["roc_auc"])

    best_model_name = max(results, key=results.get)
    best_model = models[best_model_name]
    y_prob = best_model.predict_proba(X_val)[:, 1]
    threshold, expected_value = _find_best_threshold(y_val.to_numpy(), y_prob)
    metrics = classification_metrics(y_val.to_numpy(), y_prob, threshold=threshold)

    ensure_dir(model_path.parent)
    joblib.dump(best_model, model_path)

    metadata = {
        "model_name": best_model_name,
        "trained_at": datetime.utcnow().isoformat(),
        "metrics": metrics,
        "threshold": threshold,
        "expected_value": expected_value,
        "label_column": CONFIG.label_column,
        "feature_count": X.shape[1],
        "training_rows": int(len(X_train)),
        "validation_rows": int(len(X_val)),
        "random_seed": CONFIG.random_seed,
        "costs": {"churn_loss": CONFIG.churn_loss, "retention_offer_cost": CONFIG.retention_offer_cost},
    }
    reference_stats = {}
    for col in X_train.columns:
        if X_train[col].dtype.kind in {"i", "u", "f"}:
            reference_stats[col] = {"type": "numeric", "values": X_train[col].dropna().tolist()}
        else:
            reference_stats[col] = {"type": "categorical", "values": X_train[col].dropna().tolist()}
    metadata["reference_stats"] = reference_stats
    save_json(metadata, metadata_path)
    logger.info("Saved model to %s", model_path)
    logger.info("Saved metadata to %s", metadata_path)
    return {"model_path": str(model_path), "metadata_path": str(metadata_path)}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Train churn model")
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
        help="Path to save model",
    )
    parser.add_argument(
        "--metadata-path",
        type=Path,
        default=PATHS.models_dir / "metadata.json",
        help="Path to save metadata",
    )
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    train(args.processed_path, args.model_path, args.metadata_path)


if __name__ == "__main__":
    main()
