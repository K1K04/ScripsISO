#!/usr/bin/env sh
# Autor: Kiko y Ivan
# Descripcion: Script para escanear puertos abiertos y protocolos en un segmento de red o una dirección IP.
# Version: 1.0.3
# Fecha de creacion: 14/05/2024
# Variables:
# - ROJO: Define el color rojo para los mensajes de error.
# - VERDE: Define el color verde para algunos mensajes informativos.
# - RESET: Restablece el color del texto a su valor predeterminado.
# Variables locales:
# - entrada: Almacena la entrada (segmento de red o dirección IP) que se valida en la función validar_entrada.
# - regExpIP: Expresión regular para validar una dirección IP.
# - regExpSegIP: Expresión regular para validar un segmento de red.
# - tipo: Almacena el tipo de entrada (segmento de red o dirección IP) determinado en la función principal.
# - destino: Almacena el valor de la entrada (segmento de red o dirección IP) para mostrar en los mensajes.
# - respuesta: Almacena la respuesta del usuario al confirmar una acción en el script.

# Colores para mensajes
ROJO='\033[0;31m'
VERDE='\033[0;32m'
RESET='\033[0m'

# Función para mostrar mensaje de error
mostrar_error() {
    echo -e "${ROJO}Error: $1${RESET}"
    exit 1
}

# Función para verificar si el usuario es root
verificar_usuario_root() {
    if [ "$(id -u)" != 0 ]; then
        mostrar_error "Este script debe ejecutarse con privilegios de root."
        exit 1
    fi
}

# Función para verificar la conexión a Internet
verificar_conexion_internet() {
    if [ ! ping -c 2 8.8.8.8 &> /dev/null ]; then
        mostrar_error "No hay conexión a Internet. Por favor, asegúrate de tener conexión antes de ejecutar este script."
        exit 1
    fi
}

# Función para validar un segmento de red o una dirección IP

validar_entrada() {
    local entrada=$1
    local regExpIP="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
    local regExpSegIP="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\/(3[0-2]|[12]?[0-9])$"
    if [[ $entrada =~ $regExpIP ]]; then
        echo -e "${VERDE}La entrada '$entrada' es una dirección IP válida.${RESET}"
    elif [[ $entrada =~ $regExpSegIP ]]; then
        echo -e "${VERDE}La entrada '$entrada' es un segmento de red válido.${RESET}"
    else
        mostrar_error "'$entrada' no es ni una dirección IP válida ni un segmento de red válido."
        exit 1
    fi
}

# Función para verificar e instalar Nmap según el administrador de paquetes

verificar_instalacion_nmap() {
    if ! command -v nmap &>/dev/null; then
        local package_manager

        # Detectar el administrador de paquetes disponible
        if command -v apt-get &>/dev/null; then
            package_manager="apt-get"
        elif command -v dnf &>/dev/null; then
            package_manager="dnf"
        elif command -v pacman &>/dev/null; then
            package_manager="pacman"
        elif command -v entropy &>/dev/null; then
            package_manager="entropy"
        elif command -v zypper &>/dev/null; then
            package_manager="zypper"
        else
            echo "No se pudo detectar un administrador de paquetes compatible. Por favor, instala Nmap manualmente."
            exit 1
        fi

        # Instalar Nmap usando el administrador de paquetes adecuado
        echo -e "${VERDE}Nmap no está instalado. Instalando...${RESET}"
        case $package_manager in
            "apt-get")
                sudo apt-get update &>/dev/null
                sudo apt-get install -y nmap &>/dev/null
                ;;
            "dnf")
                sudo dnf install -y nmap &>/dev/null
                ;;
            "pacman")
                sudo pacman -Sy --noconfirm nmap &>/dev/null
                ;;
            "entropy")
                sudo equo i nmap &>/dev/null
                ;;
            "zypper")
                sudo zypper install -y nmap &>/dev/null
                ;;
        esac

        # Verificar si la instalación fue exitosa
        if command -v nmap &>/dev/null; then
            echo -e "${VERDE}Nmap instalado.${RESET}"
        else
            mostrar_error "La instalación de Nmap falló. Por favor, instálalo manualmente e intenta de nuevo."
        fi
    fi
}

# Función para verificar la accesibilidad de una dirección IP
verificar_accesibilidad_ip() {
    local segmento_red=$1
    local ips=$(nmap -sn $segmento_red | grep "Nmap scan report" | cut -d" " -f5)
    local respuesta="no"
    for ip in $ips; do
        if ping -c 1 $ip &>/dev/null; then
            respuesta="si"
            break
        fi
    done
    if [ "$respuesta" = "no" ]; then
        mostrar_error "Dirección no accesible."
    fi
}

# Función para solicitar confirmación al usuario
confirmar() {
    local respuesta
    local tipo=$1
    local destino=$2
    read -p "Vas a escanear los puertos del $tipo $destino. ¿Estás seguro? (S/n): " respuesta
    respuesta=$(echo "$respuesta" | tr '[:upper:]' '[:lower:]')  # Convertir respuesta a minúsculas
    if [[ -z "$respuesta" ]] || [[ "$respuesta" == "s" ]]; then
        return 0  # Confirmación
    elif [[ "$respuesta" == "n" ]]; then
        mostrar_error "Operación cancelada."
        exit 0
    else
        mostrar_error "Respuesta inválida."
    fi
}

# Función para escanear puertos y protocolos y guardarlo en un log
escanear_puertos() {
    local segmento_red=$1
    local log="lognmap.txt"
    local log_time=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "\nFecha y hora de ejecución: $log_time\n" | tee -a $log
    # Escaneo de puertos y filtrado de la salida
    nmap -p- -sS --open --min-rate 6000 -n -Pn $segmento_red | \
        grep -E -v "^(Starting Nmap|Host is up|Not shown|Some closed ports may be reported)" | tee -a $log
    echo -e "\nResultado del nmap guardado en el fichero $log"
}

# Función principal
main() {
    clear
    verificar_usuario_root
    verificar_conexion_internet
    verificar_instalacion_nmap

    # Validar que se pasó un argumento
    if [ $# -eq 0 ]; then
        mostrar_error "Uso: $0 <segmento_de_red_o_ip>"
    fi

    # Validar que el argumento sea un segmento de red válido o una dirección IP válida
    validar_entrada "$1"

    # Validar la accesibilidad de la dirección IP
    verificar_accesibilidad_ip "$1"

    # Determinar si el argumento es un segmento de red o una dirección IP
    tipo=""
    destino=""
    regExpSegIP="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\/(3[0-2]|[12]?[0-9])$"
    if [[ $1 =~ regExpSegIP ]]; then
        tipo="segmento de red"
        destino="($1)"
    else
        tipo="dirección IP"
        destino="$1"
    fi

    # Mostrar mensaje de confirmación y solicitar confirmación al usuario
    confirmar "$tipo" "$destino" || exit 0  # Salir si la confirmación es negativa

    # Llamada a la función de escaneo de puertos y protocolos
    escanear_puertos "$1"
}

# Llamar a la función principal con los argumentos pasados al script
main "$@"
