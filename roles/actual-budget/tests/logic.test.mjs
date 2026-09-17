import test from 'node:test';
import assert from 'node:assert/strict';
import {connected, verified, classify, duplicateIds} from '../files/sync/logic.mjs';

test('manual, closed, and unsupported-provider accounts cannot pass',()=>{
  for (const a of [{}, {account_id:'a'}, {account_id:'a',account_sync_source:'goCardless'}, {account_id:'a',account_sync_source:'simpleFin',closed:true}]) assert.ok(!connected(a));
});
test('success requires a current numeric epoch timestamp and healthy status',()=>{
  const a={account_id:'a',account_sync_source:'simpleFin',last_sync:'10001',bank_sync_status:'ok'};
  assert.ok(verified(a,10000));
  assert.ok(!verified(a,10002));
  assert.ok(!verified({...a,bank_sync_status:'error'},10000));
  assert.ok(!verified({...a,last_sync:null},10000));
});
test('provider failures become only allowlisted operational statuses',()=>{
  assert.equal(classify(new Error('secret token expired')), 'reauthentication_required');
  assert.equal(classify({code:'INVALID_ACCESS_TOKEN'}), 'reauthentication_required');
  assert.equal(classify(new Error('a private bank account failed')), 'sync_failed');
});
test('duplicate bank import IDs are rejected; manual transactions are ignored',()=>{
  assert.ok(duplicateIds([{imported_id:'x'},{imported_id:'x'}]));
  assert.ok(!duplicateIds([{imported_id:'x'},{imported_id:'y'},{},{}]));
});
