#!/usr/bin/env bash
# Script untuk menerapkan skema warna 4-zona favorit
# Zona 1: Electric Violet (Ungu Gradasi Biru)
# Zona 2: Cyan Sky Blue
# Zona 3: Emerald / Mint Green
# Zona 4: Light Lemon Yellow

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="$(which python3 || echo "python3")"
BRIGHTNESS_FILE="$SCRIPT_DIR/.last_brightness"

if [[ -z "${BRIGHTNESS:-}" ]]; then
    if [[ -f "$BRIGHTNESS_FILE" ]] && [[ "$(cat "$BRIGHTNESS_FILE" 2>/dev/null)" =~ ^[0-9]+$ ]]; then
        BRIGHTNESS="$(cat "$BRIGHTNESS_FILE")"
    else
        BRIGHTNESS=100
    fi
fi

usage() {
    echo "Penggunaan: $0 [kecerahan | -b <kecerahan>]"
    echo "  kecerahan : Nilai 0 (mati) hingga 100 (maksimal). Default: kecerahan terakhir ($BRIGHTNESS%)"
    echo ""
    echo "Contoh:"
    echo "  $0          # Kecerahan terakhir ($BRIGHTNESS%)"
    echo "  $0 50       # Kecerahan 50% (disimpan sebagai default berikutnya)"
    echo "  $0 -b 25    # Kecerahan 25% (disimpan sebagai default berikutnya)"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--brightness)
            if [[ -z "${2:-}" ]]; then
                echo "[✗] Error: Opsi $1 membutuhkan nilai angka (0-100)."
                usage
                exit 1
            fi
            BRIGHTNESS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            BRIGHTNESS="$1"
            shift
            ;;
    esac
done

if ! [[ "$BRIGHTNESS" =~ ^[0-9]+$ ]] || [ "$BRIGHTNESS" -lt 0 ] || [ "$BRIGHTNESS" -gt 100 ]; then
    echo "[✗] Error: Kecerahan harus berupa angka antara 0 hingga 100 (diterima: '$BRIGHTNESS')."
    usage
    exit 1
fi

echo "$BRIGHTNESS" > "$BRIGHTNESS_FILE" 2>/dev/null || true
chmod 666 "$BRIGHTNESS_FILE" 2>/dev/null || true
chcon -t etc_t "$BRIGHTNESS_FILE" 2>/dev/null || true
if [[ -d "/opt/turbo-fan" && -w "/opt/turbo-fan" ]]; then
    echo "$BRIGHTNESS" > "/opt/turbo-fan/.last_brightness" 2>/dev/null || true
    chmod 666 "/opt/turbo-fan/.last_brightness" 2>/dev/null || true
fi

if [[ ! -e "/dev/acer-gkbbl-0" || ! -e "/dev/acer-gkbbl-static-0" ]]; then
    echo "[!] Device node /dev/acer-gkbbl* belum tersedia. Memuat modul facer otomatis..."
    if [[ $EUID -eq 0 ]]; then
        "$SCRIPT_DIR/install.sh"
    else
        sudo "$SCRIPT_DIR/install.sh"
    fi

    if [[ ! -e "/dev/acer-gkbbl-0" || ! -e "/dev/acer-gkbbl-static-0" ]]; then
        echo "[✗] Gagal memuat device node /dev/acer-gkbbl*."
        exit 1
    fi
fi

echo "[*] Mengaplikasikan tema warna RGB 4-Zona (Kecerahan: ${BRIGHTNESS}%)..."

"$PYTHON_BIN" "$SCRIPT_DIR/facer_rgb.py" -m 0 -z 1 -b "$BRIGHTNESS" -cR 120 -cG 20 -cB 255 && \
"$PYTHON_BIN" "$SCRIPT_DIR/facer_rgb.py" -m 0 -z 2 -b "$BRIGHTNESS" -cR 0 -cG 220 -cB 255 && \
"$PYTHON_BIN" "$SCRIPT_DIR/facer_rgb.py" -m 0 -z 3 -b "$BRIGHTNESS" -cR 0 -cG 255 -cB 70 && \
"$PYTHON_BIN" "$SCRIPT_DIR/facer_rgb.py" -m 0 -z 4 -b "$BRIGHTNESS" -cR 255 -cG 220 -cB 10

if [ $? -eq 0 ]; then
    echo "[✓] Berhasil diterapkan!"
else
    echo "[✗] Gagal menerapkan warna. Pastikan modul facer sudah aktif."
fi
