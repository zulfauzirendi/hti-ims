import crypto from 'crypto';
import { ConditionStatus, Prisma, StockActionType, TransferStatus, UserRole } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { assertCanWriteLocation } from '../../middlewares/rbac';
import { AuthUser } from '../../types/express';
import { AppError } from '../../utils/appError';
import { snapshotStock, statusToColumn } from '../stocks/stocks.service';

function generateTransferCode(): string {
  const now = new Date();
  const ymd = `${now.getUTCFullYear()}${String(now.getUTCMonth() + 1).padStart(2, '0')}${String(
    now.getUTCDate()
  ).padStart(2, '0')}`;
  const suffix = crypto.randomBytes(3).toString('hex').toUpperCase();
  return `TRF-${ymd}-${suffix}`;
}

export async function createTransfer(
  input: {
    itemId: number;
    fromLocationId: number;
    toLocationId: number;
    conditionStatus: ConditionStatus;
    qty: number;
    jobCode?: string | null;
    senderNote: string;
    expectedVersion: number;
  },
  user: AuthUser
) {
  if (input.fromLocationId === input.toLocationId) {
    throw new AppError(400, 'TRANSFER_SAME_LOCATION', 'Lokasi asal dan lokasi tujuan transfer harus berbeda.');
  }

  assertCanWriteLocation(user, input.fromLocationId, { allowFieldTech: true });

  return prisma.$transaction(async (tx) => {
    const [targetLoc, sourceStock] = await Promise.all([
      tx.location.findUnique({ where: { id: input.toLocationId } }),
      tx.itemStock.findUnique({
        where: { itemId_locationId: { itemId: input.itemId, locationId: input.fromLocationId } },
      }),
    ]);

    if (!targetLoc || !targetLoc.isActive) {
      throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Lokasi tujuan transfer tidak ditemukan atau nonaktif.');
    }
    if (!sourceStock) {
      throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Saldo item di lokasi asal tidak ditemukan.');
    }

    const col = statusToColumn(input.conditionStatus);
    if (sourceStock[col] < input.qty) {
      throw new AppError(
        400,
        'INSUFFICIENT_STOCK',
        `Saldo ${input.conditionStatus} di lokasi asal hanya tersisa ${sourceStock[col]} unit.`
      );
    }

    const qtyBefore = snapshotStock(sourceStock);

    // Tahap 1: Kurangi saldo kondisi asal, pindahkan ke qty_in_transit secara atomik
    const updated = await tx.itemStock.updateMany({
      where: {
        id: sourceStock.id,
        version: input.expectedVersion,
        [col]: { gte: input.qty },
      },
      data: {
        [col]: { decrement: input.qty },
        qtyInTransit: { increment: input.qty },
        version: { increment: 1 },
        updatedById: user.id,
      },
    });

    if (updated.count === 0) {
      throw new AppError(
        409,
        'STOCK_VERSION_CONFLICT',
        'Data stok lokasi asal baru saja diubah pengguna lain. Muat ulang data terbaru.'
      );
    }

    const freshSource = await tx.itemStock.findUniqueOrThrow({ where: { id: sourceStock.id } });

    const transfer = await tx.stockTransfer.create({
      data: {
        transferCode: generateTransferCode(),
        itemId: input.itemId,
        fromLocationId: input.fromLocationId,
        toLocationId: input.toLocationId,
        conditionStatus: input.conditionStatus,
        qty: input.qty,
        status: TransferStatus.IN_TRANSIT,
        jobCode: input.jobCode ?? null,
        senderNote: input.senderNote,
        sentById: user.id,
      },
      include: {
        item: { select: { id: true, itemCode: true, description: true, unit: true } },
        fromLocation: { select: { id: true, code: true, name: true } },
        toLocation: { select: { id: true, code: true, name: true } },
        sentBy: { select: { id: true, username: true, fullName: true } },
      },
    });

    await tx.stockLog.create({
      data: {
        itemId: input.itemId,
        fromLocationId: input.fromLocationId,
        toLocationId: input.toLocationId,
        actionType: StockActionType.TRANSFER_OUT,
        statusChanged: `${input.conditionStatus}_TO_IN_TRANSIT`,
        qtyChanged: input.qty,
        qtyBefore,
        qtyAfter: snapshotStock(freshSource),
        jobCode: input.jobCode ?? null,
        note: `[${transfer.transferCode}] ${input.senderNote}`,
        transferId: transfer.id,
        userId: user.id,
      },
    });

    return transfer;
  });
}

