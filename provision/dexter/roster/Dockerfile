# roster -- the arming authority, as a container. Shaped after hf7y/crt's
# provision/dexter/zaxon/Dockerfile: the image is RUNTIME, the mount is STATE.
#
# Nothing is pip-installed. This is the process that has to come back up when
# everything else is broken, so its dependency list is "python".
FROM python:3.11-slim

RUN useradd -m -u 1000 -s /bin/bash roster && mkdir -p /data && chown roster:roster /data
COPY roster_server.py /opt/roster/roster_server.py

USER roster
ENV ROSTER_DB=/data/roster.db
EXPOSE 8646
CMD ["python", "/opt/roster/roster_server.py"]
