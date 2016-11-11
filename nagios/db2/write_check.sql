select trunc(decimal(sum(pool_write_time))/decimal((sum(pool_data_writes)+sum(pool_index_writes))),3) from sysibmadm.snaptbsp;
