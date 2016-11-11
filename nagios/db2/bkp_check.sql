select max(start_time) MAXBACKUP from sysibmadm.db_history where (operation = 'B') and (operationtype in ('B', 'N', 'F')) and (sqlcode is null or sqlcode >= 0);
