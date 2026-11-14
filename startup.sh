export UNITY_ENTRYPOINT=startup.sh
python -m uvicorn main:app --host 0.0.0.0 --port 8000
