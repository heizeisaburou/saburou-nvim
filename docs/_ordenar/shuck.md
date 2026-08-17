• lint=true indica a Shuck que, además de importar los símbolos del archivo, analice también su
contenido:

# shuck: source=/home/saburou/.shl/zsh/colors-red.zsh lint=true

source "$HOME/.shl/zsh/colors-red.zsh"

La diferencia:

# shuck: source=/ruta/archivo.zsh

Importa definiciones, habilita navegación y elimina C003, pero no muestra diagnósticos internos
del archivo.

# shuck: source=/ruta/archivo.zsh lint=true

Hace lo anterior y además muestra los errores y advertencias encontrados dentro del archivo
importado.

No afecta a la ejecución de zsh; sólo al análisis estático de Shuck.

Yo lo usaría en archivos tuyos como colors-red.zsh, pero no en Powerlevel10k, FZF o plugins de
/usr/share: podrías recibir muchos diagnósticos sobre código externo que no controlas.
