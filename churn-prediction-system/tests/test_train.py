from pathlib import Path

import pandas as pd

from src.train import train


def test_train_produces_model(tmp_path: Path):
    data = pd.DataFrame(
        {
            "tenure": [1, 10, 5, 3],
            "monthly_charges": [70, 90, 50, 40],
            "contract": ["Month-to-month", "One year", "Two year", "Month-to-month"],
            "Churn": [1, 0, 0, 1],
        }
    )
    processed_path = tmp_path / "processed.csv"
    data.to_csv(processed_path, index=False)

    model_path = tmp_path / "model.joblib"
    metadata_path = tmp_path / "metadata.json"
    train(processed_path, model_path, metadata_path)

    assert model_path.exists()
    assert metadata_path.exists()
