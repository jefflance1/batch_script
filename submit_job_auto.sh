#!/bin/bash
# SCRIPT: submit_job.sh
# AUTHOR: Jeff Poole
#
#
#The purpose of this script is to create a shell which can
#be used to submit batch jobs
#####DEFINE VARIABLES HERE################
BASE_DIR=$HOME
ARCH_JOB_ID_DIR=""
ARCH_PROP_DIR=$BASE_DIR/properties
ARCH_LOG_DIR="$BASE_DIR/logs"
ARCH_LOG_FILE=""
ARCH_LOG_DATE_TIME=$(date +"%y_%m_%d_%H:%M:%S")
ARCH_START_PROC_SECONDS=""
ARCH_END_PROC_SECONDS=""
ARCH_PROCESS_NAME=""
ARCH_APP_CODE=""
ARCH_WORKING_SECONDS=""
ARCH_DISP_DATE=""
ARCH_LOG_ERROR=""
ARCH_ERROR_PATH=""
ARCH_ERROR_FILE=""
ARCH_OUT_PATH=""
ARCH_OUT_FILE=""
#####DEFINE FUNCTIONS HERE###############
##start_process takes in process name as argument and sets up all files for logging
##as well as tracking of elapsed time for process
function start_process(){
	ARCH_ERROR_PATH="$BASE_DIR/stderr/$ARCH_APP_CODE"
	test_dir $ARCH_ERROR_PATH
	ARCH_OUT_PATH="$BASE_DIR/stdout/$ARCH_APP_CODE"
	test_dir $ARCH_OUT_PATH
	ARCH_START_PROC_SECONDS=$(date +%s)
	ARCH_DISP_DATE=$(date +"%c")
	export ARCH_PID=$$
	test_dir "$ARCH_LOG_DIR/$ARCH_APP_CODE"
	export ARCH_LOG_FILE="$ARCH_LOG_DIR/$ARCH_APP_CODE/${ARCH_PROCESS_NAME}_${ARCH_LOG_DATE_TIME}_${ARCH_PID}.log"
	zero_file $ARCH_LOG_FILE
	log_info "###################################################" "INFO"
	log_info "###################################################" "INFO"
	log_info " " "INFO"
	log_info "Process $ARCH_PROCESS_NAME started at $ARCH_DISP_DATE" "INFO"
	log_info "Process ID for $ARCH_PROCESS_NAME PID=$ARCH_PID" "INFO"
	log_info " " "INFO"
	log_info "###################################################" "INFO"
	log_info "###################################################" "INFO"
	ARCH_ERROR_FILE="$ARCH_ERROR_PATH/${ARCH_PROCESS_NAME}_${ARCH_LOG_DATE_TIME}_STDERR.error"
	zero_file "$ARCH_ERROR_FILE"
	ARCH_OUT_FILE="$ARCH_OUT_PATH/${ARCH_PROCESS_NAME}_${ARCH_LOG_DATE_TIME}_STDOUT.out"
	zero_file "$ARCH_OUT_FILE"	
#Redirect stderr to file
    exec 2>> "$ARCH_ERROR_FILE"
#Redirect stdout to file
	exec 1>> "$ARCH_OUT_FILE"
}

##log the job information to architecture table for running status
function log_job_db(){
	load_prop "$ARCH_PROP_DIR/ARCH_PROP.prop"
	ARCH_JOB_ID_DIR="$BASE_DIR/outfile/ARCH"
	test_dir $ARCH_JOB_ID_DIR
	export ARCH_JOB_ID_FILE="$ARCH_JOB_ID_DIR/${ARCH_PROCESS_NAME}_${ARCH_LOG_DATE_TIME}_${ARCH_PID}_JOB_ID.prop"
	zero_file $ARCH_JOB_ID_FILE
	mvn -e -f$BASE_DIR/$ARCH_POM_DIR exec:java -Dexec.args="1"
	ARCH_RET_VALUE=${?}
	load_prop $ARCH_JOB_ID_FILE
	test_error $ARCH_RET_VALUE
	rm $ARCH_JOB_ID_FILE
}

##update database with successful completion
function update_job_success_db(){
	mvn -e -f$BASE_DIR/$ARCH_POM_DIR exec:java -Dexec.args="2"
	ARCH_RET_VALUE=${?}
	test_error ${ARCH_RET_VALUE}
}

##update database with abend status
function update_job_abend_db(){
	mvn -e -f$BASE_DIR/$ARCH_POM_DIR exec:java -Dexec.args="3"
	ARCH_RET_VALUE=${?}
	test_error ${ARCH_RET_VALUE}
}

##load properties from .prop file to envrionment variables
function load_prop(){
	while read line          
	do  
		export $line           
	done < $1
}

##read .version file for job and version any files with a data and time stamp and place in version folder
function version_files(){
	if [ -f "$ARCH_PROP_DIR/$ARCH_APP_CODE/$ARCH_PROCESS_NAME.version" ]
	then
		VERSION_DIR=$BASE_DIR/version/$ARCH_APP_CODE/$ARCH_PROCESS_NAME
		test_dir $VERSION_DIR 
		while read vers_line          
		do  
			if [ -f "${vers_line}" ]
			then
				cp $vers_line $VERSION_DIR/"${vers_line##*/}".$(date +"%y_%m_%d_%H:%M:%S") 
				if [ $? -ne 0 ]
				then
					echo "ERROR VERSIONING $vers_line" >> "$ARCH_ERROR_FILE"
					log_error
				else
					log_info "$vers_line - FILE VERSIONED" "INFO" 
				fi
			else
				log_info "$vers_line - FILE NOT FOUND" "INFO"
			fi         
		done < "$ARCH_PROP_DIR/$ARCH_APP_CODE/$ARCH_PROCESS_NAME.version"
	else
		log_info "NO FILES TO VERSION" "INFO"
	fi
}

