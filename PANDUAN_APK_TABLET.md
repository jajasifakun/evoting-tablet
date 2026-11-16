# PANDUAN LENGKAP APLIKASI E-VOTING TABLET ANDROID MANDIRI (OFFLINE)

Aplikasi ini dirancang khusus untuk berjalan pada **1 unit Tablet Android mandiri** (Android 16, RAM 4 GB, Internal 64 GB) secara **100% Offline** tanpa memerlukan koneksi internet, tanpa laptop server, dan tanpa router WiFi.

---

## 1. SPESIFIKASI & ARSITEKTUR APLIKASI TABLET

| Parameter | Spesifikasi |
|---|---|
| **Platform Target** | Android Tablet (Android 10 s/d Android 16) |
| **Kebutuhan Minimum** | RAM 2 GB, ROM 16 GB (Tablet Anda: RAM 4 GB / ROM 64 GB sangat lancar) |
| **Koneksi Jaringan** | **100% OFFLINE** (Bisa mode pesawat / tanpa SIM card / tanpa WiFi) |
| **Penyimpanan Data** | **SQLite Database Lokal (`sqflite`)** di memori internal tablet |
| **Pemindai Kamera** | Native Mobile Scanner (Google ML Kit Engine) |
| **Keamanan Bilik** | Penguncian layar penuh (*Screen Pinning / Kiosk Mode*) |
| **Akses Admin** | Dilindungi **PIN Petugas: `1234`** |

---

## 2. FITUR LENGKAP DI DALAM APLIKASI

### A. Alur Pemilih (Bilik Suara Publik)
1. **Layar Awal**:
   * Menampilkan identitas resmi: *"Pemilihan Kepala Desa Karang Mukti Tahun 2026, Kec. Cipeundeuy, Kab. Subang"*.
   * Logo resmi Panitia Pilkades Karang Mukti.
   * Tombol sentuh besar: **"MULAI PEMILIHAN"**.
2. **Layar Pemindai QR Code**:
   * Kamera tablet otomatis aktif membaca kupon QR Code pemilih secara instan.
   * Tombol alternatif **"Input Kode Manual"** jika kupon sobek atau kamera terhalang.
3. **Surat Suara Digital**:
   * Menampilkan kartu **Calon A** (Nomor Urut 1) dan **Calon B** (Nomor Urut 2) berdampingan secara proporsional di layar tablet.
   * Dilengkapi foto resmi, nomor urut, visi & misi lengkap.
4. **Konfirmasi Pilihan**:
   * Dialog konfirmasi untuk mencegah salah sentuh pemilih: *"Apakah Anda yakin memilih Calon [A/B]?"*.
5. **Pencatatan Suara Sah**:
   * Menghasilkan kode enkripsi acak (*Vote Hash SHA-256*).
   * Token QR pemilih otomatis berstatus **USED**.
   * Pemilih di DPT otomatis berstatus **SUDAH MEMILIH**.
6. **Layar Terima Kasih**:
   * Tampilan ucapan terima kasih dengan hitung mundur otomatis 3 detik kembali ke layar awal untuk pemilih berikutnya.

### B. Panel Administrator & KPPS (Terkunci PIN: `1234`)
Di pojok kanan atas layar awal, terdapat ikon gembok rahasia untuk membuka menu pengawasan:
* **Tab 1: Rekapitulasi Suara**:
  * Grafik perolehan suara Calon A vs Calon B secara real-time.
  * Total DPT (10 pemilih), jumlah suara masuk, dan persentase partisipasi.
* **Tab 2: Daftar DPT (10 Pemilih)**:
  * Memantau daftar 10 nama DPT (Sulaeman, Siti Fatimah, dst).
  * Tombol **Reset Pemilih Ini** (ikon putar balik kuning) jika ingin pemilih tertentu mencoblos lagi pada simulasi.
* **Tab 3: Daftar Token QR**:
  * Status 10 token (Belum Dipakai / Digunakan).
* **Tab 4: Zona Reset Simulasi**:
  * **Opsi 1 (Reset Pemilih & QR Saja)**: Mengembalikan 10 DPT dan 10 QR menjadi aktif kembali tanpa menghapus suara masuk.
  * **Opsi 2 (Reset Total 0 Suara)**: Mengosongkan kembali seluruh kotak suara (kembali ke 0) dan mengaktifkan seluruh DPT serta QR Code untuk simulasi babak baru.

---

## 3. CARA MENG-COMPILE MENJADI FILE `.apk`

### CARA 1: Menggunakan GitHub Actions (Paling Mudah, Gratis & Otomatis) ⭐
Anda tidak perlu menginstal Android Studio atau Flutter di laptop Anda. Biarkan server GitHub yang meng-compile file APK-nya secara online:
1. Buat repositori baru di akun [GitHub](https://github.com/) Anda (misal beri nama `evoting-tablet-apk`).
2. Upload seluruh isi folder `evoting_tablet_app/` ini ke repositori tersebut.
3. Begitu di-upload, sistem **GitHub Actions** yang sudah terkonfigurasi di `.github/workflows/build_apk.yml` akan otomatis mulai meng-compile APK.
4. Tunggu sekitar 2-3 menit:
   * Buka tab **Actions** di repositori GitHub Anda.
   * Klik alur kerja terbaru yang selesai (*checklist* hijau).
   * Pada bagian **Artifacts**, klik download file **`EvotingPilkades-Release-APK.zip`**.
5. Ekstrak zip tersebut, Anda akan mendapatkan file **`app-release.apk`**.
6. Kirim file `.apk` tersebut ke tablet Android Anda (via kabel data USB, Bluetooth, atau WhatsApp Web), lalu instal langsung di tablet!

### CARA 2: Menggunakan Flutter SDK di Laptop
Jika laptop Anda memiliki Flutter SDK:
1. Buka terminal / command prompt pada folder `evoting_tablet_app/`.
2. Jalankan perintah:
   ```bash
   flutter pub get
   flutter build apk --release
   ```
3. File APK siap pakai akan berada di:
   `build/app/outputs/flutter-apk/app-release.apk`

---

## 4. CARA MENGUNCI LAYAR TABLET AGAR TIDAK BISA DIUTAK-ATIK PEMILIH (KIOSK MODE)

Di tablet Android 16 Anda, gunakan fitur bawaan sistem Android bernama **Screen Pinning (Sematkan Aplikasi)**:
1. Buka **Pengaturan (Settings)** tablet ➔ **Keamanan (Security)** ➔ Aktifkan **Sematkan Aplikasi (App Pinning / Screen Pinning)**.
2. Buka aplikasi **E-Voting Pilkades** di tablet.
3. Geser sedikit dari bawah untuk membuka *Recent Apps* (layar aplikasi yang baru dibuka).
4. Ketuk ikon aplikasi E-Voting di atas jendela, lalu pilih **Sematkan (Pin)**.
5. Layar tablet sekarang **100% terkunci** di dalam aplikasi E-Voting:
   * Tombol Home, Back, dan Notifikasi atas tidak akan bisa keluar.
   * Hanya panitia/KPPS yang mengetahui pola kunci/PIN tablet yang bisa keluar dari aplikasi setelah simulasi selesai.
