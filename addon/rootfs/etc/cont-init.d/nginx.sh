#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Community Add-on: TileBoard
# Configures NGINX for use with TileBoard
# ==============================================================================

info=$(curl --silent --show-error \
        --request "GET" \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        "http://supervisor/core/api/config")

external_url=$(bashio::jq "${info}" '.external_url')
internal_url="https://192.168.0.10:8124"
base_url="https://192.168.0.10:8124"
# Fallback to internal URL if external is empty.
[ -z "$base_url" ] && base_url="${internal_url}"
if bashio::config.false 'useExternalUrl'; then
    base_url="${internal_url}"
fi
bashio::log.info "Using base URL yada '${base_url}'"
# shellcheck disable=SC2001
websocket_url="$(echo "$base_url" | sed "s/^http/ws/")"

# Generate Ingress configuration
bashio::var.json \
    interface "$(bashio::addon.ip_address)" \
    ingress_path "$(bashio::addon.ingress_url)" \
    | tempio \
        -template /etc/nginx/templates/ingress.gtpl \
        -out /etc/nginx/servers/ingress.conf

# Generate direct access configuration, if enabled.
if bashio::var.has_value "$(bashio::addon.port 80)"; then
    bashio::config.require.ssl
    bashio::var.json \
        certfile "$(bashio::config 'certfile')" \
        keyfile "$(bashio::config 'keyfile')" \
        ssl "^$(bashio::config 'ssl')" \
        base_url "${base_url}" \
        websocket_url "${websocket_url}" \
        | tempio \
            -template /etc/nginx/templates/direct.gtpl \
            -out /etc/nginx/servers/direct.conf
fi
