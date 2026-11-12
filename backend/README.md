# Family Finance Backend

NestJS API untuk aplikasi Family Finance. Kontrak endpoint dan aturan akses tersedia di [`docs/backend-api.md`](docs/backend-api.md).

## Persiapan lokal

1. Gunakan Node.js versi 20 atau lebih baru.
2. Pasang dependency dengan `npm ci` dari direktori `backend`.
3. Siapkan konfigurasi runtime backend secara lokal. Jangan commit file kredensial.
4. Pastikan PostgreSQL development tersedia dan URL database dikonfigurasi.
5. Terapkan migration development dan generate Prisma Client:

   ```cmd
   npx prisma migrate dev
   npx prisma generate
   ```

## Menjalankan backend

Build source TypeScript:

```cmd
npx tsc -p tsconfig.build.json
```

Lalu jalankan output hasil build:

```cmd
npm run start:dev
```

Script `start:dev` menjalankan `node --watch dist/main.js`: ia memulai ulang Node ketika file di `dist` berubah, tetapi tidak mengompilasi perubahan dari `src`. Untuk pengembangan dengan rebuild otomatis, jalankan compiler watch di terminal pertama dan backend di terminal kedua. Pastikan kompilasi awal selesai sebelum backend dimulai:

```cmd
npx tsc -p tsconfig.build.json --watch
```

```cmd
npm run start:dev
```

Untuk menjalankan hasil build tanpa mode watch, gunakan `npm start` setelah build selesai. Port default API adalah 3000; backend juga menerima konfigurasi `PORT`.

## Fitur yang ditunda

Upload lampiran foto/dokumen belum aktif. Schema dan kode attachment masih tersimpan, tetapi `AttachmentsModule` tidak didaftarkan pada `AppModule`. Endpoint lampiran belum tersedia di aplikasi aktif dan konfigurasi object storage belum diperlukan untuk pengembangan fitur lain.
