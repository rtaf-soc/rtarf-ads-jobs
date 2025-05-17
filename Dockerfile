FROM ruby:3.0

RUN apt-get update -y
RUN apt-get install -y wget curl zip unzip apt-transport-https ca-certificates gnupg lsb-release 
RUN apt-get install chromium -y

# Chrome driver
RUN wget -O /tmp/chromedriver-linux64.zip https://storage.googleapis.com/chrome-for-testing-public/120.0.6099.109/linux64/chromedriver-linux64.zip
RUN unzip /tmp/chromedriver-linux64.zip -d /tmp
RUN cp /tmp/chromedriver-linux64/chromedriver /usr/local/bin/
RUN ls -lrt /usr/local/bin/

# Install pgdump
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN apt-get update -y
RUN apt-get install -y postgresql-client postgresql-client-common libpq-dev
RUN pg_dump --version

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
RUN chmod +x kubectl
RUN mv kubectl /usr/local/bin

# Install gcloud
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN apt-get update -y && apt-get install google-cloud-cli -y
RUN gcloud -v

WORKDIR /scripts
COPY scripts/ .

RUN gem install redis elasticsearch pg watir
