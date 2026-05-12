'use strict';

const { clearAccountLockoutForUserObjectId } = require('./usersAdminAccountLockout');

async function handleResetDevUserPassword(request) {
  const { email } = request.params;
  const newPassword = 'DevTest123!Secure';

  const query = new Parse.Query(Parse.User);
  query.equalTo('email', email);
  const user = await query.first({ useMasterKey: true });

  if (!user) {
    return { success: false, message: 'User not found' };
  }

  user.set('password', newPassword);
  await user.save(null, { useMasterKey: true });
  await clearAccountLockoutForUserObjectId(user.id);

  return {
    success: true,
    message: `Password reset for ${email}`,
    newPassword: newPassword,
    objectId: user.id
  };
}

module.exports = {
  handleResetDevUserPassword,
};
