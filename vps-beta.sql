drop table if exists vps;
create table vps (
  name varchar(64),
  uuid    varchar(48),      
  memory  int(32),
  cpu     int(8),
  state  varchar(32),
  status     varchar(32),
  node_uuid    varchar(48), 
  ip      varchar(16),
  enable  tinyint(1),
  regist_time timestamp, 
  update_key varchar(48),
  primary key(uuid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

drop table if exists ip;
create table ip (
  network varchar(32),
  ip  varchar(16),
  used tinyint(1),
  start_time time,
  end_time time,
  enable  tinyint(1),
  regist_time time, 
  primary key(ip)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

drop table if exists node;
create table node (
  node_name varchar(64),
  uuid     varchar(48),
  vps_count int(8),
  enable  tinyint(1),
  regist_time timestamp, 
  primary key(uuid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

drop table if exists user_switch;
create table user_switch (
  vlan_id        int(8),
  contract_user  varchar(32),
  enable         tinyint(1),
  regist_time timestamp, 
  primary key(vlan_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

drop table if exists contract_user;
create table contract_user (
  user_name varchar(32),
  regist_time timestamp, 
  primary key(user_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


