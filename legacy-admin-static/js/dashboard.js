// FIN1 Admin Portal - Dashboard

document.addEventListener('DOMContentLoaded', async () => {
    await loadDashboardStats();
    await loadRecentActivity();
});

async function loadDashboardStats() {
    try {
        // Load templates count
        const templates = await API.templates.getAll();
        document.getElementById('template-count').textContent = templates.length;

        // Load email templates count
        const emailTemplates = await API.emailTemplates.getAll();
        document.getElementById('email-template-count').textContent = emailTemplates.length;

        // Load categories count
        const categories = await API.templates.getCategories();
        document.getElementById('category-count').textContent = categories.length;

        // Load usage stats
        try {
            const stats = await API.templates.getUsageStats();
            document.getElementById('usage-count').textContent = stats.totalUsage || 0;
        } catch {
            document.getElementById('usage-count').textContent = '0';
        }
    } catch (error) {
        console.error('Error loading dashboard stats:', error);
        Toast.error('Fehler beim Laden der Statistiken');
    }
}

async function loadRecentActivity() {
    const container = document.getElementById('recent-activity');

    try {
        const stats = await API.templates.getUsageStats();

        if (stats.topTemplates && stats.topTemplates.length > 0) {
            container.innerHTML = `
                <h4 class="mb-2">Top verwendete Templates</h4>
                <table>
                    <thead>
                        <tr>
                            <th>Template</th>
                            <th>Kategorie</th>
                            <th>Nutzungen</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${stats.topTemplates.map(t => `
                            <tr>
                                <td>${t.title}</td>
                                <td><span class="tag">${t.category || '-'}</span></td>
                                <td>${t.usageCount}</td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            `;
        } else {
            container.innerHTML = '<p class="text-muted">Noch keine Nutzungsdaten verfügbar.</p>';
        }
    } catch (error) {
        container.innerHTML = '<p class="text-muted">Nutzungsdaten nicht verfügbar.</p>';
    }
}
