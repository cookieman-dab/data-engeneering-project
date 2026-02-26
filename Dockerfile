FROM python:3.11-slim

# Dipendenze di sistema
RUN apt-get update && apt-get install -y curl unzip && rm -rf /var/lib/apt/lists/*

# Installa Terraform
RUN curl -fsSL https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip \
    -o terraform.zip && unzip terraform.zip && mv terraform /usr/local/bin/ && rm terraform.zip

# Installa Bruin CLI
RUN curl -fsSL https://raw.githubusercontent.com/bruin-data/bruin/main/install.sh | sh

# Installa dipendenze Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia il codice del progetto
COPY pipeline/ /app/pipeline/
COPY terraform/ /app/terraform/

WORKDIR /app
