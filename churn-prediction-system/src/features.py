from __future__ import annotations

from typing import List, Tuple

import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

from src.config import CONFIG


def split_features(df: pd.DataFrame) -> Tuple[pd.DataFrame, pd.Series]:
    if CONFIG.label_column not in df.columns:
        raise ValueError(f"Label column {CONFIG.label_column} not found")
    X = df.drop(columns=[CONFIG.label_column])
    y_raw = df[CONFIG.label_column]
    y = y_raw.replace({"Yes": 1, "No": 0}).astype(int)
    return X, y


def build_preprocess_pipeline(X: pd.DataFrame) -> Tuple[Pipeline, List[str]]:
    numeric_features = X.select_dtypes(include=["number"]).columns.tolist()
    categorical_features = [col for col in X.columns if col not in numeric_features]

    numeric_transformer = Pipeline(
        steps=[("imputer", SimpleImputer(strategy="median")), ("scaler", StandardScaler())]
    )
    categorical_transformer = Pipeline(
        steps=[
            ("imputer", SimpleImputer(strategy="most_frequent")),
            ("onehot", OneHotEncoder(handle_unknown="ignore")),
        ]
    )
    preprocessor = ColumnTransformer(
        transformers=[
            ("num", numeric_transformer, numeric_features),
            ("cat", categorical_transformer, categorical_features),
        ]
    )
    feature_names = numeric_features + categorical_features
    return preprocessor, feature_names
