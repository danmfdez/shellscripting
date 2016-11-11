#!/usr/bin/sh

#### Help ####
PROGNAME=`basename $0`

print_usage() {
	echo "Usage:"
	echo "  $PROGNAME [--rebuild|-rb] <DB> <TBS> <TYPE_TBS (D: Data,I: Index)> [<ITERATIONS>]"
	echo "  $PROGNAME [--reduce|-rd] <DB> <TBS>"	
	echo "  $PROGNAME [--reorg|-ro] <DB> <TBS> <TYPE_TBS (D: Data,I: Index)>"
	echo "  $PROGNAME [--help|-h]"
}

print_help() {
	print_usage
	echo ""
	echo "Rebuild tablespace"
	echo ""
	echo "--rebuild|-rb"
	echo "   Rebuld a tablespace."
	echo "--reduce|-rd"
	echo "   Reduce a tablespace."
	echo "--reorg|-ro"
	echo "   Reorganise a tablespace."
	echo "--help|-h"
	echo "   Show this information."
	echo ""
}
###############

#### FUNCTIONS ####

## GESTION INTERRUPCIONES ##
## Input: N/A
## Output: N/A
function interrupcion {

	db2 "connect to $DB" > /dev/null
	END_TOTAL_KB=$(db2 -x "SELECT varchar(tbsp_name, 30) as tbsp_name, tbsp_total_pages*$PAGE_SIZE as Tamano FROM TABLE(MON_GET_TABLESPACE('',-2)) AS t where tbsp_name='$TBS'" | awk '{print $2}')
	db2 "terminate" > /dev/null
	
	TOTAL_REDUCED_SIZE=$(($INIT_TOTAL_KB - $END_TOTAL_KB))
	
	if [[ $OPTION = "--rebuild" || $OPTION = "--reorg" || $OPTION = "-rb" || $OPTION = "-ro" ]]; then
		echo "------------------------------------------------------------------------"
		echo " BBDD: $DB  /  Tablespace: $TBS  /  Tipo: $TYPE_TBS"
		echo "------------------------------------------------------------------------"
		echo " Se han reorganizado un total de $TOTAL_REORG_TABLES tablas."
		echo " Tamano inicial del tablespace: $INIT_TOTAL_KB KB"
		echo " Tamano final del tablespace: $END_TOTAL_KB KB"
		echo " Se ha reducido el tamano del tablespace en $(($INIT_TOTAL_KB - $END_TOTAL_KB)) KB"
		echo "------------------------------------------------------------------------"
	else
		echo "------------------------------------------------------------------------"
		echo " BBDD: $DB  /  Tablespace: $TBS"
		echo "------------------------------------------------------------------------"
		echo " Tamano inicial del tablespace: $INIT_TOTAL_KB KB"
		echo " Tamano final del tablespace: $END_TOTAL_KB KB"
		echo " Se ha reducido el tamano del tablespace en $(($INIT_TOTAL_KB - $END_TOTAL_KB)) KB"
		echo "------------------------------------------------------------------------"
	fi

	exit 0	
}

