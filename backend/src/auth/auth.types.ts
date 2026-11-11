import type { UserRole } from '../generated/prisma/enums.js';
import type { Prisma } from '../generated/prisma/client.js';

export const authenticatedUserSelect = {
  id: true,
  email: true,
  role: true,
  isActive: true,
  admin: { select: { name: true } },
  parent: { select: { name: true, familyId: true } },
  child: { select: { name: true, familyId: true } },
} satisfies Prisma.UserSelect;

export type AuthenticatedUserRecord = Prisma.UserGetPayload<{
  select: typeof authenticatedUserSelect;
}>;

export interface AuthenticatedUser {
  id: string;
  name: string;
  email: string;
  role: UserRole;
  familyId: string | null;
}

export interface JwtPayload {
  sub: string;
}

// A profile must match the role and no user may carry multiple role profiles.
export function toAuthenticatedUser(
  record: AuthenticatedUserRecord,
): AuthenticatedUser | null {
  if (record.role === 'ADMIN') {
    if (!record.admin || record.parent || record.child) return null;

    return {
      id: record.id,
      name: record.admin.name,
      email: record.email,
      role: record.role,
      familyId: null,
    };
  }

  if (record.role === 'PARENT') {
    if (!record.parent || record.admin || record.child) return null;

    return {
      id: record.id,
      name: record.parent.name,
      email: record.email,
      role: record.role,
      familyId: record.parent.familyId,
    };
  }

  if (record.role === 'CHILD') {
    if (!record.child || record.admin || record.parent) return null;

    return {
      id: record.id,
      name: record.child.name,
      email: record.email,
      role: record.role,
      familyId: record.child.familyId,
    };
  }

  return null;
}
