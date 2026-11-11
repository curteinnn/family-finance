import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../prisma/prisma.service.js';
import {
  authenticatedUserSelect,
  toAuthenticatedUser,
} from './auth.types.js';
import type { AuthenticatedUser, JwtPayload } from './auth.types.js';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.getOrThrow<string>('JWT_SECRET'),
    });
  }

  async validate(payload: JwtPayload): Promise<AuthenticatedUser> {
    if (!payload || typeof payload.sub !== 'string') {
      throw new UnauthorizedException();
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      select: authenticatedUserSelect,
    });

    if (!user?.isActive) {
      throw new UnauthorizedException();
    }

    const authenticatedUser = toAuthenticatedUser(user);
    if (!authenticatedUser) throw new UnauthorizedException();

    return authenticatedUser;
  }
}
