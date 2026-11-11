#!/usr/bin/env bash
# =====================================================================
#  BUILD APP FLUTTER trên Linux (tương đương build_app.bat bên Windows)
#  Copy file này vào thư mục gốc project Flutter (cạnh pubspec.yaml), rồi:
#      chmod +x build_app.sh
#      ./build_app.sh          # mở menu
#      ./build_app.sh 8        # chạy thẳng một mục (không hỏi gì thêm)
#  Hỗ trợ đầy đủ Debian/Ubuntu (apt). Distro khác: tự cài gói tương ứng.
#  Dùng được cho NHIỀU dự án: tên app, icon, APP_ID tự đọc từ project.
#  Muốn ghi đè (tên hiển thị, icon, nhóm menu...) -> tạo build_app.conf cạnh pubspec.yaml
#  (mẫu: build_app.conf.example).
# =====================================================================

cd "$(dirname "$(readlink -f "$0")")" || exit 1

LOG="build_log.txt"
OUT=""
NONINTERACTIVE=""

if [ ! -f pubspec.yaml ]; then
  echo "*** Không tìm thấy pubspec.yaml. Hãy copy file này vào thư mục gốc project Flutter."
  exit 1
fi

# --- PATH cho Flutter / Rust nếu cài trong $HOME ---
if [ -d "$HOME/flutter/bin" ]; then
  case ":$PATH:" in *":$HOME/flutter/bin:"*) ;; *) PATH="$HOME/flutter/bin:$PATH" ;; esac
fi
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# --- Đọc tên app + version từ pubspec.yaml ---
APPNAME=$(grep -m1 '^name:' pubspec.yaml | awk '{print $2}' | tr -d '\r')
APPVER=$(grep -m1 '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1 | tr -d '\r')

# Tên file chạy thật của bản Linux (có thể khác tên trong pubspec)
BIN=""
if [ -f linux/CMakeLists.txt ]; then
  BIN=$(grep -m1 -E 'set\(BINARY_NAME' linux/CMakeLists.txt | sed -E 's/.*BINARY_NAME[[:space:]]+"([^"]+)".*/\1/')
fi
[ -z "$BIN" ] && BIN="$APPNAME"

# ---------------------------------------------------------------------
#  Cấu hình đóng gói: TỰ PHÁT HIỆN từ project, có thể ghi đè bằng file
#  build_app.conf (đặt cạnh pubspec.yaml). Xem build_app.conf.example.
# ---------------------------------------------------------------------
# Tên hiển thị: ưu tiên tiêu đề cửa sổ trong linux/runner/my_application.cc (nếu đã đổi
# khác tên mặc định), không có thì "đẹp hoá" tên package (quan_ly_x -> Quan Ly X)
APP_DISPLAY_NAME=""
if [ -f linux/runner/my_application.cc ]; then
  APP_DISPLAY_NAME=$(grep -m1 -E 'set_title\(' linux/runner/my_application.cc | sed -nE 's/.*set_title\([^,]*,[[:space:]]*"([^"]+)".*/\1/p')
  case "$APP_DISPLAY_NAME" in "$APPNAME"|"$BIN") APP_DISPLAY_NAME="" ;; esac
fi
[ -z "$APP_DISPLAY_NAME" ] && APP_DISPLAY_NAME=$(echo "$APPNAME" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1)) substr($i,2)}1')

# Icon: image_path của flutter_launcher_icons, hoặc vài đường dẫn thường gặp
ICON_SRC=$(grep -m1 -E '^[[:space:]]*image_path:' pubspec.yaml | sed -E "s/.*image_path:[[:space:]]*[\"']?([^\"'#[:space:]]+).*/\1/" | tr -d '\r')
if [ -z "$ICON_SRC" ] || [ ! -f "$ICON_SRC" ]; then
  ICON_SRC=""
  for f in assets/icon/app_icon.png assets/icon/icon.png assets/icons/app_icon.png assets/images/app_icon.png assets/images/icon.png assets/icon.png assets/logo.png; do
    [ -f "$f" ] && { ICON_SRC="$f"; break; }
  done
