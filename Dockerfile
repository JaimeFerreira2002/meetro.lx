# Fly.io deploy image. Build context = repo root, so it can include data/
# (the local server/Dockerfile can't reach ../data and is for `docker run` in server/).
# Layout is mirrored so the server's relative paths resolve:
#   /srv/server/app/main.py -> WEB_DIR = ../web, TRACK_FILE = ../../data
FROM python:3.12-slim

WORKDIR /srv
COPY server/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY server/app ./server/app
COPY server/web ./server/web
COPY data ./data

WORKDIR /srv/server
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
