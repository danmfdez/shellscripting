select trunc(decimal(sum(pool_read_time))/decimal((sum(pool_data_p_reads)+sum(pool_index_p_reads))),3) from sysibmadm.snaptbsp;