fi

# APP_ID = APPLICATION_ID trong linux/CMakeLists.txt (phải trùng để icon taskbar khớp)
APP_ID=""
[ -f linux/CMakeLists.txt ] && APP_ID=$(grep -m1 -E 'set\(APPLICATION_ID' linux/CMakeLists.txt | sed -E 's/.*APPLICATION_ID[[:space:]]+"([^"]+)".*/\1/')
[ -z "$APP_ID" ] && APP_ID="com.example.$APPNAME"

DEB_MAINTAINER="${USER:-dev}"
DEB_SECTION="utils"
DESKTOP_CATEGORIES="Utility;"

# Gói hệ thống theo plugin thực sự dùng trong dự án
PKGS_EXTRA=""
USES_TRAY=""
if grep -qE '^[[:space:]]+(tray_manager|system_tray|tray_icon|flutter_tray)[[:alnum:]_]*:' pubspec.yaml 2>/dev/null; then
  USES_TRAY=1; PKGS_EXTRA=" libayatana-appindicator3-dev"
fi

# File cấu hình riêng của từng dự án (nếu có) ghi đè mọi giá trị ở trên
[ -f ./build_app.conf ] && . ./build_app.conf

case "$(uname -m)" in
  aarch64|arm64) LARCH="arm64"; DEBARCH="arm64" ;;
  *)             LARCH="x64";   DEBARCH="amd64" ;;
esac
BUNDLE="build/linux/$LARCH/release/bundle"

# ---------------------------------------------------------------------
#  Tiện ích
# ---------------------------------------------------------------------
pause() { [ -n "$NONINTERACTIVE" ] || read -rp "Nhấn Enter để tiếp tục..." _; }

# Chạy lệnh: hiện ra màn hình + ghi vào build_log.txt, trả về exit code thật
run() {
  { echo; echo "===== $*"; } >> "$LOG"
  "$@" 2>&1 | tee -a "$LOG"
  return "${PIPESTATUS[0]}"
}

need_flutter() {
  if ! command -v flutter >/dev/null 2>&1; then
    echo "*** Không tìm thấy lệnh flutter. Chọn S để cài môi trường, hoặc xem hướng dẫn (H)."
    return 1
  fi
}

# ---------------------------------------------------------------------
#  Môi trường Linux: kiểm tra / cài đặt / hướng dẫn
# ---------------------------------------------------------------------
PKGS="curl git unzip xz-utils zip rsync libglu1-mesa clang cmake ninja-build pkgconf libgtk-3-dev liblzma-dev libsecret-1-dev libjsoncpp-dev build-essential$PKGS_EXTRA"

linux_check() {
  local miss=0 p
  if ! command -v dpkg >/dev/null 2>&1; then
    echo "(Không phải Debian/Ubuntu: bỏ qua kiểm tra gói apt. Tự cài: clang cmake ninja pkg-config gtk3-dev liblzma-dev libsecret-dev jsoncpp-dev; thêm libayatana-appindicator3-dev nếu dùng tray_manager)"
  else
    for p in $PKGS; do
      dpkg -s "$p" >/dev/null 2>&1 || { echo "THIẾU gói: $p"; miss=1; }
    done
  fi
  command -v flutter >/dev/null 2>&1 || { echo "THIẾU Flutter"; miss=1; }
  if grep -qiE 'native_toolchain_rust|libsql_dart|flutter_rust_bridge' pubspec.lock pubspec.yaml 2>/dev/null; then
    command -v rustup >/dev/null 2>&1 || { echo "THIẾU Rust (rustup) - dự án dùng gói native Rust (libsql_dart)"; miss=1; }
  fi
  [ "$miss" = "0" ] && echo "Môi trường Linux: ĐẦY ĐỦ"
  return $miss
}

