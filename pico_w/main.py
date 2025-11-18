# main.py → Versión profesional, limpia y segura
# Usa config.py para las claves

from machine import UART, Pin
from time import sleep, ticks_ms
from micropyGPS import MicropyGPS
import network
import binascii
import urequests

# Importar configuración segura
try:
    from config import Config
except ImportError:
    print("ERROR: Crea config.py con tus claves (ver ejemplo)")
    raise

# ===================== CONFIGURACIÓN =====================
wifi_ssid = Config.WIFI_SSID
wifi_pass = Config.WIFI_PASSWORD
aio_user = Config.AIO_USERNAME
aio_key = Config.AIO_KEY
feed = Config.AIO_FEED

# GPS
gps_uart = UART(Config.GPS_UART, baudrate=9600, tx=Pin(Config.GPS_TX_PIN), rx=Pin(Config.GPS_RX_PIN))
gps = MicropyGPS(location_formatting='dd')

# Display Nextion (opcional)
display_uart = None
try:
    display_uart = UART(Config.DISPLAY_UART, baudrate=9600, tx=Pin(Config.DISPLAY_TX_PIN), rx=Pin(Config.DISPLAY_RX_PIN))
except:
    print("Sin pantalla Nextion")

led = Pin("LED", Pin.OUT)
wlan = network.WLAN(network.STA_IF)

SECURITY = {0: "Open", 1: "WEP", 3: "WPA-PSK", 5: "WPA2-PSK", 7: "WPA/WPA2-PSK"}

# ===================== FUNCIONES =====================
def conectar_wifi():
    if wlan.isconnected():
        return True
    wlan.active(True)
    wlan.connect(wifi_ssid, wifi_pass)
    print(f"Conectando a {wifi_ssid}...", end="")
    for _ in range(20):
        if wlan.isconnected():
            print(f"\nConectado! IP: {wlan.ifconfig()[0]}")
            led.on()
            return True
        print(".", end="")
        sleep(0.5)
    print("\nNo se pudo conectar al WiFi")
    return False

def enviar_a_adafruit(datos):
    url = f"https://io.adafruit.com/api/v2/{aio_user}/feeds/{feed}/data"
    headers = {"X-AIO-Key": aio_key, "Content-Type": "application/json"}
    try:
        r = urequests.post(url, json={"value": datos}, headers=headers)
        print(f"Enviado → {r.status_code}")
        r.close()
    except Exception as e:
        print("Error enviando:", e)

def actualizar_display():
    if not display_uart:
        return
    if gps.latitude[0] == 0:
        return
    
    lat = f"{gps.latitude[0]:.6f}"
    lon = f"{gps.longitude[0]:.6f}"
    
    # Enviar coordenadas
    display_uart.write(f'latitude.txt="{lat}'.encode())
    display_uart.write(b'\xff\xff\xff')
    display_uart.write(f'longitude.txt="{lon}'.encode())
    display_uart.write(b'\xff\xff\xff')

def escanear_y_enviar():
    redes = wlan.scan()
    if not redes:
        return
    
    lat = f"{gps.latitude[0]:.6f}" if gps.latitude[0] != 0 else "0.0"
    lon = f"{gps.longitude[0]:.6f}" if gps.longitude[0] != 0 else "0.0"
    
    lote = ""
    for net in redes:
        ssid = net[0].decode('utf-8', 'ignore')
        mac = binascii.hexlify(net[1]).decode()
        rssi = net[3]
        auth = SECURITY.get(net[4], "Desconocida")
        linea = f"{ssid},{auth},{lat},{lon},{rssi},{mac}"
        lote += linea + "\n"
        print(f"{ssid} | {auth} | {rssi}dBm | {mac}")
    
    if lote:
        enviar_a_adafruit(lote.strip())

# ===================== INICIO =====================
print("Wardriving Pro - Pico W + GPS + Adafruit IO")

if not conectar_wifi():
    print("Sin WiFi. Reiniciando...")
    sleep(10)
    machine.reset()

print("Sistema listo. Escaneando cada 30 segundos...")

while True:
    # Leer GPS
    while gps_uart.any():
        byte = gps_uart.read(1)
        if byte:
            for b in byte:
                gps.update(chr(b))
    
    actualizar_display()
    escanear_y_enviar()
    
    led.on()
    sleep(1)
    led.off()
    sleep(29)  # Total: 30 segundos