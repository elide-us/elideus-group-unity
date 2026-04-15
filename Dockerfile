# -----------------------------------------------------------------------------
# Setup Microsoft ODBC for Linux binaries
# -----------------------------------------------------------------------------
FROM python:3.13-trixie

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg2 ca-certificates apt-transport-https \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sSL -O https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb

RUN apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends \
    msodbcsql18 unixodbc-dev libgssapi-krb5-2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Setup Python Virtual Environment 
# -----------------------------------------------------------------------------
WORKDIR /app
 
ARG PYTHON_ENV=/app/venv
ENV VIRTUAL_ENV=$PYTHON_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

ARG AZURE_SQL_CONNECTION_STRING=""
ENV AZURE_SQL_CONNECTION_STRING=$AZURE_SQL_CONNECTION_STRING

COPY requirements.txt ./
 
RUN python -m venv $VIRTUAL_ENV \
    && pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# -----------------------------------------------------------------------------
# Deploy Build Artifacts and Cleanup
# -----------------------------------------------------------------------------
COPY . /app

RUN chmod +x /app/docker_cleanup.sh \
    && /app/docker_cleanup.sh
 
RUN rm /app/docker_cleanup.sh

# -----------------------------------------------------------------------------
# Configure Startup and Expose
# -----------------------------------------------------------------------------
RUN chmod +x /app/startup.sh

EXPOSE 8000
CMD ["/bin/sh", "/app/startup.sh"]