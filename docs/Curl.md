# Curl

Volver a [README.md](/README.md)  
<https://curl.se/docs/manpage.html>

## Brief

`curl` es una herramienta de línea de comandos para transferir datos con URLs; aquí se usa sobre
todo para descargas por HTTP(S).

Esta nota solo cubre cómo instalarlo, en Windows y Linux.

## Installation

### Windows

En Windows puedes instalar `curl` mediante el gestor de paquetes del sistema:

```powershell
winget install cURL.cURL
```

### Linux

Instala el paquete `curl` mediante el gestor de paquetes de tu distribución.

El paquete se llama `curl`, por lo que, independientemente de la distribución, puedes buscarlo
directamente con el gestor de paquetes correspondiente.

Por ejemplo:

```sh
curl
```

Una vez instalado, puedes comprobar que está disponible mediante:

```sh
curl --version
```

### macOS

```sh
brew install curl
```
