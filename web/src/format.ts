/** Format an ISO date (YYYY-MM-DD) for display, UK style. */
export function fmtDate(
  iso: string,
  opts: Intl.DateTimeFormatOptions = { day: 'numeric', month: 'short' },
): string {
  return new Date(iso).toLocaleDateString('en-GB', opts)
}
