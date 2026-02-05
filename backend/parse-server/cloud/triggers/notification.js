// ============================================================================
// Parse Cloud Code
// triggers/notification.js - Notification Triggers
// ============================================================================

'use strict';

Parse.Cloud.beforeSave('Notification', async (request) => {
  const notif = request.object;
  const isNew = !notif.existed();

  if (isNew) {
    notif.set('isRead', false);
    notif.set('isArchived', false);
    notif.set('priority', notif.get('priority') || 'normal');
    notif.set('channels', notif.get('channels') || ['in_app']);
  }

  // Validate category
  const validCategories = ['investment', 'trading', 'document', 'account', 'wallet', 'support', 'system', 'marketing', 'admin'];
  const category = notif.get('category');
  if (category && !validCategories.includes(category)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, `Invalid category: ${category}`);
  }
});

Parse.Cloud.afterSave('Notification', async (request) => {
  const notif = request.object;
  const isNew = !request.original;

  if (isNew) {
    const channels = notif.get('channels') || [];
    const userId = notif.get('userId');

    // Send push notification if enabled
    if (channels.includes('push')) {
      await sendPushNotification(userId, notif);
    }
  }
});

async function sendPushNotification(userId, notif) {
  // Get user's push tokens
  const PushToken = Parse.Object.extend('PushToken');
  const query = new Parse.Query(PushToken);
  query.equalTo('userId', userId);
  query.equalTo('isActive', true);

  const tokens = await query.find({ useMasterKey: true });

  if (tokens.length === 0) return;

  // In production, this would send to APNS/FCM
  // For now, we just log it
  console.log(`Push notification to user ${userId}: ${notif.get('title')}`);
}

// Mark notification as read
Parse.Cloud.define('markNotificationRead', async (request) => {
  const { notificationId } = request.params;
  const user = request.user;

  if (!user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'User must be logged in');
  }

  const Notification = Parse.Object.extend('Notification');
  const notif = await new Parse.Query(Notification).get(notificationId, { useMasterKey: true });

  if (notif.get('userId') !== user.id) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Not your notification');
  }

  notif.set('isRead', true);
  notif.set('readAt', new Date());
  await notif.save(null, { useMasterKey: true });

  return { success: true };
});

// Get unread count
Parse.Cloud.define('getUnreadNotificationCount', async (request) => {
  const user = request.user;

  if (!user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'User must be logged in');
  }

  const query = new Parse.Query('Notification');
  query.equalTo('userId', user.id);
  query.equalTo('isRead', false);
  query.equalTo('isArchived', false);

  const total = await query.count({ useMasterKey: true });

  // Count by category
  const categories = ['investment', 'trading', 'document', 'account', 'wallet', 'support', 'system'];
  const byCategory = {};

  for (const cat of categories) {
    const catQuery = new Parse.Query('Notification');
    catQuery.equalTo('userId', user.id);
    catQuery.equalTo('isRead', false);
    catQuery.equalTo('category', cat);
    byCategory[cat] = await catQuery.count({ useMasterKey: true });
  }

  return { total, byCategory };
});
