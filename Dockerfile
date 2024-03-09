
FROM ubuntu:22.04

ENV LANG=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /kubespray

RUN apt-get update -q \
    && apt-get install -yq --no-install-recommends \
    curl \
    python3 \
    python3-pip \
    sshpass \
    vim \
    rsync \
    openssh-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/log/*

COPY requirements.txt requirements.txt  \
    && pip3 install --no-compile --no-cache-dir -r requirements.txt \
    && find /usr -type d -name '*__pycache__' -prune -exec rm -rf {} \;

CMD ["sleep","infinity"]