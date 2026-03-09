FROM python:3.11-slim

# Dipendenze di sistema
RUN apt-get update && apt-get install -y curl unzip && rm -rf /var/lib/apt/lists/*
RUN apt-get update && apt-get install -y \
    curl unzip git \
    && rm -rf /var/lib/apt/lists/*

# Installa Terraform
RUN curl -fsSL https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip \
    -o terraform.zip && unzip terraform.zip && mv terraform /usr/local/bin/ && rm terraform.zip

# Installa Bruin CLI
RUN curl -fsSL https://raw.githubusercontent.com/bruin-data/bruin/main/install.sh | bash \
    && mv /root/.local/bin/bruin /usr/local/bin/bruin \
    && chmod +x /usr/local/bin/bruin

# Installa dipendenze Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia il codice del progetto
COPY /bruin-pipeline/assets/ /app/assets/
COPY /terraform/ /app/terraform/

WORKDIR /app

# Inizializza Git nel container (Bruin lo richiede)
RUN git config --global user.email "pipeline@example.com" \
    && git config --global user.name "Pipeline"