#!/bin/bash

# Exit codes : 
# 1 : File or ressource not found
# 2 : Access right problem

###########################################
## Définition des fonctions du programme ##
###########################################

# Fonction d'affichage des erreurs
# Params : 
	# $1 : Message d'erreur
	# $2 : exit code
logger () {
	# if (logger_is_enabled)
		# log_to_file
	echo $#
	if [ $# -ge 1 ]; then
		if ! [ -z "$1" ]; then 
			dialog --title "Une erreur à été rencontrée" --msgbox "${1}" 0 0
		fi
	else
		logger "Logger called but no params found" 1
	fi
	if [ $# -eq 2 ]; then
		if ! [ -z "$2" ]; then
			exit $2
		fi
	fi
}

# Vérification des paramètres de lancement
function verifyParams {
	if [ $# -gt 0 ]; then
		for (( i=0; i<=$#; i+=1 ))
		do
			local index=$((i+1))
			if [ ${!i} = "--conf" ];then
				if [ $index -gt $# ]; then
					logger "Usage --conf <config file>"
				else
					if [ -f ${!index} ]; then
						if [ -r ${!index} ]; then
							# echo "Conf file found ${!index}"
							conf=${!index}
						else
							logger "File not readable" 2
						fi
					else
						logger "File not found" 1
					fi
				fi
			elif [ ${!i} = "--backupdir" ]; then
				if [ $index -gt $# ]; then
					logger "Usage --backupdir <directory>"
				else
					if [ -d ${!index} ]; then
						if [ -r ${!index} ]; then
							# echo "Backup Directory found ${!index}"
							backupdir=${!index}
						else
							logger "Directory not readable" 2
						fi
					else
						logger "Backup Directory not found" 1
					fi
				fi
			fi
		done
	else
		local error=""
		if [ -f $conf ]; then
			if ! [ -r $conf ]; then
				error="Config File not readable"$'\n'" "
			fi
		else
			error="${error}File not found"$'\n'
		fi
		if [ -d $backupdir ]; then
			if ! [ -r $backupdir ]; then
				error="${error}BackupDir not readable"$'\n'" "
			fi
		else
			error="${error} BackupDir not found"$'\n'" "
		fi
		if ! [ -z "$error" ]; then
			logger "$error" 1
		fi
	fi
}

# Lecture des chemins surveillés
function readPaths {
	# TODO : rename les var files file en générique
	local found=""
	local error=""
	# Lecture du fichier contenant les différents chemins à sauvegarder
	while read -r line; do
		if [ -f $line ] || [ -d $line ]; then
			if [ -r $line ]; then
				if [ -z $found ]; then
					found=$line
				else
					found="${found} ${line}"
				fi
			else
				error=${error}"\nProblème de droit d'accès : "$line
			fi
		else
			if ! [ -d $line ]; then
				error=${error}"\nFichier inexistant : "$line
			fi
		fi
	done <<< "$conf";
	if [ -z $found ]; then
		logger "Aucun fichier n'a été trouvé" 1
	else	
		# TODO Faire fonctionner en ajoutant les synopsis de got aux archives
		doTheTar "$found"
	fi
	if ! [ -z "$error" ]; then
		dialog --title "Tous les fichiers n'ont pas étés trouvés, continuer ?" --yesno "$error" 0 0
		local answer=$?
		if [ $answer -eq  0 ]; then
			exit 4
		fi
	fi
}

# Création du nom de la sauvegarde
function chooseBackupName {
	local date=$(date +%Y-%m-%d_%H-%M)
	local name=${backupdir}${date}.tar.gz
	
	# Différence entre deux backups effectuées au même moment
	if [ -f $name ]; then
		count=$(find ${backupdir}${date}* -maxdepth 1 -type f | wc -l)
		name=${backupdir}${date}_${count}.tar.gz
	fi
	echo $name
}

# Création de la sauvegarde
function doTheTar {
	# TODO : faire une redirection des erreurs dans une variable pour l'afficher dans le logger
	local error="$(tar -zcvf "$(chooseBackupName)" --files-from $1 -C / home/${USER}/Got 2>&1 > /dev//null)"
	if ! [ -z "$error" ]; then
		logger "$error"
	fi
}

# Maintien du nombre de backup a 100 maximum
function clearOldBackups {
	local backupCount=`ls $backupdir | grep -E "[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}(_[0-9]+)?\.tar\.gz" | wc -l`
	if [ $backupCount -ge 100 ]; then
		file=`ls -tr backups | head -n 1`
		`rm ${backupdir}$file`
	fi
}

##########################################
# A faire seulement lors de l'installation
###
function prepareEncryption {
	gpg2 --gen-key
}
##########################################

# Chiffrement de la sauvegarde
## $1 nom du fichier a encrypter
## suivi de cat $fichierConf
## - $2 est le nom du destinataire
## - $3 est la passphrase du tar
function encrypt {
	gpg2 --symmetric --batch --yes --recipient $2 --passphrase $3 --encrypt $1
	rm -f $1
}

# Déchiffrement de la sauvegarde
## $1 nom du fichier a décrypter
## suivi de cat $fichierConf
## - $3 est la passphrase du tar
function decrypt {
	gpg2 --passphrase $3 --decrypt $1
}

function doTheBackup {
	verifyParams "$@"
	chooseBackupName
	readPaths
	clearOldBackups
}

###############################
## Préparation des variables ##
###############################
conf="backup.conf"
fichierConf="kublike.conf"
backupdir="backups/"

############################
## Execution du programme ##
############################
doTheBackup "$@"
#encrypt $name `cat $fichierConf`

# TODO : penser à utiliser des local
# TODO : fonction magique
# TODO : tester avec des chemins absolus