linux_setup() {
  set -e
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "Chỉ tự cài được trên Debian/Ubuntu (apt). Xem hướng dẫn (H) để cài tay."
    return 1
  fi
  echo "== [1/4] Cài gói hệ thống (nhập mật khẩu sudo nếu được hỏi) =="
  sudo apt-get update
  sudo apt-get install -y $PKGS
  echo "== [2/4] Cài Flutter =="
  if [ ! -x "$HOME/flutter/bin/flutter" ] && ! command -v flutter >/dev/null 2>&1; then
    git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
  fi
  grep -q 'flutter/bin' "$HOME/.profile" 2>/dev/null || echo 'export PATH="$HOME/flutter/bin:$PATH"' >> "$HOME/.profile"
  export PATH="$HOME/flutter/bin:$PATH"
  flutter config --enable-linux-desktop
  flutter --version
  echo "== [3/4] Cài Rust (cần cho một số gói native như libsql_dart) =="
  if ! command -v rustup >/dev/null 2>&1 && [ ! -x "$HOME/.cargo/bin/rustup" ]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
  fi
  . "$HOME/.cargo/env"
  grep -q '.cargo/env' "$HOME/.profile" 2>/dev/null || echo '. "$HOME/.cargo/env"' >> "$HOME/.profile"
  rustup default stable
  echo "== [4/4] Flutter doctor =="
  flutter doctor || true
  echo "SETUP XONG"
}

linux_guide() {
  cat <<'EOF'
=====================================================================
 HƯỚNG DẪN CÀI MÔI TRƯỜNG BUILD LINUX BẰNG TAY (Ubuntu/Debian)
=====================================================================
BƯỚC 1 - Cài các gói cần thiết (chạy MỘT dòng)
  sudo apt update
  sudo apt install -y curl git unzip xz-utils zip rsync libglu1-mesa clang cmake ninja-build pkgconf libgtk-3-dev liblzma-dev libsecret-1-dev libjsoncpp-dev build-essential
  (Dự án dùng tray_manager/system_tray: cài thêm libayatana-appindicator3-dev)
  (Nếu log báo "required packages were not found: ten>=x.y" thì cài gói ten-dev tương ứng.)

BƯỚC 2 - Cài Flutter
  git clone https://github.com/flutter/flutter.git -b stable ~/flutter
  echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.profile
  source ~/.profile
  flutter config --enable-linux-desktop
  flutter doctor        (mục "Linux toolchain" phải có dấu tích)

BƯỚC 3 - Cài Rust (BẮT BUỘC nếu dự án dùng libsql_dart / gói native Rust)
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
  source ~/.cargo/env
  echo '. "$HOME/.cargo/env"' >> ~/.profile
  rustup default stable

BƯỚC 4 - (Chỉ khi build Android) Cài Android SDK / Android Studio, rồi:
  flutter doctor --android-licenses

BƯỚC 5 - Chạy lại ./build_app.sh
LƯU Ý
  - Nên dùng phiên bản Flutter gần giống bên Windows (xem: flutter --version).
  - Gói .deb đã có icon + tên "Quản lý công trình". Cài thử: sudo apt install ./ten_goi.deb
EOF
}

# Đảm bảo môi trường sẵn sàng; hỏi cài nếu thiếu. Trả về 0 nếu OK.
ensure_linux_env() {
  linux_check && return 0
  echo
  echo "*** Môi trường Linux còn thiếu (xem danh sách ở trên)."
  if [ -n "$NONINTERACTIVE" ]; then return 1; fi
  echo "    [A] Tự động cài đặt (hỏi mật khẩu sudo, mất vài phút)"
  echo "    [G] Xem hướng dẫn cài bằng tay"
  echo "    [Q] Quay lại"
  local ans; read -rp "Chọn A/G/Q: " ans
  case "${ans,,}" in
    a) linux_setup && echo && linux_check ;;
    g) linux_guide; return 1 ;;
    *) return 1 ;;
  esac
}

