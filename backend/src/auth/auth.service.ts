import {
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { PrismaService } from "../prisma/prisma.service.js";
import { LoginDto } from "./login.dto.js";
import {
  authenticatedUserSelect,
  toAuthenticatedUser,
} from "./auth.types.js";
import * as bcrypt from "bcrypt";
import { createHash, randomBytes } from 'node:crypto';

const REFRESH_TOKEN_TTL_DAYS = 30;

function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async login({ email, password }: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: {
        email: email.trim().toLowerCase(),
      },
      select: {
        passwordHash: true,
        ...authenticatedUserSelect,
      },
    });

    if (!user || !user.isActive) {
      throw new UnauthorizedException(
        "Email atau password salah",
      );
    }

    const authenticatedUser = toAuthenticatedUser(user);
    if (!authenticatedUser) {
      throw new UnauthorizedException("Email atau password salah");
    }

    const isPasswordValid = await bcrypt.compare(
      password,
      user.passwordHash,
    );

    if (!isPasswordValid) {
      throw new UnauthorizedException(
        "Email atau password salah",
      );
    }

    const accessToken = await this.jwtService.signAsync({
      sub: user.id,
    });
    const refreshToken = randomBytes(48).toString('base64url');
    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: hashRefreshToken(refreshToken),
        expiresAt: new Date(Date.now() + REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000),
      },
    });

    return {
      message: "Login berhasil",
      accessToken,
      refreshToken,
      user: authenticatedUser,
    };
  }

  async refresh(presentedToken: string) {
    const now = new Date();
    const existing = await this.prisma.refreshToken.findUnique({
      where: { tokenHash: hashRefreshToken(presentedToken) },
      select: {
        id: true,
        userId: true,
        expiresAt: true,
        revokedAt: true,
        user: { select: authenticatedUserSelect },
      },
    });
    if (!existing || existing.revokedAt || existing.expiresAt <= now || !existing.user.isActive) {
      throw new UnauthorizedException('Refresh token tidak valid atau sudah kedaluwarsa.');
    }
    const authenticatedUser = toAuthenticatedUser(existing.user);
    if (!authenticatedUser) throw new UnauthorizedException();

    const nextRefreshToken = randomBytes(48).toString('base64url');
    const expiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000);
    await this.prisma.$transaction(async (tx) => {
      const revoked = await tx.refreshToken.updateMany({
        where: { id: existing.id, revokedAt: null, expiresAt: { gt: now } },
        data: { revokedAt: now },
      });
      if (revoked.count !== 1) throw new UnauthorizedException('Refresh token sudah digunakan.');
      await tx.refreshToken.create({
        data: {
          userId: existing.userId,
          tokenHash: hashRefreshToken(nextRefreshToken),
          expiresAt,
        },
      });
    });

    const accessToken = await this.jwtService.signAsync({ sub: existing.userId });
    return { accessToken, refreshToken: nextRefreshToken, user: authenticatedUser };
  }

  async logout(presentedToken: string) {
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash: hashRefreshToken(presentedToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { message: 'Logout berhasil.' };
  }
}
