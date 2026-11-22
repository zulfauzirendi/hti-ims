import { Router } from 'express';
import { UserRole } from '@prisma/client';
import { authenticateJwt } from '../../middlewares/authenticate';
import { authorizeRoles } from '../../middlewares/rbac';
import { requirePasswordChanged } from '../../middlewares/requirePasswordChanged';
import { validateBody, validateParams } from '../../middlewares/validate';
import { sendSuccess } from '../../utils/response';
import {
  createCategorySchema,
  createLocationSchema,
  createUserSchema,
  idParamSchema,
  updateCategorySchema,
  updateLocationSchema,
  updateUserSchema,
} from './master.schema';
import {
  createCategory,
  createLocation,
  createUser,
  listCategories,
  listLocations,
  listUsers,
  revokeAllUserSessions,
  updateCategory,
  updateLocation,
  updateUser,
} from './master.service';

export const categoriesRouter = Router();
categoriesRouter.use(authenticateJwt, requirePasswordChanged);
categoriesRouter.get('/', async (req, res, next) => {
  try {
    sendSuccess(req, res, await listCategories(), 200);
  } catch (err) {
    next(err);
  }
});
categoriesRouter.post(
  '/',
  authorizeRoles(UserRole.SUPER_ADMIN),
  validateBody(createCategorySchema),
  async (req, res, next) => {
    try {
      sendSuccess(req, res, await createCategory(req.body), 201);
    } catch (err) {
      next(err);
    }
  }
);
categoriesRouter.patch(
  '/:id',
  authorizeRoles(UserRole.SUPER_ADMIN),
  validateParams(idParamSchema),
  validateBody(updateCategorySchema),
  async (req, res, next) => {
    try {
      sendSuccess(req, res, await updateCategory(Number(req.params.id), req.body), 200);
    } catch (err) {
      next(err);
    }
  }
);

export const locationsRouter = Router();
locationsRouter.use(authenticateJwt, requirePasswordChanged);
locationsRouter.get('/', async (req, res, next) => {
  try {
    const includeInactive = req.user?.role === UserRole.SUPER_ADMIN && req.query.includeInactive === 'true';
    sendSuccess(req, res, await listLocations(includeInactive), 200);
  } catch (err) {
    next(err);
  }
});
locationsRouter.post(
  '/',
  authorizeRoles(UserRole.SUPER_ADMIN),
  validateBody(createLocationSchema),
  async (req, res, next) => {
    try {
      sendSuccess(req, res, await createLocation(req.body), 201);
    } catch (err) {
      next(err);
    }
  }
);
locationsRouter.patch(
  '/:id',
  authorizeRoles(UserRole.SUPER_ADMIN),
  validateParams(idParamSchema),
  validateBody(updateLocationSchema),
  async (req, res, next) => {
    try {
      sendSuccess(req, res, await updateLocation(Number(req.params.id), req.body), 200);
    } catch (err) {
      next(err);
    }
  }
);

export const usersRouter = Router();
usersRouter.use(authenticateJwt, requirePasswordChanged, authorizeRoles(UserRole.SUPER_ADMIN));

usersRouter.get('/', async (req, res, next) => {
  try {
    sendSuccess(req, res, await listUsers(), 200);
  } catch (err) {
    next(err);
  }
});

usersRouter.post('/', validateBody(createUserSchema), async (req, res, next) => {
  try {
    sendSuccess(req, res, await createUser(req.body), 201);
  } catch (err) {
    next(err);
  }
});

usersRouter.patch(
  '/:id',
  validateParams(idParamSchema),
  validateBody(updateUserSchema),
  async (req, res, next) => {
    try {
      sendSuccess(req, res, await updateUser(Number(req.params.id), req.body, req.user!.id), 200);
    } catch (err) {
      next(err);
    }
  }
);

usersRouter.post('/:id/revoke-sessions', validateParams(idParamSchema), async (req, res, next) => {
  try {
    sendSuccess(req, res, await revokeAllUserSessions(Number(req.params.id), req.user!.id), 200);
  } catch (err) {
    next(err);
  }
});
