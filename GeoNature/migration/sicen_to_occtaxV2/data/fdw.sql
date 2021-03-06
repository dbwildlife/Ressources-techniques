CREATE EXTENSION IF NOT EXISTS postgres_fdw;

DROP SERVER IF EXISTS obsocc_server CASCADE;
CREATE SERVER obsocc_server  
      FOREIGN DATA WRAPPER postgres_fdw 
      OPTIONS (host :'db_host', dbname :'db_oo_name', port :'db_port');

CREATE USER MAPPING  
        FOR :user_pg
        SERVER obsocc_server
        OPTIONS (password :'user_pg_pass',user :'user_pg');

DROP SCHEMA IF EXISTS export_oo CASCADE;
CREATE SCHEMA IF NOT EXISTS export_oo;
IMPORT FOREIGN SCHEMA export_oo
      FROM SERVER obsocc_server INTO export_oo;

DROP SCHEMA IF EXISTS inpn CASCADE;
CREATE SCHEMA IF NOT EXISTS inpn;
IMPORT FOREIGN SCHEMA inpn
      FROM SERVER obsocc_server INTO inpn;