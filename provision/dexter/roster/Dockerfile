# roster -- the arming authority. After hf7y/crt's provision/dexter/zaxon:
# the image is RUNTIME, the mount is STATE, and nothing is pip-installed.
FROM python:3.11-slim

RUN useradd -m -u 1000 -s /bin/bash roster && mkdir -p /data && chown roster:roster /data
COPY roster_server.py /opt/roster/roster_server.py

USER roster
ENV ROSTER_DB=/data/roster.db
EXPOSE 8646
CMD ["python", "/opt/roster/roster_server.py"]
