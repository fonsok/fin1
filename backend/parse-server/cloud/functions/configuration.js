// ============================================================================
// Parse Cloud Code
// functions/configuration.js - Configuration Management with 4-Eyes Principle
// ============================================================================
//
// Verwaltet kritische Konfigurationsparameter mit 4-Augen-Prinzip.
//
// Workflow für kritische Parameter:
// 1. Admin beantragt Änderung → FourEyesRequest erstellt
// 2. Zweiter Admin genehmigt → Änderung wird angewendet
// 3. Alle Änderungen werden im Audit-Log protokolliert
//
// ============================================================================

'use strict';

const { registerConfigurationReadFunctions } = require('./configuration/read');
const { registerConfigurationWorkflowFunctions } = require('./configuration/workflow');

registerConfigurationReadFunctions();
registerConfigurationWorkflowFunctions();

console.log('Configuration cloud functions loaded');
