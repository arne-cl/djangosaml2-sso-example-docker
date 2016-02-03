FROM debian:jessie

MAINTAINER Arne Neumann <djangosaml2.programming@arne.cl>

# NOTE: This Dockerfile is based on Sergey's tutorial
# "How to setup Shibboleth Identity Provider 3 with Django Website"
# http://codeinpython.blogspot.de/2015/11/how-to-setup-shibboleth-identity.html

RUN apt-get update
RUN apt-get install \
    git \
    curl \
    python2.7-dev \
    xmlsec1 \
    libffi-dev \
    libssl-dev -y

WORKDIR /opt
RUN git clone https://github.com/serglopatin/sp1.git

# create certificate and key
WORKDIR /opt/sp1/sp1
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout sp1_key.key \
    -out sp1_cert.pem \
    -subj "/C=GB/ST=London/L=London/O=ACME Company/OU=IT Department/CN=example.com"

RUN apt-get install vim -y
RUN apt-get install python-pip -y

WORKDIR /opt/sp1
RUN pip install -r requirements.txt
RUN python manage.py migrate # migrate database

# EXPOSE 8000
#CMD ["python", "manage.py", "runserver"]

RUN echo "127.0.0.1 idp.localhost sp1.localhost ldap.localhost" >> /etc/hosts


# shibboleth installation
WORKDIR /opt
RUN curl -O http://shibboleth.net/downloads/identity-provider/3.1.2/shibboleth-identity-provider-3.1.2.tar.gz
RUN tar -xvzf shibboleth-identity-provider-3.1.2.tar.gz

WORKDIR /opt/shibboleth-idp
RUN chown "$USER" /opt/shibboleth-idp/

RUN apt-get install openjdk-7-jdk -y


# install shibboleth

WORKDIR /opt/shibboleth-identity-provider-3.1.2
RUN JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/ bin/install.sh \
    -Didp.src.dir=$(pwd) \
    -Didp.target.dir=/opt/shibboleth-idp \
    -Didp.host.name=idp.localhost \
    -Didp.scope=localhost \
    -Didp.keystore.password=test \ 
    -Didp.sealer.password=test
    # keystore.password: TLS private key password
    # sealer.password: cookie encryption key password

# log "everything" that could go wrong,
# use this line for troubleshooting:
#     tail -f /opt/shibboleth-idp/logs/*.log
#
WORKDIR /opt/shibboleth-idp/conf
RUN sed -i 's/name="net.shibboleth.idp" level="INFO"/name="net.shibboleth.idp" level="ALL"/g' logback.xml
RUN sed -i 's/name="org.opensaml.saml" level="INFO"/name="org.opensaml.saml" level="ALL"/g' logback.xml
RUN sed -i 's/name="org.ldaptive" level="WARN"/name="org.ldaptive" level="ALL"/g' logback.xml


