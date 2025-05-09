FROM ruby:3.0

RUN apt-get update -y
RUN apt-get install -y wget curl zip unzip apt-transport-https ca-certificates gnupg lsb-release 
RUN apt-get install chromium -y

#RUN wget -O /tmp/chromedriver.zip https://chromedriver.storage.googleapis.com/2.46/chromedriver_linux64.zip
RUN wget -O /tmp/chromedriver-linux64.zip https://storage.googleapis.com/chrome-for-testing-public/136.0.7103.92/linux64/chromedriver-linux64.zip
RUN unzip /tmp/chromedriver-linux64.zip -d /tmp
RUN cp /tmp/chromedriver-linux64/chromedriver /usr/local/bin/
RUN ls -lrt /usr/local/bin/

WORKDIR /scripts
COPY scripts/ .

RUN gem install redis elasticsearch pg watir
