#!/bin/bash
# Solr 4.x.x multi-core installer for multiple distributions
# Supports: Debian, Ubuntu, LinuxMint, CentOS, Red Hat and Fedora.

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

# Enable error checking
set -e

# Set CONSTANTS
TOMCAT_PORT=8080
TOMCAT_DIR=/usr/share/tomcat7
TOMCAT_WEBAPP_DIR=$TOMCAT_DIR/webapps
TOMCAT_CATALINA_DIR=/etc/tomcat7/Catalina/localhost
SOLR_INSTALL_DIR=/usr/share/solr4
APACHE_CLOSER_URL=http://www.apache.org/dyn/closer.cgi
APACHE_BACKUP_URL=http://www.us.apache.org/dist/lucene/solr
DOWNLOAD_DIR=/root
TMP_DIR=/tmp

function display_help {
  echo \
"Install for Apache Solr 4.x.x in Tomcat 6 on Debian, Ubuntu, LinuxMint,
Red Hat, Fedora, and CentOS.

Usage: install.sh [OPTION]

Options:

  -a, --apachesolr-schema
        Install the current Drupal Apache Solr Search 7.x-1.x-dev module conf
        for Solr 4.x

  -h, --help
        Display help

  -s, --search-api-schema
        Install the current Drupal Search API Solr search 7.x-1.x-dev module
        conf for Solr 4.x
"
}

# Function to check for required programs
function program_exists {
  echo -n Checking for $1...
  if ! command -v $1 2>/dev/null; then
     echo "Not found" >&2
     exit 1
  fi
}

# Set defaults for the optional schema install
INSTALL_APACHESOLR=""
INSTALL_SEARCH_API=""

# Parse the command line options
while :
do
  case "$1" in
    -a | --apachesolr-schema)
      INSTALL_APACHESOLR="install-apachesolr"
      shift
      ;;
    -h | --help)
      display_help
      exit 0
      ;;
    -s | --search-api-schema)
      INSTALL_SEARCH_API="install-search-api"
      shift
      ;;
    --) # End of all options
      shift
      break
      ;;
    -*)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
    *)  # No more options
      break
      ;;
  esac
done

# If both options are set, exit with error.
if [ $INSTALL_APACHESOLR ] && [ $INSTALL_SEARCH_API ]; then
  echo "ERROR: Only one Drupal module Solr conf can be selected for install." >&2
  display_help
  exit 1
fi

echo -n "Installing Apache Solr 4.x.x multi-core with "
if [ $INSTALL_APACHESOLR ]; then
  echo "Drupal Apache Solr Search module conf"
elif [ $INSTALL_SEARCH_API ]; then
  echo "Drupal Search API Solr Search module conf"
else
  echo "default conf"
fi

# Check for user is root
echo -n "Running as root..."
if [[ $EUID -ne 0 ]]; then
  echo "No. This must be run as root" >&2
  exit 1
fi
echo "Yes"

# TODO: Check for open port, default 8080

# Check for md5sum & tar
program_exists md5sum
program_exists tar

# Determine which package manager is available
echo -n "Checking for a supported package manager..."
if command -v apt-get 2>/dev/null; then
  # Debian, Ubuntu, Linux Mint
  PACKAGE_MAN=apt-get
elif command -v yum 2>/dev/null; then
  # Red Hat, CentOS
  PACKAGE_MAN=yum
else
  echo "Not Found" >&2
  echo "Supported package managers: apt-get, yum" >&2
  exit 1
fi

echo "Installing Tomcat 6 and curl"
if [ "$PACKAGE_MAN" = "apt-get" ]; then
  apt-get update
  apt-get install -y tomcat7 tomcat7-admin tomcat7-common tomcat7-user curl
  # Apt-get starts tomcat
elif [ "$PACKAGE_MAN" = "yum" ]; then
  yum install -y tomcat7 tomcat7-webapps tomcat7-admin-webapps curl
  # Set tomcat to start on boot
  chkconfig tomcat7 on
  # Start tomcat
  service tomcat7 start
fi

