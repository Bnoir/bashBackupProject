#!/bin/bash
source uploadBackup.bash

# Il faut donc que chaque heure (13:00, 14:00, 15:00, ... ), le script:
# synchronise les synopsis, 
# effectue un backup
# et l’upload sur le service d’upload de backups, le tout automatiquement.
upload 