export async function listTransfers(
  params: {
    direction: 'incoming' | 'outgoing' | 'all';
    status?: TransferStatus;
    locationId?: number;
    page: number;
    limit: number;
  },
  user: AuthUser
) {
  const { direction, status, locationId, page, limit } = params;
  const skip = (page - 1) * limit;

  const focusLocId = locationId ?? user.assignedLocationId ?? undefined;
  const where: Prisma.StockTransferWhereInput = {
    ...(status ? { status } : {}),
  };

  if (direction === 'incoming' && focusLocId) {
    where.toLocationId = focusLocId;
  } else if (direction === 'outgoing' && focusLocId) {
    where.fromLocationId = focusLocId;
  } else if (direction === 'all' && locationId) {
    where.OR = [{ fromLocationId: locationId }, { toLocationId: locationId }];
  }

  const [total, items] = await Promise.all([
    prisma.stockTransfer.count({ where }),
    prisma.stockTransfer.findMany({
      where,
      skip,
      take: limit,
      orderBy: [{ sentAt: 'desc' }],
      include: {
        item: { select: { id: true, itemCode: true, description: true, specification: true, unit: true } },
        fromLocation: { select: { id: true, code: true, name: true } },
        toLocation: { select: { id: true, code: true, name: true } },
        sentBy: { select: { id: true, username: true, fullName: true } },
        receivedBy: { select: { id: true, username: true, fullName: true } },
      },
    }),
  ]);

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

export async function receiveTransfer(transferId: number, receiverNote: string | null | undefined, user: AuthUser) {
  return prisma.$transaction(async (tx) => {
    const transfer = await tx.stockTransfer.findUnique({ where: { id: transferId } });
    if (!transfer) {
      throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Transaksi transfer tidak ditemukan.');
    }

    // Hanya lokasi tujuan atau SUPER_ADMIN yang berwenang menerima (Read Global, Write Local)
    assertCanWriteLocation(user, transfer.toLocationId, { allowFieldTech: true });

    // Atomic state lock mencegah double-receive atau balapan dengan cancel
    const claimed = await tx.stockTransfer.updateMany({
      where: { id: transferId, status: TransferStatus.IN_TRANSIT },
      data: {
        status: TransferStatus.RECEIVED,
        receiverNote: receiverNote ?? null,
        receivedById: user.id,
        resolvedAt: new Date(),
      },
    });
    if (claimed.count === 0) {
      throw new AppError(
        400,
        'TRANSFER_INVALID_STATE',
        'Transfer tidak lagi berstatus IN_TRANSIT (sudah diterima, ditolak, atau dibatalkan).'
      );
    }

    const col = statusToColumn(transfer.conditionStatus);

    // Kurangi qty_in_transit di lokasi asal
    const srcUpdated = await tx.itemStock.updateMany({
      where: {
        itemId: transfer.itemId,
        locationId: transfer.fromLocationId,
        qtyInTransit: { gte: transfer.qty },
      },
      data: {
        qtyInTransit: { decrement: transfer.qty },
        version: { increment: 1 },
      },
    });
    if (srcUpdated.count === 0) {
      throw new AppError(409, 'STOCK_VERSION_CONFLICT', 'Saldo in-transit asal tidak konsisten.');
    }

    // Tambahkan ke lokasi tujuan (upsert otomatis bila lokasi tujuan belum punya baris stok)
    const existingTarget = await tx.itemStock.findUnique({
      where: { itemId_locationId: { itemId: transfer.itemId, locationId: transfer.toLocationId } },
    });
    const targetBefore = existingTarget
      ? snapshotStock(existingTarget)
      : { good: 0, service: 0, broken: 0, in_transit: 0 };

    const freshTarget = await tx.itemStock.upsert({
      where: { itemId_locationId: { itemId: transfer.itemId, locationId: transfer.toLocationId } },
      create: {
        itemId: transfer.itemId,
        locationId: transfer.toLocationId,
        qtyGood: transfer.conditionStatus === ConditionStatus.GOOD ? transfer.qty : 0,
        qtyService: transfer.conditionStatus === ConditionStatus.SERVICE ? transfer.qty : 0,
        qtyBroken: transfer.conditionStatus === ConditionStatus.BROKEN ? transfer.qty : 0,
        jobCode: transfer.jobCode,
        updatedById: user.id,
      },
      update: {
        [col]: { increment: transfer.qty },
        ...(transfer.jobCode ? { jobCode: transfer.jobCode } : {}),
        version: { increment: 1 },
        updatedById: user.id,
      },
    });

    await tx.stockLog.create({
      data: {
        itemId: transfer.itemId,
        fromLocationId: transfer.fromLocationId,
        toLocationId: transfer.toLocationId,
        actionType: StockActionType.TRANSFER_IN,
        statusChanged: `IN_TRANSIT_TO_${transfer.conditionStatus}`,
        qtyChanged: transfer.qty,
        qtyBefore: targetBefore,
        qtyAfter: snapshotStock(freshTarget),
        jobCode: transfer.jobCode,
        note: `[${transfer.transferCode}] Diterima${receiverNote ? `: ${receiverNote}` : ''}`,
        transferId: transfer.id,
        userId: user.id,
      },
    });

    return tx.stockTransfer.findUniqueOrThrow({
      where: { id: transferId },
      include: {
        item: { select: { id: true, itemCode: true, description: true, unit: true } },
        fromLocation: { select: { id: true, code: true, name: true } },
        toLocation: { select: { id: true, code: true, name: true } },
        sentBy: { select: { id: true, username: true, fullName: true } },
        receivedBy: { select: { id: true, username: true, fullName: true } },
      },
    });
  });
}

async function revertInTransitTransfer(
  transferId: number,
  targetStatus: 'REJECTED' | 'CANCELLED',
  note: string | null | undefined,
  user: AuthUser
) {
  return prisma.$transaction(async (tx) => {
    const transfer = await tx.stockTransfer.findUnique({ where: { id: transferId } });
    if (!transfer) {
      throw new AppError(404, 'RESOURCE_NOT_FOUND', 'Transaksi transfer tidak ditemukan.');
    }

    if (targetStatus === 'REJECTED') {
      assertCanWriteLocation(user, transfer.toLocationId, { allowFieldTech: true });
    } else {
      // Cancel hanya boleh oleh lokasi pengirim atau SUPER_ADMIN
      if (user.role !== UserRole.SUPER_ADMIN) {
        assertCanWriteLocation(user, transfer.fromLocationId, { allowFieldTech: true });
      }
    }

    const claimed = await tx.stockTransfer.updateMany({
      where: { id: transferId, status: TransferStatus.IN_TRANSIT },
      data: {
        status: targetStatus === 'REJECTED' ? TransferStatus.REJECTED : TransferStatus.CANCELLED,
        ...(targetStatus === 'REJECTED'
          ? { receiverNote: note ?? null, receivedById: user.id }
          : { senderNote: note ? `${transfer.senderNote ?? ''} | Batal: ${note}` : transfer.senderNote }),
        resolvedAt: new Date(),
      },
    });
    if (claimed.count === 0) {
      throw new AppError(400, 'TRANSFER_INVALID_STATE', 'Transfer tidak lagi berstatus IN_TRANSIT.');
    }

    const col = statusToColumn(transfer.conditionStatus);
    const srcStock = await tx.itemStock.findUniqueOrThrow({
      where: { itemId_locationId: { itemId: transfer.itemId, locationId: transfer.fromLocationId } },
    });
    const srcBefore = snapshotStock(srcStock);

    const restored = await tx.itemStock.updateMany({
      where: { id: srcStock.id, qtyInTransit: { gte: transfer.qty } },
      data: {
        qtyInTransit: { decrement: transfer.qty },
        [col]: { increment: transfer.qty },
        version: { increment: 1 },
        updatedById: user.id,
      },
    });
    if (restored.count === 0) {
      throw new AppError(409, 'STOCK_VERSION_CONFLICT', 'Gagal mengembalikan saldo in-transit lokasi asal.');
    }

    const freshSrc = await tx.itemStock.findUniqueOrThrow({ where: { id: srcStock.id } });
    await tx.stockLog.create({
      data: {
        itemId: transfer.itemId,
        fromLocationId: transfer.fromLocationId,
        toLocationId: transfer.toLocationId,
        actionType:
          targetStatus === 'REJECTED' ? StockActionType.TRANSFER_REJECT : StockActionType.TRANSFER_CANCEL,
        statusChanged: `IN_TRANSIT_REVERTED_TO_${transfer.conditionStatus}`,
        qtyChanged: transfer.qty,
        qtyBefore: srcBefore,
        qtyAfter: snapshotStock(freshSrc),
        jobCode: transfer.jobCode,
        note: `[${transfer.transferCode}] ${targetStatus === 'REJECTED' ? 'Ditolak' : 'Dibatalkan'}${note ? `: ${note}` : ''}`,
        transferId: transfer.id,
        userId: user.id,
      },
    });

    return tx.stockTransfer.findUniqueOrThrow({
      where: { id: transferId },
      include: {
        item: { select: { id: true, itemCode: true, description: true, unit: true } },
        fromLocation: { select: { id: true, code: true, name: true } },
        toLocation: { select: { id: true, code: true, name: true } },
        sentBy: { select: { id: true, username: true, fullName: true } },
        receivedBy: { select: { id: true, username: true, fullName: true } },
      },
    });
  });
}

export function rejectTransfer(transferId: number, receiverNote: string, user: AuthUser) {
  return revertInTransitTransfer(transferId, 'REJECTED', receiverNote, user);
}

export function cancelTransfer(transferId: number, senderNote: string | null | undefined, user: AuthUser) {
  return revertInTransitTransfer(transferId, 'CANCELLED', senderNote, user);
}
