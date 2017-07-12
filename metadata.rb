name 'deploy_tomcat_app'
maintainer 'Carlos Alberto Beleño Caballero'
maintainer_email 'cbeleno@redsis.com'
license 'all_rights'
description 'Installs/Configures deploy_tomcat_app'
version '2.0.1'
long_description <<-DSCPT
#### Cookbook to deploy Tomcat Applications in a big number of nodes

##### Changelog v2.0.1 11/05/2017:

- Add resource `ruby_block \"Verify if #{$app_name} is deployed\"` to `deploy.rb` recipe.

##### Changelog v2.0.0 09/05/2017:

- Add `depends` and include default recipe of `tomcat_manager` cookbook.

- Delete default attributes related to `Tomcat Manager`. These are defined by `tomcat_manager` cookbook.

##### Changelog v1.1.0 28/04/2017:

- New recipe `download_sw_64bits.rb` to downloaded Tomcat and Java of 64 bits if deployment fails.

- Fix `deploy_app` method of `TomcatManager` module, it failed using `simple_email` method of `Tool` module.

- Add resource `ruby_block 'Wait for tomcat to start'` to `deploy.rb` recipe.

DSCPT

depends 'windows', '~> 1.44.1'
depends 'tomcat_manager'

# If you upload to Supermarket you should set this so your cookbook
# gets a `View Issues` link
# issues_url 'https://github.com/<insert_org_here>/deploy_tomcat_app/issues' if respond_to?(:issues_url)

# If you upload to Supermarket you should set this so your cookbook
# gets a `View Source` link
# source_url 'https://github.com/<insert_org_here>/deploy_tomcat_app' if respond_to?(:source_url)
