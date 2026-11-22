import { ConditionStatus, StockActionType } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { assertCanWriteLocation } from '../../middlewares/rbac';
import { AuthUser } from '../../types/express';
import { AppError } from '../../utils/appError';
import { extractEvidenceFilename, storageService } from '../uploads/local.storage';

export type QtyColumn = 'qtyGood' | 'qtyService' | 'qtyBroken';

export function statusToColumn(status: ConditionStatus): QtyColumn {
  switch (status) {
    case ConditionStatus.GOOD:
      return 'qtyGood';
    case ConditionStatus.SERVICE:
      return 'qtyService';
    case ConditionStatus.BROKEN:
      return 'qtyBroken';
  }
}

export function snapshotStock(stock: {
  qtyGood: number;
  qtyService: number;
  qtyBroken: number;
  qtyInTransit: number;
}) {
  return {
    good: stock.qtyGood,
    service: stock.qtyService,
    broken: stock.qtyBroken,
    in_transit: stock.qtyInTransit,
  };
}

export async function updateStockCondition(
  input: {
    itemId: number;
    locationId: number;
    fromStatus: ConditionStatus;
    toStatus: ConditionStatus;
    qty: number;
    note: string;
    photoUrl?: string | null;
    jobCode?: string | null;
    expectedVersion: number;
  },
  user: AuthUser
) {
  assertCanWriteLocation(user, input.locationId, { allowFieldTech: true });

  // Wajib bukti foto K3 ISO 45001 setiap kali status pindah ke SERVICE atau BROKEN (SRS-CAP-011)
  if (input.toStatus === ConditionStatus.SERVICE || input.toStatus === ConditionStatus.BROKEN) {
    const filename = input.photoUrl ? extractEvidenceFilename(input.photoUrl) : null;
    if (!filename || !(await storageService.exists(filename))) {
      throw new AppError(
        400,
        'SAFETY_PHOTO_REQUIRED',
        'Bukti foto kondisi K3 (ISO 45001) wajib diunggah untuk mengubah status ke Service atau Broken.'
      );
    }
  }

  return prisma.$transaction(async (tx) => {
    const stock = await tx.itemStock.findUnique({
      where: { itemId_locationId: { itemId: input.itemId, locationId: input.locationId } },
    });
    if (!stock) {
      throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Saldo item pada lokasi ini tidak ditemukan.');
    }

    const fromField = statusToColumn(input.fromStatus);
    const toField = statusToColumn(input.toStatus);
    const available = stock[fromField];

    if (available < input.qty) {
      throw new AppError(
        400,
        'INSUFFICIENT_STOCK',
        `Saldo ${input.fromStatus} tidak mencukupi (tersedia ${available} unit, diminta ${input.qty} unit).`
      );
    }

    const qtyBefore = snapshotStock(stock);

    // Optimistic locking mencegah race condition (SRS-CAP-015)
    const updated = await tx.itemStock.updateMany({
      where: {
        id: stock.id,
        version: input.expectedVersion,
        [fromField]: { gte: input.qty },
      },
      data: {
        [fromField]: { decrement: input.qty },
        [toField]: { increment: input.qty },
        ...(input.jobCode !== undefined ? { jobCode: input.jobCode } : {}),
        version: { increment: 1 },
        updatedById: user.id,
      },
    });

    if (updated.count === 0) {
      throw new AppError(
        409,
        'STOCK_VERSION_CONFLICT',
        'Data stok baru saja diubah pengguna lain. Silakan muat ulang data terbaru.'
      );
    }

    const freshStock = await tx.itemStock.findUniqueOrThrow({ where: { id: stock.id } });

    await tx.stockLog.create({
      data: {
        itemId: input.itemId,
        fromLocationId: input.locationId,
        toLocationId: input.locationId,
        actionType: StockActionType.STATUS_CHANGE,
        statusChanged: `${input.fromStatus}_TO_${input.toStatus}`,
        qtyChanged: input.qty,
        qtyBefore,
        qtyAfter: snapshotStock(freshStock),
        jobCode: input.jobCode !== undefined ? input.jobCode : stock.jobCode,
        note: input.note,
        photoUrl: input.photoUrl ?? null,
        userId: user.id,
      },
    });

    return freshStock;
  });
}

export async function updateStockRemarks(
  input: {
    itemId: number;
    locationId: number;
    jobCode?: string | null;
    remarks?: string | null;
    expectedVersion: number;
  },
  user: AuthUser
) {
  assertCanWriteLocation(user, input.locationId, { allowFieldTech: true });

  return prisma.$transaction(async (tx) => {
    const stock = await tx.itemStock.findUnique({
      where: { itemId_locationId: { itemId: input.itemId, locationId: input.locationId } },
    });
    if (!stock) {
      throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Saldo item pada lokasi ini tidak ditemukan.');
    }

    const updated = await tx.itemStock.updateMany({
      where: { id: stock.id, version: input.expectedVersion },
      data: {
        ...(input.jobCode !== undefined ? { jobCode: input.jobCode } : {}),
        ...(input.remarks !== undefined ? { remarks: input.remarks } : {}),
        version: { increment: 1 },
        updatedById: user.id,
      },
    });

    if (updated.count === 0) {
      throw new AppError(
        409,
        'STOCK_VERSION_CONFLICT',
        'Data stok baru saja diubah pengguna lain. Silakan muat ulang data terbaru.'
      );
    }

    const freshStock = await tx.itemStock.findUniqueOrThrow({ where: { id: stock.id } });
    const snap = snapshotStock(freshStock);

    await tx.stockLog.create({
      data: {
        itemId: input.itemId,
        fromLocationId: input.locationId,
        toLocationId: input.locationId,
        actionType: StockActionType.REMARKS_UPDATE,
        qtyChanged: 0,
        qtyBefore: snap,
        qtyAfter: snap,
        jobCode: freshStock.jobCode,
        note: freshStock.remarks ?? 'Pembaruan Job Code / Remarks',
        userId: user.id,
      },
    });

    return freshStock;
  });
}

