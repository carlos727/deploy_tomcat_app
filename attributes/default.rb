#
# Application info
#
default['app']['name'] = 'wsEva'
default['app']['war_url'] = 'https://evachef.blob.core.windows.net/resources/pdt/war/v1.0/wsEva.war'
default['app']['version_url'] = 'http://localhost:8080/wsEva/EVApdt/api/V1.0/pedidos/tienda'
default['app']['version_patterm'] = /\d+(\.)\d+/
default['app']['version_from_url'] = true

#
# Notification
#
default["mail"]["to"] = 'cbeleno@redsis.com'
