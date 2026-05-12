'use strict';

const { logComplianceEvent, createNotification } = require('./userTriggerComplianceNotifications');

async function userAfterSave(request) {
  const user = request.object;
  const isNew = !request.original;
  const platformName = (process.env.FIN1_LEGAL_PLATFORM_NAME || '').trim() || 'Platform';

  if (isNew) {
    const UserProfile = Parse.Object.extend('UserProfile');
    const profile = new UserProfile();
    profile.set('userId', user.id);
    profile.set('preferredLanguage', 'de');
    await profile.save(null, { useMasterKey: true });

    const NotificationPreference = Parse.Object.extend('NotificationPreference');
    const notifPref = new NotificationPreference();
    notifPref.set('userId', user.id);
    notifPref.set('notificationsEnabled', true);
    notifPref.set('inAppEnabled', true);
    notifPref.set('pushEnabled', true);
    notifPref.set('emailEnabled', true);
    await notifPref.save(null, { useMasterKey: true });

    await logComplianceEvent(user.id, 'account_created', 'info',
      'New user account created', { role: user.get('role') });

    await createNotification(user.id, 'system', 'account',
      `Willkommen bei ${platformName}!`,
      'Ihr Konto wurde erfolgreich erstellt. Bitte vervollständigen Sie Ihr Profil.');
  }

  if (request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = user.get('status');

    if (oldStatus !== newStatus) {
      await logComplianceEvent(user.id,
        newStatus === 'suspended' ? 'account_suspended' :
          newStatus === 'active' ? 'account_reactivated' : 'account_closed',
        'medium',
        `Account status changed from ${oldStatus} to ${newStatus}`,
        { oldStatus, newStatus }
      );

      if (newStatus === 'active') {
        await createNotification(user.id, 'system', 'account',
          'Konto aktiviert',
          'Ihr Konto ist jetzt aktiv. Sie können nun alle Funktionen nutzen.');
      } else if (newStatus === 'suspended') {
        await createNotification(user.id, 'system', 'account',
          'Konto gesperrt',
          'Ihr Konto wurde vorübergehend gesperrt. Bitte kontaktieren Sie den Support.',
          'high');
      }
    }

    const oldKyc = request.original.get('kycStatus');
    const newKyc = user.get('kycStatus');

    if (oldKyc !== newKyc) {
      await logComplianceEvent(user.id,
        newKyc === 'verified' ? 'kyc_verified' :
          newKyc === 'rejected' ? 'kyc_rejected' : 'kyc_initiated',
        newKyc === 'verified' ? 'low' : 'medium',
        `KYC status changed from ${oldKyc} to ${newKyc}`,
        { oldKyc, newKyc }
      );

      if (newKyc === 'verified') {
        await createNotification(user.id, 'kyc_approved', 'account',
          'KYC verifiziert',
          'Ihre Identität wurde erfolgreich verifiziert.');
      } else if (newKyc === 'rejected') {
        await createNotification(user.id, 'kyc_rejected', 'account',
          'KYC abgelehnt',
          'Ihre Identitätsprüfung konnte nicht abgeschlossen werden. Bitte prüfen Sie Ihre Dokumente.',
          'high');
      }
    }

    const oldKybStatus = request.original.get('companyKybStatus');
    const newKybStatus = user.get('companyKybStatus');

    if (oldKybStatus !== newKybStatus && newKybStatus) {
      const severityMap = {
        pending_review: 'medium',
        approved: 'low',
        rejected: 'high',
        more_info_requested: 'high',
        draft: 'low',
      };

      const eventMap = {
        approved: 'company_kyb_approved',
        rejected: 'company_kyb_rejected',
        pending_review: 'company_kyb_submitted',
        more_info_requested: 'company_kyb_info_requested',
        draft: 'company_kyb_reset',
      };

      await logComplianceEvent(user.id,
        eventMap[newKybStatus] || 'company_kyb_status_change',
        severityMap[newKybStatus] || 'medium',
        `Company KYB status changed from ${oldKybStatus || 'none'} to ${newKybStatus}`,
        { oldKybStatus, newKybStatus }
      );

      if (newKybStatus === 'approved') {
        await createNotification(user.id, 'kyb_approved', 'account',
          'KYB genehmigt',
          'Die Identitätsprüfung Ihres Unternehmens wurde erfolgreich abgeschlossen. Ihr Firmenkonto ist nun freigeschaltet.');
      } else if (newKybStatus === 'rejected') {
        await createNotification(user.id, 'kyb_rejected', 'account',
          'KYB abgelehnt',
          'Die Identitätsprüfung Ihres Unternehmens konnte nicht abgeschlossen werden. Bitte prüfen Sie die Hinweise und kontaktieren Sie den Support.',
          'high');
      } else if (newKybStatus === 'pending_review') {
        await createNotification(user.id, 'kyb_submitted', 'account',
          'KYB eingereicht',
          'Ihre Unternehmensunterlagen wurden eingereicht und werden nun geprüft. Sie erhalten eine Benachrichtigung, sobald die Prüfung abgeschlossen ist.');
      } else if (newKybStatus === 'more_info_requested') {
        await createNotification(user.id, 'kyb_info_requested', 'account',
          'Zusätzliche Informationen benötigt',
          'Bei der Prüfung Ihrer Unternehmensunterlagen wurden Rückfragen festgestellt. Bitte ergänzen Sie die fehlenden Angaben.',
          'high');
      } else if (newKybStatus === 'draft' && oldKybStatus) {
        await createNotification(user.id, 'kyb_reset', 'account',
          'KYB zur Überarbeitung freigegeben',
          'Ihr Unternehmens-KYB wurde zur Überarbeitung freigegeben. Sie können den Vorgang jetzt erneut starten.');
      }
    }
  }
}

module.exports = {
  userAfterSave,
};
