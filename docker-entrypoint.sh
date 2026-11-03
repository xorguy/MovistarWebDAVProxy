#!/bin/sh
set -e

TOKENS_DIR="${TOKENS_DIR:-/app/tokens}"
export TOKENS_DIR

APP_UID="$(id -u app)"
APP_GID="$(id -g app)"

log() {
    echo "[$(date +%H:%M:%S)] [ENTRYPOINT] $*"
}

can_access_as_app() {
    su-exec app:app sh -c '
        test -r "$1" && test -w "$1" || exit 1
        for f in "$1"/.env "$1"/*.env; do
            if [ -e "$f" ]; then
                test -r "$f" && test -w "$f" || exit 1
            fi
        done
    ' -- "$TOKENS_DIR"
}

# Arranque directo como usuario sin privilegios (ej. `user: "10001:10001"`).
if [ "$(id -u)" != "0" ]; then
    if [ ! -w "$TOKENS_DIR" ]; then
        log "[WARNING] ⚠️ $TOKENS_DIR no es escribible por UID $(id -u). Ejecuta en el host: chown -R $APP_UID:$APP_GID <carpeta_tokens>"
    fi
    exec /app/movistar-proxy "$@"
fi

# Arranque como root: preparamos /app/tokens y soltamos privilegios al usuario "app" (UID 10001).
mkdir -p "$TOKENS_DIR"

# 1) ¿Puede el contenedor cambiar de usuario? Requiere CAP_SETUID y CAP_SETGID.
#    Si se han eliminado (cap_drop: ALL / SETGID / SETUID), su-exec falla con
#    "setgroups(10001): Operation not permitted" y no hay forma de soltar privilegios.
if ! su-exec app:app true 2>/dev/null; then
    log "[WARNING] ⚠️ No se pueden soltar privilegios: faltan las capabilities SETUID/SETGID (¿cap_drop: ALL?)."
    log "[WARNING] ⚠️ El proceso se ejecutará como ROOT y los ficheros nuevos serán propiedad de root."
    log "[WARNING] ⚠️ Solución A (recomendada): añade 'user: \"$APP_UID:$APP_GID\"' y ejecuta en el host 'chown -R $APP_UID:$APP_GID <carpeta_tokens>'."
    log "[WARNING] ⚠️ Solución B: añade 'cap_add: [CHOWN, DAC_OVERRIDE, FOWNER, SETUID, SETGID]' junto a tu cap_drop."
    exec /app/movistar-proxy "$@"
fi

# 2) Migramos la propiedad (volúmenes de versiones <= v2.0.7 o bind mounts creados por root).
#    Requiere CAP_CHOWN; en algunos hosts (ej. Synology DSM, NFS con root_squash) chown está bloqueado.
if ! chown -R app:app "$TOKENS_DIR" 2>/dev/null; then
    log "[WARNING] ⚠️ No se pudo cambiar la propiedad de $TOKENS_DIR a $APP_UID:$APP_GID (falta CAP_CHOWN o el sistema de ficheros lo impide)."
fi
chmod 700 "$TOKENS_DIR" 2>/dev/null || true
chmod 600 "$TOKENS_DIR"/.env "$TOKENS_DIR"/*.env 2>/dev/null || true

# 3) Si "app" puede leer/escribir las credenciales, soltamos privilegios.
#    Si no, mantenemos root para no perder acceso a credenciales existentes.
if can_access_as_app 2>/dev/null; then
    exec su-exec app:app /app/movistar-proxy "$@"
fi

log "[WARNING] ⚠️ El usuario 'app' ($APP_UID) no tiene acceso de lectura/escritura a $TOKENS_DIR o a sus ficheros .env."
log "[WARNING] ⚠️ El proceso se ejecutará como ROOT. Ejecuta en el host: chown -R $APP_UID:$APP_GID <carpeta_tokens>"
exec /app/movistar-proxy "$@"
