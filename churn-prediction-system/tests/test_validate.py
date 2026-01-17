import pandas as pd
import pytest

from src.validate import validate_schema
from src.config import CONFIG


def test_validate_missing_label():
    df = pd.DataFrame({"feature": [1, 2, 3]})
    issues = validate_schema(df, required_columns=["feature"])
    assert "missing_label" in issues
    assert CONFIG.label_column in issues["missing_label"]
