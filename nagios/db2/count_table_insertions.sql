SELECT sum(rows_inserted) as total_rows_inserted FROM TABLE(MON_GET_TABLE('','',-2)) AS t where tabname='TABLA' GROUP BY tabschema, tabname;

