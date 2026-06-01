FROM python:3.11-slim

# System dependencies for mysqlclient
RUN apt-get update && apt-get install -y \
    pkg-config \
    default-libmysqlclient-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Collect static files
RUN python manage.py collectstatic --noinput

EXPOSE 8000

CMD gunicorn vision4farms_api.wsgi:application \
    --bind 0.0.0.0:$PORT \
    --workers 2 \
    --timeout 120
