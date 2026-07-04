FROM python:3.12-alpine

RUN apk add --no-cache tini \
    && pip install --no-cache-dir fastapi==0.115.6 uvicorn[standard]==0.32.1

WORKDIR /app
COPY app/main.py /app/app/main.py

ENV PYTHONUNBUFFERED=1
EXPOSE 8080

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080", "--proxy-headers", "--forwarded-allow-ips", "*"]
