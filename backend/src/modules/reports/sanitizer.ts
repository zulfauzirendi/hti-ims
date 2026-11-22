const DANGEROUS_FORMULA_PREFIX = /^[=+\-@\t\r]/;

/**
 * Mencegah Excel / CSV Formula Injection (SRS-SEC-014).
 * Setiap teks masukan pengguna yang diawali =, +, -, @, Tab, atau CR
 * diberi awalan petik tunggal (') agar dirender sebagai teks literal aman.
 */
export function sanitizeSpreadsheetCell(value: string | null | undefined): string {
  if (value === null || value === undefined) return '';
  const text = String(value);
  return DANGEROUS_FORMULA_PREFIX.test(text) ? `'${text}` : text;
}

export function formatWibTimestamp(date: Date): string {
  return new Intl.DateTimeFormat('id-ID', {
    timeZone: 'Asia/Jakarta',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).format(date) + ' WIB';
}
