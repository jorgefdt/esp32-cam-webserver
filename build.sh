#!/bin/bash

# Fail on any error
set -e

##
## Debug tasks
##
NOW=$(date '+%Y%m%d.%H%M%S')
CONFIG_BKP_ROOT=~/backup/arduino_config
CONFIG_BKP_DIR=$CONFIG_BKP_ROOT/$NOW
CONFIG_BKP_DIR_LAST=$CONFIG_BKP_ROOT/last


function backupArduinoConfig {
    mkdir -v -p ${CONFIG_BKP_DIR}
    echo ":: Saving arduino configuration to ${CONFIG_BKP_DIR} and creating symlink at ${CONFIG_BKP_DIR_LAST}"
    cp -rv ~/.arduino15 "${CONFIG_BKP_DIR}"
    cp -rv ~/.arduinoIDE "${CONFIG_BKP_DIR}" || true # ignore error if not source present
    cp -rv ~/Arduino "${CONFIG_BKP_DIR}" || true # ignore error if not source present

    # Remove the existing symlink if it exists to avoid nesting
    if [ -L "${CONFIG_BKP_DIR_LAST}" ]; then
        rm "${CONFIG_BKP_DIR_LAST}"
    fi
    ln -sf "${CONFIG_BKP_DIR}" "${CONFIG_BKP_DIR_LAST}"
}



function restoreArduinoConfig {
    # Confirmation prompt
    read -p "Are you sure you want to override current arduino configuration with ${CONFIG_BKP_DIR}? (y/n) " confirm
    if [[ "$confirm" != "y" ]]; then
        echo "Operation canceled."
        exit 0
    fi
    echo ":: Restoring arduino configuration from ${CONFIG_BKP_DIR}"
    rm -rf ~/.arduino15 ~/.arduinoIDE ~/Arduino
    # cp -r $CONFIG_BKP_DIR_LAST/.arduino15 ~/

    shopt -s dotglob  # Enable matching of hidden files
    cp -r "$CONFIG_BKP_DIR_LAST/"* ~/
    shopt -u dotglob  # Restore the default behavior

}

# Reads the configuration of the project in the current directory to file {project_name}.config
function readProjectConfig {
    INO_FILE="$(ls *.ino | head -n 1)"
    PROJECT_NAME="${INO_FILE%.*}"
    echo ":: Analizing project: ${PROJECT_NAME}"

    # Identify core.
    local CORE=$(arduino-cli core list  | tail --lines=+2)

    # Estimate the list of libraries used in the project.
    # This assumes you have used the libraries in your .ino file
    local LIBRARIES=$(grep "#include" *.ino | awk -F '[<>"]' '{print $2}' | sed 's/\.h//g' | sort -u | xargs) 

    # List installed libraries.
    local GLOBALLIBRARIES=$(arduino-cli lib list)

    # Generate config file.
    echo "FQBN: ${FQBN}" > ${PROJECT_NAME}.config
    echo "PORT: ${PORT}" >> ${PROJECT_NAME}.config
    echo "INO_FILE: ${INO_FILE}" >> ${PROJECT_NAME}.config
    echo "PROJECT_NAME: ${PROJECT_NAME%.*}" >> ${PROJECT_NAME}.config
    echo "CORE: ${CORE}" > ${PROJECT_NAME}.config
    echo "LIBRARIES: ${LIBRARIES}" >> ${PROJECT_NAME}.config    
    echo "GLOBALLIBRARIES: ${GLOBALLIBRARIES}" >> ${PROJECT_NAME}.config

    cat ${PROJECT_NAME}.config
}

# Setups the project environment.
function setupProject {
    PORT=/dev/ttyUSB0
    FQBN="esp32:esp32:esp32cam"
    CORE="esp32:esp32@2.0.17"

    INO_FILE="$(ls *.ino | head -n 1)"
    PROJECT_NAME=$(basename -- "$INO_FILE")
    echo ":: Project: ${PROJECT_NAME%.*}"

    # Install core packages
    arduino-cli core update-index
    arduino-cli core install ${CORE}

    # Install required libraries
    # arduino-cli lib install "WiFi" "Adafruit_Sensor"
    # WiFi         2.0.0   /home/jorge/.arduino15/packages/esp32/hardware/esp32/2.0.17/libraries/WiFi
    # DNSServer    2.0.0   /home/jorge/.arduino15/packages/esp32/hardware/esp32/2.0.17/libraries/DNSServer
    # ArduinoOTA   2.0.0   /home/jorge/.arduino15/packages/esp32/hardware/esp32/2.0.17/libraries/ArduinoOTA
    # Update       2.0.0   /home/jorge/.arduino15/packages/esp32/hardware/esp32/2.0.17/libraries/Update
    # ESPmDNS      2.0.0   /home/jorge/.arduino15/packages/esp32/hardware/esp32/2.0.17/libraries/ESPmDNS
    # FS           2.0.0   /home/jorge/.arduino15/packages/esp32/hardware/esp32/2.0.17/libraries/FS
    # SPIFFS       2.0.0   /home/jorge/.arduino15/packages/esp32/hardware/esp32/2.0.17/libraries/SPIFFS

}

# Builds and upload the sketch in the current directory.
function buildProject {
    PORT=/dev/ttyUSB0
    FQBN="esp32:esp32:esp32cam"
    CORE="esp32:esp32@2.0.17"

    INO_FILE="$(ls *.ino | head -n 1)"
    PROJECT_NAME=$(basename -- "$INO_FILE")
    echo ":: Building project: ${PROJECT_NAME%.*}"

     # Compile and upload the sketch
    echo ":: Compiling ${INO_FILE}"
    # --clean
    arduino-cli compile --fqbn "${FQBN}" ${INO_FILE}

    echo ":: Uploading to ${PORT}"
    arduino-cli upload -p $PORT --fqbn "${FQBN}" ${INO_FILE}

    echo ":: Monitoring ${PORT}"
    arduino-cli monitor -p $PORT --config 115200 -b "${FQBN}"   
}

##
## -- MAIN
##

# Main logic to handle command arguments
case "$1" in
    backup)
        backupArduinoConfig
        tree -a -L 3 ~/backup
        ;;
    restore)
        restoreArduinoConfig
        tree -a -L 1 ~/.arduino15
        ;;
    remove-arduino)
        rm -fr ~/.arduino15 ~/.arduinoIDE ~/Arduino
        ;;
    read-project)
        readProjectConfig
        ;;
    setup-project)
        setupProject
        ;;
    build-project)
        buildProject
        ;;
    *)
        echo "Usage: $0 {backup|restore|remove-arduino|read-project|write-project}"
        exit 1
        ;;
esac

# EOF