# Check for Java >= 1.6.0
echo -n "Checking Java version >= 1.6.0..."
JAVA_VER=$(java -version 2>&1 | sed 's/java version "\(.*\)\.\(.*\)\..*"/\1\2/; 1q')
if [ $JAVA_VER -lt 16 ]; then
  if [ "$PACKAGE_MAN" = "apt-get" ]; then
    echo "Failed" >&2
    echo "Apache Solr requires Java 1.6.0 or greater." >&2
    exit 1
  elif [ "$PACKAGE_MAN" = "yum" ]; then
    echo "Upgrading"
    # Install Java 1.7.0; it should become the default
    yum install -y java-1.7.0
    service tomcat7 restart
    echo -n "Rechecking Java version >= 1.6.0..."
    JAVA_VER=$(java -version 2>&1 | sed 's/java version "\(.*\)\.\(.*\)\..*"/\1\2/; 1q')
    if [ $JAVA_VER -lt 16 ]; then
      echo "Failed" >&2
      echo "Apache Solr requires Java 1.6.0 or greater." >&2
      exit 1
    fi
    echo "Ok"
  fi
else
  echo "Ok"
fi

TOMCAT_URL=http://localhost:$TOMCAT_PORT
echo -n "Checking Tomcat: $TOMCAT_URL..."
# Wait a moment for Tomcat to start up
sleep 5

# Load the Tomcat start page and return the HTTP code
TOMCAT_RUNNING=$(curl -s -o /dev/null -w '%{http_code}' $TOMCAT_URL)

if [ "$TOMCAT_RUNNING" != "200" ]; then
  echo "Failed. Tomcat is not running." >&2
  exit 1
fi
echo "Ok"

echo Locating an Apache Download Mirror
# Get the mirror list, display only lines where http is in the content,
# get the first match result.
MIRROR=$(curl -s $APACHE_CLOSER_URL \
         | grep '>http' | grep -o -m 1 'http://[^" ]*/' | head -n1)
echo Using: $MIRROR

echo Get HTML of the lucene/solr directory
HTML_LUCENE_SOLR=$(curl -s ${MIRROR}lucene/solr/)

# Get the most recent 4.x.x version number.
SOLR_VERSION=$(echo $HTML_LUCENE_SOLR | grep -o '4\.[^/ ]*' | tail -n1)
if [ -z "$SOLR_VERSION" ]; then
  echo "ERROR: Apache Solr 4.x.x archive cannot be found." >&2
  exit 1
fi

echo Found version: $SOLR_VERSION

