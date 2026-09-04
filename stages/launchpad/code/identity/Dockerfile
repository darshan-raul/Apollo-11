FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN addgroup --system apollo \
    && adduser --system --ingroup apollo --no-create-home apollo

COPY --chown=apollo:apollo . .

EXPOSE 8080

USER apollo

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
