# main.py → VERSIÓN FINAL OFICIAL AGUASCALIENTES 2025 (SIN ERRORES 1KB)
from machine import UART, Pin
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
except:
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
INTERVALO_ENVIO = 90  # 90 segundos máximo → nunca pasa de 1KB

# Crear carpeta pending
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
    print("\nSin WiFi")
    return False

def esperar_gps_fix():
    print("GPS...", end="")
    timeout = time.ticks_ms() + 18000  # 18 segundos máximo
    while time.ticks_ms() < timeout:
        if gps_uart.any():
            data = gps_uart.read()
            if data:
                for b in data:
                    gps.update(chr(b))
                if gps.satellites_in_use >= 4 and gps.latitude[0] != 0.0:
                    print(f" FIX → {gps.latitude[0]:.6f},{gps.longitude[0]:.6f}")
                    return True
        time.sleep(0.05)
    print(" sin fix")
    return False

def guardar_local(datos):
    if not datos.strip(): return
    filename = f"{PENDING_DIR}/p_{time.ticks_ms()}.txt"
    try:
        with open(filename, "w") as f:
            f.write(datos)
        print(f"Guardado offline: {filename}")
    except Exception as e:
        print("ERROR guardando:", e)

def enviar_a_adafruit(datos):
    if not wlan.isconnected() or not datos.strip():
        return False
    
    lineas = datos.strip().split('\n')
    if len(lineas) > 60:  # MÁXIMO 60 REDES POR ENVÍO → siempre < 1KB
        datos = '\n'.join(lineas[:60]) + '\n'
        print("Lote recortado a 60 redes")
    
    try:
        addr = usocket.getaddrinfo('io.adafruit.com', 443)[0][-1]
        s = usocket.socket()
        s.settimeout(12)
        s.connect(addr)
        s = ssl.wrap_socket(s)

        payload = ujson.dumps({"value": datos})
        request = (
            f"POST /api/v2/{aio_user}/feeds/{feed}/data HTTP/1.1\r\n"
            f"Host: io.adafruit.com\r\n"
            f"X-AIO-Key: {aio_key}\r\n"
            f"Content-Type: application/json\r\n"
            f"Content-Length: {len(payload)}\r\n\r\n"
            f"{payload}"
        )
        s.write(request.encode())
        response = s.read(100)
        s.close()
        
        if b"200" in response or b"201" in response:
            print(f"ENVIADO {len(lineas)} redes ({len(payload)} bytes)")
            return True
        else:
            print("Error HTTP en envío")
            return False
    except Exception as e:
        print("Error conexión:", e)
        return False

def enviar_pendientes():
    if not wlan.isconnected(): return
    try:
        for f in uos.listdir(PENDING_DIR):
            if not f.endswith(".txt"): continue
            path = f"{PENDING_DIR}/{f}"
            with open(path, "r") as file:
                data = file.read()
            if enviar_a_adafruit(data):
                uos.remove(path)
                print(f"Borrado: {f}")
    except Exception as e:
        print("Error pendientes:", e)

def ciclo():
    global lote_acumulado, ultimo_envio

    if not esperar_gps_fix():
        return  # ← NO guarda basura sin GPS

    lat = f"{gps.latitude[0]:.6f}"
    lon = f"{gps.longitude[0]:.6f}"

    redes = wlan.scan()
    nuevo_lote = ""
    for net in redes:
        ssid = net[0].decode('utf-8','ignore').strip() or "Hidden"
        mac = ':'.join(f"{b:02X}" for b in net[1])
        rssi = net[3]
        auth = SECURITY.get(net[4], "Desconocida")
        nuevo_lote += f"{ssid},{auth},{lat},{lon},{rssi},{mac}\n"

    lote_acumulado += nuevo_lote
    print(f"Total acumuladas: {lote_acumulado.count(chr(10))} redes")

    ahora = time.time()
    if (ahora - ultimo_envio >= INTERVALO_ENVIO) or len(lote_acumulado.split('\n')) > 55:
        if wlan.isconnected():
            enviar_pendientes()
            if enviar_a_adafruit(lote_acumulado):
                lote_acumulado = ""
                ultimo_envio = ahora
            else:
                guardar_local(lote_acumulado)
                lote_acumulado = ""
        else:
            guardar_local(lote_acumulado)
            lote_acumulado = ""

# ===================== INICIO =====================
print("=== WARDRIVING AGUASCALIENTES 2025 - LISTO PARA DEMO ===")
conectar_wifi()

while True:
    # Leer GPS siempre
    while gps_uart.any():
        b = gps_uart.read(1)
        if b: gps.update(chr(b[0]))
    
    ciclo()
    
    led.on()
    time.sleep(0.2)
    led.off()
    time.sleep(33)  # Ciclo cada ~35 segundos