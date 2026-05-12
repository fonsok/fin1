'use strict';

async function handleCreateTestUsers(request) {
  console.log('📊 Redirecting to seedTestUsers for full user provisioning...');
  return await Parse.Cloud.run('seedTestUsers', {}, { sessionToken: request.user?.getSessionToken?.() || undefined });
}

module.exports = {
  handleCreateTestUsers,
};
