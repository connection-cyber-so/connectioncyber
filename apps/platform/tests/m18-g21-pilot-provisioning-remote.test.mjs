import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const script = await readFile(new URL('../scripts/Invoke-PilotProvisioningStaging.ps1', import.meta.url), 'utf8');

test('executor PowerShell usa somente ASCII',()=>assert.doesNotMatch(script,/[^\x00-\x7F]/));
test('executor exige Apply e project ref exato de staging',()=>{assert.match(script,/M18_G21_APPLY_FLAG_REQUIRED/);assert.match(script,/M18_G21_STAGING_ONLY/);assert.match(script,/ozvylnaipubrmaadikvk/)});
test('cofre DPAPI e chave service role ficam somente em memoria',()=>{assert.match(script,/ProtectedData\]::Unprotect/);assert.match(script,/service_role/);assert.doesNotMatch(script,/Set-Content|Out-File|Add-Content/)});
test('ordem segura prepara, convida, registra e finaliza',()=>{const steps=['erp_prepare_pilot_provisioning_v1','auth/v1/invite','erp_record_pilot_auth_identity_v1','erp_finalize_pilot_identity_v1'];let cursor=-1;for(const step of steps){const next=script.indexOf(step);assert.ok(next>cursor);cursor=next}});
test('e-mail Auth deve estar ausente antes da preparacao PostgreSQL',()=>{const absence=script.indexOf('Assert-AuthEmailAbsent $baseUrl');const prepare=script.indexOf('$prepared = Invoke-JsonPost');assert.ok(absence>=0);assert.ok(absence<prepare);assert.match(script,/M18_G21_AUTH_EMAIL_ALREADY_EXISTS/)});
test('falha apos Auth tenta remover identidade criada',()=>{assert.match(script,/authCreated/);assert.match(script,/Method Delete/);assert.match(script,/M18_G21_PROVISIONING_FAILED_FAIL_CLOSED/)});
test('nenhum segredo ou identidade aparece no marcador final',()=>{assert.match(script,/secretsLogged=false/);assert.doesNotMatch(script,/Write-Output.*\$(legalName|taxId|stateRegistration|ownerEmail|serviceKey|authUserId)/)});
test('falha informa somente a etapa tecnica',()=>{assert.match(script,/M18_G21_FAILED_STAGE=\$stage/);for(const stage of['preflight_auth_email','prepare_postgres','create_auth_invitation','record_auth_identity','finalize_identity'])assert.match(script,new RegExp(`'${stage}'`))});
test('Windows PowerShell usa Invoke-WebRequest com parser basico',()=>{assert.match(script,/Invoke-WebRequest -UseBasicParsing/);assert.doesNotMatch(script,/Invoke-RestMethod/)});
test('preflight Auth termina antes da preparacao PostgreSQL',()=>{assert.match(script,/PreflightOnly/);assert.match(script,/M18_G21_AUTH_PREFLIGHT_OK/);assert.ok(script.indexOf('M18_G21_AUTH_PREFLIGHT_OK')<script.indexOf('$prepared = Invoke-JsonPost'))});
test('diagnostico revela somente codigo permitido de e-mail existente',()=>{assert.match(script,/safeCode -eq 'M18_G21_AUTH_EMAIL_ALREADY_EXISTS'/);assert.doesNotMatch(script,/Write-Output \$safeCode/)});
