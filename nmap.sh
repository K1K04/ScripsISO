#!/usr/bin/env bash
# Autor: Kiko y Ivan
# Descripcion: Crea un script que escanee un equipo o un segmento de red y devuelva los puertos abiertos y los protocolos estándar que se ejecutan en ellos (sacado de /etc/services por ejemplo).
# Version: 10.1
# Fecha de creacion: $(date)
# Variables: (las que se utilicen)

# Función para verificar si el usuario es root
verificar_usuario_root() {
    if [ "$(id -u)" != 0 ]; then
        echo "Este script debe ejecutarse con privilegios de root."
        exit 1
    fi
}

# Función para verificar la conexión a Internet
verificar_conexion_internet() {
    if ! ping -c 1 google.com &> /dev/null; then
        echo "No hay conexión a Internet. Por favor, asegúrate de tener conexión antes de ejecutar este script."
        exit 1
    fi
}

# Función para validar un segmento de red
validar_segmento_red() {
    local segmento=$1
    if [[ ! $segmento =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        echo "Error: '$segmento' no es un segmento de red válido."
        exit 1
    fi
}

# Función para verificar e instalar Nmap si es necesario
verificar_instalacion_nmap() {
    if ! command -v nmap &>/dev/null; then
        echo "Nmap no está instalado. Instalando..."
        sudo apt-get update
        sudo apt-get install -y nmap
    fi
}

# Función para verificar la accesibilidad de una dirección IP
verificar_accesibilidad_ip() {
    local ip=$1
    if ! ping -c 1 $ip &>/dev/null; then
        echo "La dirección IP $ip no es accesible."
        exit 1
    fi
}

# Función para solicitar confirmación al usuario
confirmar() {
    local respuesta
    read -p "Vas a escanear los puertos del segmento de red $1. ¿Estás seguro? (S/n): " respuesta
    respuesta=$(echo "$respuesta" | tr '[:upper:]' '[:lower:]')  # Convertir respuesta a minúsculas
    if [[ -z "$respuesta" ]] || [[ "$respuesta" == "s" ]]; then
        return 0  # Confirmación
    elif [[ "$respuesta" == "n" ]]; then
        echo "Operación cancelada."
        exit 0
    else
        echo "Respuesta inválida."
        confirmar "$1"
    fi
}

# Función para escanear puertos y protocolos
escanear_puertos() {
    local segmento_red=$1
    # Escaneo de puertos y filtrado de la salida
    sudo nmap -p- -sS --open --min-rate 6000 -n -Pn $segmento_red | \
        grep -E -v "^(Starting Nmap|Host is up|Not shown|Some closed ports may be reported)"
}

# Verificar si el usuario es root
verificar_usuario_root

# Verificar la conexión a Internet
verificar_conexion_internet

# Verificar e instalar Nmap si es necesario
verificar_instalacion_nmap

# Zona de creacion del script

# Validar que se pasó un argumento
if [ $# -eq 0 ]; then
    echo "Uso: $0 <segmento_de_red>"
    exit 1
fi

# Validar que el argumento sea un segmento de red válido
validar_segmento_red "$1"

# Validar la accesibilidad de la dirección IP
verificar_accesibilidad_ip "$1"

# Mostrar mensaje de confirmación y solicitar confirmación al usuario
confirmar "$1" || exit 0  # Salir si la confirmación es negativa

# Llamada a la función de
