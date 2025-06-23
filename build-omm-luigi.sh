#!/bin/bash

# =============================================================================
# SM64EX-OMM Android Builder - Versión Profesional
# =============================================================================

set -e  # Salir en errores, pero menos estricto

# Configuración global
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${HOME}/sm64_build.log"
readonly MIN_SPACE_MB=2048
readonly RESTART_INSTRUCTIONS="Cerrando shell. Para recompilar, desliza desde la parte superior de tu pantalla, toca la flecha en el lado derecho de tu Notificación de Termux, toca 'Salir', luego vuelve a abrir esta aplicación."

# URLs y configuración de archivos
readonly AUDIO_URL="https://github.com/emu-list/8mb/raw/refs/heads/main/luigiAudio.zip"
readonly REPO_URL="https://github.com/robertkirkman/sm64ex-omm.git"

# Archivos locales
readonly AUDIO_ZIP="luigiAudio.zip"
readonly AUDIO_DIR="luigiAudio"
readonly BASEROM_FILE="${HOME}/baserom.us.z64"
readonly PROJECT_DIR="${HOME}/sm64ex-omm"
readonly SAMPLE_DIR="${PROJECT_DIR}/sound/samples"
readonly APK_PATH="${PROJECT_DIR}/build/us_pc/sm64.us.f3dex2e.apk"

# Posibles ubicaciones del baserom
readonly BASEROM_LOCATIONS=(
    "/storage/emulated/0/Download/baserom.us.z64"
    "/storage/emulated/0/baserom.us.z64"
    "/storage/emulated/0/Download/baserom.z64"
    "/storage/emulated/0/baserom.z64"
    "${HOME}/baserom.us.z64"
)

# Colores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# =============================================================================
# FUNCIONES DE UTILIDAD
# =============================================================================

log() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

show_banner() {
    cat <<EOF
${BLUE}
____ ____ ____ ___ 
|    |  | |  | |__]
|___ |__| |__| |   
___  _  _ _ _    ___  ____ ____
|__] |  | | |    |  \ |___ |__/
|__] |__| | |___ |__/ |___ |  \\
${NC}
EOF
}

cleanup_temp_files() {
    log "Limpiando archivos temporales..."
    local files_to_clean=("$AUDIO_ZIP")
    
    for file in "${files_to_clean[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file" && log "Eliminado: $file"
        fi
    done
    
    # Limpiar directorio de audio si existe y está vacío
    if [[ -d "$AUDIO_DIR" ]] && [[ -z "$(ls -A "$AUDIO_DIR" 2>/dev/null)" ]]; then
        rmdir "$AUDIO_DIR" && log "Eliminado directorio vacío: $AUDIO_DIR"
    fi
}

check_storage_permission() {
    log "Verificando permisos de almacenamiento..."
    if ! ls /storage/emulated/0 >/dev/null 2>&1; then
        log "Configurando permisos de almacenamiento..."
        yes | termux-setup-storage
        sleep 2
    fi
    log_success "Permisos de almacenamiento OK"
}

check_free_space() {
    log "Verificando espacio libre..."
    local blocks_free
    blocks_free=$(df /data/data/com.termux/files/home | awk 'NR==2 {print $4}')
    local mb_free=$((blocks_free / 1024))
    
    log "Espacio libre: ${mb_free} MB"
    
    if (( mb_free < MIN_SPACE_MB )); then
        cat <<EOF
${RED}
____ _  _ _    _   
|___ |  | |    |   
|    |__| |___ |___
${NC}
EOF
        log_error "Tu dispositivo necesita al menos ${MIN_SPACE_MB} MB de espacio libre para continuar!"
        log_error "Espacio actual: ${mb_free} MB"
        echo "$RESTART_INSTRUCTIONS"
        exit 1
    fi
    
    log_success "Espacio suficiente disponible"
}

install_dependencies() {
    log "Instalando dependencias del sistema..."
    
    # Actualizar repositorios y paquetes
    apt-mark hold bash >/dev/null 2>&1 || true
    
    log "Actualizando paquetes existentes..."
    yes | pkg upgrade -y >/dev/null 2>&1 || {
        log_warning "Algunos paquetes no se pudieron actualizar, continuando..."
    }
    
    # Lista de paquetes necesarios (sin gnupg)
    local packages=(
        "git" "wget" "make" "python" "getconf" "zip" "apksigner"
        "clang" "binutils" "libglvnd-dev" "aapt" "which" 
        "netcat-openbsd" "unzip"
    )
    
    log "Instalando paquetes: ${packages[*]}"
    
    # Instalar paquetes uno por uno para mejor control de errores
    for package in "${packages[@]}"; do
        log "Instalando $package..."
        if yes | pkg install "$package" >/dev/null 2>&1; then
            log_success "$package instalado"
        else
            log_warning "Error instalando $package, puede que ya esté instalado"
        fi
    done
    
    log_success "Instalación de dependencias completada"
}

