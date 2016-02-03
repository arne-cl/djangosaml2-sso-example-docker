# NOTE: This Dockerfile is based on Sergey's tutorial
# "How to setup Shibboleth Identity Provider 3 with Django Website"
# http://codeinpython.blogspot.de/2015/11/how-to-setup-shibboleth-identity.html


# Sergey uses Debian Jessie but that comes with Tomcat 7.0.56,
# which will produce a "Unable to process file XYZ for annotations java.io.EOFException"
# http://stackoverflow.com/questions/23541532/tomcat7-and-java8-wont-start/23608847
#
# debian jessie: tomcat 7.0.56
#FROM debian:jessie 
# ubuntu 14.04: tomcat 7.0.52
#FROM ubuntu:14.04
# ubuntu 15.10: tomcat 7.0.64
FROM ubuntu:15.10

MAINTAINER Arne Neumann <djangosaml2.programming@arne.cl>

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


RUN echo "127.0.0.1 idp.localhost sp1.localhost ldap.localhost" >> /etc/hosts


# shibboleth installation

WORKDIR /opt
RUN curl -O http://shibboleth.net/downloads/identity-provider/3.1.2/shibboleth-identity-provider-3.1.2.tar.gz
RUN tar -xvzf shibboleth-identity-provider-3.1.2.tar.gz

WORKDIR /opt/shibboleth-idp
RUN chown "$USER" /opt/shibboleth-idp/

RUN apt-get install openjdk-8-jdk -y

WORKDIR /opt/shibboleth-identity-provider-3.1.2
RUN JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/ bin/install.sh \
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


# Tomcat installation

# log files are here: /var/log/tomcat7/
RUN apt-get install tomcat7 -y

ADD idp.xml /etc/tomcat7/Catalina/localhost/idp.xml


# add current user to tomcat group; allow tomcat to access shibboleth
# NOTE: the tutorial used "$USER" instead of root,
# but 'echo $ROOT' just returns an empty line here
RUN gpasswd -a root tomcat7
RUN chown -R tomcat7:tomcat7 /opt/shibboleth-idp
RUN newgrp tomcat7

# http://localhost:8080/idp/profile/status depends on jstl,
# which is not included to shibboleth libs, so we will need to
# download it manually and rebuild the war file
WORKDIR /opt/shibboleth-idp/webapp/WEB-INF/lib
RUN curl -O http://repo1.maven.org/maven2/javax/servlet/jstl/1.2/jstl-1.2.jar
RUN JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/ \
    JAVACMD=/usr/bin/java /opt/shibboleth-idp/bin/build.sh \
    -Didp.target.dir=/opt/shibboleth-idp \
    -Didp.host.name=idp.localhost \
    -Didp.scope=localhost \
    -Didp.keystore.password=test \ 
    -Didp.sealer.password=test

RUN apt-get install htop lsof -y # TODO: rm after debug
