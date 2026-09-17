export function connected(account) {
  return account && !account.closed && account.account_id && account.account_sync_source === 'simpleFin';
}
export function verified(account, started) {
  return connected(account) && account.bank_sync_status === 'ok' && Number(account.last_sync) >= started;
}
export function classify(error) {
  // Inspect in memory only; never persist the provider's error text or code.
  return /reauth|login|credential|unauthori|expired|401|403|invalid_access_token/i.test(String(error?.code || '') + ' ' + String(error?.message || ''))
    ? 'reauthentication_required' : 'sync_failed';
}
export function duplicateIds(transactions) {
  const seen = new Set();
  for (const t of transactions) {
    if (!t.imported_id) continue;
    if (seen.has(t.imported_id)) return true;
    seen.add(t.imported_id);
  }
  return false;
}
