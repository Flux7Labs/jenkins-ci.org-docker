FROM java:openjdk-7u65-jdk

## ENV attributes for proxy. These HAVE to get overwritten when you run the container
#ENV no_proxy localhost,127.0.0.0/8
#ENV http_proxy http://10.0.5.150:8080
#ENV https_proxy http://10.0.5.150:8080

RUN apt-get update && apt-get install -y \
    wget \
    git \
    curl \
    zip \
    python2.7 \
    python-dev \
    python-pip \
    git \
    docker \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

RUN pip install awscli ansible boto cfn-pyplates

## Run the fix for boto's bug "data must be a byte string"
RUN apt-get remove -y python-openssl

## SSH 

RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd
RUN echo 'root:screencast' | chpasswd
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

ENV JENKINS_HOME /var/jenkins_home

# Jenkins is ran with user `jenkins`, uid = 1000
# If you bind mount a volume from host/vloume from a data container, 
# ensure you use same uid
RUN useradd -d "$JENKINS_HOME" -u 1000 -m -s /bin/bash jenkins

# Jenkins home directoy is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d


COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-angent-port.groovy

ENV JENKINS_VERSION 1.596.2

# could use ADD but this one does not check Last-Modified header 
# see https://github.com/docker/docker/issues/8331
RUN curl -L http://mirrors.jenkins-ci.org/war-stable/$JENKINS_VERSION/jenkins.war -o /usr/share/jenkins/jenkins.war

ENV JENKINS_UC https://updates.jenkins-ci.org
RUN chown -R jenkins "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface
EXPOSE 8080

# will be used by attached slave agents:
EXPOSE 50000

# for ssh into this docker container
EXPOSE 22

ENTRYPOINT ["/usr/bin/supervisord"]

ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf 
COPY jenkins.sh /usr/local/bin/jenkins.sh

# from a derived Dockerfile, can use `RUN plugin.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh

