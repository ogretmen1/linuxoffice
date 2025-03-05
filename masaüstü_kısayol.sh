#!/bin/bash


IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' linuxoffice)
# Kullanıcıların ev dizinini kontrol et
for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        USERNAME=$(basename "$user_home")

        # Olası masaüstü dizinleri
        DESKTOP_DIR="$user_home/Desktop"
        ALTERNATE_DESKTOP_DIR="$user_home/Masaüstü"

        # Kullanıcının masaüstü dizinini belirle
        if [ -d "$DESKTOP_DIR" ]; then
            LAUNCHER_PATH="$DESKTOP_DIR/linuxoffice.desktop"
        elif [ -d "$ALTERNATE_DESKTOP_DIR" ]; then
            LAUNCHER_PATH="$ALTERNATE_DESKTOP_DIR/linuxoffice.desktop"
        else
            echo "⚠️  Kullanıcı $USERNAME için masaüstü dizini bulunamadı, atlanıyor..."
            continue
        fi

        # Eğer başlatıcı zaten varsa atla
        if [ ! -f "$LAUNCHER_PATH" ]; then
            echo "📌 $USERNAME için başlatıcı oluşturuluyor: $LAUNCHER_PATH"

            # Başlatıcıyı oluştur
            cat <<EOF > "$LAUNCHER_PATH"
[Desktop Entry]
Version=1.0
Type=Application
Name=Remote Desktop
Comment=Linux Office
Exec=xfreerdp /u:MyWindowsUser /p:MyWindowsPassword /v:$IP /cert:tofu
Icon=computer
Terminal=false
Categories=Network;
EOF

            # Çalıştırma izni ver
            chmod +x "$LAUNCHER_PATH"

            # Kullanıcıya ait yap
            chown "$USERNAME:$USERNAME" "$LAUNCHER_PATH"

            echo "✅ $USERNAME için başlatıcı oluşturuldu."
        else
            echo "ℹ️  $USERNAME için başlatıcı zaten var, atlanıyor."
        fi
    fi
done

echo "🎯 İşlem tamamlandı!"