## OBTENER TBS_ID A PARTIR DEL TBS_NAME ##
## Input: <DB> <TBS>
## Output: <TBS_ID>
function tbs_name_to_tbs_id {
	if [ $# -ne 2 ]; then
		echo "La funcion tbs_name_to_tbs_id debe recibir la base de datos y un tablespace (nombre) como argumentos."
		exit -1
	fi

	db2 "connect to $DB" > /dev/null
	TBS_ID=$(db2 "get snapshot for tablespaces on $DB" | grep -p $TBS | grep "Tablespace ID" | awk '{print $4}')
	db2 "terminate" > /dev/null
	
	return $TBS_ID
}

## REDUCIR TABLESPACE ##
## Input: <DB> <TBS>
## Output: <REDUCED_SIZE in KB>
function reduce_tbs {
	if [ $# -ne 2 ]; then
		echo "La funcion reduce_tbs debe recibir la base de datos y un tablespace como argumentos."
		exit -1
	fi

	DB=$1
	TBS=$2
	
	echo "Reduciendo tablespace $TBS ..."
	
	db2 "connect to $DB" > /dev/null
		
	# Discriminamos si el tablespace esta en Automatic Storage o no.
	TBS_TYPE=$(db2 "get snapshot for tablespaces on $DB" | grep -p $TBS | grep Using | cut -d"=" -f2 | tr -d " ")
	
	if [ $TBS_TYPE = "Yes" ]; then
		db2 "alter tablespace $TBS reduce" > /dev/null
		echo "Se ha reducido el tablespace $TBS\n"
	else
		REDUCED_SIZE=0
		for PAGE_NUM in 10000 1000 100; 
		do
			CONDITION=0
			while [ $CONDITION -eq 0 ]; do
				db2 "alter tablespace $TBS reduce (all containers $PAGE_NUM)" > /dev/null
				CONDITION=$? 
				if [ $CONDITION -eq 0 ]; then
					let REDUCED_SIZE=$REDUCED_SIZE+$PAGE_NUM*$PAGE_SIZE
				fi	
			done
		done
		echo "Se ha reducido el tablespace $TBS en $REDUCED_SIZE KB.\n"	
	fi
	
	db2 "terminate" > /dev/null
	
	return $REDUCED_SIZE
}

## REORGANIZAR TABLESPACE ##
## Input: <DB> <RPT_FILE> <TYPE_TBS>
## Output: 10 -> No se necesitan reorganizar más tablas
##         20 -> Quedan tablas por reorganizar
function reorg_tbs {
	if [ $# -ne 3 ]; then
		echo "La funcion reorg_tbs debe recibir la base de datos, el archivo de report del db2dart y el tipo del tablespace como argumentos."
		exit -1
	fi

	DB=$1
	FILE=$2
	
	# Filtramos la entrada del archivos y escogemos las lineas que necesitamos.
	VAR=$(sed -n '/=>/ {p; n; p; n; p; n; p; n; p;}' $FILE)
	# Obtenemos el numero de tablas que tiene el tablespace.
	NUM_TABLES=$(($(echo $VAR | tr -s ' ' '\n' | grep -c '=>')+1))
	
	echo "El tablespace $TBS tiene $(($NUM_TABLES - 1)) posibles tablas a reorganizar.\n"
	
	# Cantidad de tablas que no necesitan reorganizacion.
	NO_REORG=0
	
	db2 "connect to $DB" > /dev/null
	
	echo "Reorganizando tablas...\n"
	
	# Para cada tabla en el tablespace, comprobamos si se debe reorganizar o no.
	COUNT=2
	while [ $COUNT -le $NUM_TABLES ]
	do
		
		#TABLE=$(echo $VAR | cut -d "=>" -f $COUNT | tr -d " " | cut -d ":" -f 2)
		TABLE=$(echo $VAR | cut -d "=>" -f $COUNT | sed 's/Table:/%/g' | cut -d "%" -f 2 |  cut -d " " -f 2 | tr -d " ")
		
		if [ "$(echo $VAR | cut -d "=>" -f $COUNT | grep REORG)" != "" ]; then
		
			# Comprobamos el tipo de tablespace (Datos, Indices)
			if [ "$3" = "D" ]; then
				echo "[$(($COUNT - 1))] - [$(date +"%H:%M:%S")] - Se procede a reorganizar la tabla $TABLE"
				RESULT=$(db2 "reorg table $TABLE")				
			elif [ "$3" = "I" ]; then
				echo "[$(($COUNT - 1))] - [$(date +"%H:%M:%S")] - Se procede a reorganizar los indices de la tabla $TABLE"
				RESULT=$(db2 "reorg indexes all for table $TABLE allow write access")
			else
				echo "El tipo del tablespace debe ser de datos (D) o de indices (I)."
				exit -1
			fi
			
			echo $RESULT
			
			if [ "$(echo $RESULT | grep successfully)" != "" ]; then
				TOTAL_REORG_TABLES=$(($TOTAL_REORG_TABLES + 1))
			fi

		else
			NO_REORG=$(($NO_REORG + 1))
			echo "[$(($COUNT - 1))] - [$(date +"%H:%M:%S")] - No se puede reorganizar la tabla $TABLE"
		fi
		COUNT=$(($COUNT + 1))
	done
		
	db2 "terminate" > /dev/null

	# Devolvemos un codigo segun si existen tablas a reorganizar o no.
	if [ $NO_REORG = $(($NUM_TABLES - 1)) ]; then
		return 10	# No se necesita reorganizar nada mas.
	else
		return 20 # Quedan tablas pendientes de reorganizar.
	fi
}

###################

function main {
	#### VARIABLES ####
	OPTION=$1
	DB=$2
	TBS=$3
	TYPE_TBS=$4
	###################
	
	readonly PAGE_SIZE=16
	
	case "$OPTION" in
		--rebuild|-rb)
			
			if [ $# -eq 4 ]; then
				ITERATIONS=100
			elif [ $# -eq 5 ]; then
				ITERATIONS=$5
				echo "Se realizaran $5 iteraciones como maximo.\n"
			else
				echo "ERROR en el numero de argumentos. La opcion REBUILD debe recibir 3 o 4 argumentos extra."
				exit -1
			fi
			
			# Obtener el tamano inicial del Tablespace.
			db2 "connect to $DB" > /dev/null
			INIT_TOTAL_KB=$(db2 -x "SELECT varchar(tbsp_name, 30) as tbsp_name, tbsp_total_pages*$PAGE_SIZE as Tamano FROM TABLE(MON_GET_TABLESPACE('',-2)) AS t where tbsp_name='$TBS'" | awk '{print $2}')
			db2 "terminate" > /dev/null
		
			TOTAL_REORG_TABLES=0
			RESULT=0
			ROUND=1
			while [[ $ROUND -le $ITERATIONS && $RESULT -ne 10 ]]
			do
				
				echo "Iteracion: $ROUND \n"
					
				# Reducir el TBS
				#reduce_tbs $DB $TBS
				#REDUCED=$?
				
				# Obtener el archivo RPT del DB2DART
				tbs_name_to_tbs_id $DB $TBS
				TBS_ID=$?
				
				echo "Generando archivo RPT..."
				
				DB2DART_RPT=$(db2dart $DB /LHWM /TSI $TBS_ID /np 0)
				RPT_PATH=$(db2 "get dbm cfg" | grep dump | tr -d " " | cut -d "=" -f 2)
				RPT_FILE=${RPT_PATH}"/DART0000/"${DB}".RPT"
				#RPT_FILE=$(echo $DB2DART_RPT | tr -d " " | cut -d ":" -f 5)
				
				
				echo "Archivo $RPT_FILE generado.\n"
				
				# Reorganizar TBS
				reorg_tbs $DB $RPT_FILE $TYPE_TBS
				RESULT=$?
				
				if [ $RESULT -eq 10 ]; then
					echo "No quedan tablas por reorganizar.\n"
				elif [ $RESULT -eq 20 ]; then
					echo "Existen tablas pendientes de reorganizar.\n"
				else
					echo "Se ha producido algun tipo de error al reorganizar."
					exit -1
				fi
				
				ROUND=$(($ROUND + 1))
				
				# Obtener el tamano final del Tablespace.
				db2 "connect to $DB" > /dev/null
				END_TOTAL_KB=$(db2 -x "SELECT varchar(tbsp_name, 30) as tbsp_name, tbsp_total_pages*$PAGE_SIZE as Tamano FROM TABLE(MON_GET_TABLESPACE('',-2)) AS t where tbsp_name='$TBS'" | awk '{print $2}')
				db2 "terminate" > /dev/null
			
				TOTAL_REDUCED_SIZE=$(($INIT_TOTAL_KB - $END_TOTAL_KB))
				
				echo "Se ha reducido el tamano del tablespace en $(($INIT_TOTAL_KB - $END_TOTAL_KB)) KB\n"
			
			done
			
			# Reducir el TBS
			reduce_tbs $DB $TBS

			# Obtener el tamano final del Tablespace.
			db2 "connect to $DB" > /dev/null
			END_TOTAL_KB=$(db2 -x "SELECT varchar(tbsp_name, 30) as tbsp_name, tbsp_total_pages*$PAGE_SIZE as Tamano FROM TABLE(MON_GET_TABLESPACE('',-2)) AS t where tbsp_name='$TBS'" | awk '{print $2}')
			db2 "terminate" > /dev/null
			
			TOTAL_REDUCED_SIZE=$(($INIT_TOTAL_KB - $END_TOTAL_KB))
			
			echo "------------------------------------------------------------------------"
			echo " BBDD: $DB  /  Tablespace: $TBS  /  Tipo: $TYPE_TBS"
			echo "------------------------------------------------------------------------"
			echo " Se han reorganizado un total de $TOTAL_REORG_TABLES tablas."
			echo " Tamano inicial del tablespace: $INIT_TOTAL_KB KB"
			echo " Tamano final del tablespace: $END_TOTAL_KB KB"
			echo " Se ha reducido el tamano del tablespace en $(($INIT_TOTAL_KB - $END_TOTAL_KB)) KB"
			echo "------------------------------------------------------------------------"
			
			exit 0
			;;
	
		--reduce|-rd)
		
			if [ $# -ne 3 ]; then
				echo "ERROR en el numero de argumentos. La opcion REDUCE debe recibir 2 argumentos extra."
				exit -1
			fi
			
			# Obtener el tamano inicial del Tablespace.
			db2 "connect to $DB" > /dev/null
			INIT_TOTAL_KB=$(db2 -x "SELECT varchar(tbsp_name, 30) as tbsp_name, tbsp_total_pages*$PAGE_SIZE as Tamano FROM TABLE(MON_GET_TABLESPACE('',-2)) AS t where tbsp_name='$TBS'" | awk '{print $2}')
			db2 "terminate" > /dev/null
	  	
			reduce_tbs $DB $TBS
			REDUCED_SIZE=$?
	
			# Obtener el tamano final del Tablespace.
			db2 "connect to $DB" > /dev/null
			END_TOTAL_KB=$(db2 -x "SELECT varchar(tbsp_name, 30) as tbsp_name, tbsp_total_pages*$PAGE_SIZE as Tamano FROM TABLE(MON_GET_TABLESPACE('',-2)) AS t where tbsp_name='$TBS'" | awk '{print $2}')
			db2 "terminate" > /dev/null
			
			TOTAL_REDUCED_SIZE=$(($INIT_TOTAL_KB - $END_TOTAL_KB))
			
			echo "------------------------------------------------------------------------"
			echo " BBDD: $DB  /  Tablespace: $TBS"
			echo "------------------------------------------------------------------------"
			echo " Tamano inicial del tablespace: $INIT_TOTAL_KB KB"
			echo " Tamano final del tablespace: $END_TOTAL_KB KB"
			echo " Se ha reducido el tamano del tablespace en $(($INIT_TOTAL_KB - $END_TOTAL_KB)) KB"
			echo "------------------------------------------------------------------------"
			
			exit 0
			;;
	
		--reorg|-ro)
	
			if [ $# -ne 4 ]; then
				echo "ERROR en el numero de argumentos. La opcion REORG debe recibir 3 argumentos extra."
				exit -1
			fi
			
			# Obtener el tamano inicial del Tablespace.
			db2 "connect to $DB" > /dev/null
			INIT_TOTAL_KB=$(db2 -x "SELECT varchar(tbsp_name, 30) as tbsp_name, tbsp_total_pages*$PAGE_SIZE as Tamano FROM TABLE(MON_GET_TABLESPACE('',-2)) AS t where tbsp_name='$TBS'" | awk '{print $2}')
			db2 "terminate" > /dev/null
	  	
			tbs_name_to_tbs_id $DB $TBS
			TBS_ID=$?
			
			DB2DART_RPT=$(db2dart $DB /LHWM /TSI $TBS_ID /np 0)
			RPT_FILE=$(echo $DB2DART_RPT | tr -d " " | cut -d ":" -f 5)
			
			TOTAL_REORG_TABLES=0
			
			reorg_tbs $DB $RPT_FILE $TYPE_TBS
			RESULT=$?
			
			if [ $RESULT -eq 10 ]; then
				echo "No quedan tablas por reorganizar."
			elif [ $RESULT -eq 20 ]; then
				echo "Existen tablas pendientes de reorganizar."
			else
				echo "Se ha producido algun tipo de error."
				exit -1
			fi
			
			# Obtener el tamano final del Tablespace.
			db2 "connect to $DB" > /dev/null
			END_TOTAL_KB=$(db2 -x "SELECT varchar(tbsp_name, 30) as tbsp_name, tbsp_total_pages*$PAGE_SIZE as Tamano FROM TABLE(MON_GET_TABLESPACE('',-2)) AS t where tbsp_name='$TBS'" | awk '{print $2}')
			db2 "terminate" > /dev/null
			
			TOTAL_REDUCED_SIZE=$(($INIT_TOTAL_KB - $END_TOTAL_KB))

			echo "------------------------------------------------------------------------"
			echo " BBDD: $DB  /  Tablespace: $TBS  /  Tipo: $TYPE_TBS"
			echo "------------------------------------------------------------------------"
			echo " Se han reorganizado un total de $TOTAL_REORG_TABLES tablas."
			echo " Tamano inicial del tablespace: $INIT_TOTAL_KB KB"
			echo " Tamano final del tablespace: $END_TOTAL_KB KB"
			echo " Se ha reducido el tamano del tablespace en $(($INIT_TOTAL_KB - $END_TOTAL_KB)) KB"
			echo "------------------------------------------------------------------------"
			
			exit 0
			;;
	
		--help|-h)
			print_help
			exit 0
			;;
	
		*)
			print_help
			exit -1
			;;
	esac
}


# Llamada a la gestion de Ctrl+C
trap interrupcion 1 2

# Llamada a inicio del programa
main $*

