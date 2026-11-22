import { Router } from 'express';
import { authenticateJwt } from '../../middlewares/authenticate';
import { requirePasswordChanged } from '../../middlewares/requirePasswordChanged';
import { sendSuccess } from '../../utils/response';
import { getDashboardSummary } from './dashboard.service';

export const dashboardRouter = Router();

dashboardRouter.get('/summary', authenticateJwt, requirePasswordChanged, async (req, res, next) => {
  try {
    const summary = await getDashboardSummary(req.user!);
    sendSuccess(req, res, summary, 200);
  } catch (err) {
    next(err);
  }
});
