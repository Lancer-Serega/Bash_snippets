#!/bin/bash

MYSQL_HOST=
MYSQL_PORT=
MYSQL_DB_NAME=
MYSQL_USER=
MYSQL_PASS=

FTP_HOST=
FTP_LOGIN=
FTP_PASS=

SSH_HOST=
SSH_LOGIN=root

# Путь для монтирования FTP в папку (должен существовать!)
PATH_TO_MOUNT=~/web/ftp

# Название папки с сайтом после входа на FTP сервер
DOMAIN_NAME=

# Название файла дампа
DUMP_FILE_NAME=dump.sql

# Цвет текста:
# Для вывода текста используйте ключи -en
# т.е echo -en ${RED} Красный текст ${NORMAL} нормальный текст
NORMAL='\e[97m'     # все атрибуты по умолчанию
BLACK='\033[0;30m'   # чёрный цвет знаков
RED='\033[0;31m'     # красный цвет знаков
GREEN='\033[0;32m'   # зелёный цвет знаков
YELLOW='\033[0;33m'  # желтый цвет знаков
BLUE='\033[0;34m'    # синий цвет знаков
MAGENTA='\033[0;35m' # фиолетовый цвет знаков
CYAN='\033[0;36m'    # цвет морской волны знаков
GRAY='\033[0;37m'    # серый цвет знаков

# TODO: Дописать для передачи параметров не через константы выше, а через консольные опции
#while getopts "h:s:" arg; do
#  case $arg in
#    h)
#      echo "usage"
#      ;;
#    s)
#      strength=$OPTARG
#      echo $strength
#      ;;
#  esac
#done
#exit

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 

# Создаем дамп на сервере
function createDumpToServer {
    echo -en "${NORMAL}===> Создаем дамп на сервере...\n${NORMAL}"
    ssh ${SSH_LOGIN}@${SSH_HOST} "bash /var/www/${DOMAIN_NAME}/server/backup.sh -m db" && echo -en "${GREEN}<=== Дамп успешно создан и отправлен на FTP сервер...\n${NORMAL}"
}

# Монтируем ФС сервера как папку в системе (only linux)
function mountServerPathAsFolderFS {
    if [ `ls ${PATH_TO_MOUNT} | wc -l` -eq 0 ]
    then
        echo -en "${NORMAL}===> Мотируем FTP как диск в папку '${PATH_TO_MOUNT}'\n${NORMAL}"
        if ! which fusermount > /dev/null; then
            echo -en "${NORMAL}Установка программы ${CYAN}fusermount\n${NORMAL}"
            sudo apt install fusermount 
        fi
        fusermount -u ${PATH_TO_MOUNT} 

        if ! which curlftpfs > /dev/null; then
            echo -en "${NORMAL}Установка программы ${CYAN}curlftpfs\n${NORMAL}"
            sudo apt install curlftpfs 
        fi
        curlftpfs ${FTP_LOGIN}:${FTP_PASS}@${FTP_HOST} ${PATH_TO_MOUNT} && echo -en "${GREEN}<=== Монтирование прошло успешно! '${CYAN}${PATH_TO_MOUNT}'\n${NORMAL}"
    else
        echo -en "${NORMAL}<=== Папка ${CYAN}'${PATH_TO_MOUNT}'${NORMAL} уже смонтирована'\n${NORMAL}"
    fi
}

# Распаковка дампа
function extractDump {
    echo -en "${NORMAL}===> Распаковка дампа...\n${NORMAL}"
    tar -xvzf ${PATH_TO_MOUNT}/${DOMAIN_NAME}/${DIR_NAME}/${FILE_NAME} -C ${CURRENT_DIR} && echo -en "${GREEN}<=== Распаковка дампа прошла успешно!\n${NORMAL}" && echo -en "${NORMAL}Находится в '${CYAN}${CURRENT_DIR}/${DUMP_FILE_NAME}'\n${NORMAL}"
}

# Импортирование дампа в БД
function importDumpFileToDB {
    cd ${CURRENT_DIR}
    if [[ -f ${DUMP_FILE_NAME} ]]
        then
            echo -en "${NORMAL}===> DROP DATABASE IF EXISTS ${MYSQL_DB_NAME};\n${NORMAL}"
            echo -en "${NORMAL}===> CREATE DATABASE IF NOT EXISTS ${MYSQL_DB_NAME}\n${NORMAL}"
            echo "DROP DATABASE IF EXISTS ${MYSQL_DB_NAME}; CREATE DATABASE IF NOT EXISTS ${MYSQL_DB_NAME}" | mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -u${MYSQL_USER} -p${MYSQL_PASS}
            echo -en "${CYAN}<=== База данных успешно очищена.\n${NORMAL}"
            if ! which pv > /dev/null; then
                echo -en "${NORMAL}Установка программы ${CYAN}pv\n${NORMAL}"
                sudo apt install pv
            fi

            if ! which mysql > /dev/null; then
                echo -en "${NORMAL}Установка программы ${CYAN}mysql\n${NORMAL}"
                sudo apt install mysql-client-core-5.7
            fi
            
            pv ${CURRENT_DIR}/${DUMP_FILE_NAME} | mysql -h${MYSQL_HOST} -P${MYSQL_PORT} -D${MYSQL_DB_NAME} -u${MYSQL_USER} -p${MYSQL_PASS} && rm ${DUMP_FILE_NAME} && echo -en "${GREEN}<=== Импортирование прошло успешно! =)\n";
        else
            echo -en "${RED}Файл дампа БД не найден! =(\n${NORMAL}";
            exit 1
    fi
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
echo -en "\n${NORMAL}Начало импорта...\n\n${NORMAL}"
CURRENT_DIR=`pwd`

# Создаем дамп на сервере
createDumpToServer

# Монтируем ФС сервера как папку в системе (only linux)
mountServerPathAsFolderFS

cd ${PATH_TO_MOUNT}/${DOMAIN_NAME}
DIR_NAME=`ls | tail -1`
cd ${DIR_NAME}
FILE_NAME=`ls | tail -1`

# Распаковка дампа
extractDump

# Импортирование дампа в БД
importDumpFileToDB

echo -en "\n${BLUE}Конец импорта!\n\n${NORMAL}"
exit 0
