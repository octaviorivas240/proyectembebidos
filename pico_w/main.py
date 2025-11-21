# main.py → OPTIMIZADO PARA ADAFRUIT IO FREE (NUNCA TE BLOQUEAN)
from machine import UART, Pin
import machine
import time
import network
import uos
import usocket
import ujson
import ssl
from micropyGPS import MicropyGPS

# ===================== CONFIG =====================
try:
    from config import Config
except ImportError:
    print("ERROR: Crea config.py")
    raise

wifi_ssid = Config.WIFI_SSID
wifi_pass = Config.WIFI_PASSWORD
aio_user = Config.AIO_USERNAME
aio_key = Config.AIO_KEY
feed = Config.AIO_FEED

gps_uart = UART(Config.GPS_UART, baudrate=9600, tx=Pin(Config.GPS_TX_PIN), rx=Pin(Config.GPS_RX_PIN))
gps = MicropyGPS(location_formatting='dd')
wlan = network.WLAN(network.STA_IF)
led = Pin("LED", Pin.OUT)

SECURITY = {0: "Abierta", 1: "WEP", 3: "WPA-PSK", 5: "WPA2-PSK", 7: "WPA/WPA2-PSK"}
PENDING_DIR = "pending"

# Crear carpeta pending
try:
    if PENDING_DIR not in uos.listdir():
        uos.mkdir(PENDING_DIR)
except:
    pass

# ===================== VARIABLES GLOBALES =====================
lote_acumulado = ""           # ← ACUMULA TODAS LAS REDES
ultimo_envio = 0              # ← Control de tiempo (2 minutos = 120 segundos)
INTERVALO_ENVIO = 120         # ← 2 MINUTOS = 120 SEGUNDOS (PERFECTO PARA FREE)

# ===================== FUNCIONES =====================
def conectar_wifi():
    if wlan.isconnected(): return True
    wlan.active(True)
    wlan.connect(wifi_ssid, wifi_pass)
    print("Conectando WiFi", end="")
    for _ in range(40):
        if wlan.isconnected():
            print(f"\nConectado! IP: {wlan.ifconfig()[0]}")
            led.on()
            return True
        print(".", end="")
        time.sleep(0.5)
    print("\nSin internet")
    return False

def obtener_gps():
    timeout = time.ticks_ms() + 30000
    while time.ticks_ms() < timeout:
        if gps_uart.any():
            data = gps_uart.read()
            if data:
                for b in data:
                    gps.update(chr(b))
        if gps.satellites_in_use >= 4 and gps.latitude[0] != 0.0:
            return True
        time.sleep(0.1)
    return False

def guardar_local(datos):
    if not datos.strip(): return
    filename = f"{PENDING_DIR}/data_{time.ticks_ms()}.txt"
    try:
        with open(filename, "w") as f:
            f.write(datos)
        print(f"Guardado offline: {filename}")
    except Exception as e:
        print("ERROR guardando:", e)

def enviar_a_adafruit(datos):
    if not wlan.isconnected() or len(datos) == 0:
        return False
    try:
        addr = usocket.getaddrinfo('io.adafruit.com', 443)[0][-1]
        s = usocket.socket()
        s.settimeout(15)
        s.connect(addr)
        s = ssl.wrap_socket(s)

        payload = ujson.dumps({"value": datos})
        if len(payload) > 1000:  # ← 1KB límite
            print("Lote muy grande, se recorta")
            datos = "\n".join(datos.split("\n")[:50])  # máx 50 redes por envío
            payload = ujson.dumps({"value": datos})

        request = (
            f"POST /api/v2/{aio_user}/feeds/{feed}/data HTTP/1.1\r\n"
            f"Host: io.adafruit.com\r\n"
            f"X-AIO-Key: {aio_key}\r\n"
            f"Content-Type: application/json\r\n"
            f"Content-Length: {len(payload)}\r\n"
            f"Connection: close\r\n\r\n"
            f"{payload}"
        )
        s.write(request.encode())
        s.close()
        print(f"ENVIADO LOTE DE {datos.count(chr(10))+1} REDES")
        return True
    except Exception as e:
        print("Error enviando:", e)
        return False

def enviar_pendientes():
    if not wlan.isconnected(): return
    try:
        archivos = [f for f in uos.listdir(PENDING_DIR) if f.endswith(".txt")]
        for archivo in archivos:
            path = f"{PENDING_DIR}/{archivo}"
            with open(path, "r") as f:
                datos = f.read()
            if enviar_a_adafruit(datos):
                uos.remove(path)
                print(f"Borrado: {archivo}")
    except Exception as e:
        print("Error enviando pendientes:", e)

def escanear_y_acumular():
    global lote_acumulado, ultimo_envio

    print("\n--- Escaneando ---")
    redes = wlan.scan()
    if not redes:
        print("No hay redes")
        return

    print("GPS...", end="")
    if obtener_gps():
        lat = f"{gps.latitude[0]:.6f}"
        lon = f"{gps.longitude[0]:.6f}"
        print(f" OK → {lat},{lon}")
    else:
        lat = lon = "0.000000"
        print(" sin fix")

    lote_nuevo = ""
    for net in redes:
        ssid = net[0].decode('utf-8', 'ignore').strip() or "Hidden"
        mac = ':'.join(f"{b:02X}" for b in net[1])
        rssi = net[3]
        auth = SECURITY.get(net[4], "Desconocida")
        lote_nuevo += f"{ssid},{auth},{lat},{lon},{rssi},{mac}\n"

    lote_acumulado += lote_nuevo
    print(f"Acumulado: {lote_acumulado.count(chr(10))+1} redes totales")

    # ENVÍO CADA 2 MINUTOS O SI HAY MUCHO ACUMULADO
    ahora = time.time()
    if (ahora - ultimo_envio >= INTERVALO_ENVIO) or (lote_acumulado.count("\n") > 80):
        if wlan.isconnected():
            enviar_pendientes()  # primero lo viejo
            if enviar_a_adafruit(lote_acumulado.strip()):
                lote_acumulado = ""    # ← LIMPIAR ACUMULADO
                ultimo_envio = time.time()
            else:
                guardar_local(lote_acumulado.strip())
                lote_acumulado = ""
        else:
            guardar_local(lote_acumulado.strip())
            lote_acumulado = ""

# ===================== INICIO =====================
print("=== WARDRIVING MÉXICO 2025 - OPTIMIZADO PARA ADAFRUIT FREE ===")
print("Envío cada 2 minutos máximo → NUNCA TE BLOQUEAN")
conectar_wifi()

while True:
    start = time.ticks_ms()

    # GPS continuo
    while gps_uart.any():
        b = gps_uart.read(1)
        if b: gps.update(chr(b[0]))

    escanear_y_acumular()

    led.on(); time.sleep(0.3); led.off()

    elapsed = time.ticks_diff(time.ticks_ms(), start) / 1000
    time.sleep(max(1, 35 - elapsed))