# Convert the version string into an array
ARRAY_SOLR_VERSION=(${SOLR_VERSION//./ })

# Check the minor version (Still needed?)
#if [ ${ARRAY_SOLR_VERSION[1]} != 6 ]; then
#  echo ERROR: Only Solr 4.6.x or greater is supported by this script.
#  exit 1;
#fi

# Construct a filename and download the file to $DOWNLOAD_DIR
SOLR_FILENAME=solr-$SOLR_VERSION.tgz
SOLR_FILE_URL=${MIRROR}lucene/solr/$SOLR_VERSION/$SOLR_FILENAME
echo Downloading: $SOLR_FILE_URL
curl -o $DOWNLOAD_DIR/$SOLR_FILENAME $SOLR_FILE_URL

# Verify the download
SOLR_MD5_URL=$APACHE_BACKUP_URL/$SOLR_VERSION/$SOLR_FILENAME.md5
echo
echo Downloading MD5 checksum: $SOLR_MD5_URL
curl -o $DOWNLOAD_DIR/$SOLR_FILENAME.md5 $SOLR_MD5_URL
echo Verifying the MD5 checksum
(cd $DOWNLOAD_DIR; md5sum -c $SOLR_FILENAME.md5)

echo Uncompressing the file
(cd $TMP_DIR; tar zxf $DOWNLOAD_DIR/$SOLR_FILENAME)

echo Installing Solr as a Tomcat webapp
SOLR_SRC_DIR=$TMP_DIR/solr-$SOLR_VERSION
mkdir -p $TOMCAT_WEBAPP_DIR
cp $SOLR_SRC_DIR/dist/solr-$SOLR_VERSION.war $TOMCAT_WEBAPP_DIR/solr4.war

# Copy the multicore files and change ownership
mkdir -p $SOLR_INSTALL_DIR/multicore
cp -R $SOLR_SRC_DIR/example/multicore $SOLR_INSTALL_DIR/
# Debian & Red Hat use different tomcat users/groups
# TODO: Detect correct user/group
if [ "$PACKAGE_MAN" = "apt-get" ]; then
  chown -R tomcat7:tomcat7 $SOLR_INSTALL_DIR
elif [ "$PACKAGE_MAN" = "yum" ]; then
  chown -R tomcat:tomcat $SOLR_INSTALL_DIR
fi

# Setup the config file for Tomcat
cat > $TOMCAT_CATALINA_DIR/solr4.xml << EOF
<Context docBase="$TOMCAT_WEBAPP_DIR/solr4.war" debug="0" privileged="true" allowLinking="true" crossContext="true">
    <Environment name="solr/home" type="java.lang.String" value="$SOLR_INSTALL_DIR/multicore" override="true" />
</Context>
EOF

# Setup log4j
# see: http://wiki.apache.org/solr/SolrLogging#Using_the_example_logging_setup_in_containers_other_than_Jetty
cp $SOLR_SRC_DIR/example/lib/ext/* $TOMCAT_DIR/lib/
cp $SOLR_SRC_DIR/example/resources/log4j.properties $TOMCAT_DIR/lib/

# Install Drupal module specific schema
if [ $INSTALL_APACHESOLR ]; then
  echo "Downloading Drupal Apache Solr Search module 7.x-1.x-dev"
  curl -o $DOWNLOAD_DIR/apachesolr.tar.gz http://ftp.drupal.org/files/projects/apachesolr-7.x-1.x-dev.tar.gz
  (cd $DOWNLOAD_DIR; tar zxf apachesolr.tar.gz)
  echo "Installing schema"
  cp $DOWNLOAD_DIR/apachesolr/solr-conf/solr-4.x/* $SOLR_INSTALL_DIR/multicore/core0/conf
  rm $DOWNLOAD_DIR/apachesolr.tar.gz
  rm -rf $DOWNLOAD_DIR/apachesolr
elif [ $INSTALL_SEARCH_API ]; then
  echo "Downloading Drupal Search API Solr Search module 7.x-1.x-dev"
  curl -o $DOWNLOAD_DIR/search_api_solr.tar.gz http://ftp.drupal.org/files/projects/search_api_solr-7.x-1.x-dev.tar.gz
  (cd $DOWNLOAD_DIR; tar zxf search_api_solr.tar.gz)
  echo "Installing schema"
  cp $DOWNLOAD_DIR/search_api_solr/solr-conf/4.x/* $SOLR_INSTALL_DIR/multicore/core0/conf
  rm $DOWNLOAD_DIR/search_api_solr.tar.gz
  rm -rf $DOWNLOAD_DIR/search_api_solr
fi

echo "Restarting Tomcat to enable Solr"
service tomcat7 restart

# Wait for tomcat to restart
sleep 5

echo Checking Solr core0...
# Load the Tomcat start page and check for the default response, ignore grep exit code.
SOLR_CORE0_RUNNING=$(curl http://localhost:$TOMCAT_PORT/solr4/core0/select | grep -c "<response>" || true)

if [ "$SOLR_CORE0_RUNNING" = "0" ]; then
  echo "Failed. Solr core0 is not returning expected results." >&2
  exit
fi
echo "Ok"

# Delete source files and archive.
rm -rf $SOLR_SRC_DIR
rm $DOWNLOAD_DIR/$SOLR_FILENAME
rm $DOWNLOAD_DIR/$SOLR_FILENAME.md5

echo Apache Solr $SOLR_VERSION has been successfully setup as a Tomcat webapp.
echo
# TODO: Setup solr users

echo \
"The Solr configuration for core0 is available at:
  $SOLR_INSTALL_DIR/multicore/core0/conf
Then restart tomcat with:
  service tomcat7 restart
The first Solr core is available via HTTP at:
  http://localhost:$TOMCAT_PORT/solr4/core0

You must manually create additional cores.

Additional information about Solr multicore is available here:
https://wiki.apache.org/solr/CoreAdmin

Done!
"
exit 0
