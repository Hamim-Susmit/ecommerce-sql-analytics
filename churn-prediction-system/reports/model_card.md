# Model Card - Churn Prediction

## Intended Use
This model predicts the likelihood of customer churn for retention targeting. It is intended for internal analytics support and decision-making.

## Data
- Source: Telco-style customer churn dataset (CSV format).
- Label: `Churn` (Yes/No or 0/1).
- Preprocessing: Missing value imputation, scaling for numeric features, one-hot encoding for categorical features.

## Metrics
Evaluation metrics include ROC-AUC, PR-AUC, F1, precision, recall, Brier score, and top-10% recall. See `reports/evaluation_summary.md` for latest results.

## Limitations
- Performance may degrade on populations that differ from the training data.
- The model does not incorporate causal inference; it estimates correlation-based risk.

## Fairness Notes
No protected attributes are explicitly modeled. If such attributes exist in the data, fairness analysis should be conducted separately.

## Monitoring Plan
Use `src/monitor.py` to compute drift metrics (PSI and categorical distribution shift) and review the drift report regularly.
