import test from 'node:test';
import assert from 'node:assert/strict';
import {
  content,
  safeUrl,
  taxonomy,
  tags,
  validateFile,
  repositorySuggestion,
  uuid,
  pageNumber,
} from '../src/features/knowledge-base/validations.ts';
test('reject executable URLs, credentials and invalid identifiers', () => {
  for (const url of [
    'javascript:alert(1)',
    'http://example.com',
    'https://user:pass@example.com',
    'file:///test',
  ])
    assert.throws(() => safeUrl(url));
  assert.throws(() => uuid('../other-tenant'));
  assert.equal(safeUrl('https://example.com/docs'), 'https://example.com/docs');
});
test('entry contract enforces title, kind, source and body budget', () => {
  assert.throws(() => content({ title: 'a', kind: 'code' }));
  assert.throws(() => content({ title: 'Valid', kind: 'video' }));
  assert.throws(() => content({ title: 'Valid', kind: 'bad' }));
  assert.throws(() => content({ title: 'Valid', kind: 'code', body: 'x'.repeat(100001) }));
  assert.equal(
    content({ title: 'SQL reference', kind: 'migration', body: 'select 1;' }).kind,
    'migration',
  );
});
test('classification is complete and bounds generated output', () => {
  assert.throws(() => taxonomy({ theme: 'SQL' }));
  assert.throws(() => tags(Array.from({ length: 31 }, (_, i) => 'tag' + i).join(',')));
  assert.deepEqual(tags(' SQL,sql, Docs '), ['sql', 'docs']);
  const t = taxonomy(
    Object.fromEntries(
      ['ai', 'sector', 'segment', 'theme', 'project', 'technical_application', 'repository'].map(
        (k) => [k, 'test'],
      ),
    ),
  );
  assert.equal(t.theme, 'test');
});
test('uploads refuse executable binaries, empty files, paths and oversize', () => {
  for (const file of [
    { name: 'x.exe', size: 1, type: '' },
    { name: 'x.pdf', size: 0, type: '' },
    { name: '../x.pdf', size: 1, type: '' },
    { name: 'x.zip', size: 3145729, type: '' },
  ])
    assert.throws(() => validateFile(file));
  assert.equal(
    validateFile({ name: 'reference.sql', size: 50, type: '' }).mime,
    'application/octet-stream',
  );
});
test('repository suggestions normalize project names without executing content', () => {
  const result = repositorySuggestion('migration', 'Projeto A / ../../');
  assert.match(result.path, /^knowledge\/projeto-a\/supabase\/migrations$/);
  assert.equal(pageNumber('-1'), 1);
  assert.equal(pageNumber('2'), 2);
});
