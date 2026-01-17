setup:
	python -m pip install --upgrade pip
	pip install -r requirements.txt

ingest:
	python -m src.ingestion

validate:
	python -m src.validate

train:
	python -m src.train

evaluate:
	python -m src.evaluate

explain:
	python -m src.explain

monitor:
	python -m src.monitor

app:
	streamlit run app/streamlit_app.py

test:
	pytest -q
