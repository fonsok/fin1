'use strict';

const { formatValue } = require('./shared');

async function notifyApproversOfPendingRequest(fourEyesReq, parameterName, newValue, reason) {
  const approvalRoles = ['admin', 'business_admin', 'compliance'];
  const userQuery = new Parse.Query(Parse.User);
  userQuery.containedIn('role', approvalRoles);
  userQuery.notEqualTo('objectId', fourEyesReq.get('requesterId'));
  userQuery.equalTo('status', 'active');

  const approvers = await userQuery.find({ useMasterKey: true });

  for (const approver of approvers) {
    const Notification = Parse.Object.extend('Notification');
    const notif = new Notification();
    notif.set('userId', approver.id);
    notif.set('type', 'configuration_change_pending');
    notif.set('category', 'admin');
    notif.set('title', 'Konfigurationsänderung erfordert Genehmigung');
    notif.set('message', `Eine Änderung von '${parameterName}' auf ${formatValue(newValue)} wurde beantragt. Grund: ${reason}`);
    notif.set('priority', 'high');
    notif.set('isRead', false);
    notif.set('channels', ['in_app', 'push']);
    notif.set('metadata', { fourEyesRequestId: fourEyesReq.id });
    await notif.save(null, { useMasterKey: true });
  }
}

async function notifyRequesterOfApproval(fourEyesReq, parameterName, newValue) {
  const Notification = Parse.Object.extend('Notification');
  const notif = new Notification();
  notif.set('userId', fourEyesReq.get('requesterId'));
  notif.set('type', 'configuration_change_approved');
  notif.set('category', 'admin');
  notif.set('title', 'Konfigurationsänderung genehmigt');
  notif.set('message', `Ihre Änderung von '${parameterName}' auf ${formatValue(newValue)} wurde genehmigt und angewendet.`);
  notif.set('isRead', false);
  notif.set('channels', ['in_app', 'push']);
  await notif.save(null, { useMasterKey: true });
}

async function notifyRequesterOfRejection(fourEyesReq, parameterName, reason) {
  const Notification = Parse.Object.extend('Notification');
  const notif = new Notification();
  notif.set('userId', fourEyesReq.get('requesterId'));
  notif.set('type', 'configuration_change_rejected');
  notif.set('category', 'admin');
  notif.set('title', 'Konfigurationsänderung abgelehnt');
  notif.set('message', `Ihre Änderung von '${parameterName}' wurde abgelehnt. Grund: ${reason}`);
  notif.set('priority', 'high');
  notif.set('isRead', false);
  notif.set('channels', ['in_app', 'push']);
  await notif.save(null, { useMasterKey: true });
}

module.exports = {
  notifyApproversOfPendingRequest,
  notifyRequesterOfApproval,
  notifyRequesterOfRejection,
};
