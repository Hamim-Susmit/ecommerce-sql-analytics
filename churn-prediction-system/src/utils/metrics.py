from __future__ import annotations

from typing import Dict

import numpy as np
from sklearn.metrics import (
    average_precision_score,
    brier_score_loss,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)


def classification_metrics(y_true: np.ndarray, y_prob: np.ndarray, threshold: float) -> Dict[str, float]:
    y_pred = (y_prob >= threshold).astype(int)
    return {
        "roc_auc": float(roc_auc_score(y_true, y_prob)),
        "pr_auc": float(average_precision_score(y_true, y_prob)),
        "f1": float(f1_score(y_true, y_pred)),
        "precision": float(precision_score(y_true, y_pred, zero_division=0)),
        "recall": float(recall_score(y_true, y_pred, zero_division=0)),
        "brier": float(brier_score_loss(y_true, y_prob)),
    }


def confusion_at_threshold(y_true: np.ndarray, y_prob: np.ndarray, threshold: float) -> Dict[str, int]:
    y_pred = (y_prob >= threshold).astype(int)
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
    return {"tn": int(tn), "fp": int(fp), "fn": int(fn), "tp": int(tp)}


def top_k_recall(y_true: np.ndarray, y_prob: np.ndarray, top_k: float = 0.1) -> float:
    if not 0 < top_k <= 1:
        raise ValueError("top_k must be in (0, 1].")
    k = max(1, int(len(y_prob) * top_k))
    top_indices = np.argsort(y_prob)[-k:]
    return float(y_true[top_indices].sum() / max(1, y_true.sum()))
