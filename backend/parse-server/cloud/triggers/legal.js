// ============================================================================
// Parse Cloud Code
// triggers/legal.js - Legal Document Triggers (entry)
// ============================================================================
//
// Purpose:
// - Stable content hash / placeholders for TermsContent
// - Append-only legal audit classes
// - Delete protection (GoB / audit)
//
// ============================================================================

'use strict';

require('./legalTermsContentBeforeSave');
require('./legalTermsContentAfterSave');
require('./legalTermsContentBeforeDelete');
require('./legalAppendOnlyHooks');
require('./legalDeleteProtection');
