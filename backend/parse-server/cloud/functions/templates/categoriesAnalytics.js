'use strict';

const { requirePermission, requireAdminRole } = require('../../utils/permissions');

function registerCategoriesAndAnalyticsFunctions() {
  Parse.Cloud.define('getTemplateCategories', async (request) => {
    requireAdminRole(request);

    const { language = 'de' } = request.params;

    const Category = Parse.Object.extend('CSRTemplateCategory');
    const query = new Parse.Query(Category);
    query.equalTo('isActive', true);
    query.ascending('sortOrder');

    const categories = await query.find({ useMasterKey: true });

    return categories.map(c => {
      const data = c.toJSON();

      return {
        id: data.objectId,
        key: data.key,
        displayName: language === 'de'
          ? (data.displayNameDe || data.displayName)
          : data.displayName,
        icon: data.icon,
        sortOrder: data.sortOrder
      };
    });
  });

  Parse.Cloud.define('getTemplateUsageStats', async (request) => {
    requireAdminRole(request);
    requirePermission(request, 'viewAnalytics');

    const params = request.params || {};
    const now = new Date();
    const maxSpanMs = 366 * 24 * 60 * 60 * 1000;

    let rangeStart;
    let rangeEnd;
    let periodDays;

    if (params.startDate && params.endDate) {
      rangeStart = new Date(params.startDate);
      rangeEnd = new Date(params.endDate);
      if (Number.isNaN(rangeStart.getTime()) || Number.isNaN(rangeEnd.getTime())) {
        throw new Parse.Error(Parse.Error.INVALID_QUERY, 'Ungültiges startDate oder endDate');
      }
      if (rangeStart > rangeEnd) {
        throw new Parse.Error(Parse.Error.INVALID_QUERY, 'startDate muss vor oder gleich endDate sein');
      }
      if (rangeEnd.getTime() - rangeStart.getTime() > maxSpanMs) {
        throw new Parse.Error(Parse.Error.INVALID_QUERY, 'Zeitraum darf höchstens 366 Tage betragen');
      }
      if (rangeEnd > now) {
        rangeEnd = now;
      }
      periodDays = Math.max(1, Math.ceil((rangeEnd.getTime() - rangeStart.getTime()) / (24 * 60 * 60 * 1000)));
    } else {
      let days = parseInt(params.days, 10);
      if (Number.isNaN(days) || days < 1) days = 30;
      if (days > 366) days = 366;
      rangeEnd = now;
      rangeStart = new Date(now);
      rangeStart.setDate(rangeStart.getDate() - days);
      periodDays = days;
    }

    const UsageStat = Parse.Object.extend('CSRTemplateUsageStat');
    const PAGE = 1000;
    const MAX_STATS = 25000;
    const stats = [];
    let skip = 0;
    while (skip < MAX_STATS) {
      const statQuery = new Parse.Query(UsageStat);
      statQuery.greaterThanOrEqualTo('usedAt', rangeStart);
      statQuery.lessThanOrEqualTo('usedAt', rangeEnd);
      statQuery.ascending('usedAt');
      statQuery.limit(PAGE);
      statQuery.skip(skip);
      const page = await statQuery.find({ useMasterKey: true });
      if (!page.length) break;
      stats.push(...page);
      if (page.length < PAGE) break;
      skip += PAGE;
    }

    const agentUsage = {};
    const templateUsageInRange = {};
    stats.forEach(s => {
      const agentId = s.get('agentId');
      if (agentId) {
        if (!agentUsage[agentId]) agentUsage[agentId] = 0;
        agentUsage[agentId]++;
      }
      const templateId = s.get('templateId');
      if (templateId) {
        templateUsageInRange[templateId] = (templateUsageInRange[templateId] || 0) + 1;
      }
    });

    const topEntries = Object.entries(templateUsageInRange)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 20);

    const Template = Parse.Object.extend('CSRResponseTemplate');
    let topTemplates = [];
    if (topEntries.length > 0) {
      const ids = topEntries.map(([id]) => id);
      const tq = new Parse.Query(Template);
      tq.containedIn('objectId', ids);
      tq.limit(ids.length);
      const templateRows = await tq.find({ useMasterKey: true });
      const byId = {};
      templateRows.forEach(t => {
        byId[t.id] = t;
      });
      topTemplates = topEntries.map(([templateId, usageCount]) => {
        const t = byId[templateId];
        return {
          id: templateId,
          title: t ? (t.get('titleDe') || t.get('title')) : templateId,
          category: t ? t.get('categoryKey') : '-',
          usageCount
        };
      });
    }

    return {
      period: {
        start: rangeStart.toISOString(),
        end: rangeEnd.toISOString(),
        days: periodDays
      },
      totalUsage: stats.length,
      topTemplates,
      agentUsage: Object.entries(agentUsage).map(([agentId, count]) => ({
        agentId,
        usageCount: count
      })).sort((a, b) => b.usageCount - a.usageCount)
    };
  });
}

module.exports = { registerCategoriesAndAnalyticsFunctions };
