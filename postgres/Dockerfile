FROM postgres

RUN apt-get update \
    && apt-get install -y git make gcc postgresql-server-dev-all \
    && git clone https://github.com/pgvector/pgvector.git \
    && cd pgvector \
    && make \
    && make install \
    && rm -rf /var/lib/apt/lists/* pgvector
