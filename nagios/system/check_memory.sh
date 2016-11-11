#!/bin/bash

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2

option=$1
warning=$2
critical=$3

#### Help ####
PROGNAME=`basename $0`

print_usage() {
  echo "Usage:"
  echo "  $PROGNAME --mem <%warning> <%critical>"
  echo "  $PROGNAME --no_cached <%warning> <%critical>"
  echo "  $PROGNAME --help"
}

print_help() {
  print_usage
  echo ""
  echo "Check SQL Server status"
  echo ""
  echo "--mem"
  echo "   Check used memory"
  echo "--no_cached"
  echo "   Check no buffers and no cached used memory"
  echo "--help"
  echo "   Show this information."
  echo ""
}
###############


case "$option" in
  --mem)
		VALUES=$(free | grep Mem | tr -s " ")
		
		TOTAL=$(echo $VALUES | cut -d" " -f2)
		USED=$(echo $VALUES | cut -d" " -f3)
		#FREE=$(echo $VALUES | cut -d" " -f4)
		#BUFFERS=$(echo $VALUES | cut -d" " -f5)
		#CACHED=$(echo $VALUES | cut -d" " -f6)
		
		let PERCENT=$USED*100/$TOTAL
		
		if [ $PERCENT -gt $warning ]; then
      if [ $PERCENT -gt $critical ]; then
        echo "CRITICAL: $PERCENT% used memory [ $USED KB / $TOTAL KB ] | " mem"="$PERCENT";"$warning";"$critical";0;100"
        exit $STATE_CRITICAL
      else
	      echo "WARNING: $PERCENT% used memory [ $USED KB / $TOTAL KB ] | " mem"="$PERCENT";"$warning";"$critical";0;100"
	      exit $STATE_WARNING
      fi
		else
      echo "OK: $PERCENT% used memory [ $USED_NO_CACHED KB / $TOTAL KB ] | " mem"="$PERCENT";"$warning";"$critical";0;100"
      exit $STATE_OK
		fi
  ;;
  --no_cached)
		VALUES=$(free | grep Mem | tr -s " ")
		
		TOTAL=$(echo $VALUES | cut -d" " -f2)
		USED=$(echo $VALUES | cut -d" " -f3)
		#FREE=$(echo $VALUES | cut -d" " -f4)
		BUFFERS=$(echo $VALUES | cut -d" " -f5)
		CACHED=$(echo $VALUES | cut -d" " -f6)
		
		let USED_NO_CACHED=$USED-$BUFFERS-$CACHED
		let PERCENT=$USED_NO_CACHED*100/$TOTAL
		
		if [ $PERCENT -gt $warning ]; then
		  if [ $PERCENT -gt $critical ]; then
		    echo "CRITICAL: $PERCENT% used memory (no cached) [ $USED_NO_CACHED KB / $TOTAL KB ] | " mem_no_cached"="$PERCENT";"$warning";"$critical";0;100"
		    exit $STATE_CRITICAL
		  else
		    echo "WARNING: $PERCENT% used memory (no cached) [ $USED_NO_CACHED KB / $TOTAL KB ] | " mem_no_cached"="$PERCENT";"$warning";"$critical";0;100"
		    exit $STATE_WARNING
		  fi
			else
		  echo "OK: $PERCENT% used memory (no cached) [ $USED_NO_CACHED KB / $TOTAL KB ] | " mem_no_cached"="$PERCENT";"$warning";"$critical";0;100"
		  exit $STATE_OK
		fi
  ;;
  --help)
    print_help
    exit $STATE_OK
	;;
	*)
		print_help
		exit -1
  ;;

esac
