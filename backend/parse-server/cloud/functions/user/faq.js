'use strict';

// Role-based FAQ filtering: targetRoles on FAQ/FAQCategory.
// ["all"] or absent → everyone; ["trader"] / ["investor"] → role-specific.
function matchesRole(targetRoles, userRole) {
  if (!targetRoles || targetRoles.length === 0 || targetRoles.includes('all')) {
    return true;
  }
  if (!userRole) return true;
  return targetRoles.includes(userRole);
}

Parse.Cloud.define('getFAQs', async (request) => {
  const { categorySlug, isPublic, userRole, location, context } = request.params;

  const query = new Parse.Query('FAQ');

  if (context === 'admin' && request.user) {
    const adminRoleQuery = new Parse.Query(Parse.Role);
    adminRoleQuery.equalTo('name', 'admin');
    adminRoleQuery.equalTo('users', request.user);
    const isAdmin = await adminRoleQuery.first({ useMasterKey: true });
    if (isAdmin) {
      // No visibility or publish filters for admin
    } else {
      query.equalTo('isPublished', true);
      query.equalTo('isArchived', false);
    }
  } else {
    query.equalTo('isPublished', true);
    query.equalTo('isArchived', false);

    if (location === 'help_center') {
      query.equalTo('isUserVisible', true);
    } else if (isPublic) {
      query.equalTo('isPublic', true);
    } else if (request.user) {
      query.equalTo('isUserVisible', true);
    } else {
      query.equalTo('isPublic', true);
    }
  }

  if (categorySlug) {
    const catQuery = new Parse.Query('FAQCategory');
    catQuery.equalTo('slug', categorySlug);
    const category = await catQuery.first({ useMasterKey: true });
    if (category) {
      query.equalTo('categoryId', category.id);
    }
  }

  query.ascending('sortOrder');
  query.limit(500);
  let faqs = await query.find({ useMasterKey: true });

  if (userRole) {
    faqs = faqs.filter(f => matchesRole(f.get('targetRoles'), userRole));
  }

  return { faqs: faqs.map(f => f.toJSON()) };
});

Parse.Cloud.define('getFAQCategories', async (request) => {
  const { location, userRole } = request.params;

  const query = new Parse.Query('FAQCategory');
  query.equalTo('isActive', true);

  if (location === 'landing') {
    query.equalTo('showOnLanding', true);
  } else if (location === 'help_center') {
    query.equalTo('showInHelpCenter', true);
  } else if (location === 'csr') {
    query.equalTo('showInCSR', true);
  }

  query.ascending('sortOrder');
  let categories = await query.find({ useMasterKey: true });

  if (userRole) {
    categories = categories.filter(c => matchesRole(c.get('targetRoles'), userRole));
  }

  return { categories: categories.map(c => c.toJSON()) };
});
