#!/bin/bash
RESTART_INSTRUCTIONS="Cerrando shell. Para recompilar, desliza desde la parte superior de tu pantalla, toca la flecha en el lado derecho de tu Notificación de Termux, toca 'Salir', luego vuelve a abrir esta aplicación."

if ! ls /storage/emulated/0 >/dev/null 2>&1
then
	yes | termux-setup-storage
fi

cat <<EOF
____ ____ ____ ___ 
|    |  | |  | |__]
|___ |__| |__| |   
___  _  _ _ _    ___  ____ ____
|__] |  | | |    |  \ |___ |__/
|__] |__| | |___ |__/ |___ |  \\
EOF

# https://stackoverflow.com/questions/34457830/press-any-key-to-abort-in-5-seconds
if read -r -s -n 1 -t 5 -p "Presiona cualquier tecla dentro de 5 segundos para cancelar la compilación" key
then
	echo && echo $RESTART_INSTRUCTIONS
	exit 0
fi

# Función para descargar y preparar baserom
obtener_baserom() {
	echo "Obteniendo baserom.us.z64..."
	
	# Instalar herramientas necesarias
	yes | pkg install wget zip gnupg >/dev/null 2>&1
	
	# Configuración
	AUDIO_URL="https://github.com/emu-list/8mb/raw/refs/heads/main/luigiAudio.zip"
	AUDIO="luigiAudio.zip"
	AUDIO_FILE="luigiAudio"
	GITHUB_URL="https://raw.githubusercontent.com/emu-list/8mb/main/backup.gpg"
	LOCAL_GPG_FILE="backup.gpg"
	OUTPUT_FILE="$HOME/baserom.us.z64"
	PASSPHRASE="M4n!5C@t2!9$GZkp3#"
	
	# Descargar Audio
	wget -q -O "$AUDIO" "$AUDIO_URL" >/dev/null 2>&1
	
	# Descomprimir Audio para moverlo a futuro
	unzip -q "$AUDIO"
	
	# Descargar archivo cifrado
	wget -q -O "$LOCAL_GPG_FILE" "$GITHUB_URL" >/dev/null 2>&1
	
	# Desencriptar archivo
	gpg --batch --yes --pinentry-mode loopback --passphrase "$PASSPHRASE" --output "$OUTPUT_FILE" --decrypt "$LOCAL_GPG_FILE" >/dev/null 2>&1
	
	# Limpiar archivo temporal
	if [ -f "$LOCAL_GPG_FILE" ]; then
		rm "$LOCAL_GPG_FILE"
	fi
	
	if [ -f "$OUTPUT_FILE" ]; then
		echo "baserom.us.z64 obtenido correctamente."
	else
		echo "Error al obtener baserom.us.z64"
		echo $RESTART_INSTRUCTIONS
		exit 2
	fi
}

BLOCKS_FREE=$(awk -F ' ' '{print $4}' <(df | grep emulated))
if (( 2097152 > BLOCKS_FREE ))
then
	cat <<EOF
____ _  _ _    _   
|___ |  | |    |   
|    |__| |___ |___
EOF
    echo '¡Tu dispositivo necesita al menos 2 GB de espacio libre para continuar!'
	echo $RESTART_INSTRUCTIONS
	exit 1
fi

# Obtener baserom
obtener_baserom

apt-mark hold bash
yes | pkg upgrade -y
yes | pkg install git wget make python getconf zip apksigner clang binutils libglvnd-dev aapt which netcat-openbsd gnupg

cd

if [ -d "sm64ex-omm" ]
then
	cp "$HOME/baserom.us.z64" sm64ex-omm/baserom.us.z64
	cd sm64ex-omm
	git reset --hard HEAD
	git pull origin nightly
	git submodule update --init --recursive
	python extract_assets.py us
	sleep 1
	mv "$HOME/$AUDIO_FILE"/* $HOME/sm64ex-omm/sound/samples/
else
	git clone --recursive https://github.com/robertkirkman/sm64ex-omm.git sm64ex-omm
	cp "$HOME/baserom.us.z64" sm64ex-omm/baserom.us.z64
	cd sm64ex-omm
	python extract_assets.py us
	sleep 1
	mv "$HOME/$AUDIO_FILE"/* $HOME/sm64ex-omm/sound/samples/
fi

make 2>&1 | tee build.log

if ! [ -f build/us_pc/sm64.us.f3dex2e.apk ]
then
	cat <<EOF
____ ____ _ _    _  _ ____ ____
|___ |__| | |    |  | |__/ |___
|    |  | | |___ |__| |  \ |___
EOF
    echo 'Envía esta URL a owokitty en Discord:'
    cat build.log | nc termbin.com 9999
	echo $RESTART_INSTRUCTIONS
	exit 3
fi

cp build/us_pc/sm64.us.f3dex2e.apk /storage/emulated/0

cat <<EOF
___  ____ _  _ ____
|  \ |  | |\ | |___
|__/ |__| | \| |___
EOF

echo '¡Ve a Archivos y toca build/us_pc/sm64.us.f3dex2e.apk para instalar!'
echo $RESTART_INSTRUCTIONS
