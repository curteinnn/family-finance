
import "dotenv/config";
import bcrypt from "bcrypt";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "../src/generated/prisma/client.js";
const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error("DATABASE_URL belum dikonfigurasi");
}

const adapter = new PrismaPg({ connectionString });
const prisma = new PrismaClient({ adapter });

const categories = [
  "Makan pokok",
  "Jajan",
  "Transportasi",
  "Pendidikan",
  "Kesehatan",
  "Kebutuhan pribadi",
  "Hiburan",
  "Lainnya",
];

async function main() {
  const name = process.env.ADMIN_NAME;
  const email = process.env.ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD;

  if (!name || !email || !password) {
    throw new Error("Konfigurasi ADMIN belum lengkap di .env");
  }

  if (password.length < 12) {
    throw new Error("Password ADMIN minimal 12 karakter");
  }

  const passwordHash = await bcrypt.hash(password, 12);

  await prisma.$transaction(async (transaction) => {
    const adminUser = await transaction.user.upsert({
      where: { email },
      update: {},
      create: {
        email,
        passwordHash,
        role: "ADMIN",
      },
      select: { id: true, role: true },
    });

    if (adminUser.role !== "ADMIN") {
      throw new Error("Email ADMIN sudah digunakan oleh role lain.");
    }

    await transaction.admin.upsert({
      where: { userId: adminUser.id },
      update: { name },
      create: { userId: adminUser.id, name },
    });
  });

  for (const categoryName of categories) {
    await prisma.category.upsert({
      where: { name: categoryName },
      update: {},
      create: { name: categoryName },
    });
  }

  console.log("ADMIN dan kategori default berhasil disiapkan.");
}

main()
  .catch((error) => {
    console.error("Seed gagal:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
