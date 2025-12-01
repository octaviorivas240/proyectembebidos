# main.py → SÓLO GUARDA Y ENVÍA CUANDO HAYA GPS FIX REAL (MAPA 100% LIMPIO)
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
lote_acumulado = ""
ultimo_envio = 0
INTERVALO_ENVIO = 120  # 2 minutos máximo (Adafruit Free

try:
    if PENDING_DIR not in uos.listdir():
        uos.mkdir(PENDING_DIR)
except:
    pass

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

# FUNCIÓN CLAVE: ESPERA GPS REAL (máximo 20 segundos)
def esperar_gps_fix():
    print("Esperando GPS fix...", end="")
    timeout = time.ticks_ms() + 20000  # 20 segundos máximo
    while time.ticks_ms() < timeout:
        if gps_uart.any():
            data = gps_uart.read()
            if data:
                for b in data:
                    stat = gps.update(chr(b))
                    if stat:  # gps.update devuelve algo cuando hay frase completa
                        if gps.satellites_in_use >= 4 and gps.latitude[0] != 0.0:
                            print(f"\nGPS FIX! → {gps.latitude[0]:.6f}, {gps.longitude[0]:.6f}")
                            return True
        time.sleep(0.05)
    print("\nSin GPS fix → ciclo omitido")
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
    if not wlan.isconnected() or not datos.strip(): return False
    try:
        addr = usocket.getaddrinfo('io.adafruit.com', 443)[0][-1]
        s = usocket.socket()
        s.settimeout(15)
        s.connect(addr)
        s = ssl.wrap_socket(s)

        payload = ujson.dumps({"value": datos})
        if len(payload) > 950:  # seguridad por límite 1KB
            datos = "\n".join(datos.split("\n")[:60])
            payload = ujson.dumps({"value": datos})

        request = f"POST /api/v2/{aio_user}/feeds/{feed}/data HTTP/1.1\r\n"
        request += f"Host: io.adafruit.com\r\n"
        request += f"X-AIO-Key: {aio_key}\r\n"
        request += f"Content-Type: application/json\r\n"
        request += f"Content-Length: {len(payload)}\r\n"
        request += f"Connection: close\r\n\r\n"
        request += payload

        s.write(request.encode())
        s.close()
        print(f"ENVIADO {datos.count(chr(10))+1} redes con GPS real")
        return True
    except Exception as e:
        print("Error enviando:", e)
        return False

def enviar_pendientes():
    if not wlan.isconnected(): return
    try:
        for archivo in uos.listdir(PENDING_DIR):
            if not archivo.endswith(".txt"): continue
            path = f"{PENDING_DIR}/{archivo}"
            with open(path, "r") as f:
                datos = f.read()
            if enviar_a_adafruit(datos):
                uos.remove(path)
                print(f"Borrado: {archivo}")
    except Exception as e:
        print("Error enviando pendientes:", e)

def ciclo_wardriving():
    global lote_acumulado, ultimo_envio

    # CLAVE: SI NO HAY GPS FIX → NO HACEMOS NADA ESTE CICLO
    if not esperar_gps_fix():
        return  # ← se salta todo el ciclo si no hay GPS

    lat = f"{gps.latitude[0]:.6f}"
    lon = f"{gps.longitude[0]:.6f}"

    print("--- Escaneando con GPS real ---")
    redes = wlan.scan()
    lote_nuevo = ""
    for net in redes:
        ssid = net[0].decode('utf-8', 'ignore').strip() or "Hidden"
        mac = ':'.join(f"{b:02X}" for b in net[1])
        rssi = net[3]
        auth = SECURITY.get(net[4], "Desconocida")
        lote_nuevo += f"{ssid},{auth},{lat},{lon},{rssi},{mac}\n"

    lote_acumulado += lote_nuevo
    print(f"Acumuladas: {lote_acumulado.count(chr(10))} redes con GPS")

    # ENVÍO CADA 2 MIN O SI HAY MUCHAS
    ahora = time.time()
    if (ahora - ultimo_envio >= INTERVALO_ENVIO) or (lote_acumulado.count("\n") > 80):
        if wlan.isconnected():
            enviar_pendientes()
            if enviar_a_adafruit(lote_acumulado.strip()):
                lote_acumulado = ""
                ultimo_envio = time.time()
            else:
                guardar_local(lote_acumulado.strip())
                lote_acumulado = ""
        else:
            guardar_local(lote_acumulado.strip())
            lote_acumulado = ""

# ===================== INICIO =====================
print("=== WARDRIVING MÉXICO 2025 - SOLO GPS REAL ===")
print("No guarda ni envía nada sin fix → mapa 100% limpio")
conectar_wifi()

while True:
    start = time.ticks_ms()

    # GPS en tiempo real (siempre leyendo)
    while gps_uart.any():
        b = gps_uart.read(1)
        if b: gps.update(chr(b[0]))

    ciclo_wardriving()

    led.on(); time.sleep(0.3); led.off()

    elapsed = time.ticks_diff(time.ticks_ms(), start) / 1000
    time.sleep(max(1, 35 - elapsed))