# Vá json.hpp cũ của flutter_secure_storage_linux (clang mới coi `operator "" _json` là lỗi -Werror)
patch_json_hpp() {
  find "$HOME/.pub-cache/hosted" -path '*flutter_secure_storage_linux*' -name json.hpp \
    -exec sed -i -E 's/operator[[:space:]]*""[[:space:]]+_json/operator ""_json/g' {} + 2>/dev/null || true
}

# ---------------------------------------------------------------------
#  Các mục build. Mỗi hàm: return 0 = OK (đặt OUT), 1 = lỗi, 2 = hủy
# ---------------------------------------------------------------------
b_apk()     { need_flutter || return 1; run flutter pub get || return 1
              run flutter build apk --release || return 1
              OUT="build/app/outputs/flutter-apk"; }

b_apk_abi() { need_flutter || return 1; run flutter pub get || return 1
              run flutter build apk --release --split-per-abi || return 1
              OUT="build/app/outputs/flutter-apk"; }

b_aab()     { need_flutter || return 1; run flutter pub get || return 1
              run flutter build appbundle --release || return 1
              OUT="build/app/outputs/bundle/release"; }

b_linux_run() {
  need_flutter || return 1
  ensure_linux_env || return 2
  run flutter pub get || return 1
  patch_json_hpp
  run flutter build linux --release || return 1
  mkdir -p build/linux
  local tgz="build/linux/${APPNAME}_${APPVER}_linux_${LARCH}.tar.gz"
  tar -czf "$tgz" -C "$BUNDLE" . || return 1
  echo "Đã nén: $tgz"
  echo "Chạy thử: $BUNDLE/$BIN"
  OUT="$BUNDLE"
}

b_linux_deb() {
  b_linux_run || return $?
  command -v dpkg-deb >/dev/null 2>&1 || { echo "*** Thiếu dpkg-deb (chỉ có trên Debian/Ubuntu)."; return 1; }
  [ -x "$BUNDLE/$BIN" ] || { echo "*** Không thấy file chạy $BUNDLE/$BIN (BINARY_NAME trong linux/CMakeLists.txt?)"; return 1; }
  local HAS_ICON=1 ICON_LINE=""
  [ -n "$ICON_SRC" ] && [ -f "$ICON_SRC" ] || { HAS_ICON=""; echo "!!! Không tìm thấy icon (đặt ICON_SRC trong build_app.conf) -> .deb sẽ không có logo."; }

  local P D deps
  P=$(echo "$APPNAME" | tr '_' '-' | tr '[:upper:]' '[:lower:]')
  D=$(mktemp -d "/tmp/deb_${P}.XXXXXX")
  deps="libgtk-3-0, liblzma5"
  [ -n "$USES_TRAY" ] && deps="$deps, libayatana-appindicator3-1"
  grep -q 'flutter_secure_storage' pubspec.lock 2>/dev/null && deps="$deps, libsecret-1-0"

  mkdir -p "$D/DEBIAN" "$D/opt/$P" "$D/usr/bin" "$D/usr/share/applications" \
           "$D/usr/share/icons/hicolor/256x256/apps" build/deb
  cp -r "$BUNDLE"/. "$D/opt/$P/"
  ln -s "/opt/$P/$BIN" "$D/usr/bin/$P"

  # Icon: tên file = APP_ID
  if [ -n "$HAS_ICON" ]; then
    cp "$ICON_SRC" "$D/usr/share/icons/hicolor/256x256/apps/$APP_ID.png"
    ICON_LINE="Icon=$APP_ID"
  fi

  # .desktop: tên file = APP_ID, Icon = APP_ID (không dùng đường dẫn), Name = tên hiển thị
  cat > "$D/usr/share/applications/$APP_ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$APP_DISPLAY_NAME
Exec=/opt/$P/$BIN
$ICON_LINE
Terminal=false
Categories=$DESKTOP_CATEGORIES
StartupWMClass=$APP_ID
EOF

  cat > "$D/DEBIAN/control" <<EOF
Package: $P
Version: $APPVER
Section: $DEB_SECTION
Priority: optional
Architecture: $DEBARCH
Depends: $deps
Maintainer: $DEB_MAINTAINER
Description: $APP_DISPLAY_NAME
EOF

  cat > "$D/DEBIAN/postinst" <<'EOF'
#!/bin/sh
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true
exit 0
EOF
  cat > "$D/DEBIAN/postrm" <<'EOF'
#!/bin/sh
gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true
exit 0
EOF
  chmod 755 "$D/DEBIAN" "$D/DEBIAN/postinst" "$D/DEBIAN/postrm"

  run dpkg-deb --root-owner-group --build "$D" "build/deb/${P}_${APPVER}_${DEBARCH}.deb" || { rm -rf "$D"; return 1; }
  rm -rf "$D"
  DEB_FILE="build/deb/${P}_${APPVER}_${DEBARCH}.deb"
  DEB_PKG="$P"
  echo "DEB XONG: $DEB_FILE"
  OUT="build/deb"
}

