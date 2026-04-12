'use strict';

async function sendApprovalNotification(req, requestType, metadata) {
  try {
    const Notification = Parse.Object.extend('Notification');
    const notif = new Notification();
    notif.set('userId', req.get('requesterId'));
    notif.set('type', `${requestType}_approved`);
    notif.set('category', 'admin');
    notif.set('title', 'Anfrage genehmigt');
    notif.set(
      'message',
      requestType === 'configuration_change'
        ? `Ihre Konfigurationsänderung '${metadata.parameterName}' wurde genehmigt und angewendet.`
        : `Ihre Anfrage (${requestType}) wurde genehmigt.`
    );
    notif.set('isRead', false);
    notif.set('channels', ['in_app', 'push']);
    await notif.save(null, { useMasterKey: true });
  } catch (err) {
    console.error('Failed to send approval notification:', err.message);
  }
}

async function sendRejectionNotification(req, requestType, metadata, reason) {
  try {
    const Notification = Parse.Object.extend('Notification');
    const notif = new Notification();
    notif.set('userId', req.get('requesterId'));
    notif.set('type', `${requestType}_rejected`);
    notif.set('category', 'admin');
    notif.set('title', 'Anfrage abgelehnt');
    notif.set(
      'message',
      requestType === 'configuration_change'
        ? `Ihre Konfigurationsänderung '${metadata.parameterName}' wurde abgelehnt. Grund: ${reason}`
        : `Ihre Anfrage (${requestType}) wurde abgelehnt. Grund: ${reason}`
    );
    notif.set('priority', 'high');
    notif.set('isRead', false);
    notif.set('channels', ['in_app', 'push']);
    await notif.save(null, { useMasterKey: true });
  } catch (err) {
    console.error('Failed to send rejection notification:', err.message);
  }
}

module.exports = {
  sendApprovalNotification,
  sendRejectionNotification,
};
