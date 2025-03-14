#!/bin/bash
if docker-compose ps | grep -q 'Up'; then
    echo "Konteyner çalışıyor."
    echo "Kısayollar oluşturuluyor"
else
    echo "Çalışan konteyner bulunamadı."
    exit 1
fi
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

        echo "📌 $USERNAME için başlatıcı oluşturuluyor: $LAUNCHER_PATH"
	rm -rf $LAUNCHER_PATH

        # Başlatıcıyı oluştur
        cat <<EOF > "$LAUNCHER_PATH"
[Desktop Entry]
Version=1.0
Type=Application
Name=Windows
Comment=Windows
Exec=xfreerdp /u:MyWindowsUser /p:MyWindowsPassword /v:$IP /cert:ignore /gfx /sound /dynamic-resolution
Icon=computer
Terminal=false
Categories=Network;
EOF

        # Çalıştırma izni ver
        chmod +x "$LAUNCHER_PATH"

        # Kullanıcıya ait yap
        chown "$USERNAME:$USERNAME" "$LAUNCHER_PATH"

        echo "✅ $USERNAME için başlatıcı oluşturuldu."
    fi
done

echo "İşlem tamamlandı!"
echo "Masaüstü Windows kısayolu oluşturuldu!"


for user_home in /home/*; do
    if [ -d "$user_home" ]; then
        USERNAME=$(basename "$user_home")

        # Olası masaüstü dizinleri
        DESKTOP_DIR="$user_home/Desktop"
        ALTERNATE_DESKTOP_DIR="$user_home/Masaüstü"

        # Kullanıcının masaüstü dizinini belirle
        if [ -d "$DESKTOP_DIR" ]; then
            LAUNCHER_PATH="$DESKTOP_DIR/linuxoffice_powerpoint.desktop"
        elif [ -d "$ALTERNATE_DESKTOP_DIR" ]; then
            LAUNCHER_PATH="$ALTERNATE_DESKTOP_DIR/linuxoffice_powerpoint.desktop"
        else
            echo "⚠️  Kullanıcı $USERNAME için masaüstü dizini bulunamadı, atlanıyor..."
            continue
        fi

        # Eğer başlatıcı zaten varsa atla
        echo "📌 $USERNAME için başlatıcı oluşturuluyor: $LAUNCHER_PATH"
	rm -rf $LAUNCHER_PATH

        # Başlatıcıyı oluştur
        cat <<EOF > "$LAUNCHER_PATH"
[Desktop Entry]
Version=1.0
Type=Application
Name=Office Powerpoint 16
Comment=Office Powerpoint
Exec=xfreerdp /u:MyWindowsUser /p:MyWindowsPassword /v:$IP /cert:ignore /app:'C:\Program Files (x86)\Microsoft Office\root\Office16\POWERPNT.EXE' /dynamic-resolution /gfx /sound
Icon=computer
Terminal=false
Categories=Network;
EOF

        # Çalıştırma izni ver
        chmod +x "$LAUNCHER_PATH"

        # Kullanıcıya ait yap
        chown "$USERNAME:$USERNAME" "$LAUNCHER_PATH"

        echo "✅ $USERNAME için başlatıcı oluşturuldu."
    fi
done

echo "İşlem tamamlandı!"
echo "Office 16 uygulama kısayolu oluşturuldu!"



##### OFFİCE DİZİN KISAYOLU

# Hedef dizin ve kısayol adı
TARGET_DIR="/linuxoffice/office"
SHORTCUT_NAME="Office Dosyaları"
DESKTOP_PATH="/etc/skel/Masaüstü"  # Yeni kullanıcılar için
GLOBAL_DESKTOP_PATH="/usr/share/applications"

# Hedef dizin mevcut mu?
if [ ! -d "$TARGET_DIR" ]; then
    echo "Hedef dizin mevcut değil: $TARGET_DIR"
    exit 1
fi

# .desktop dosya içeriği
SHORTCUT_CONTENT="[Desktop Entry]
Type=Link
Name=$SHORTCUT_NAME
Icon=folder
URL=file://$TARGET_DIR"

# Var olan kullanıcılar için
for user_home in /home/*; do
    for desktop_folder in "Desktop" "Masaüstü"; do
        user_desktop="$user_home/$desktop_folder"
        if [ -d "$user_desktop" ]; then
            echo "$SHORTCUT_CONTENT" > "$user_desktop/$SHORTCUT_NAME.desktop"
            chmod 644 "$user_desktop/$SHORTCUT_NAME.desktop"
            chown $(basename "$user_home"):$(basename "$user_home") "$user_desktop/$SHORTCUT_NAME.desktop"
        fi
    done
done

# Yeni kullanıcılar için
for desktop_folder in "Desktop" "Masaüstü"; do
    mkdir -p "/etc/skel/$desktop_folder"
    echo "$SHORTCUT_CONTENT" > "/etc/skel/$desktop_folder/$SHORTCUT_NAME.desktop"
    chmod 644 "/etc/skel/$desktop_folder/$SHORTCUT_NAME.desktop"
done

echo "Office dizini kısayolu oluşturuldu."
