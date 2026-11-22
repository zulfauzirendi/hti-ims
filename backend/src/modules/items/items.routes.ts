import { Router } from 'express';
import { UserRole } from '@prisma/client';
import { authenticateJwt } from '../../middlewares/authenticate';
import { authorizeRoles } from '../../middlewares/rbac';
import { requirePasswordChanged } from '../../middlewares/requirePasswordChanged';
import { validateBody, validateParams, validateQuery } from '../../middlewares/validate';
import { sendSuccess } from '../../utils/response';
import {
  createItemSchema,
  itemIdParamSchema,
  searchItemsQuerySchema,
  updateItemSchema,
} from './items.schema';
import { createItem, getItemDetail, searchItems, softDeleteItem, updateItem } from './items.service';

export const itemsRouter = Router();

itemsRouter.use(authenticateJwt, requirePasswordChanged);

itemsRouter.get('/search', validateQuery(searchItemsQuerySchema), async (req, res, next) => {
  try {
    const q = req.query as unknown as {
      q?: string;
      categoryId?: number;
      locationId?: number;
      condition?: 'GOOD' | 'SERVICE' | 'BROKEN' | 'IN_TRANSIT';
      page: number;
      limit: number;
    };
    const result = await searchItems(q);
    sendSuccess(req, res, result.items, 200, result.meta);
  } catch (err) {
    next(err);
  }
});

itemsRouter.get('/:id', validateParams(itemIdParamSchema), async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const detail = await getItemDetail(id);
    sendSuccess(req, res, detail, 200);
  } catch (err) {
    next(err);
  }
});

itemsRouter.post(
  '/',
  authorizeRoles(UserRole.SUPER_ADMIN),
  validateBody(createItemSchema),
  async (req, res, next) => {
    try {
      const created = await createItem(req.body);
      sendSuccess(req, res, created, 201);
    } catch (err) {
      next(err);
    }
  }
);

itemsRouter.patch(
  '/:id',
  authorizeRoles(UserRole.SUPER_ADMIN),
  validateParams(itemIdParamSchema),
  validateBody(updateItemSchema),
  async (req, res, next) => {
    try {
      const updated = await updateItem(Number(req.params.id), req.body);
      sendSuccess(req, res, updated, 200);
    } catch (err) {
      next(err);
    }
  }
);

itemsRouter.delete(
  '/:id',
  authorizeRoles(UserRole.SUPER_ADMIN),
  validateParams(itemIdParamSchema),
  async (req, res, next) => {
    try {
      const deleted = await softDeleteItem(Number(req.params.id));
      sendSuccess(req, res, deleted, 200);
    } catch (err) {
      next(err);
    }
  }
);
