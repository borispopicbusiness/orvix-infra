FROM postgres:latest

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       python3 \
       python3-pip \
       python3-venv \
       python3-dev \
       gcc \
       libpq-dev \
       gettext-base \
    && python3 -m venv /opt/patroni \
    && /opt/patroni/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/patroni/bin/pip install --no-cache-dir "patroni[kubernetes,psycopg3]" \
    && apt-get purge -y \
       python3-dev \
       gcc \
       libpq-dev \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/patroni/bin:$PATH"

COPY patroni.yaml /etc/patroni/patroni.yaml.template
COPY create-database.sh /usr/local/bin/create-database.sh

RUN chmod +x /usr/local/bin/create-database.sh

#ENTRYPOINT ["patroni", "/etc/patroni/patroni.yaml"]
ENTRYPOINT ["/bin/sh", "-c", "envsubst < /etc/patroni/patroni.yaml.template > /tmp/patroni.yaml && exec patroni /tmp/patroni.yaml"]