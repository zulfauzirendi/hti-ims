import PDFDocument from 'pdfkit';
import { prisma } from '../../config/prisma';
import { buildLogsWhereClause } from '../logs/logs.service';
import { formatWibTimestamp } from './sanitizer';

function drawCorporateHeader(doc: PDFKit.PDFDocument, title: string, printedBy: string): void {
  doc
    .rect(36, 30, doc.page.width - 72, 54)
    .fill('#0f2942');

  doc
    .fillColor('#ffffff')
    .font('Helvetica-Bold')
    .fontSize(13)
    .text('PT HIKARI TEKNOLOGI INDONESIA (PT HTI)', 48, 40);

  doc
    .fillColor('#fbbf24')
    .font('Helvetica-Bold')
    .fontSize(9.5)
    .text(title, 48, 57);

  doc
    .fillColor('#cbd5e1')
    .font('Helvetica')
    .fontSize(7.5)
    .text('ISO 9001:2015 (Mutu) & ISO 45001:2018 (K3) — Controlled Compliance Report', 48, 70);

  doc
    .fillColor('#1f2937')
    .font('Helvetica')
    .fontSize(8)
    .text(`Dicetak oleh: ${printedBy}   |   Waktu Cetak: ${formatWibTimestamp(new Date())}`, 36, 92);

  doc.moveDown(1);
}

function drawSignatureBlock(doc: PDFKit.PDFDocument): void {
  if (doc.y > doc.page.height - 130) {
    doc.addPage();
  }
  const y = doc.y + 18;
  const colW = (doc.page.width - 72) / 3;
  const labels = ['Dibuat Oleh (Admin / Petugas)', 'Diperiksa Oleh (QA / HSE ISO)', 'Disetujui Oleh (Manajemen)'];

  doc.font('Helvetica-Bold').fontSize(8.5).fillColor('#0f2942');
  labels.forEach((label, idx) => {
    const x = 36 + idx * colW;
    doc.text(label, x, y, { width: colW - 10, align: 'center' });
    doc
      .moveTo(x + 25, y + 52)
      .lineTo(x + colW - 35, y + 52)
      .strokeColor('#64748b')
      .stroke();
    doc.font('Helvetica').fontSize(7.5).fillColor('#475569').text('Tanggal: ____ / ____ / 20__', x, y + 58, {
      width: colW - 10,
      align: 'center',
    });
    doc.font('Helvetica-Bold').fontSize(8.5).fillColor('#0f2942');
  });
}

export async function buildStockPdfBuffer(filters: {
  locationId?: number;
  categoryId?: number;
  printedBy: string;
}): Promise<Buffer> {
  const items = await prisma.item.findMany({
    where: { isActive: true, ...(filters.categoryId ? { categoryId: filters.categoryId } : {}) },
    orderBy: [{ categoryId: 'asc' }, { itemCode: 'asc' }],
    take: 5000,
    include: {
      category: true,
      stocks: { where: filters.locationId ? { locationId: filters.locationId } : undefined },
    },
  });

  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', layout: 'landscape', margin: 36 });
    const chunks: Buffer[] = [];
    doc.on('data', (c: Buffer) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    drawCorporateHeader(doc, 'LAPORAN REKAPITULASI STOK TOOL & EQUIPMENT', filters.printedBy);

    let y = 112;
    const drawTableHeader = () => {
      doc.rect(36, y, doc.page.width - 72, 18).fill('#1e3a5f');
      doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(8);
      doc.text('SKU', 42, y + 5, { width: 78 });
      doc.text('Kategori', 124, y + 5, { width: 120 });
      doc.text('Deskripsi & Spesifikasi', 248, y + 5, { width: 250 });
      doc.text('Sat', 502, y + 5, { width: 35 });
      doc.text('Good', 540, y + 5, { width: 55, align: 'right' });
      doc.text('Service', 598, y + 5, { width: 55, align: 'right' });
      doc.text('Broken', 656, y + 5, { width: 55, align: 'right' });
      doc.text('Total', 716, y + 5, { width: 65, align: 'right' });
      y += 20;
    };

    drawTableHeader();

    let sumG = 0;
    let sumS = 0;
    let sumB = 0;

    for (const it of items) {
      if (y > doc.page.height - 60) {
        doc.addPage();
        y = 40;
        drawTableHeader();
      }
      const g = it.stocks.reduce((a, s) => a + s.qtyGood, 0);
      const s = it.stocks.reduce((a, st) => a + st.qtyService, 0);
      const b = it.stocks.reduce((a, st) => a + st.qtyBroken, 0);
      const t = g + s + b + it.stocks.reduce((a, st) => a + st.qtyInTransit, 0);
      sumG += g;
      sumS += s;
      sumB += b;

      doc.fillColor('#1f2937').font('Helvetica').fontSize(7.5);
      doc.text(it.itemCode, 42, y, { width: 78, ellipsis: true });
      doc.text(it.category.name, 124, y, { width: 120, ellipsis: true });
      const descLine = it.specification ? `${it.description} (${it.specification})` : it.description;
      doc.text(descLine, 248, y, { width: 250, ellipsis: true });
      doc.text(it.unit, 502, y, { width: 35 });
      doc.text(String(g), 540, y, { width: 55, align: 'right' });
      doc.text(String(s), 598, y, { width: 55, align: 'right' });
      doc.text(String(b), 656, y, { width: 55, align: 'right' });
      doc.text(String(t), 716, y, { width: 65, align: 'right' });
      y += 14;
    }

    y += 6;
    doc.rect(36, y, doc.page.width - 72, 18).fill('#f1f5f9');
    doc.fillColor('#0f2942').font('Helvetica-Bold').fontSize(8.5);
    doc.text(`TOTAL KESELURUHAN (${items.length} Item)`, 42, y + 5, { width: 450 });
    doc.text(String(sumG), 540, y + 5, { width: 55, align: 'right' });
    doc.text(String(sumS), 598, y + 5, { width: 55, align: 'right' });
    doc.text(String(sumB), 656, y + 5, { width: 55, align: 'right' });
    doc.text(String(sumG + sumS + sumB), 716, y + 5, { width: 65, align: 'right' });

    doc.y = y + 26;
    drawSignatureBlock(doc);
    doc.end();
  });
}

