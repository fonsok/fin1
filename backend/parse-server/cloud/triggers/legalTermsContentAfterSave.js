'use strict';

Parse.Cloud.afterSave('TermsContent', async (request) => {
  const obj = request.object;
  const original = request.original;

  if (original) {
    const wasActive = original.get('isActive');
    const isActive = obj.get('isActive');
    if (wasActive && !isActive) {
      try {
        const AuditLog = Parse.Object.extend('AuditLog');
        const log = new AuditLog();
        log.set('logType', 'legal');
        log.set('action', 'legal_document_deactivated');
        log.set('resourceType', 'TermsContent');
        log.set('resourceId', obj.id);
        log.set('metadata', {
          version: obj.get('version'),
          language: obj.get('language'),
          documentType: obj.get('documentType'),
          documentHash: obj.get('documentHash'),
          deactivatedAt: new Date().toISOString(),
          source: 'system',
        });
        await log.save(null, { useMasterKey: true });
      } catch (err) {
        console.error('Failed to log TermsContent deactivation:', err.message);
      }
    }
    return;
  }

  try {
    const effectiveDate = obj.get('effectiveDate');
    const AuditLog = Parse.Object.extend('AuditLog');
    const log = new AuditLog();
    log.set('logType', 'legal');
    log.set('action', 'legal_document_version_created');
    log.set('resourceType', 'TermsContent');
    log.set('resourceId', obj.id);
    log.set('newValues', {
      version: obj.get('version'),
      language: obj.get('language'),
      documentType: obj.get('documentType'),
      effectiveDate: effectiveDate instanceof Date ? effectiveDate.toISOString() : null,
      documentHash: obj.get('documentHash'),
      sectionCount: (obj.get('sections') || []).length,
      isActive: obj.get('isActive'),
    });
    log.set('metadata', {
      createdAt: new Date().toISOString(),
      source: request.context?.source || 'unknown',
      reason: request.context?.reason || null,
      deployedBy: request.context?.deployedBy || null,
    });
    await log.save(null, { useMasterKey: true });
  } catch (err) {
    console.error('Failed to log TermsContent creation:', err.message);
  }
});
