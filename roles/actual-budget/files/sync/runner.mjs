import fs from 'node:fs';
import { connected, verified, classify, duplicateIds } from './logic.mjs';
// All SDK/worker stdout and stderr are discarded by the host launcher and Docker
// logging is disabled. Only this allowlisted result crosses that boundary.
const result = { status: 'sync_failed', accounts: [] };
let api;
let initialized = false;
function save() {
  fs.writeFileSync('/cache/result.tmp', JSON.stringify(result), {mode: 0o600});
  fs.renameSync('/cache/result.tmp', '/cache/result.json');
}
try {
  const config = JSON.parse(fs.readFileSync('/credentials/config.json', 'utf8'));
  if (!config.password || !config.syncId || !Array.isArray(config.accountIds) || !config.accountIds.length || new Set(config.accountIds).size !== config.accountIds.length) {
    throw new Error('credentials incomplete');
  }
  api = await import('@actual-app/api');
  await api.init({serverURL: 'http://127.0.0.1:5006', password: config.password, dataDir: '/cache/budget', verbose: false});
  initialized = true;
  await api.downloadBudget(config.syncId, {password: config.budgetEncryptionPassword || undefined});
  async function accounts() {
    return (await api.runQuery(api.q('accounts').select(['id','closed','account_id','account_sync_source','last_sync','bank_sync_status']))).data;
  }
  const before = await accounts();
  // Explicit allowlist avoids silently accepting unlinked/manual accounts.
  if (config.accountIds.some(id => !connected(before.find(a => a.id === id)))) throw new Error('account configuration incomplete');
  let failed = false;
  let reauth = false;
  for (const id of config.accountIds) {
    const started = Date.now();
    let status = 'ok';
    try {
      await api.runBankSync({accountId: id});
      const after = (await accounts()).find(a => a.id === id);
      if (!verified(after, started)) throw new Error('account sync unverified');
    } catch (error) {
      status = classify(error);
      try {
        if ((await accounts()).find(a=>a.id===id)?.bank_sync_status === 'reauth-required') status = 'reauthentication_required';
      } catch { /* Keep the original sanitized failure. */ }
      failed = true;
      reauth ||= status === 'reauthentication_required';
    }
    result.accounts.push(status);
  }
  // Persist successes and failure state even if another account failed.
  await api.sync();
  if (failed) result.status = reauth ? 'reauthentication_required' : 'sync_failed';
  else result.status = 'ok';
  if (process.argv.includes('--verify-imports') && !failed) {
    // Requires an immediate second sync with unchanged upstream data. No amounts,
    // payees, dates, IDs, or transaction counts are written to operational logs.
    for (const id of config.accountIds) {
      const first = await api.getTransactions(id, '1900-01-01', '9999-12-31');
      if (!first.some(t => t.imported_id) || duplicateIds(first)) throw new Error('imports not verified');
      const existing = new Set(first.map(t => t.id));
      const started = Date.now();
      await api.runBankSync({accountId:id});
      if (!verified((await accounts()).find(a=>a.id===id), started)) throw new Error('second sync unverified');
      const second = await api.getTransactions(id, '1900-01-01', '9999-12-31');
      if (duplicateIds(second) || first.length !== second.length || second.some(t => !existing.has(t.id))) throw new Error('second sync changed transactions; review required');
    }
    await api.sync();
    result.acceptance = 'imports_and_second_sync_verified';
  }
} catch (error) {
  result.status = classify(error);
} finally {
  if (initialized) {
    try { await api.shutdown(); } catch { result.status = 'sync_failed'; }
  }
  save();
}
process.exit(result.status === 'ok' ? 0 : 1);
