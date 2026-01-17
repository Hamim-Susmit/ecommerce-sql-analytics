from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Paths:
    base_dir: Path = Path(__file__).resolve().parents[1]
    data_raw: Path = base_dir / "data" / "raw"
    data_processed: Path = base_dir / "data" / "processed"
    models_dir: Path = base_dir / "models"
    reports_dir: Path = base_dir / "reports"
    figures_dir: Path = reports_dir / "figures"


@dataclass(frozen=True)
class Config:
    label_column: str = "Churn"
    random_seed: int = 42
    train_size: float = 0.8
    churn_loss: float = 500.0
    retention_offer_cost: float = 50.0
    raw_filename: str = "telco_churn.csv"
    processed_filename: str = "telco_churn_processed.csv"


PATHS = Paths()
CONFIG = Config()
