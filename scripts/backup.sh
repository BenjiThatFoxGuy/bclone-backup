#!/bin/bash

. /app/includes.sh

function clear_dir() {
    rm -rf "${BACKUP_DIR}"
}

function backup_init() {
    NOW="$(date +"${BACKUP_FILE_DATE_FORMAT}")"
    BACKUP_FILE_DB_POSTGRESQL="${BACKUP_DIR}/db.${NOW}.dump"
    BACKUP_FILE_ZIP="${BACKUP_DIR}/backup.${NOW}.${ZIP_TYPE}"
}

function backup_folders() {
    color blue "Backup folders"

    for BACKUP_FOLDER_X in "${BACKUP_FOLDER_LIST[@]}"
    do
        local BACKUP_FOLDER_NAME=$(echo ${BACKUP_FOLDER_X} | cut -d: -f1)
        local BACKUP_FOLDER_PATH=$(echo ${BACKUP_FOLDER_X} | cut -d: -f2)
        local BACKUP_FILE="${BACKUP_DIR}/${BACKUP_FOLDER_NAME}.${NOW}.tar"

        if [[ -d "${BACKUP_FOLDER_PATH}" ]]; then
            if [[ -n "$(ls -A "${BACKUP_FOLDER_PATH}" 2>/dev/null)" ]]; then
                color blue "Backing up $(color yellow "[${BACKUP_FOLDER_NAME}]")"
                tar -C "${BACKUP_FOLDER_PATH}" -cf "${BACKUP_FILE}" .
                color blue "Backed up files:"
                tar -tf "${BACKUP_FILE}"
            else
                color yellow "Skipping empty folder: ${BACKUP_FOLDER_PATH}"
                continue
            fi
        else
            color yellow "${BACKUP_FOLDER_PATH} does not exist, skipping"
        fi
    done
}


function backup_db_postgresql() {
    local i=0
    local HAS_ERROR="FALSE"
    local TOTAL_DBS=0
    
    while true; do
        local VAR_NAME="PG_CONNECTION_STRING"
        if [[ $i -gt 0 ]]; then
            VAR_NAME="${VAR_NAME}_${i}"
        fi
        
        if [[ -z "${!VAR_NAME}" ]]; then
            break
        fi

        local BACKUP_FILE="${BACKUP_DIR}/db${i}.${NOW}.dump"
        local MASKED_CONN=$(echo "${!VAR_NAME}" | sed 's|//.*@|//***:***@|')
        color blue "Backing up PostgreSQL database ${i} (${MASKED_CONN})"
    
        if ! pg_dump -Fc "${!VAR_NAME}" -f "${BACKUP_FILE}"; then
            color red "Backup PostgreSQL database ${i} failed"
            HAS_ERROR="TRUE"
        else
            TOTAL_DBS=$((TOTAL_DBS + 1))
        fi
        
        ((i++))
    done

    if [[ $TOTAL_DBS -eq 0 ]]; then
        color red "No PostgreSQL databases were backed up successfully"
        HAS_ERROR="TRUE"
    fi

    if [[ "${HAS_ERROR}" == "TRUE" ]]; then
        send_mail_content "FALSE" "Backup failed at $(date +"%Y-%m-%d %H:%M:%S %Z"). Reason: One or more PostgreSQL database backups failed."
        exit 1
    fi

    color green "Successfully backed up ${TOTAL_DBS} PostgreSQL database(s)"
}

function backup() {
    mkdir -p "${BACKUP_DIR}"

    backup_folders

    backup_db_postgresql
}

function backup_package() {
    if [[ "${ZIP_ENABLE}" == "TRUE" ]]; then
        color blue "Package backup file"

        UPLOAD_FILE="${BACKUP_FILE_ZIP}"

        if [[ "${ZIP_TYPE}" == "zip" ]]; then
            7z a -tzip -mx=9 -p"${ZIP_PASSWORD}" "${BACKUP_FILE_ZIP}" "${BACKUP_DIR}"/*  >/dev/null 2>&1 
        else
            7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mhe=on -p"${ZIP_PASSWORD}" "${BACKUP_FILE_ZIP}" "${BACKUP_DIR}"/*  >/dev/null 2>&1
        fi

        ls -lah "${BACKUP_DIR}"

    else
        color yellow "Skipped package backup files"

        UPLOAD_FILE="${BACKUP_DIR}"
    fi
}

function upload() {
    # upload file not exist
    if [[ ! -e "${UPLOAD_FILE}" ]]; then
        color red "Upload file not found"

        send_mail_content "FALSE" "File upload failed at $(date +"%Y-%m-%d %H:%M:%S %Z"). Reason: Upload file not found."

        exit 1
    fi

    # upload
    local HAS_ERROR="FALSE"

    for RCLONE_REMOTE_X in "${RCLONE_REMOTE_LIST[@]}"
    do
        color blue "Upload backup file to storage system $(color yellow "[${RCLONE_REMOTE_X}]")"

        rclone ${RCLONE_GLOBAL_FLAG} copy "${UPLOAD_FILE}" "${RCLONE_REMOTE_X}"
        if [[ $? != 0 ]]; then
            color red "upload failed"

            HAS_ERROR="TRUE"
        fi
    done

    if [[ "${HAS_ERROR}" == "TRUE" ]]; then
        send_mail_content "FALSE" "File upload failed at $(date +"%Y-%m-%d %H:%M:%S %Z")."

        exit 1
    fi
}

function clear_history() {
    if [[ "${BACKUP_KEEP_DAYS}" -gt 0 ]]; then
        for RCLONE_REMOTE_X in "${RCLONE_REMOTE_LIST[@]}"
        do
            color blue "Delete backup files from ${BACKUP_KEEP_DAYS} days ago $(color yellow "[${RCLONE_REMOTE_X}]")"

            mapfile -t RCLONE_DELETE_LIST < <(rclone ${RCLONE_GLOBAL_FLAG} lsf "${RCLONE_REMOTE_X}" --min-age "${BACKUP_KEEP_DAYS}d")

            for RCLONE_DELETE_FILE in "${RCLONE_DELETE_LIST[@]}"
            do
                color yellow "Deleting \"${RCLONE_DELETE_FILE}\""

                rclone ${RCLONE_GLOBAL_FLAG} delete "${RCLONE_REMOTE_X}/${RCLONE_DELETE_FILE}"
                if [[ $? != 0 ]]; then
                    color red "Deleting \"${RCLONE_DELETE_FILE}\" failed"
                fi
            done
        done
    fi
}

color blue "Running the backup program at $(date +"%Y-%m-%d %H:%M:%S %Z")"

init_env
check_rclone_connection

clear_dir
backup_init
backup
backup_package
upload
clear_dir
clear_history

send_mail_content "TRUE" "The file was successfully uploaded at $(date +"%Y-%m-%d %H:%M:%S %Z")."
send_ping

color none ""
