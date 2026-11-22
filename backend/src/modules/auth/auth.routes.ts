import { Router } from 'express';
import { authenticateJwt } from '../../middlewares/authenticate';
import { loginRateLimiter } from '../../middlewares/rateLimiter';
import { validateBody } from '../../middlewares/validate';
import { sendSuccess } from '../../utils/response';
import { changePasswordSchema, loginSchema, logoutSchema, refreshSchema } from './auth.schema';
import {
  changeUserPassword,
  getCurrentUserProfile,
  loginUser,
  logoutSession,
  refreshSession,
} from './auth.service';

export const authRouter = Router();

authRouter.post('/login', loginRateLimiter, validateBody(loginSchema), async (req, res, next) => {
  try {
    const result = await loginUser(req.body.username, req.body.password, req.body.deviceInfo);
    sendSuccess(req, res, result, 200);
  } catch (err) {
    next(err);
  }
});

authRouter.post('/refresh', validateBody(refreshSchema), async (req, res, next) => {
  try {
    const result = await refreshSession(req.body.refreshToken, req.body.deviceInfo);
    sendSuccess(req, res, result, 200);
  } catch (err) {
    next(err);
  }
});

authRouter.post('/logout', authenticateJwt, validateBody(logoutSchema), async (req, res, next) => {
  try {
    await logoutSession(req.body.refreshToken, req.user!.id);
    sendSuccess(req, res, { revoked: true }, 200);
  } catch (err) {
    next(err);
  }
});

authRouter.post(
  '/change-password',
  authenticateJwt,
  validateBody(changePasswordSchema),
  async (req, res, next) => {
    try {
      const result = await changeUserPassword(
        req.user!.id,
        req.body.currentPassword,
        req.body.newPassword
      );
      sendSuccess(req, res, result, 200);
    } catch (err) {
      next(err);
    }
  }
);

authRouter.get('/me', authenticateJwt, async (req, res, next) => {
  try {
    const profile = await getCurrentUserProfile(req.user!.id);
    sendSuccess(req, res, profile, 200);
  } catch (err) {
    next(err);
  }
});
