import { Prisma, TransferStatus } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { AppError } from '../../utils/appError';

export interface SearchItemsParams {
  q?: string;
  categoryId?: number;
  locationId?: number;
  condition?: 'GOOD' | 'SERVICE' | 'BROKEN' | 'IN_TRANSIT';
  page: number;
  limit: number;
}

export async function searchItems(params: SearchItemsParams) {
  const { q, categoryId, locationId, condition, page, limit } = params;
  const skip = (page - 1) * limit;

  const stockSomeFilter: Prisma.ItemStockWhereInput = {};
  if (locationId) stockSomeFilter.locationId = locationId;
  if (condition === 'GOOD') stockSomeFilter.qtyGood = { gt: 0 };
  if (condition === 'SERVICE') stockSomeFilter.qtyService = { gt: 0 };
  if (condition === 'BROKEN') stockSomeFilter.qtyBroken = { gt: 0 };
  if (condition === 'IN_TRANSIT') stockSomeFilter.qtyInTransit = { gt: 0 };

  const where: Prisma.ItemWhereInput = {
    isActive: true,
    ...(categoryId ? { categoryId } : {}),
    ...(q && q.length > 0
      ? {
          OR: [
            { itemCode: { contains: q, mode: 'insensitive' } },
            { description: { contains: q, mode: 'insensitive' } },
            { specification: { contains: q, mode: 'insensitive' } },
          ],
        }
      : {}),
    ...(Object.keys(stockSomeFilter).length > 0 ? { stocks: { some: stockSomeFilter } } : {}),
  };

  // 2 query paralel terindeks (pg_trgm GIN + hydration 4 lokasi — anti N+1)
  const [total, rawItems, allLocations] = await Promise.all([
    prisma.item.count({ where }),
    prisma.item.findMany({
      where,
      skip,
      take: limit,
      orderBy: [{ categoryId: 'asc' }, { itemCode: 'asc' }],
      include: {
        category: { select: { id: true, code: true, name: true } },
        stocks: {
          include: {
            location: { select: { id: true, code: true, name: true, locationType: true } },
          },
        },
      },
    }),
    prisma.location.findMany({
      where: { isActive: true },
      orderBy: { id: 'asc' },
      select: { id: true, code: true, name: true, locationType: true },
    }),
  ]);

  const items = rawItems.map((it) => {
    const stockByLocId = new Map(it.stocks.map((s) => [s.locationId, s]));
    const locationMatrix = allLocations.map((loc) => {
      const st = stockByLocId.get(loc.id);
      return {
        stockId: st?.id ?? null,
        locationId: loc.id,
        locationCode: loc.code,
        locationName: loc.name,
        locationType: loc.locationType,
        qtyGood: st?.qtyGood ?? 0,
        qtyService: st?.qtyService ?? 0,
        qtyBroken: st?.qtyBroken ?? 0,
        qtyInTransit: st?.qtyInTransit ?? 0,
        jobCode: st?.jobCode ?? null,
        remarks: st?.remarks ?? null,
        version: st?.version ?? 1,
        updatedAt: st?.updatedAt ?? null,
      };
    });

    const totals = locationMatrix.reduce(
      (acc, s) => ({
        good: acc.good + s.qtyGood,
        service: acc.service + s.qtyService,
        broken: acc.broken + s.qtyBroken,
        inTransit: acc.inTransit + s.qtyInTransit,
      }),
      { good: 0, service: 0, broken: 0, inTransit: 0 }
    );

    return {
      id: it.id,
      itemCode: it.itemCode,
      description: it.description,
      specification: it.specification,
      unit: it.unit,
      category: it.category,
      totals: {
        ...totals,
        totalVolume: totals.good + totals.service + totals.broken + totals.inTransit,
      },
      stocks: locationMatrix,
    };
  });

  return {
    items,
    meta: {
      page,
      limit,
      total,
      totalPages: Math.max(1, Math.ceil(total / limit)),
    },
  };
}