export async function buildLogsPdfBuffer(filters: {
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
      item: { select: { itemCode: true, description: true } },
      fromLocation: { select: { code: true } },
      toLocation: { select: { code: true } },
      user: { select: { fullName: true } },
    },
  });

  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', layout: 'landscape', margin: 36 });
    const chunks: Buffer[] = [];
    doc.on('data', (c: Buffer) => chunks.push(c));
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);

    drawCorporateHeader(doc, 'LAPORAN AUDIT TRAIL MUTASI & KONDISI ALAT (ISO 9001:2015)', filters.printedBy);

    let y = 112;
    const drawTableHeader = () => {
      doc.rect(36, y, doc.page.width - 72, 18).fill('#1e3a5f');
      doc.fillColor('#ffffff').font('Helvetica-Bold').fontSize(8);
      doc.text('Waktu (WIB)', 42, y + 5, { width: 100 });
      doc.text('SKU & Item', 146, y + 5, { width: 165 });
      doc.text('Aksi', 315, y + 5, { width: 85 });
      doc.text('Qty', 402, y + 5, { width: 32, align: 'right' });
      doc.text('Asal -> Tujuan', 442, y + 5, { width: 110 });
      doc.text('Catatan / Job Code', 556, y + 5, { width: 150 });
      doc.text('Petugas', 710, y + 5, { width: 85 });
      y += 20;
    };

    drawTableHeader();

    for (const log of logs) {
      if (y > doc.page.height - 60) {
        doc.addPage();
        y = 40;
        drawTableHeader();
      }
      doc.fillColor('#1f2937').font('Helvetica').fontSize(7.3);
      doc.text(formatWibTimestamp(log.createdAt), 42, y, { width: 100 });
      doc.text(`${log.item.itemCode} - ${log.item.description}`, 146, y, { width: 165, ellipsis: true });
      doc.text(log.actionType, 315, y, { width: 85 });
      doc.text(String(log.qtyChanged), 402, y, { width: 32, align: 'right' });
      doc.text(`${log.fromLocation?.code ?? '-'} -> ${log.toLocation?.code ?? '-'}`, 442, y, { width: 110 });
      doc.text(`${log.jobCode ? `[${log.jobCode}] ` : ''}${log.note ?? ''}`, 556, y, { width: 150, ellipsis: true });
      doc.text(log.user?.fullName ?? 'SYSTEM', 710, y, { width: 85, ellipsis: true });
      y += 14;
    }

    doc.y = y + 16;
    drawSignatureBlock(doc);
    doc.end();
  });
}
