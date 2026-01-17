from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict

import joblib
import pandas as pd
import streamlit as st

from src.config import CONFIG, PATHS
from src.utils.io import load_json


@st.cache_resource
def load_model() -> Any:
    return joblib.load(PATHS.models_dir / "model.joblib")


@st.cache_resource
def load_metadata() -> Dict[str, Any]:
    return load_json(PATHS.models_dir / "metadata.json")


def _prepare_input(df: pd.DataFrame) -> pd.DataFrame:
    if CONFIG.label_column in df.columns:
        df = df.drop(columns=[CONFIG.label_column])
    return df


def main() -> None:
    st.title("Churn Prediction")
    st.write("Upload a CSV or input a single customer to get churn risk.")

    model = load_model()
    metadata = load_metadata()
    threshold = float(metadata.get("threshold", 0.5))

    tabs = st.tabs(["Batch Scoring", "Single Customer"])

    with tabs[0]:
        uploaded = st.file_uploader("Upload CSV", type=["csv"])
        if uploaded:
            df = pd.read_csv(uploaded)
            input_df = _prepare_input(df)
            probs = model.predict_proba(input_df)[:, 1]
            predictions = (probs >= threshold).astype(int)
            results = input_df.copy()
            results["churn_probability"] = probs
            results["churn_prediction"] = predictions
            st.dataframe(results.head(50))
            st.download_button("Download predictions", results.to_csv(index=False), "predictions.csv")

    with tabs[1]:
        st.write("Enter customer attributes:")
        sample_cols = metadata.get("reference_stats", {}).keys()
        form_data: Dict[str, Any] = {}
        for col in sample_cols:
            stats = metadata["reference_stats"].get(col, {})
            if stats.get("type") == "numeric":
                form_data[col] = st.number_input(col, value=0.0)
            else:
                options = list(dict.fromkeys(stats.get("values", [])))
                form_data[col] = st.selectbox(col, options or ["Unknown"])

        if st.button("Score customer"):
            input_df = pd.DataFrame([form_data])
            prob = model.predict_proba(input_df)[0, 1]
            prediction = int(prob >= threshold)
            st.metric("Churn probability", f"{prob:.2%}")
            st.metric("Predicted class", "Churn" if prediction == 1 else "No churn")
            action = "Offer retention discount" if prediction == 1 else "No action"
            st.write(f"Suggested action: **{action}**")


if __name__ == "__main__":
    main()