##read .delete file for job and delete files
function delete_files(){
	if [ -f "$ARCH_PROP_DIR/$ARCH_APP_CODE/$ARCH_PROCESS_NAME.delete" ]
	then
		while read del_line          
		do 
			if [ -f "${del_line}" ]
			then 
				rm $del_line
				if [ $? -ne 0 ]
				then
					echo "ERROR DELETING $del_line" >> "$ARCH_ERROR_FILE"
					log_error
				else
					log_info "$del_line - FILE DELETED" "INFO"	
				fi
			else
				log_info "$del_line - FILE NOT FOUND" "INFO"
			fi            
		done < "$ARCH_PROP_DIR/$ARCH_APP_CODE/$ARCH_PROCESS_NAME.delete"
	else
		log_info "NO FILES TO DELETE" "INFO"
	fi
}

##sort file(s)
function sort_files(){
	while read sort_line
	do
		sort " " $sort_line
		if [ $? -ne 0 ]
		then
			echo "ERROR SORTING $sort_line" >> "$ARCH_ERROR_FILE"
			log_error
		else
			log_info "$sort_line EXECUTED" "INFO"
		fi
	done < $1
}

##end_process calculates elapsed time and removes files where stderr and stdout were redirected
function end_process(){
	log_error
	log_output
	ARCH_END_PROC_SECONDS=$(date +%s)
	if [ -z "$ARCH_START_PROC_SECONDS" ]
	then
	  ARCH_START_PROC_SECONDS=$(date +%s)
	fi
	ARCH_DISP_DATE=$(date +"%c")
	log_info " " "INFO"
	log_info "####################################################################################" "INFO"
	log_info "####################################################################################" "INFO"
	log_info " " "INFO"
	log_info "Process $ARCH_PROCESS_NAME finished  at $ARCH_DISP_DATE" "INFO"
	log_info " " "INFO"
	log_info "####################################################################################" "INFO"
	log_info "####################################################################################" "INFO"
	log_info " " "INFO"
	get_elapsed_time $(($ARCH_END_PROC_SECONDS - $ARCH_START_PROC_SECONDS)) $ARCH_PROCESS_NAME
	log_info " " "INFO"
	log_info "####################################################################################" "INFO"
	log_info "####################################################################################" "INFO"	
	rm $ARCH_ERROR_FILE
	rm $ARCH_OUT_FILE
}


##test for existence of directory; if not present create
function test_dir(){
	if [ ! -d "$1" ]
	then 
	   mkdir -p $1
	fi
}

##test for existence of file; if present clear, if not present create
function zero_file(){
	if [ -f "$1" ] 
	then
	   >$1
	else
	   touch $1
	fi
}

##log information to log_file, test if log_file doesn't exist put information to default log file	
function log_info(){
	echo "$2 ($(date +"%c")) -- $1" >> "$ARCH_LOG_FILE"
}

##put elapsed time into user friendly format
function get_elapsed_time(){
	ARCH_SEC=$1
	ARCH_NAME=$2
	(( SEC < 60 )) && log_info "$ARCH_NAME Elapsed time: $ARCH_SEC seconds" "INFO"
	(( SEC >= 60 && SEC < 3600 )) && log_info "$ARCH_NAME Elapsed time:$(( SEC / 60 )) min $(( SEC % 60 )) sec" "INFO"
	(( SEC > 3600 )) && log_info "$ARCH_NAME Elapsed time: $(( SEC / 3600 )) hr $(( (SEC % 3600) / 60 )) min $(((SEC % 3600) % 60 )) sec" "INFO"
}

##put contents of error_file to variable and log error
function log_error(){
	ARCH_ERROR=$(< $ARCH_ERROR_FILE)
	if [ ! -z "${ARCH_ERROR}" ]
	then
		log_info "$ARCH_ERROR" "ERROR"
		>$ARCH_ERROR_FILE
	fi
}

##put contents of output_file to variable and log output
function log_output(){
	ARCH_OUTPUT=$(< $ARCH_OUT_FILE)
	log_info "$ARCH_OUTPUT" "OUTPUT"
	>$ARCH_OUT_FILE
}

##test for error from process
function test_error(){
	if [ $1 -ne 0 ]
	then
   	   log_error
	fi
}

export ARCH_PROCESS_NAME=$1
export ARCH_APP_CODE=${ARCH_PROCESS_NAME:0:4}
load_prop "$ARCH_PROP_DIR/$ARCH_APP_CODE/$ARCH_PROCESS_NAME.prop"
start_process 
log_job_db
if [ -f "$ARCH_PROP_DIR/$ARCH_APP_CODE/$ARCH_PROCESS_NAME.sortbefore" ]
then
	sort_files $ARCH_PROP_DIR/$ARCH_APP_CODE/$ARCH_PROCESS_NAME.sortbefore
fi
update_job_success_db
if [ -f "$ARCH_PROP_DIR/$ARCH_APP_CODE/$ARCH_PROCESS_NAME.sortafter" ]
then
	sort_files $ARCH_PROP_DIR/$ARCH_APP_CODE/$ARCH_PROCESS_NAME.sortafter
fi
version_files
delete_files
end_process