export async function recordStockIn(
  input: {
    itemId: number;
    locationId: number;
    qty: number;
    note: string;
    jobCode?: string | null;
    expectedVersion?: number;
  },
  user: AuthUser
) {
  assertCanWriteLocation(user, input.locationId, { allowFieldTech: false });

  return prisma.$transaction(async (tx) => {
    const [item, loc] = await Promise.all([
      tx.item.findUnique({ where: { id: input.itemId } }),
      tx.location.findUnique({ where: { id: input.locationId } }),
    ]);
    if (!item || !item.isActive) {
      throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Master item aktif tidak ditemukan.');
    }
    if (!loc || !loc.isActive) {
      throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Lokasi aktif tidak ditemukan.');
    }

    const existing = await tx.itemStock.findUnique({
      where: { itemId_locationId: { itemId: input.itemId, locationId: input.locationId } },
    });

    let qtyBefore;
    let freshStock;

    if (!existing) {
      qtyBefore = { good: 0, service: 0, broken: 0, in_transit: 0 };
      freshStock = await tx.itemStock.create({
        data: {
          itemId: input.itemId,
          locationId: input.locationId,
          qtyGood: input.qty,
          jobCode: input.jobCode ?? null,
          updatedById: user.id,
        },
      });
    } else {
      qtyBefore = snapshotStock(existing);
      const whereClause =
        input.expectedVersion !== undefined
          ? { id: existing.id, version: input.expectedVersion }
          : { id: existing.id, version: existing.version };

      const updated = await tx.itemStock.updateMany({
        where: whereClause,
        data: {
          qtyGood: { increment: input.qty },
          ...(input.jobCode !== undefined ? { jobCode: input.jobCode } : {}),
          version: { increment: 1 },
          updatedById: user.id,
        },
      });
      if (updated.count === 0) {
        throw new AppError(409, 'STOCK_VERSION_CONFLICT', 'Data stok berubah bersamaan. Muat ulang data.');
      }
      freshStock = await tx.itemStock.findUniqueOrThrow({ where: { id: existing.id } });
    }

    await tx.stockLog.create({
      data: {
        itemId: input.itemId,
        toLocationId: input.locationId,
        actionType: StockActionType.STOCK_IN,
        statusChanged: 'NEW_GOOD',
        qtyChanged: input.qty,
        qtyBefore,
        qtyAfter: snapshotStock(freshStock),
        jobCode: input.jobCode ?? freshStock.jobCode,
        note: input.note,
        userId: user.id,
      },
    });

    return freshStock;
  });
}

export async function disposeBrokenStock(
  input: {
    itemId: number;
    locationId: number;
    qty: number;
    note: string;
    expectedVersion: number;
  },
  user: AuthUser
) {
  return prisma.$transaction(async (tx) => {
    const stock = await tx.itemStock.findUnique({
      where: { itemId_locationId: { itemId: input.itemId, locationId: input.locationId } },
    });
    if (!stock) {
      throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Saldo item pada lokasi ini tidak ditemukan.');
    }
    if (stock.qtyBroken < input.qty) {
      throw new AppError(
        400,
        'INSUFFICIENT_STOCK',
        `Disposal hanya diizinkan untuk saldo BROKEN (tersedia ${stock.qtyBroken} unit, diminta ${input.qty} unit).`
      );
    }

    const qtyBefore = snapshotStock(stock);
    const updated = await tx.itemStock.updateMany({
      where: { id: stock.id, version: input.expectedVersion, qtyBroken: { gte: input.qty } },
      data: {
        qtyBroken: { decrement: input.qty },
        version: { increment: 1 },
        updatedById: user.id,
      },
    });
    if (updated.count === 0) {
      throw new AppError(409, 'STOCK_VERSION_CONFLICT', 'Data stok berubah bersamaan. Muat ulang data.');
    }

    const freshStock = await tx.itemStock.findUniqueOrThrow({ where: { id: stock.id } });
    await tx.stockLog.create({
      data: {
        itemId: input.itemId,
        fromLocationId: input.locationId,
        actionType: StockActionType.DISPOSAL,
        statusChanged: 'BROKEN_DISPOSED',
        qtyChanged: input.qty,
        qtyBefore,
        qtyAfter: snapshotStock(freshStock),
        note: input.note,
        userId: user.id,
      },
    });

    return freshStock;
  });
}
