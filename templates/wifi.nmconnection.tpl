[connection]
id={{WIFI_SSID}}
uuid={{CONN_UUID}}
type=wifi
autoconnect=true
autoconnect-priority=100

[wifi]
mode=infrastructure
ssid={{WIFI_SSID}}

[wifi-security]
auth-alg=open
key-mgmt=wpa-psk
psk={{WIFI_PASSWORD}}

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto

[proxy]
