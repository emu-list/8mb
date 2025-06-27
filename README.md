# Audio Odyssey - Guía de Instalación

## 📋 Requisitos Previos

> [!NOTE]  
> Descarga Termux desde F-droid o desde Github, el de _Play Store No sirve_
> 
### Instalación de Termux
Para comenzar, necesitas descargar Termux desde las siguientes fuentes oficiales:

- **F-Droid** (Recomendado)
- **GitHub Releases**

> ⚠️ **IMPORTANTE**: No descargues Termux desde Google Play Store, ya que esa versión no funciona correctamente para este proyecto.

## 🎮 Instalación de Audio Odyssey

Este proyecto te permite instalar una versión modificada con la voz del personaje Luigi. Sigue estos pasos:

### Versión Luigi
Para instalar la versión con la voz de Luigi, ejecuta el siguiente comando en Termux:

```bash
bash -i <(curl -sL https://is.gd/luigiomm)
```

### Versión Mario
Para instalar la versión con la voz de Mario, ejecuta el siguiente comando en Termux:

```bash
bash -i <(curl -sL https://is.gd/marioomm)
```

## ⚠️ Limitaciones Importantes

### Compilación Única
- **Solo puedes realizar una compilación a la vez**
- Una vez generada la APK, debes moverla a otra ubicación antes de compilar la segunda versión
- Si no mueves el archivo, la nueva compilación reemplazará la anterior
- La última versión compilada quedará como predeterminada

### Solución Futura
Se está trabajando en una solución que permitirá tener ambas versiones instaladas simultáneamente sin conflictos entre ellas.

## 📝 Proceso Recomendado

1. Instala Termux desde F-Droid o GitHub
2. Ejecuta el comando para la versión que prefieras (Luigi o Mario)
3. Una vez completada la compilación, mueve la APK generada a una carpeta segura
4. Si deseas la segunda versión, ejecuta el otro comando
5. Instala las APK según tus preferencias

## 🔧 Soporte

Si encuentras algún problema durante la instalación, asegúrate de:
- Usar la versión correcta de Termux
- Tener conexión a internet estable
- Seguir el orden recomendado para evitar conflictos entre versiones


> [!CAUTION]  
> _Solo podras realizar una compilación a la vez, aparte deberás mover tu apk generado a otra ruta porque una de las dos va a reemplazar la anterior. quedandose la última como la por defecto, a futuro hare un truco oara que tengas las fos instaladas y no se afecten una a la otra. Mientras una a la vez._
