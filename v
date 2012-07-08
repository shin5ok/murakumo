# rename this file to Murakumo.yml and put a ':' after 'name' if
# you want to use YAML like in old versions of Catalyst
name Murakumo

api_port 3000

root_item_name root

fix_request_arg /vps/clone_start,/vps/clone,/vps/hoge,/vps/remove,/vps/create,/vps/define/remove,/node/vps/define/remove
fix_request_node node111
test

vm_root /nfs
vm_config_dirname config
template_dirname template

db_dsn dbi:mysql:dbname=vpsdb
db_user vps-admin
db_pass test_password

vps_list_expire_second 30
node_list_expire_second 30

require_cpu_for_node 2
require_memory_for_node 4096000

