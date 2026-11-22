import { Router } from 'express';
import { z } from 'zod';
import { authenticateJwt } from '../../middlewares/authenticate';
import { requirePasswordChanged } from '../../middlewares/requirePasswordChanged';
import { validateQuery } from '../../middlewares/validate';
import { buildLogsExcelBuffer, buildStockExcelBuffer } from './excel.builder';
import { buildLogsPdfBuffer, buildStockPdfBuffer } from './pdf.builder';

const exportQuerySchema = z.object({
  type: z.enum(['stock', 'logs']).default('stock'),
  format: z.enum(['xlsx', 'pdf']).default('xlsx'),
  locationId: z.coerce.number().int().positive().optional(),
  categoryId: z.coerce.number().int().positive().optional(),
  dateFrom: z.string().optional(),
  dateTo: z.string().optional(),
});

export const reportsRouter = Router();

reportsRouter.get(
  '/export',
  authenticateJwt,
  requirePasswordChanged,
  validateQuery(exportQuerySchema),
  async (req, res, next) => {
    try {
      const q = req.query as unknown as z.infer<typeof exportQuerySchema>;
      const printedBy = req.user!.fullName;
      const dateTag = new Date().toISOString().slice(0, 10);

      if (q.format === 'xlsx') {
        const buffer =
          q.type === 'stock'
            ? await buildStockExcelBuffer({ locationId: q.locationId, categoryId: q.categoryId, printedBy })
            : await buildLogsExcelBuffer({ locationId: q.locationId, dateFrom: q.dateFrom, dateTo: q.dateTo, printedBy });

        const filename = `HTI_${q.type === 'stock' ? 'Inventory_Stock' : 'ISO9001_Audit_Logs'}_${dateTag}.xlsx`;
        res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
        res.send(buffer);
        return;
      }

      const buffer =
        q.type === 'stock'
          ? await buildStockPdfBuffer({ locationId: q.locationId, categoryId: q.categoryId, printedBy })
          : await buildLogsPdfBuffer({ locationId: q.locationId, dateFrom: q.dateFrom, dateTo: q.dateTo, printedBy });

      const filename = `HTI_${q.type === 'stock' ? 'Inventory_Stock' : 'ISO9001_Audit_Logs'}_${dateTag}.pdf`;
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
      res.send(buffer);
    } catch (err) {
      next(err);
    }
  }
);
