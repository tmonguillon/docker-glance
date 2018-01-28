FROM python:2.7-alpine
MAINTAINER thomas.monguillon "thomas.monguillon@orange.com"
ARG GLANCE_BRANCH=master
ENV GLANCE_BRANCH $GLANCE_BRANCH
WORKDIR /opt
RUN apk add --no-cache \
    bash \
    wget \
    curl \
    libffi \
    libxslt \
    mariadb-client
# Install build-deps, pip install packages and clean deps (to keep image small)
RUN apk add --no-cache --virtual build-deps \
        git \
        gcc \
        linux-headers \
        libc-dev \
        python-dev \
        openssl-dev \
        libffi-dev \
        libxml2-dev \
        libxslt-dev \
        mariadb-dev \
    && pip install MySQL-python pymysql pymysql_sa \
    && git clone --branch $GLANCE_BRANCH --depth=1 https://github.com/openstack/requirements \
    && git clone --branch $GLANCE_BRANCH --depth=1 https://github.com/openstack/glance \
    && git clone --branch $GLANCE_BRANCH --depth=1 https://github.com/openstack/python-openstackclient \
    && pip install /opt/glance -c /opt/requirements/upper-constraints.txt -r /opt/glance/requirements.txt -r /opt/requirements/requirements.txt \
    && pip install /opt/python-openstackclient -r /opt/python-openstackclient/requirements.txt -r /opt/requirements/requirements.txt \
    && mkdir -p /etc/glance \
    && cp /opt/glance/etc/glance-*-paste.ini /etc/glance \
    && rm -rf /root/.cache \
#    && rm -rf /opt/* \
    && rm -rf /var/cache/apk/* \
    && apk del build-deps
EXPOSE 9191 9292
#copy sql script
COPY glance.sql /root/glance.sql
#copy glance config file
COPY glance-api.conf /etc/glance/glance-api.conf
COPY glance-registry.conf /etc/glance/glance-registry.conf
# add bootstrap script and make it executable
COPY bootstrap.sh /etc/bootstrap.sh
RUN chown root.root /etc/bootstrap.sh && chmod a+x /etc/bootstrap.sh
#ENTRYPOINT ["/etc/bootstrap.sh"]
CMD ["tail", "-f", "/dev/null"]