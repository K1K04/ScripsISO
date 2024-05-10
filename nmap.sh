#!/usr/bin/env sh
# Autor: Kiko y Ivan
# Descripcion: Script para escanear puertos abiertos y protocolos en un segmento de red o una dirección IP.
# Version: 1.0
# Fecha de creacion: $(date)
# Variables: (las que se utilicen)

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
    fi
}

# Función para verificar la conexión a Internet
verificar_conexion_internet() {
    if ! ping -c 2 google.com &>/dev/null; then
        mostrar_error "No hay conexión a Internet. Por favor, asegúrate de tener conexión antes de ejecutar este script."
    fi
}

# Función para validar un segmento de red o una dirección IP
validar_segmento_red_o_ip() {
    local entrada=$1
    if [[ ! $entrada =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
        mostrar_error "'$entrada' no es un segmento de red válido ni una dirección IP válida."
    fi
}

# Función para verificar e instalar Nmap si es necesario
verificar_instalacion_nmap() {
    if ! command -v nmap &>/dev/null; then
        echo -e "${VERDE}Nmap no está instalado. Instalando...${RESET}"
        sudo apt-get update
        sudo apt-get install -y nmap
        # Verificar si la instalación fue exitosa
        if ! command -v nmap &>/dev/null; then
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
        mostrar_error "No hay ninguna dirección IP accesible en el segmento de red $segmento_red."
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
        echo "Operación cancelada."
        exit 0
    else
        mostrar_error "Respuesta inválida."
    fi
}

# Función para escanear puertos y protocolos
escanear_puertos() {
    local segmento_red=$1
    # Escaneo de puertos y filtrado de la salida
    nmap -p- -sS --open --min-rate 6000 -n -Pn $segmento_red | \
        grep -E -v "^(Starting Nmap|Host is up|Not shown|Some closed ports may be reported)"
}

# Función principal
main() {
    verificar_usuario_root
    verificar_conexion_internet
    verificar_instalacion_nmap

    # Validar que se pasó un argumento
    if [ $# -eq 0 ]; then
        mostrar_error "Uso: $0 <segmento_de_red_o_ip>"
    fi

    # Validar que el argumento sea un segmento de red válido o una dirección IP válida
    validar_segmento_red_o_ip "$1"

    # Validar la accesibilidad de la dirección IP
    verificar_accesibilidad_ip "$1"

    # Determinar si el argumento es un segmento de red o una dirección IP
    tipo=""
    destino=""
    if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
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
