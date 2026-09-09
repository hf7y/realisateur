# roster -- the arming authority. After hf7y/crt's provision/dexter/zaxon:
# the image is RUNTIME, the mount is STATE, and nothing is pip-installed.
FROM python:3.11-slim

# CONFIG IS BAKED IN, NOT FETCHED AT RUN TIME (realisateur#1080). CI reads
# hf7y/scheduler ONCE, at this pinned commit, when the image builds -- bump it
# by hand in a PR to pick up new schedule/ content, same as any other pin.
ARG SCHEDULER_PIN=d73c70a44b5bf279ec23f03ecfef4c37c3e9ebcd

RUN useradd -m -u 1000 -s /bin/bash roster && mkdir -p /data && chown roster:roster /data

COPY bake_schedule.py /tmp/bake_schedule.py
RUN python3 /tmp/bake_schedule.py "$SCHEDULER_PIN" /opt/roster/schedule \
    && rm /tmp/bake_schedule.py

COPY roster_server.py /opt/roster/roster_server.py
RUN chown -R roster:roster /opt/roster

USER roster
ENV ROSTER_DB=/data/roster.db
ENV ROSTER_SCHEDULE_DIR=/opt/roster/schedule
EXPOSE 8646
CMD ["python", "/opt/roster/roster_server.py"]
