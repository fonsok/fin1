// ============================================================================
// Parse Cloud Code
// functions/notifications.js - Email Notification Functions
// ============================================================================

'use strict';

const { requirePermission, requireAdminRole } = require('../utils/permissions');
const emailService = require('../utils/emailService');

// ============================================================================
// EMAIL TEST
// ============================================================================

/**
 * Test email configuration.
 * Available to: admin only
 */
Parse.Cloud.define('testEmailConfig', async (request) => {
  requirePermission(request, '*'); // admin only

  const result = await emailService.testEmailConfig();
  return result;
});

/**
 * Send a test email to a specific address.
 * Available to: admin only
 */
Parse.Cloud.define('sendTestEmail', async (request) => {
  requirePermission(request, '*'); // admin only

  const { to } = request.params;
  if (!to) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'to email required');
  }

  const sent = await emailService.sendEmail({
    to,
    subject: '[FIN1] Test-E-Mail',
    text: `Dies ist eine Test-E-Mail von FIN1.\n\nGesendet von: ${request.user.get('email')}`,
  });

  return { success: sent };
});

// ============================================================================
// TICKET NOTIFICATIONS
// ============================================================================

/**
 * Send notification when a new ticket is created.
 * Called automatically from ticket trigger.
 */
async function notifyNewTicket(ticket) {
  try {
    await emailService.sendTicketNotification(ticket, 'new');
  } catch (error) {
    console.error('Failed to send ticket notification:', error);
  }
}

/**
 * Send notification when a ticket is updated.
 */
async function notifyTicketUpdate(ticket) {
  try {
    await emailService.sendTicketNotification(ticket, 'update');
  } catch (error) {
    console.error('Failed to send ticket update notification:', error);
  }
}

/**
 * Send notification when a ticket gets a reply.
 */
async function notifyTicketReply(ticket) {
  try {
    await emailService.sendTicketNotification(ticket, 'reply');
  } catch (error) {
    console.error('Failed to send ticket reply notification:', error);
  }
}

// ============================================================================
// APPROVAL NOTIFICATIONS
// ============================================================================

/**
 * Send notification when a new 4-eyes approval is needed.
 * Called automatically from approval trigger.
 */
async function notifyNewApprovalRequest(request) {
  try {
    // Get all admins and compliance officers who can approve
    const userQuery = new Parse.Query(Parse.User);
    userQuery.containedIn('role', ['admin', 'compliance']);
    userQuery.notEqualTo('objectId', request.requesterId); // Exclude requester
    const approvers = await userQuery.find({ useMasterKey: true });

    for (const approver of approvers) {
      const email = approver.get('email');
      if (email) {
        await emailService.sendApprovalNotification(request, email);
      }
    }
  } catch (error) {
    console.error('Failed to send approval notification:', error);
  }
}

/**
 * Send notification when an approval is completed.
 */
async function notifyApprovalComplete(request, approved) {
  try {
    // Notify the requester
    const requester = await new Parse.Query(Parse.User).get(request.requesterId, { useMasterKey: true });
    const email = requester.get('email');

    if (email) {
      await emailService.sendEmail({
        to: email,
        subject: `[FIN1] Ihre Anfrage wurde ${approved ? 'genehmigt' : 'abgelehnt'}`,
        text: `
Ihre 4-Augen-Anfrage wurde ${approved ? 'genehmigt' : 'abgelehnt'}.

Typ: ${request.requestType}
Status: ${approved ? 'Genehmigt' : 'Abgelehnt'}
${request.approverNotes ? `Notiz: ${request.approverNotes}` : ''}
${request.rejectionReason ? `Grund: ${request.rejectionReason}` : ''}

---
FIN1 Admin Portal
        `.trim(),
      });
    }
  } catch (error) {
    console.error('Failed to send approval complete notification:', error);
  }
}

// ============================================================================
// SECURITY NOTIFICATIONS
// ============================================================================

/**
 * Send security alert to security officers.
 */
async function notifySecurityAlert(alert) {
  try {
    // Get all security officers and admins
    const userQuery = new Parse.Query(Parse.User);
    userQuery.containedIn('role', ['admin', 'security_officer']);
    const securityTeam = await userQuery.find({ useMasterKey: true });

    for (const member of securityTeam) {
      const email = member.get('email');
      if (email) {
        await emailService.sendSecurityAlert(alert, email);
      }
    }
  } catch (error) {
    console.error('Failed to send security alert:', error);
  }
}

/**
 * Cloud function to manually send a security alert.
 * Available to: admin, security_officer
 */
Parse.Cloud.define('sendSecurityAlertEmail', async (request) => {
  requirePermission(request, 'getSecurityDashboard');

  const { alertId } = request.params;
  if (!alertId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'alertId required');
  }

  const alert = await new Parse.Query('ComplianceEvent').get(alertId, { useMasterKey: true });

  await notifySecurityAlert({
    type: alert.get('eventType'),
    severity: alert.get('severity'),
    message: alert.get('description'),
    userId: alert.get('userId'),
    createdAt: alert.get('occurredAt')?.toISOString(),
  });

  return { success: true };
});

// ============================================================================
// PASSWORD RESET
// ============================================================================

/**
 * Send password reset email.
 * Available to: admin, security_officer, customer_service
 */
Parse.Cloud.define('sendPasswordResetEmail', async (request) => {
  requirePermission(request, 'forcePasswordReset');

  const { userId } = request.params;
  if (!userId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId required');
  }

  const user = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });
  const email = user.get('email');
  const resetToken = user.get('passwordResetToken');

  if (!email) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'User has no email');
  }

  if (!resetToken) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'No reset token - call forcePasswordReset first');
  }

  const sent = await emailService.sendPasswordResetEmail(email, resetToken);
  return { success: sent };
});

// ============================================================================
// EXPORTS
// ============================================================================

module.exports = {
  notifyNewTicket,
  notifyTicketUpdate,
  notifyTicketReply,
  notifyNewApprovalRequest,
  notifyApprovalComplete,
  notifySecurityAlert,
};

console.log('Notification Cloud Functions loaded');
