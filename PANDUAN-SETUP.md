# Panduan Setup - Sistem Tracking Perbaikan Mesin (Versi Mandiri)

Hasil akhir: aplikasi web yang bisa dibuka dari HP, tablet, dan laptop oleh siapa saja yang Anda daftarkan,
**tanpa akun Claude**. Semua layanan memakai paket gratis. Estimasi waktu: 15-20 menit.

Isi folder: `index.html` (aplikasi), `config.js` (pengaturan), `schema.sql` (database).

## Langkah 1 - Buat database (Supabase)
1. Daftar gratis di https://supabase.com, lalu **New project**. Pilih region terdekat (mis. Singapore) dan catat Database Password.
2. Tunggu project selesai dibuat (1-2 menit).

## Langkah 2 - Jalankan skema
1. Buka **SQL Editor > New query**.
2. Salin seluruh isi `schema.sql`, tempel, lalu klik **Run**. Harus muncul "Success".
   Langkah ini membuat tabel, aturan keamanan per peran, penyimpanan foto, dan realtime.

## Langkah 3 - Atur login
1. **Authentication > Providers (atau Sign In / Providers) > Email**: pastikan aktif.
2. Matikan **Confirm email** agar staff bisa langsung masuk setelah daftar (nama menu bisa sedikit berbeda).

## Langkah 4 - Isi config.js
1. Buka **Project Settings > API** (atau API Keys).
2. Salin **Project URL** dan kunci **anon / public**.
3. Buka `config.js`, ganti kedua nilai. Jangan memakai kunci `service_role`.
   Kunci anon memang boleh terlihat publik; keamanan data dijaga oleh aturan di `schema.sql`.

## Langkah 5 - Pasang di hosting gratis
Pilih salah satu:
- **Netlify Drop** (termudah): buka https://app.netlify.com/drop, seret **seluruh folder** ini. Anda langsung mendapat link `https://xxxx.netlify.app`.
- **Cloudflare Pages** atau **GitHub Pages**: unggah ketiga file ke repositori/proyek, lalu publikasikan.

## Langkah 6 - Daftarkan Site URL
Di Supabase: **Authentication > URL Configuration**, isi **Site URL** dengan link dari Langkah 5.

## Langkah 7 - Mulai dipakai
1. Buka link aplikasi dan **daftar lebih dulu**. Akun pertama otomatis menjadi **Editor**.
2. Bagikan link ke tim. Setiap orang mendaftar sendiri dengan email dan password, lalu memilih **Produksi** atau **Staff ME**.
3. Editor membuka menu **Pengguna** untuk menaikkan peran seseorang menjadi **Manager** atau **Editor**.
4. Di HP, buka link lalu pilih "Tambahkan ke layar utama" agar tampil seperti aplikasi.

## Hak akses (dijaga oleh database)
| Peran | Bisa |
|---|---|
| Produksi | Lapor kerusakan + foto, verifikasi perbaikan |
| Manager | Dashboard, lapor, tugaskan staff, close tiket |
| Staff ME | Ubah status perbaikan tiket miliknya, tambah foto |
| Editor | Semua + edit/hapus tiket dan foto, kelola pengguna |

## Catatan paket gratis
- Project Supabase gratis akan **dijeda jika tidak dipakai sekitar 7 hari**. Buka dashboard Supabase lalu klik Restore.
- Batas gratis saat ini sekitar 500 MB database dan 1 GB foto. Foto dikompres otomatis. Cek batas terbaru di halaman harga Supabase.
- Cadangkan data secara berkala lewat tombol **Export Excel**.
- Lupa password: reset lewat Supabase **Authentication > Users**.

## Jika bermasalah
- Layar "Konfigurasi belum diisi": `config.js` belum diganti atau belum ikut terunggah.
- "Gagal memuat data" / "relation does not exist": `schema.sql` belum dijalankan.
- Tidak bisa masuk setelah daftar: Confirm email masih aktif (Langkah 3), cek email konfirmasi.
- Perubahan tidak muncul otomatis di perangkat lain: jalankan ulang baris terakhir `schema.sql` (realtime) atau muat ulang halaman.
