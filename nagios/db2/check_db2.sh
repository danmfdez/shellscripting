#! /bin/sh
#
#  This Nagios plugin was created to check DB2 status
#

PROGNAME=`basename $0`

print_usage() {
 echo "Usage:"
  echo "  $PROGNAME --db <database>"
  echo "  $PROGNAME --bkp <path> <database>"
  echo "  $PROGNAME --tablespace <path> <database> <tablespace>"
  echo "  $PROGNAME --logs"
  echo "  $PROGNAME --size"
  echo "  $PROGNAME --used_size"
  echo "  $PROGNAME --sessions" 
  echo "  $PROGNAME --ins"
  echo "  $PROGNAME --help"
}


print_help() {
  print_usage
  echo ""
  echo "Check DB2 status"
  echo ""
  echo "--db"
  echo "   Check database status"
  echo "--bkp"
  echo "   Check the date of the last backup"
  echo "--tablespace"
  echo "   Check used space of a tablespace"
  echo "--logs"
  echo "   Check logs used space"
  echo "--size"
  echo "   Check db size"
  echo "--used_size"
  echo "   Check db used size"
  echo "--sessions"
  echo "   Check db open sessions"
  echo "--ins"
  echo "   Check count table insertions"
  echo ""
# support
}

case "$1" in
1)
    cmd='--tns'
    ;;
2)
    cmd='--db'
    ;;
*)
    cmd="$1"
    ;;
esac

# Information options
case "$cmd" in
--help)
    print_help
    exit 0
    ;;
-h)
    print_help
    exit 0
    ;;
esac



case "$cmd" in
--db)
	database=$2
	
	db2 connect to $database > /dev/null
	db2 list active databases | grep $database
	db2 terminate > /dev/null
	;;
--bkp)
	path=$2
	database=$3

	db2 connect to $database > /dev/null
	#db2 -txf $path/nagios/libexec/mkdb2_views.sql > /dev/null
	db2 -txf $path/nagios/libexec/bkp_check.sql
    	db2 terminate > /dev/null
	;;
--tablespace)
	path=$2
	database=$3
	tablespace=$4
	
	cat $path/nagios/libexec/check_db2_tablespace.sql | sed s/tablespace/$tablespace/g > $path/$tablespace.sql

	db2 connect to $database > /dev/null
	db2 -txf $path/$tablespace.sql
	db2 terminate > /dev/null

	rm $path/$tablespace.sql
    ;;
--size)
    path=$2
    database=$3

    db2 connect to $database > /dev/null
    db2 -txf $path/nagios/libexec/size_bbdd_check.sql
	db2 terminate > /dev/null
	;;
--used_size)
    path=$2
    database=$3

    db2 connect to $database > /dev/null
    db2 -txf $path/nagios/libexec/used_size_bbdd_check.sql
    db2 terminate > /dev/null
	;;
--logs)
    path=$2
    database=$3

    db2 connect to $database > /dev/null
    db2 -txf $path/nagios/libexec/logs_check.sql

	#Obtener LOG
	db2 get db cfg | grep "First active log file" | tr -s " " | sed "s/ //g" | cut -d"=" -f2 > tmp.txt
	LOG=`cat tmp.txt`
	echo $LOG
	#Obtener fecha de LOG
	ls -la /db2/$database/log_dir/NODE0000 | grep $LOG | tr -s " " | cut -d" " -f6,7,8 | sed "s/ /-/g"
	
	#Obtener numero de logs
	db2 get db cfg | grep "LOGPRIMARY" | tr -s " " | sed "s/ //g" | cut -d"=" -f2
	db2 get db cfg | grep "LOGSECOND" | tr -s " " | sed "s/ //g" | cut -d"=" -f2
 	db2 terminate > /dev/null
	rm -f tmp.txt	
   	;;

--sessions)
    path=$2
    database=$3

    db2 connect to $database > /dev/null
    db2 list applications | grep $database | wc -l
  	db2 terminate > /dev/null
	;;

--mem) 
	db2pd -dbptnmem | grep -e "Memory Limit" -e "Current usage" | tr -s " " | cut -d" " -f3 
	;;

--avg-write)
        path=$2
        database=$3

        db2 connect to $database > /dev/null
        db2 -txf $path/nagios/libexec/write_check.sql

    ;;

--avg-read)
        path=$2
        database=$3

        db2 connect to $database > /dev/null
        db2 -txf $path/nagios/libexec/read_check.sql

    ;;

--ins)
        path=$2
        database=$3
	tabla=$4

	cat $path/nagios/libexec/count_table_insertions.sql | sed s/TABLA/$tabla/g > $path/$tabla.sql	

	db2 connect to $database > /dev/null
	
	if [ -e ins.tmp ]; then
	 value_ini=$(cat ins.tmp)
	 value_fin=$(db2 -txf $path/$tabla.sql)
	else
	 value_ini=$(db2 -txf $path/$tabla.sql)
	 value_fin=$value_ini
	fi

        db2 terminate > /dev/null

	echo $value_fin > ins.tmp
	echo $(($value_fin - $value_ini))

        rm $path/$tabla.sql

    ;;



*)
    print_usage
    exit -1

esac

