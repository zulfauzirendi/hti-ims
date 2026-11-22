import { UserRole } from '@prisma/client';

export interface AuthUser {
  id: number;
  username: string;
  fullName: string;
  role: UserRole;
  assignedLocationId: number | null;
  mustChangePassword: boolean;
}

declare global {
  namespace Express {
    interface Request {
      requestId: string;
      user?: AuthUser;
    }
  }
}
