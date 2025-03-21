#!/bin/bash


# Variables
REPO_DIR="/opt/linuxoffice"  # Replace with the name of the cloned repository directory
FILE="/var/lib/docker/volumes/linuxoffice/_data/tiny11.iso"
COMPOSE_FILE="$REPO_DIR/docker-compose.yml"  # Path to docker-compose.yml in the cloned repo



# Silinecek dizinler
DIRS=("/linuxoffice" "/opt/linuxoffice")

for DIR in "${DIRS[@]}"; do
    if [ -e "$DIR" ]; then
        echo "Siliniyor: $DIR"
	chattr -a $DIR
        rm -rf "$DIR"
    else
        echo "Kurulum başlıyor"
    fi
done


# Update package lists
echo "Paket listesi güncelleniyor..."
sudo apt update

if ! command -v git &> /dev/null; then
    sudo apt install -y git
else
    echo "Git sürüm yöneticisi zaten yüklü."
fi


# Clone the repository (if not already cloned)
if [ ! -d "$REPO_DIR/docker-compose.yml" ]; then
    echo "Repository klonlaniyor..."
    git clone https://github.com/ogretmen1/linuxoffice.git "$REPO_DIR"
else
    echo "Repository zaten klonlanmis."
fi


read -p "Office uygulamasına vermek istediğiniz RAM'i (GB) giriniz (Varsayılan: 4): " RAM
RAM=${RAM:-4}

read -p "Office uygulamasına vermek istediğiniz CPU miktarını giriniz (Varsayılan: 2): " CPU
CPU=${CPU:-2}

read -p "Office uygulamasına vermek istediğiniz disk alanını (GB) giriniz (Varsayılan: 20): " DISK
DISK=${DISK:-20}

# Update docker-compose.yml with user inputs
sed -i "s/RAM_SIZE:.*/RAM_SIZE: \"${RAM}G\"/" "$COMPOSE_FILE"
sed -i "s/CPU_CORES:.*/CPU_CORES: \"${CPU}\"/" "$COMPOSE_FILE"
sed -i "s/DISK_SIZE:.*/DISK_SIZE: \"${DISK}G\"/" "$COMPOSE_FILE"

echo "RAM: ${RAM}GB, CPU: ${CPU}, Disk: ${DISK}GB olarak ayarlandı. Vazgeçmek için ctrl+c"


if ! command -v xfreerdp &> /dev/null; then
    echo "Freerdp yükleniyor..."
    sudo apt install freerdp2-x11 -y
else
    echo "Freerdp is already installed."
fi


# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    echo "Docker yükleniyor..."
    sudo apt install -y docker.io
    sudo systemctl enable --now docker
else
    echo "Docker zaten yüklü."
    if docker ps -a | grep -q linuxoffice; then
	echo "Konteyner mevcut"
    else
	echo "Konteyner mevcut değil"
    fi
fi

# Install Docker Compose (v2, included with Docker)
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose yükleniyor..."
    sudo apt install -y docker-compose
else
    echo "Docker Compose zaten yüklü."
fi


# Check for docker-compose.yml
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: $COMPOSE_FILE not found in the cloned repository."
    exit 1
fi


# Modify docker-compose.yml based on the presence of tiny11.iso
#if [ -f "$FILE" ]; then
#    echo "File $FILE found. Modifying $COMPOSE_FILE..."
    
    # Comment out VERSION=tiny11
#    sed -i 's/VERSION: "tiny11"/#VERSION: "tiny11"/' "$COMPOSE_FILE" 
    
    # Uncomment the line starting with - /opt
#    sed -i 's|#- /var/lib/docker/volumes/linuxoffice/_data/tiny11.iso:/custom.iso|- /var/lib/docker/volumes/linuxoffice/_data/tiny11.iso:/custom.iso|' "$COMPOSE_FILE"

#    echo "Modifications completed in $COMPOSE_FILE."
#else
#    echo "File $FILE does not exist. No changes made to $COMPOSE_FILE."
#fi



if [ ! -d "/linuxoffice" ]; then
    mkdir /linuxoffice
    echo "/linuxoffice dizini oluşturuldu."
else
    echo "/linuxoffice dizini zaten mevcut."
fi
chown root:root /linuxoffice
chmod 1777 /linuxoffice
chattr +a /linuxoffice


cd "$REPO_DIR"  # Change to the repository directory
sudo docker-compose up -d

# Verify Docker Compose status
if docker-compose ps | grep -q 'Up'; then
    echo "Konteyner  başarıyla başlatıldı."
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Sistem ayağa kaldırılıyor... Bu 10 ile 15 dakika arasında sürebilir..."
else
    echo "Hata: Docker Compose başlatırken hata."
    exit 1
fi

IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' linuxoffice)
#echo "Container IP: $IP"

echo "Kurulma işlemi sürüyor... Tarayıcınızdan http://localhost:8006/ bağlantısına giderek görebilirsiniz."
sleep 60

while true; do
    # xfreerdp'yi çalıştır ve çıktıyı al
    OUTPUT=$(xfreerdp /u:"MyWindowsUser" /p:"MyWindowsPassword" /v:$IP /cert:ignore 2>&1)

    # Eğer hata mesajı içeriyorsa, bekleyip tekrar dene
    if echo "$OUTPUT" | grep -q -E "Broken pipe|ERRCONNECT_CONNECT_TRANSPORT_FAILED|freerdp_post_connect failed"; then
        echo "Kurulma işlemi sürüyor..."
        sleep 30
    else
        echo "Kurulma işlemi başarıyla sonuçlandı"
        break
    fi
done


echo "Linux bilgisayarınızdan /linuxoffice/office/ dizinine indirdiğiniz her şeyi Computer\Network\host.lan\_data dizininde görebilirsiniz. Office Winrar gibi uygulamaları bu şekilde windows tarafına yüklemeniz gerekmektedir."


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
