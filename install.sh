#!/bin/bash
# Solr 4.6.x multi-core Ubuntu/Debian installer

# Copyright 2014 Brad Erickson
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This scripts performs an automatic install of the current multi-core Apache
# Solr 4.6.x in Tomcat 6 on Ubuntu/Debian. Ideally, it would be updated to
# support 4.x.x as released and Centos/Redhat.

# Enable error checking
set -e

echo Installing Apache Solr multi-core
echo

# Set "constants"
TOMCAT_PORT=8080
TOMCAT_DIR=/usr/share/tomcat6
TOMCAT_WEBAPP_DIR=$TOMCAT_DIR/webapps
TOMCAT_CATALINA_DIR=/etc/tomcat6/Catalina/localhost
SOLR_INSTALL_DIR=/usr/share/solr4

# TODO: Check for user is root, otherwise fail.
# TODO: Check for open port, default 8080
# TODO: Check for md5sum
# TODO: Check for curl

# Install Tomcat 6
# TODO: Tomcat 7 if available.
apt-get update
apt-get install -y tomcat6 tomcat6-admin tomcat6-common tomcat6-user

echo Checking Tomcat...
# Load the Tomcat start page and check for the default response, ignore grep exit code.
TOMCAT_RUNNING=$(curl http://localhost:$TOMCAT_PORT | grep -c "It works" || true)

if [ "$TOMCAT_RUNNING" = "0" ]; then
  echo "ERROR: Tomcat is not running"
  exit
fi
echo Tomcat is running

echo Locating an Apache Download Mirror
# Get the mirror list, display only lines where http is in the content,
# get the first match result.
MIRROR=$(curl -s http://www.apache.org/dyn/closer.cgi \
         | grep '>http' | grep -o -m 1 'http://[^" ]*/' | head -n1)
echo Using: $MIRROR

echo Get HTML of the lucene/solr directory
HTML_LUCENE_SOLR=$(curl -s ${MIRROR}lucene/solr/)

# Get the most recent 4.x.x version number.
SOLR_VERSION=$(echo $HTML_LUCENE_SOLR | grep -o '4\.[^/ ]*' | tail -n1)
echo Found version: $SOLR_VERSION

# Convert the version string into an array
ARRAY_SOLR_VERSION=(${SOLR_VERSION//./ })

# Check the minor version
# TODO: Check/test all of 4.x.x
if [ ${ARRAY_SOLR_VERSION[1]} != 6 ]; then
  echo ERROR: Found minor version: ${ARRAY_SOLR_VERSION[1]}. Only Solr 4.6.x is supported by this script.
  exit 1;
fi

# Construct a filename and download the file to /tmp
SOLR_FILENAME=solr-$SOLR_VERSION.tgz
SOLR_FILE_URL=${MIRROR}lucene/solr/$SOLR_VERSION/$SOLR_FILENAME
echo Downloading: $SOLR_FILE_URL
curl -o /tmp/$SOLR_FILENAME $SOLR_FILE_URL

# Verify the download
SOLR_MD5_URL=http://www.us.apache.org/dist/lucene/solr/$SOLR_VERSION/$SOLR_FILENAME.md5
echo Downloading MD5 checksum: $SOLR_MD5_URL
curl -o /tmp/$SOLR_FILENAME.md5 $SOLR_MD5_URL
echo Verifying the MD5 checksum
(cd /tmp; md5sum -c $SOLR_FILENAME.md5)

echo Uncompressing the file
(cd /tmp; tar zxf $SOLR_FILENAME)

echo Installing Solr as a Tomcat webapp
SOLR_SRC_DIR=/tmp/solr-$SOLR_VERSION
mkdir -p $TOMCAT_WEBAPP_DIR
cp $SOLR_SRC_DIR/dist/solr-$SOLR_VERSION.war $TOMCAT_WEBAPP_DIR/solr4.war

# Copy the multicore files and change ownership
mkdir -p $SOLR_INSTALL_DIR/multicore
cp -R $SOLR_SRC_DIR/example/multicore $SOLR_INSTALL_DIR/
chown -R tomcat6:tomcat6 $SOLR_INSTALL_DIR

# Setup the config file for Tomcat
cat > $TOMCAT_CATALINA_DIR/solr4.xml << EOF
<Context docBase="$TOMCAT_WEBAPP_DIR/solr4.war" debug="0" privileged="true"
         allowLinking="true" crossContext="true">
    <Environment name="solr/home" type="java.lang.String"
                 value="$SOLR_INSTALL_DIR/multicore" override="true" />
</Context>
EOF

# Setup log4j
# see: http://wiki.apache.org/solr/SolrLogging#Using_the_example_logging_setup_in_containers_other_than_Jetty
cp $SOLR_SRC_DIR/example/lib/ext/* $TOMCAT_DIR/lib/
cp $SOLR_SRC_DIR/example/resources/log4j.properties $TOMCAT_DIR/lib/

# Restart Tomcat to enable Solr
service tomcat6 restart

echo Checking Solr core0...
# Load the Tomcat start page and check for the default response, ignore grep exit code.
SOLR_CORE0_RUNNING=$(curl http://localhost:$TOMCAT_PORT/solr4/core0/select | grep -c "<response>" || true)

if [ "$SOLR_CORE0_RUNNING" = "0" ]; then
  echo "ERROR: Solr core0 is not running."
  exit
fi

# Delete source files and archive.
rm -rf $SOLR_SRC_DIR
rm /tmp/$SOLR_FILENAME

echo Solr4 has been successfully setup as a Tomcat webapp.
echo
# TODO: Setup solr users

# TODO: Setup Drupal configurations
echo If you are installing Solr for use with Drupal, please download the Apache
echo Solr Search module or the Search API Solr search module and install the
echo provided Solr configrations to the Solr core at:
echo $SOLR_INSTALL_DIR/multicore/core0
echo Then restart tomcat with: service tomcat6 restart
echo
echo The first Solr core is available at:
echo http://localhost:$TOMCAT_PORT/solr4/core0
echo You will need to manually create additional cores.
echo
echo Additional information about Solr multicore is available here:
echo https://wiki.apache.org/solr/CoreAdmin
