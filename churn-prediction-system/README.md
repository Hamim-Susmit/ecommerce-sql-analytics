# Churn Prediction System

## Overview
This repository provides a complete, production-ready churn prediction system that covers data ingestion, validation, feature engineering, model training, evaluation, explainability, monitoring, and a Streamlit app for inference. The pipeline is designed to run locally on CPU with open-source tooling.

## Architecture
```
churn-prediction-system/
├── data/                # Raw and processed data
├── notebooks/           # EDA notebooks (optional)
├── src/                 # Core pipeline modules
├── app/                 # Streamlit app
├── models/              # Trained model + metadata
├── reports/             # Evaluation artifacts and model card
├── tests/               # Pytest unit tests
```

## Getting Started
### 1) Setup
```bash
make setup
```

### 2) Ingest + Validate
```bash
make ingest
make validate
```
If `data/raw/telco_churn.csv` is missing, ingestion will generate a synthetic dataset that mirrors Telco-style churn columns.

### 3) Train
```bash
make train
```
Trains a baseline Logistic Regression and a stronger Gradient Boosting model, then selects the best model by ROC-AUC. The training pipeline picks a business-aware threshold using a cost-based framework.

### 4) Evaluate
```bash
make evaluate
```
Generates metrics (ROC-AUC, PR-AUC, F1, precision, recall, Brier score, top-10% recall), confusion matrix, and plots in `reports/`.

### 5) Explain
```bash
make explain
```
Uses SHAP if installed; otherwise falls back to permutation importance. Plots are stored in `reports/figures/`.

### 6) Monitor Drift
```bash
make monitor
```
Compares new data against training reference statistics and writes a drift report to `reports/drift_report.md`.

### 7) Run the App
```bash
make app
```
Provides batch and single-customer scoring with suggested retention actions.

## CLI Reference
- `python -m src.ingestion`
- `python -m src.validate`
- `python -m src.train`
- `python -m src.evaluate`
- `python -m src.explain`
- `python -m src.monitor`

## What “Production-Ready” Means Here
- Modular pipeline with typed functions and logging.
- Reproducible training via seeded splits.
- Automatic data handling (synthetic data if missing).
- Model metadata for traceability, thresholding, and monitoring.
- Tests for critical validation and training artifacts.

## Notes
- Optional dependency: `shap` for richer explainability. Install with `pip install shap` if desired.
