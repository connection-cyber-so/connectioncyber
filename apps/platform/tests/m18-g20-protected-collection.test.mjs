import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const collect = await readFile(new URL('../scripts/Collect-PilotProvisioningProtected.ps1', import.meta.url), 'utf8');
const validate = await readFile(new URL('../scripts/Test-PilotProvisioningProtected.ps1', import.meta.url), 'utf8');
const preflight = await readFile(new URL('../../../supabase/preflight/m18_g20_pilot_identity_preflight.sql', import.meta.url), 'utf8');

test('scripts PowerShell usam somente ASCII',()=>{assert.doesNotMatch(collect,/[^\x00-\x7F]/);assert.doesNotMatch(validate,/[^\x00-\x7F]/)});
test('coleta usa entrada mascarada e DPAPI',()=>{assert.match(collect,/Read-Host \$Prompt -AsSecureString/);assert.match(collect,/ConvertFrom-SecureString/)});
test('cofre fica fora do projeto',()=>{assert.match(collect,/LOCALAPPDATA/);assert.match(validate,/LOCALAPPDATA/);assert.doesNotMatch(collect,/apps\\platform\\\.env/)});
test('gravacao declara UTF-8 explicitamente',()=>assert.match(collect,/Set-Content[^\n]+-Encoding utf8/));
test('validador nao imprime valores protegidos',()=>{assert.doesNotMatch(validate,/Write-Output.*\$(legalName|taxId|stateRegistration|ownerEmail)/);assert.match(validate,/plaintextLogged=false/)});
test('quatro campos possuem validacao fail-closed',()=>{for(const marker of['LEGAL_NAME','CNPJ','STATE_REGISTRATION','OWNER_EMAIL'])assert.match(validate,new RegExp(`INVALID_${marker}`))});
test('preflight remoto e somente leitura com rollback',()=>{assert.match(preflight,/begin transaction read only/);assert.match(preflight,/rollback;/);assert.match(preflight,/M18_G20_REMOTE_PREFLIGHT_OK/)});
test('preflight exige 0034 e tenant ausente',()=>{assert.match(preflight,/version='0034'/);assert.match(preflight,/TENANT_ALREADY_EXISTS/)});
