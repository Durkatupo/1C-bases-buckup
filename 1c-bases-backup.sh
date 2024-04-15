#!/bin/bash

# если не указан аргумент №1 то запускаем скрипт
# иначе выполняем скрипт
if [ -z ${1} ]
then
	# если нужно, то создаём папку для записи логов
	logs_dir="/mnt/backup/logs"
	year=`date +"%Y"`
	month=`date +"%m"`
	day=`date +"%d"`

	log_dir="${logs_dir}/${year}/${month}"
	log_filename="1c-bases-backup-`date +'%Y%m%d-%H%M%S'`.log"

	if ! [ -d ./${log_dir} ]
	then
		mkdir -p ${log_dir}
	fi
	
	$0 start >> "${log_dir}/${log_filename}" 2>&1
	gzip "${log_dir}/${log_filename}"
else
	echo -e "\n---------- START BACKUP ----------\n`date +'%Y%m%d-%H%M%S'`\n"

	dir_backup_from="/mnt/1c-bases"
	dir_backup_to="/mnt/backup/1c-bases"
	dir_script=`pwd`
	objects_to_backup_ar=("1Cv8.1CD" "1Cv8Log" "attached-files")
	dir_backup_to_remote="/mnt/wdmycloud/BACKUP/1c-bases"

	cd ${dir_backup_from}

	# останавливаем веб сервер
	systemctl stop apache2

	# перебираем базы по одной
	# #копируем файл базы и папку с логами
	# архивируем по отдельности файл базы и папку с логами
	find . -mindepth 1 -maxdepth 1 -type d -printf "%P\n" | sort |
	while read dir_to_work
	do
		echo "${dir_to_work}"

		for object_to_backup in ${objects_to_backup_ar[@]}
		do
		echo "${object_to_backup}"
			#cp -ar "${dir_to_work}/${object_to_backup}" "${dir_backup_to}"
			#sh -c "tar -cf - '${dir_backup_to}/${object_to_backup}' | 7z a -si -sdel -mx=2 '${dir_backup_to}/${dir2work}-${object_to_backup}-`date +'%Y%m%d-%H%M%S'`.tar.7z'"
			sh -c "7z a -mx=3 '${dir_backup_to}/${dir_to_work}-${object_to_backup}-`date +'%Y%m%d-%H%M%S'`.7z' '${dir_to_work}/${object_to_backup}'"
		done
	done

	# запускаем веб сервер
	systemctl start apache2

	#exit


	echo -e "\n---------- DELETE/MOVE BACKUPS ----------\n`date +'%Y%m%d-%H%M%S'`\n"

	# проверяем примонтирована ли папка удалённого хранилища
	paths=`df -h | grep /mnt/wdmycloud`
	# если не примонтирована, то пробуем смонтировать
	if [ -z "$paths" ]
	then
		mount -a
	fi

	# проверяем ещё раз примонтирована ли папка удалённого хранилища
	paths=`df -h | grep /mnt/wdmycloud`
	# если примонтирована, то обрабатываем файлы бэкапов
	if ! [ -z "$paths" ]
	then
		regex=".*([0-9-]{15})\.7z"

		# удаляем файлы в удалённом хранилище
		# старше X дней
		days_ago=30
		# выводим список файлов
		echo -e "\nФайлы для удаления в удалённом хранилище старше ${days_ago} дней:\n"
		#find "${dir_backup_to_remote}" -type f -mtime +${days_ago} -printf "%P\n" | sort
		# удаляем файлы
		#find "${dir_backup_to_remote}" -type f -mtime +${days_ago} -exec rm -rf {} \;

		datetime_point=`date -d "-${days_ago} days" +%Y%m%d-%H%M%S`
		echo -e "${datetime_point}\n\n"

		find "${dir_backup_to_remote}" -type f -regextype sed -regex ".*\([0-9\-]\{15\}\)\.7z" |
		while read filename
		do
			[[ ${filename} =~ ${regex} ]]
		datetime_file=${BASH_REMATCH[1]}
		
			if [[ "${datetime_file}" < "${datetime_point}" ]]
		then
				echo $(basename "${filename}")
				rm -rf "${filename}"
			fi
		done


		# переносим файлы бэкапов в удалённое хранилище
		# старше X дней
		days_ago=2
		# выводим список файлов
		echo -e "\nФайлы для перемещения в удалённое хранилище старше ${days_ago} дней:\n"
		#find "${dir_backup_to}" -type f -mtime +${days_ago} -printf "%P\n" | sort
		# переносим файлы
		#find "${dir_backup_to}" -type f -mtime +${days_ago} -exec mv -t "${dir_backup_to_remote}" {} \;

		datetime_point=`date -d "-${days_ago} days" +%Y%m%d-%H%M%S`
		echo -e "${datetime_point}\n\n"

		find "${dir_backup_to}" -type f -regextype sed -regex ".*\([0-9\-]\{15\}\)\.7z" |
		while read filename
		do
			[[ ${filename} =~ ${regex} ]]
		datetime_file=${BASH_REMATCH[1]}
		
			if [[ "${datetime_file}" < "${datetime_point}" ]]
		then
				echo $(basename "${filename}")
				mv -t "${dir_backup_to_remote}" "${filename}"
			fi
		done
	fi

	echo -e "\n`date +'%Y%m%d-%H%M%S'`\n---------- END BACKUP ----------\n"
fi

# cron
#15	22	*	*	1-5	/home/install/1c/1c-bases-backup.sh
#*/5	*	*	*	1-5	/home/install/SCRIPTS/exchange-remount.sh
#0	3	*	*	1-5	/sbin/reboot & > /var/log/reboot.log