export async function getItemDetail(itemId: number) {
  const [item, allLocations, recentLogs] = await Promise.all([
    prisma.item.findUnique({
      where: { id: itemId },
      include: {
        category: { select: { id: true, code: true, name: true } },
        stocks: true,
      },
    }),
    prisma.location.findMany({
      where: { isActive: true },
      orderBy: { id: 'asc' },
      select: { id: true, code: true, name: true, locationType: true },
    }),
    prisma.stockLog.findMany({
      where: { itemId },
      orderBy: { createdAt: 'desc' },
      take: 10,
      include: {
        fromLocation: { select: { id: true, code: true, name: true } },
        toLocation: { select: { id: true, code: true, name: true } },
        user: { select: { id: true, username: true, fullName: true } },
      },
    }),
  ]);

  if (!item) {
    throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Item tidak ditemukan.');
  }

  const stockByLocId = new Map(item.stocks.map((s) => [s.locationId, s]));
  const stocks = allLocations.map((loc) => {
    const st = stockByLocId.get(loc.id);
    return {
      stockId: st?.id ?? null,
      locationId: loc.id,
      locationCode: loc.code,
      locationName: loc.name,
      locationType: loc.locationType,
      qtyGood: st?.qtyGood ?? 0,
      qtyService: st?.qtyService ?? 0,
      qtyBroken: st?.qtyBroken ?? 0,
      qtyInTransit: st?.qtyInTransit ?? 0,
      jobCode: st?.jobCode ?? null,
      remarks: st?.remarks ?? null,
      version: st?.version ?? 1,
      updatedAt: st?.updatedAt ?? null,
    };
  });

  return {
    id: item.id,
    itemCode: item.itemCode,
    description: item.description,
    specification: item.specification,
    unit: item.unit,
    isActive: item.isActive,
    deletedAt: item.deletedAt,
    category: item.category,
    stocks,
    recentLogs,
  };
}

export async function createItem(input: {
  categoryId: number;
  description: string;
  specification?: string | null;
  unit: string;
}) {
  const category = await prisma.category.findUnique({ where: { id: input.categoryId } });
  if (!category) {
    throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Kategori tidak ditemukan.');
  }

  // Generate SKU deterministik HTI-<CAT>-<0001>
  const prefix = `HTI-${category.code}-`;
  const lastItem = await prisma.item.findFirst({
    where: { itemCode: { startsWith: prefix } },
    orderBy: { itemCode: 'desc' },
    select: { itemCode: true },
  });

  let nextSeq = 1;
  if (lastItem) {
    const numPart = Number(lastItem.itemCode.slice(prefix.length));
    if (Number.isInteger(numPart) && numPart >= 1) nextSeq = numPart + 1;
  }
  const itemCode = `${prefix}${String(nextSeq).padStart(4, '0')}`;

  return prisma.item.create({
    data: {
      itemCode,
      categoryId: input.categoryId,
      description: input.description,
      specification: input.specification ?? null,
      unit: input.unit,
      isActive: true,
    },
    include: {
      category: { select: { id: true, code: true, name: true } },
    },
  });
}

export async function updateItem(
  itemId: number,
  input: {
    categoryId?: number;
    description?: string;
    specification?: string | null;
    unit?: string;
  }
) {
  const existing = await prisma.item.findUnique({ where: { id: itemId } });
  if (!existing || !existing.isActive) {
    throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Item aktif tidak ditemukan.');
  }

  if (input.categoryId !== undefined) {
    const cat = await prisma.category.findUnique({ where: { id: input.categoryId } });
    if (!cat) throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Kategori tidak ditemukan.');
  }

  return prisma.item.update({
    where: { id: itemId },
    data: {
      ...(input.categoryId !== undefined ? { categoryId: input.categoryId } : {}),
      ...(input.description !== undefined ? { description: input.description } : {}),
      ...(input.specification !== undefined ? { specification: input.specification } : {}),
      ...(input.unit !== undefined ? { unit: input.unit } : {}),
    },
    include: {
      category: { select: { id: true, code: true, name: true } },
    },
  });
}

export async function softDeleteItem(itemId: number) {
  const item = await prisma.item.findUnique({
    where: { id: itemId },
    include: { stocks: true },
  });
  if (!item || !item.isActive) {
    throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Item aktif tidak ditemukan.');
  }

  const totalUnits = item.stocks.reduce(
    (sum, s) => sum + s.qtyGood + s.qtyService + s.qtyBroken + s.qtyInTransit,
    0
  );
  if (totalUnits > 0) {
    throw new AppError(
      400,
      'ITEM_HAS_ACTIVE_STOCK',
      `Item tidak dapat dihapus karena masih memiliki total ${totalUnits} unit stok aktif atau in-transit.`
    );
  }

  const pendingTransfers = await prisma.stockTransfer.count({
    where: { itemId, status: TransferStatus.IN_TRANSIT },
  });
  if (pendingTransfers > 0) {
    throw new AppError(
      400,
      'ITEM_HAS_ACTIVE_STOCK',
      'Item masih memiliki transaksi transfer IN_TRANSIT yang belum diselesaikan.'
    );
  }

  return prisma.item.update({
    where: { id: itemId },
    data: { isActive: false, deletedAt: new Date() },
    select: { id: true, itemCode: true, isActive: true, deletedAt: true },
  });
}
