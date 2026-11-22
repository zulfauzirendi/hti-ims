import { Prisma, StockActionType } from '@prisma/client';
import { prisma } from '../../config/prisma';

export interface ListLogsParams {
  itemId?: number;
  locationId?: number;
  actionType?: StockActionType;
  userId?: number;
  dateFrom?: string;
  dateTo?: string;
  page: number;
  limit: number;
}

export function buildLogsWhereClause(params: Omit<ListLogsParams, 'page' | 'limit'>): Prisma.StockLogWhereInput {
  const where: Prisma.StockLogWhereInput = {};
  if (params.itemId) where.itemId = params.itemId;
  if (params.actionType) where.actionType = params.actionType;
  if (params.userId) where.userId = params.userId;
  if (params.locationId) {
    where.OR = [{ fromLocationId: params.locationId }, { toLocationId: params.locationId }];
  }
  if (params.dateFrom || params.dateTo) {
    where.createdAt = {};
    if (params.dateFrom) where.createdAt.gte = new Date(params.dateFrom);
    if (params.dateTo) {
      const end = new Date(params.dateTo);
      if (/^\d{4}-\d{2}-\d{2}$/.test(params.dateTo)) {
        end.setUTCHours(23, 59, 59, 999);
      }
      where.createdAt.lte = end;
    }
  }
  return where;
}

export async function listAuditLogs(params: ListLogsParams) {
  const where = buildLogsWhereClause(params);
  const skip = (params.page - 1) * params.limit;

  const [total, logs] = await Promise.all([
    prisma.stockLog.count({ where }),
    prisma.stockLog.findMany({
      where,
      skip,
      take: params.limit,
      orderBy: { createdAt: 'desc' },
      include: {
        item: { select: { id: true, itemCode: true, description: true, unit: true } },
        fromLocation: { select: { id: true, code: true, name: true } },
        toLocation: { select: { id: true, code: true, name: true } },
        user: { select: { id: true, username: true, fullName: true, role: true } },
        transfer: { select: { id: true, transferCode: true, status: true } },
      },
    }),
  ]);

  return {
    items: logs,
    meta: {
      page: params.page,
      limit: params.limit,
      total,
      totalPages: Math.max(1, Math.ceil(total / params.limit)),
    },
  };
}
