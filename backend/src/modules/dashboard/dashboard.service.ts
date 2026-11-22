import { TransferStatus, UserRole } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { AuthUser } from '../../types/express';

interface LocationAggregateRow {
  location_id: number;
  code: string;
  name: string;
  location_type: string;
  good: bigint;
  service: bigint;
  broken: bigint;
  in_transit: bigint;
}

interface CategoryAggregateRow {
  category_id: number;
  code: string;
  name: string;
  total_items: bigint;
  total_units: bigint;
}

export async function getDashboardSummary(user: AuthUser) {
  const [byLocationRaw, byCategoryRaw, itemsCount, pendingIncomingTransfers] = await Promise.all([
    prisma.$queryRaw<LocationAggregateRow[]>`
      SELECT
        l.id AS location_id,
        l.code,
        l.name,
        l.location_type::text AS location_type,
        COALESCE(SUM(s.qty_good), 0)::bigint AS good,
        COALESCE(SUM(s.qty_service), 0)::bigint AS service,
        COALESCE(SUM(s.qty_broken), 0)::bigint AS broken,
        COALESCE(SUM(s.qty_in_transit), 0)::bigint AS in_transit
      FROM locations l
      LEFT JOIN item_stocks s ON s.location_id = l.id
      LEFT JOIN items i ON i.id = s.item_id AND i.is_active = TRUE
      WHERE l.is_active = TRUE
      GROUP BY l.id, l.code, l.name, l.location_type
      ORDER BY l.id ASC
    `,
    prisma.$queryRaw<CategoryAggregateRow[]>`
      SELECT
        c.id AS category_id,
        c.code,
        c.name,
        COUNT(DISTINCT i.id)::bigint AS total_items,
        COALESCE(SUM(s.qty_good + s.qty_service + s.qty_broken + s.qty_in_transit), 0)::bigint AS total_units
      FROM categories c
      LEFT JOIN items i ON i.category_id = c.id AND i.is_active = TRUE
      LEFT JOIN item_stocks s ON s.item_id = i.id
      GROUP BY c.id, c.code, c.name
      ORDER BY c.id ASC
    `,
    prisma.item.count({ where: { isActive: true } }),
    user.role === UserRole.SUPER_ADMIN
      ? prisma.stockTransfer.count({ where: { status: TransferStatus.IN_TRANSIT } })
      : user.assignedLocationId
        ? prisma.stockTransfer.count({
            where: {
              status: TransferStatus.IN_TRANSIT,
              toLocationId: user.assignedLocationId,
            },
          })
        : Promise.resolve(0),
  ]);

  const byLocation = byLocationRaw.map((r) => {
    const good = Number(r.good);
    const service = Number(r.service);
    const broken = Number(r.broken);
    const inTransit = Number(r.in_transit);
    return {
      locationId: r.location_id,
      code: r.code,
      name: r.name,
      locationType: r.location_type,
      good,
      service,
      broken,
      inTransit,
      total: good + service + broken + inTransit,
    };
  });

  const byCategory = byCategoryRaw.map((r) => ({
    categoryId: r.category_id,
    code: r.code,
    name: r.name,
    totalItems: Number(r.total_items),
    totalUnits: Number(r.total_units),
  }));

  const grandGood = byLocation.reduce((acc, l) => acc + l.good, 0);
  const grandService = byLocation.reduce((acc, l) => acc + l.service, 0);
  const grandBroken = byLocation.reduce((acc, l) => acc + l.broken, 0);
  const grandInTransit = byLocation.reduce((acc, l) => acc + l.inTransit, 0);

  return {
    grandTotal: {
      itemsCount,
      good: grandGood,
      service: grandService,
      broken: grandBroken,
      inTransit: grandInTransit,
      totalVolume: grandGood + grandService + grandBroken + grandInTransit,
    },
    byLocation,
    byCategory,
    pendingIncomingTransfers,
  };
}