download_file() {
    local url="$1"
    local output="$2"
    local description="$3"
    
    log "Descargando $description..."
    
    if wget -q --timeout=30 --tries=3 -O "$output" "$url"; then
        log_success "$description descargado correctamente"
        return 0
    else
        log_error "Error al descargar $description desde $url"
        return 1
    fi
}

check_audio_files() {
    log "Verificando archivos de audio existentes..."
    
    if [[ -d "$SAMPLE_DIR" ]] && [[ -n "$(ls -A "$SAMPLE_DIR" 2>/dev/null)" ]]; then
        local file_count
        file_count=$(find "$SAMPLE_DIR" -name "*.aiff" -o -name "*.wav" | wc -l)
        if (( file_count > 0 )); then
            log_success "Se encontraron $file_count archivos de audio existentes"
            return 0
        fi
    fi
    
    log "No se encontraron archivos de audio existentes"
    return 1
}

backup_audio_files() {
    log "Creando respaldo de archivos de audio..."
    
    local backup_dir="${HOME}/audio_backup"
    
    # Crear directorio de respaldo
    mkdir -p "$backup_dir"
    
    # Respaldar archivos de audio si existen
    if [[ -d "$SAMPLE_DIR" ]] && [[ -n "$(ls -A "$SAMPLE_DIR" 2>/dev/null)" ]]; then
        if cp -r "$SAMPLE_DIR"/* "$backup_dir/" 2>/dev/null; then
            log_success "Archivos de audio respaldados en $backup_dir"
            return 0
        else
            log_warning "No se pudieron respaldar todos los archivos de audio"
            return 1
        fi
    else
        log "No hay archivos de audio para respaldar"
        return 1
    fi
}

restore_audio_files() {
    log "Restaurando archivos de audio desde respaldo..."
    
    local backup_dir="${HOME}/audio_backup"
    
    # Crear directorio de samples si no existe
    mkdir -p "$SAMPLE_DIR"
    
    # Restaurar archivos de audio si existe el respaldo
    if [[ -d "$backup_dir" ]] && [[ -n "$(ls -A "$backup_dir" 2>/dev/null)" ]]; then
        if cp -r "$backup_dir"/* "$SAMPLE_DIR/" 2>/dev/null; then
            log_success "Archivos de audio restaurados desde respaldo"
            # Limpiar respaldo después de restaurar
            rm -rf "$backup_dir"
            return 0
        else
            log_error "Error al restaurar archivos de audio desde respaldo"
            return 1
        fi
    else
        log "No se encontró respaldo de archivos de audio"
        return 1
    fi
}

extract_audio_files() {
    log "Descargando archivos de audio de Luigi..."
    
    if ! download_file "$AUDIO_URL" "$AUDIO_ZIP" "archivo de audio"; then
        log_warning "No se pudo descargar el audio, continuando sin él"
        return 1
    fi
    
    log "Extrayendo archivos de audio..."
    if unzip -q "$AUDIO_ZIP" -d .; then
        log_success "Archivos de audio extraídos correctamente"
        
        # Crear directorio de samples si no existe
        mkdir -p "$SAMPLE_DIR"
        
        # Mover archivos de audio (reemplazando existentes)
        if [[ -d "$AUDIO_DIR" ]] && [[ -n "$(ls -A "$AUDIO_DIR" 2>/dev/null)" ]]; then
            # Copiar todos los archivos reemplazando los existentes
            cp -rf "$AUDIO_DIR"/* "$SAMPLE_DIR/" 2>/dev/null || true
            log_success "Archivos de audio de Luigi movidos a $SAMPLE_DIR (reemplazando existentes)"
            
            # Limpiar directorio temporal
            rm -rf "$AUDIO_DIR"
        fi
        
        return 0
    else
        log_error "Error al extraer archivos de audio"
        return 1
    fi
}

find_baserom() {
    log "Buscando baserom.us.z64 en ubicaciones conocidas..."
    
    for location in "${BASEROM_LOCATIONS[@]}"; do
        if [[ -f "$location" ]]; then
            log_success "Baserom encontrado en: $location"
            
            # Copiar al directorio home si no está ahí
            if [[ "$location" != "$BASEROM_FILE" ]]; then
                log "Copiando baserom a $BASEROM_FILE..."
                if cp "$location" "$BASEROM_FILE"; then
                    log_success "Baserom copiado correctamente"
                else
                    log_error "Error al copiar baserom"
                    return 1
                fi
            fi
            
            # Verificar que el archivo es válido (tamaño aproximado de 8MB)
            local file_size
            file_size=$(stat -c%s "$BASEROM_FILE" 2>/dev/null || echo 0)
            
            if (( file_size > 7000000 && file_size < 9000000 )); then
                log_success "Baserom válido (tamaño: $((file_size / 1024 / 1024)) MB)"
                return 0
            else
                log_error "El archivo baserom parece inválido (tamaño: $((file_size / 1024 / 1024)) MB)"
                return 1
            fi
        fi
    done
    
    log_error "No se encontró baserom.us.z64 en ninguna ubicación"
    log_error "Ubicaciones buscadas:"
    for location in "${BASEROM_LOCATIONS[@]}"; do
        log_error "  - $location"
    done
    log_error ""
    log_error "Por favor, coloca el archivo baserom.us.z64 en una de estas ubicaciones:"
    log_error "  - /storage/emulated/0/Download/baserom.us.z64"
    log_error "  - /storage/emulated/0/baserom.us.z64"
    
    return 1
}

check_existing_build() {
    if [[ -f "$APK_PATH" ]]; then
        log_warning "Se detectó una compilación existente"
        log "APK encontrado en: $APK_PATH"
        return 0
    fi
    return 1
}

clean_build() {
    log "Realizando compilación limpia..."
    
    cd "$PROJECT_DIR"
    
    # Ejecutar make distclean para limpiar completamente
    log "Ejecutando make distclean..."
    if make distclean >/dev/null 2>&1; then
        log_success "Limpieza completa realizada"
    else
        log_warning "make distclean falló, continuando..."
    fi
    
    # Copiar baserom si existe
    if [[ -f "$BASEROM_FILE" ]]; then
        cp "$BASEROM_FILE" "./baserom.us.z64"
        log_success "Baserom copiado al directorio del proyecto"
    fi
    
    # Extraer assets después de la limpieza
    log "Extrayendo assets del juego..."
    if python extract_assets.py us >/dev/null 2>&1; then
        log_success "Assets extraídos correctamente"
    else
        log_error "Error al extraer assets"
        return 1
    fi
    
    # Ahora descargar y mover los archivos de Luigi (el truco está aquí)
    log "Descargando archivos de audio de Luigi..."
    extract_audio_files || log_warning "No se pudieron obtener archivos de audio"
    
    return 0
}

setup_project() {
    log "Configurando proyecto SM64EX-OMM..."
    
    cd "$HOME"
    
    local needs_clean_build=false
    
    if [[ -d "$PROJECT_DIR" ]]; then
        log "Actualizando proyecto existente..."
        cd "$PROJECT_DIR"
        
        # Verificar si existe una compilación previa
        if check_existing_build; then
            needs_clean_build=true
        fi
        
        # Copiar baserom si existe
        if [[ -f "$BASEROM_FILE" ]]; then
            cp "$BASEROM_FILE" "./baserom.us.z64"
        fi
        
        git reset --hard HEAD >/dev/null 2>&1
        git pull origin nightly >/dev/null 2>&1
        git submodule update --init --recursive >/dev/null 2>&1
        
        log_success "Proyecto actualizado"
        
        # Realizar compilación limpia si es necesario
        if $needs_clean_build; then
            if ! clean_build; then
                return 1
            fi
        else
            # Extraer assets normalmente si no hay compilación previa y después mover audios de Luigi
            if [[ -f "./baserom.us.z64" ]]; then
                log "Extrayendo assets del juego..."
                if python extract_assets.py us >/dev/null 2>&1; then
                    log_success "Assets extraídos correctamente"
                    
                    # Descargar y mover archivos de Luigi después de extraer assets
                    log "Descargando archivos de audio de Luigi..."
                    extract_audio_files || log_warning "No se pudieron obtener archivos de audio"
                else
                    log_error "Error al extraer assets"
                    return 1
                fi
            else
                log_error "No se encontró baserom.us.z64 en el directorio del proyecto"
                return 1
            fi
        fi
    else
        log "Clonando proyecto desde repositorio..."
        if git clone --recursive "$REPO_URL" "$PROJECT_DIR" >/dev/null 2>&1; then
            cd "$PROJECT_DIR"
            
            # Copiar baserom si existe
            if [[ -f "$BASEROM_FILE" ]]; then
                cp "$BASEROM_FILE" "./baserom.us.z64"
            fi
            
            log_success "Proyecto clonado correctamente"
            
            # Extraer assets para nueva instalación y después mover audios de Luigi
            if [[ -f "./baserom.us.z64" ]]; then
                log "Extrayendo assets del juego..."
                if python extract_assets.py us >/dev/null 2>&1; then
                    log_success "Assets extraídos correctamente"
                    
                    # Descargar y mover archivos de Luigi después de extraer assets
                    log "Descargando archivos de audio de Luigi..."
                    extract_audio_files || log_warning "No se pudieron obtener archivos de audio"
                else
                    log_error "Error al extraer assets"
                    return 1
                fi
            else
                log_error "No se encontró baserom.us.z64 en el directorio del proyecto"
                return 1
            fi
        else
            log_error "Error al clonar el repositorio"
            return 1
        fi
    fi
}

build_project() {
    log "Iniciando compilación del proyecto..."
    
    cd "$PROJECT_DIR"
    
    # Ejecutar make y capturar output
    if make 2>&1 | tee build.log; then
        if [[ -f "$APK_PATH" ]]; then
            log_success "Compilación completada exitosamente"
            return 0
        else
            log_error "La compilación terminó pero no se generó el APK"
            return 1
        fi
    else
        log_error "Error durante la compilación"
        return 1
    fi
}

install_apk() {
    log "Copiando APK a almacenamiento..."
    
    if cp "$APK_PATH" /storage/emulated/0/; then
        log_success "APK copiado a /storage/emulated/0/"
        
        cat <<EOF
${GREEN}
___  ____ _  _ ____
|  \ |  | |\ | |___
|__/ |__| | \| |___
${NC}
EOF
        echo
        log_success "¡Compilación completada!"
        log_success "Ve a Archivos y toca 'sm64.us.f3dex2e.apk' para instalar el juego"
        return 0
    else
        log_error "Error al copiar APK al almacenamiento"
        return 1
    fi
}

handle_build_failure() {
    cat <<EOF
${RED}
____ ____ _ _    _  _ ____ ____
|___ |__| | |    |  | |__/ |___
|    |  | | |___ |__| |  \ |___
${NC}
EOF
    echo
    log_error "La compilación falló. Enviando log de error..."
    
    if [[ -f "${PROJECT_DIR}/build.log" ]]; then
        log "Subiendo log de error a termbin..."
        local url
        if url=$(cat "${PROJECT_DIR}/build.log" | nc termbin.com 9999 2>/dev/null); then
            echo
            log "Envía esta URL a owokitty en Discord:"
            echo "${url}"
        else
            log_error "No se pudo subir el log de error"
            log "Log de error guardado en: ${PROJECT_DIR}/build.log"
        fi
    fi
}

main() {
    # Inicializar log
    echo "=== SM64EX-OMM Build Log - $(date) ===" > "$LOG_FILE"
    
    show_banner
    
    # Cancelación opcional
    if read -r -s -n 1 -t 5 -p "Presiona cualquier tecla dentro de 5 segundos para cancelar la compilación" key; then
        echo
        echo "$RESTART_INSTRUCTIONS"
        exit 0
    fi
    echo
    
    # Configurar trap para limpieza solo al final exitoso
    # trap 'cleanup_temp_files' EXIT
    
    # Ejecutar pasos principales
    check_storage_permission || { echo "$RESTART_INSTRUCTIONS"; exit 1; }
    check_free_space || { echo "$RESTART_INSTRUCTIONS"; exit 1; }
    install_dependencies || { echo "$RESTART_INSTRUCTIONS"; exit 1; }
    
    if ! find_baserom; then
        echo "$RESTART_INSTRUCTIONS"
        exit 2
    fi
    
    if ! setup_project; then
        cleanup_temp_files
        echo "$RESTART_INSTRUCTIONS"
        exit 3
    fi
    
    if ! build_project; then
        handle_build_failure
        cleanup_temp_files
        echo "$RESTART_INSTRUCTIONS"
        exit 4
    fi
    
    if ! install_apk; then
        cleanup_temp_files
        echo "$RESTART_INSTRUCTIONS"
        exit 5
    fi
    
    cleanup_temp_files
    log_success "¡Proceso completado exitosamente!"
    echo "$RESTART_INSTRUCTIONS"
}

# Ejecutar función principal
main "$@"