b_web_build() { need_flutter || return 1; run flutter pub get || return 1
                run flutter build web --release || return 1
                OUT="build/web"; }

b_web_run() {
  need_flutter || return 1
  run flutter pub get || return 1
  if command -v google-chrome >/dev/null 2>&1 || command -v chromium >/dev/null 2>&1 \
     || command -v chromium-browser >/dev/null 2>&1 || [ -n "$CHROME_EXECUTABLE" ]; then
    flutter run -d chrome --release
  else
    echo "Không tìm thấy Chrome/Chromium -> chạy web-server tại http://localhost:8080"
    flutter run -d web-server --web-port 8080 --release
  fi
  return 2   # không có thư mục kết quả để mở
}

b_clean() { need_flutter || return 1; run flutter clean; run flutter pub get; return 2; }

# ---------------------------------------------------------------------
#  Kết thúc
# ---------------------------------------------------------------------
finish_ok() {
  echo
  echo "=============================================="
  echo "  HOÀN TẤT. Kết quả nằm ở: $PWD/$OUT"
  echo "=============================================="
  if [ -z "$NONINTERACTIVE" ] && [ -d "$OUT" ] && command -v xdg-open >/dev/null 2>&1 \
     && { [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; }; then
    xdg-open "$OUT" >/dev/null 2>&1 &
  fi
  suggest_install_deb
}

# Gợi ý lệnh cài .deb (đè bản cũ kể cả khi version không đổi) và hỏi cài luôn
suggest_install_deb() {
  [ -n "$DEB_FILE" ] && [ -f "$DEB_FILE" ] || return 0
  local cmd="sudo apt install --reinstall --allow-downgrades -y ./$DEB_FILE"
  echo
  echo "----------------------------------------------"
  echo "  CÀI ĐẶT (đè bản cũ, kể cả khi chưa đổi version):"
  echo "    $cmd"
  echo "  Gỡ app:  sudo apt remove $DEB_PKG"
  echo "  (Nên tắt app đang chạy trước khi cài đè.)"
  echo "----------------------------------------------"
  [ -n "$NONINTERACTIVE" ] && return 0
  local ans; read -rp "Cài đặt ngay bây giờ? [y/N]: " ans
  case "${ans,,}" in
    y|yes)
      if pgrep -x "$BIN" >/dev/null 2>&1; then
        read -rp "App '$BIN' đang chạy. Tắt app rồi nhấn Enter để tiếp tục..." _
      fi
      sudo apt install --reinstall --allow-downgrades -y "./$DEB_FILE" \
        && echo "ĐÃ CÀI XONG. Mở app từ menu ứng dụng hoặc gõ: $DEB_PKG" \
        || echo "*** Cài đặt thất bại (xem thông báo ở trên)." ;;
  esac
}

