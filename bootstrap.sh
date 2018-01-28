#!/bin/bash
set -x

# Init GLANCE vars
GLANCE_USER_NAME=${GLANCE_USER_NAME:-glance}
GLANCE_PASSWORD=${GLANCE_PASSWORD:-GLANCE_PASS}
GLANCE_HOST=${GLANCE_HOST:-$HOSTNAME}

API_CONFIG_FILE=/etc/glance/glance-api.conf
REGISTRY_CONFIG_FILE=/etc/glance/glance-registry.conf

# create database for glance if specified
SQL_SCRIPT=${SQL_SCRIPT:-/root/glance.sql}
if env | grep -qi MYSQL_ROOT_PASSWORD && test -e $SQL_SCRIPT; then
  MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
  MYSQL_HOST=${MYSQL_HOST:-mysql}
  until mysql -uroot -p$MYSQL_ROOT_PASSWORD -h $MYSQL_HOST -e 'select 1'; do
    >&2 echo "MySQL is unavailable - sleeping"
    sleep 1
  done
  mysql -uroot -p$MYSQL_ROOT_PASSWORD -h $MYSQL_HOST <$SQL_SCRIPT
  rm -f $SQL_SCRIPT

  # update glance-api.conf
  sed -i "s#^connection.*=.*#connection = mysql+pymysql://glance:GLANCE_DBPASS@${MYSQL_HOST}/glance?charset=utf8#" $API_CONFIG_FILE
  # update glance-registry.conf
  sed -i "s#^connection.*=.*#connection = mysql+pymysql://glance:GLANCE_DBPASS@${MYSQL_HOST}/glance?charset=utf8#" $REGISTRY_CONFIG_FILE

fi

# sync the database
glance-manage db_sync

if [[ ${KEYSTONE_HOST+x} ]]; then
  # To create the Identity service credentials
  KEYSTONE_HOST=${KEYSTONE_HOST:-keystone}
  export OS_USERNAME=${OS_USERNAME:-admin}
  export OS_PASSWORD=${OS_PASSWORD:-ADMIN_PASS}
  export OS_TENANT_NAME=${OS_TENANT_NAME:-admin}
  export OS_AUTH_URL=${OS_AUTH_URL:-http://${KEYSTONE_HOST}:35357}

  # Change configuration depending on the input parameters
  # update glance-api.conf
  sed -i "s#^auth_uri.*=.*#auth_uri = http://${KEYSTONE_HOST}:5000#" $API_CONFIG_FILE
  sed -i "s#^identity_uri.*=.*#identity_uri = http://${KEYSTONE_HOST}:35357#" $API_CONFIG_FILE
  sed -i "s#^admin_tenant_name.*=.*#admin_tenant_name = service#" $API_CONFIG_FILE
  sed -i "s#^admin_user.*=.*#admin_user = ${GLANCE_USER_NAME}#" $API_CONFIG_FILE
  sed -i "s#^admin_password.*=.*#admin_password = ${GLANCE_PASSWORD}#" $API_CONFIG_FILE
  sed -i "s#^flavor.*=.*#flavor = keystone+cachemanagement#" $API_CONFIG_FILE
  # update glance-registry.conf
  sed -i "s#^auth_uri.*=.*#auth_uri = http://${KEYSTONE_HOST}:5000#" $REGISTRY_CONFIG_FILE
  sed -i "s#^identity_uri.*=.*#identity_uri = http://${KEYSTONE_HOST}:35357#" $REGISTRY_CONFIG_FILE
  sed -i "s#^admin_tenant_name.*=.*#admin_tenant_name = service#" $REGISTRY_CONFIG_FILE
  sed -i "s#^admin_user.*=.*#admin_user = ${GLANCE_USER_NAME}#" $REGISTRY_CONFIG_FILE
  sed -i "s#^admin_password.*=.*#admin_password = ${GLANCE_PASSWORD}#" $REGISTRY_CONFIG_FILE
  sed -i "s#^flavor.*=.*#flavor = keystone#" $REGISTRY_CONFIG_FILE

  # Openstack initialization
  openstack user create --password $GLANCE_PASSWORD $GLANCE_USER_NAME
  openstack role add --project service --user $GLANCE_USER_NAME admin
  openstack service create --name $GLANCE_USER_NAME --description "OpenStack Image service" image
  openstack endpoint create --region RegionOne image public http://${GLANCE_HOST}:9292
  openstack endpoint create --region RegionOne image internal http://${GLANCE_HOST}:9292
  openstack endpoint create --region RegionOne image admin http://${GLANCE_HOST}:9292
fi


# create a admin-openrc.sh file
ADMIN_OPENRC=/root/admin-openrc.sh
cat >$ADMIN_OPENRC <<EOF
export OS_TENANT_NAME=$OS_TENANT_NAME
export OS_USERNAME=$OS_USERNAME
export OS_PASSWORD=$OS_PASSWORD
export OS_AUTH_URL=$OS_AUTH_URL
EOF

# start glance service
#glance-registry &
#sleep 5
#glance-api
