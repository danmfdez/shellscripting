select total_log_used/1024/1024 USADO_MB, total_log_available/1024/1024 RESERVADO_MB, int((float(total_log_used)/float(total_log_used+total_log_available))*100) UTILIZADO from sysibmadm.snapdb;