finish_fail() {
  echo
  echo "=============================================="
  echo "  *** BUILD THẤT BẠI ***"
  echo "  Log đầy đủ: $PWD/$LOG"
  echo "=============================================="
  echo "----- 40 dòng cuối của log -----"
  tail -n 40 "$LOG"
  echo "--------------------------------"
  case "$1" in 8|9) echo "GỢI Ý: nếu lỗi do thiếu gói/Flutter/Rust, chọn S để kiểm tra và cài đặt." ;; esac
  grep -qiE 'cargo|rustc|rustup' "$LOG" 2>/dev/null && \
    echo "GỢI Ý: log có nhắc đến Rust (cargo). Chọn S để cài Rust rồi build lại."
  grep -qi 'required packages were not found' "$LOG" 2>/dev/null && \
    echo "GỢI Ý: thiếu thư viện dev. Xem tên sau \"were not found\" trong log (vd libsecret-1) và chạy: sudo apt install -y ten-dev"
  grep -qi 'Android SDK' "$LOG" 2>/dev/null && \
    echo "GỢI Ý: chưa cấu hình Android SDK. Cài Android Studio, rồi: flutter doctor --android-licenses"
}

# ---------------------------------------------------------------------
#  Menu
# ---------------------------------------------------------------------
show_menu() {
  clear 2>/dev/null
  cat <<EOF
==============================================
  BUILD APP FLUTTER (Linux)
  Project: $PWD
  App: $APPNAME   Version: $APPVER
==============================================

 ANDROID  (cần Android SDK)
   1. APK                      (file cài đặt trực tiếp)
   2. APK tách theo ABI        (nhẹ hơn, nhiều file)
   3. AAB                      (để upload Google Play)

 LINUX
   8. Bản chạy trực tiếp       (thư mục bundle + file .tar.gz)
   9. Gói cài đặt .deb
   S. Kiểm tra / cài đặt môi trường Linux
   H. Xem hướng dẫn cài môi trường bằng tay

 WEB
  10. Build web                (thư mục build/web để deploy)
  11. Chạy thử web (Chrome / web-server)

 KHÁC
   C. flutter clean + pub get
   L. Xem file log lần build gần nhất
   0. Thoát

 (Windows: MSIX / Inno / MSI chỉ build được trên máy Windows -> dùng build_app.bat)

EOF
}

dispatch() {
  local c="${1^^}" fn=""
  case "$c" in
    0)  exit 0 ;;
    L)  if [ -f "$LOG" ]; then "${PAGER:-less}" "$LOG"; else echo "Chưa có file log."; pause; fi; return ;;
    H)  linux_guide; pause; return ;;
    S)  if linux_check; then echo; echo "Môi trường Linux đã đầy đủ, sẵn sàng build."
        else ensure_linux_env && echo "Cài đặt môi trường thành công."; fi
        pause; return ;;
    1)  fn=b_apk ;;
    2)  fn=b_apk_abi ;;
    3)  fn=b_aab ;;
    8)  fn=b_linux_run ;;
    9)  fn=b_linux_deb ;;
    10) fn=b_web_build ;;
    11) fn=b_web_run ;;
    C)  fn=b_clean ;;
    *)  echo "Lựa chọn không hợp lệ."; pause; return ;;
  esac

  echo "Build log - $(date '+%F %T') - lựa chọn $c" > "$LOG"
  OUT=""; DEB_FILE=""; DEB_PKG=""
  "$fn"
  case $? in
    0) finish_ok ;;
    2) : ;;
    *) finish_fail "$c" ;;
  esac
  pause
}

if [ -n "$1" ]; then
  NONINTERACTIVE=1
  dispatch "$1"
  exit 0
fi

while true; do
  show_menu
  read -rp "Chọn số: " CHOICE
  dispatch "$CHOICE"
done
