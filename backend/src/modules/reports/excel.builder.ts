import ExcelJS from 'exceljs';
import { prisma } from '../../config/prisma';
import { buildLogsWhereClause } from '../logs/logs.service';
import { formatWibTimestamp, sanitizeSpreadsheetCell } from './sanitizer';

export async function buildStockExcelBuffer(filters: {
  locationId?: number;
  categoryId?: number;
  printedBy: string;
}): Promise<Buffer> {
  const [locations, items] = await Promise.all([
    prisma.location.findMany({
      where: { isActive: true, ...(filters.locationId ? { id: filters.locationId } : {}) },
      orderBy: { id: 'asc' },
    }),
    prisma.item.findMany({
      where: { isActive: true, ...(filters.categoryId ? { categoryId: filters.categoryId } : {}) },
      orderBy: [{ categoryId: 'asc' }, { itemCode: 'asc' }],
      include: {
        category: true,
        stocks: {
          where: filters.locationId ? { locationId: filters.locationId } : undefined,
        },
      },
    }),
  ]);

  const wb = new ExcelJS.Workbook();
  wb.creator = 'PT Hikari Teknologi Indonesia — HTI-TEIS';
  wb.created = new Date();

  const sheet = wb.addWorksheet('Inventory Stock', { views: [{ state: 'frozen', ySplit: 4 }] });

  sheet.addRow(['PT HIKARI TEKNOLOGI INDONESIA — LAPORAN STOK TOOL & EQUIPMENT (ISO 9001:2015 / ISO 45001:2018)']);
  sheet.addRow([`Dicetak oleh: ${sanitizeSpreadsheetCell(filters.printedBy)}`, `Waktu Cetak: ${formatWibTimestamp(new Date())}`]);
  sheet.addRow([]);

  const headers = ['Kode SKU', 'Kategori', 'Deskripsi', 'Spesifikasi', 'Satuan'];
  for (const loc of locations) {
    headers.push(`${loc.name} (Good)`, `${loc.name} (Service)`, `${loc.name} (Broken)`, `${loc.name} (In-Transit)`);
  }
  headers.push('Total Volume', 'Job Code / Remarks');

  const headerRow = sheet.addRow(headers);
  headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
  headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF0F2942' } };

  for (const it of items) {
    const stockMap = new Map(it.stocks.map((s) => [s.locationId, s]));
    let totalVol = 0;
    const notes: string[] = [];

    const rowData: (string | number)[] = [
      sanitizeSpreadsheetCell(it.itemCode),
      sanitizeSpreadsheetCell(it.category.name),
      sanitizeSpreadsheetCell(it.description),
      sanitizeSpreadsheetCell(it.specification),
      sanitizeSpreadsheetCell(it.unit),
    ];

    for (const loc of locations) {
      const st = stockMap.get(loc.id);
      const g = st?.qtyGood ?? 0;
      const s = st?.qtyService ?? 0;
      const b = st?.qtyBroken ?? 0;
      const t = st?.qtyInTransit ?? 0;
      totalVol += g + s + b + t;
      rowData.push(g, s, b, t);
      if (st?.jobCode || st?.remarks) {
        notes.push(`[${loc.code}] ${st.jobCode ? `Job: ${st.jobCode} ` : ''}${st.remarks ?? ''}`.trim());
      }
    }

    rowData.push(totalVol, sanitizeSpreadsheetCell(notes.join(' | ')));
    sheet.addRow(rowData);
  }

  sheet.columns.forEach((col) => {
    col.width = 18;
  });
  if (sheet.getColumn(3)) sheet.getColumn(3).width = 34;
  if (sheet.getColumn(4)) sheet.getColumn(4).width = 28;

  const arrayBuffer = await wb.xlsx.writeBuffer();
  return Buffer.from(arrayBuffer);
}

export async function buildLogsExcelBuffer(filters: {
  locationId?: number;
  dateFrom?: string;
  dateTo?: string;
  printedBy: string;
}): Promise<Buffer> {
  const where = buildLogsWhereClause({
    locationId: filters.locationId,
    dateFrom: filters.dateFrom,
    dateTo: filters.dateTo,
  });

  const logs = await prisma.stockLog.findMany({
    where,
    orderBy: { createdAt: 'desc' },
    take: 5000,
    include: {
      item: { select: { itemCode: true, description: true, unit: true } },
      fromLocation: { select: { code: true, name: true } },
      toLocation: { select: { code: true, name: true } },
      user: { select: { username: true, fullName: true } },
    },
  });

  const wb = new ExcelJS.Workbook();
  wb.creator = 'PT Hikari Teknologi Indonesia — HTI-TEIS';
  wb.created = new Date();

  const sheet = wb.addWorksheet('ISO 9001 Audit Trail', { views: [{ state: 'frozen', ySplit: 4 }] });
  sheet.addRow(['PT HIKARI TEKNOLOGI INDONESIA — LAPORAN AUDIT TRAIL MUTASI ALAT (ISO 9001:2015)']);
  sheet.addRow([`Dicetak oleh: ${sanitizeSpreadsheetCell(filters.printedBy)}`, `Waktu Cetak: ${formatWibTimestamp(new Date())}`]);
  sheet.addRow([]);

  const headerRow = sheet.addRow([
    'Waktu (WIB)',
    'Kode SKU',
    'Nama Item',
    'Aksi',
    'Perubahan Status',
    'Qty',
    'Dari Lokasi',
    'Ke Lokasi',
    'Job Code',
    'Catatan',
    'Bukti Foto K3',
    'Petugas',
  ]);
  headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' } };
  headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF0F2942' } };

  for (const log of logs) {
    sheet.addRow([
      formatWibTimestamp(log.createdAt),
      sanitizeSpreadsheetCell(log.item.itemCode),
      sanitizeSpreadsheetCell(log.item.description),
      sanitizeSpreadsheetCell(log.actionType),
      sanitizeSpreadsheetCell(log.statusChanged),
      log.qtyChanged,
      sanitizeSpreadsheetCell(log.fromLocation?.name ?? '-'),
      sanitizeSpreadsheetCell(log.toLocation?.name ?? '-'),
      sanitizeSpreadsheetCell(log.jobCode),
      sanitizeSpreadsheetCell(log.note),
      sanitizeSpreadsheetCell(log.photoUrl ?? '-'),
      sanitizeSpreadsheetCell(log.user?.fullName ?? 'SYSTEM'),
    ]);
  }

  sheet.columns.forEach((col) => {
    col.width = 20;
  });

  const arrayBuffer = await wb.xlsx.writeBuffer();
  return Buffer.from(arrayBuffer);
}
