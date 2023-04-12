FROM python:3.11.3-bullseye

RUN pip install pipenv

WORKDIR /app

COPY Pipfile /app
RUN pipenv lock
RUN pipenv install --system --deploy

COPY app.py /app

EXPOSE 8080

CMD ["gunicorn", "-b", ":8080", "--workers", "2", "--threads", "4", "--worker-class", "gthread", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
