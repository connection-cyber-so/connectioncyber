import assert from'node:assert/strict';import test from'node:test';import{PeripheralSimulator}from'../simulators/peripheral-simulator.mjs';
const command=(type,payload={})=>({type,payload,idempotencyKey:`sim:${type}:001`});
test('impressão simulada preserva hash e cópias',()=>{const r=new PeripheralSimulator().execute(command('print.execute',{documentHash:'a'.repeat(64),copies:2}));assert.deepEqual([r.status,r.code,r.copies],['succeeded','PRINTED',2])});
test('balança simulada retorna peso estável',()=>{const r=new PeripheralSimulator({scaleWeight:2.5}).execute(command('scale.read'));assert.deepEqual([r.weight,r.unit,r.stable],[2.5,'kg',true])});
test('gaveta simulada apenas confirma pulso',()=>assert.equal(new PeripheralSimulator().execute(command('cash_drawer.open')).code,'DRAWER_PULSE_SENT'));
test('TEF aprovado não contém PAN ou CVV',()=>{const r=new PeripheralSimulator().execute(command('tef.execute',{amount:100}));assert.equal(r.code,'TEF_APPROVED');assert.equal('pan'in r||'cvv'in r,false)});
test('timeout TEF exige revisão manual',()=>{const r=new PeripheralSimulator({tefOutcome:'timeout'}).execute(command('tef.execute'));assert.equal(r.status,'manual_review')});
test('reexecução idempotente não repete efeito',()=>{const s=new PeripheralSimulator(),c=command('print.execute',{documentHash:'b'.repeat(64)}),a=s.execute(c),b=s.execute(c);assert.equal(a.resultHash,b.resultHash);assert.equal(b.replayed,true)});
test('comando desconhecido falha fechado',()=>assert.equal(new PeripheralSimulator().execute(command('unknown')).code,'UNSUPPORTED_COMMAND'));
