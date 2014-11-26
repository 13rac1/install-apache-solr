Solr 4.x.x multi-core install.sh
--------------------------------

This script installs the current multi-core Apache Solr 4.x.x in Tomcat 7 on
Debian, Ubuntu, LinuxMint, Red Hat, Fedora, and CentOS. It will optionally
install the Solr 4.x configurations supplied with the Drupal Apache Solr or
Search API Solr modules.

Install
-------

*There are multiple options. Choose one.*

To install without cloning the repository using the default Solr conf:

    curl https://raw.github.com/eosrei/install-apache-solr/master/install.sh | sudo bash -s

To install using the Drupal Apache Solr module conf:

    git clone https://github.com/eosrei/install-apache-solr.git
    cd install-apache-solr
    sudo ./install.sh -a

To install using the Drupal Search API Solr module conf:

    git clone https://github.com/eosrei/install-apache-solr.git
    cd install-apache-solr
    sudo ./install.sh -s

Clone the repository to test Ubuntu 12.04 LTS with Vagrant:

    git clone https://github.com/eosrei/install-apache-solr.git
    cd install-apache-solr/vagrant/ubuntu12.04
    vagrant up

Notes
-----
* Are you *sure* you need Solr on your project? Think about it. Be sure.
* Installs Tomcat 7 using the distribution's package manager.
* The default Tomcat 7 port is 8080. It should be firewalled from external
  access.
* Only one Solr core is created, additional cores will need to be created
  manually.
* A random Apache Download Mirror is choosen and some are slow. It is OK to
  stop(^C) the script and start it again.
* This should work to upgrade between 4.x.x releases, but will overwrite custom
  conf/schema. Test it.

Todo
----
* Setup Tomcat7 Users
* Docker support/tests
* Install current Tomcat7 from the Apache Download mirrors 

Tested with a VagrantFile
-------------------------
* Ubuntu 12.04 LTS x64
* Ubuntu 14.04 LTS x64

Untested and possibly broken with a VagrantFile
-----------------------------------------------
These used to work, but haven't been tested recently.

* Debian 6 x64
* CentOS 7.0 x64
* Fedora 18 x64



Tested with Solr 4.9.1

More information
----------------
* Solr Multicore details: https://wiki.apache.org/solr/CoreAdmin
* Solr on Tomcat details: https://wiki.apache.org/solr/SolrTomcat
* The Drupal Apache Solr Search module project page: https://drupal.org/project/apachesolr
* The Drupal Search API Solr search module project page: https://drupal.org/project/search_api_solr
