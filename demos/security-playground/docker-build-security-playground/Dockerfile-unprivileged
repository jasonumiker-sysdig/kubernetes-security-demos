FROM python:3.11.4-bullseye

ARG UID=1000
ARG GID=1000

RUN groupadd -g "${GID}" python \
  && useradd --create-home --no-log-init -u "${UID}" -g "${GID}" python
USER python
WORKDIR /home/python

RUN pip install --user pipenv

ENV PATH="/home/python/.local/bin:${PATH}"

COPY --chown=python:python Pipfile Pipfile
RUN pipenv lock
RUN pipenv requirements > requirements.txt
RUN pip install --user -r requirements.txt

COPY --chown=python:python app.py .

EXPOSE 8080

CMD ["gunicorn", "-b", ":8080", "--workers", "2", "--threads", "4", "--worker-class", "gthread", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
