// FIN1 Admin Portal - API Client

const API = {
    // Always use same origin as this page (e.g. https://localhost/parse via Nginx).
    // Avoids mixed-content blocks when the admin HTML is served over HTTPS but Parse was hardcoded to http://localhost:1338.
    // Fallback: direct Parse port for local file:// or unusual hosts.
    baseURL: (() => {
        const { protocol, hostname } = window.location;
        if (protocol === 'file:' || !hostname) {
            return 'http://localhost:1338/parse';
        }
        return `${window.location.origin}/parse`;
    })(),
    applicationId: 'fin1-app-id',
    sessionToken: null,

    isLoginPage() {
        return /login\.html$/i.test(window.location.pathname || '');
    },

    // Initialize
    init() {
        this.sessionToken = localStorage.getItem('sessionToken');
        this.applyStoredUserLabel();
        this.updateConnectionStatus();
    },

    applyStoredUserLabel() {
        const userEl = document.getElementById('current-user');
        const name = localStorage.getItem('adminUsername');
        if (userEl && name) {
            userEl.textContent = name;
        }
    },

    async login(username, password) {
        const response = await fetch(`${this.baseURL}/login`, {
            method: 'POST',
            headers: {
                'X-Parse-Application-Id': this.applicationId,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ username, password })
        });
        let data;
        try {
            data = await response.json();
        } catch {
            throw new Error('Ungültige Antwort vom Server');
        }
        if (!response.ok) {
            throw new Error(data.error || 'Anmeldung fehlgeschlagen');
        }
        this.sessionToken = data.sessionToken;
        localStorage.setItem('sessionToken', data.sessionToken);
        const label = data.username || data.email || username;
        localStorage.setItem('adminUsername', label);
        return data;
    },

    // Headers for requests
    getHeaders() {
        const headers = {
            'X-Parse-Application-Id': this.applicationId,
            'Content-Type': 'application/json'
        };
        if (this.sessionToken) {
            headers['X-Parse-Session-Token'] = this.sessionToken;
        }
        return headers;
    },

    // Call Cloud Function
    async callFunction(functionName, params = {}) {
        const response = await fetch(`${this.baseURL}/functions/${functionName}`, {
            method: 'POST',
            headers: this.getHeaders(),
            body: JSON.stringify(params)
        });

        if (!response.ok) {
            let message = 'API request failed';
            try {
                const err = await response.json();
                message = err.error || message;
            } catch {
                /* ignore */
            }
            throw new Error(message);
        }

        const data = await response.json();
        return data.result;
    },

    // Health Check
    async checkHealth() {
        try {
            const response = await fetch(this.baseURL.replace('/parse', '/health'));
            return response.ok;
        } catch {
            return false;
        }
    },

    // Update connection status
    async updateConnectionStatus() {
        const statusEl = document.getElementById('connection-status');
        if (!statusEl) return;

        const isConnected = await this.checkHealth();
        statusEl.textContent = isConnected ? 'Verbunden' : 'Nicht verbunden';
        statusEl.className = 'status-badge ' + (isConnected ? 'connected' : 'disconnected');
    },

    // Templates API
    templates: {
        async getAll(role = 'teamlead') {
            return API.callFunction('getResponseTemplates', { role, includeInactive: true });
        },

        async get(templateId) {
            return API.callFunction('getResponseTemplate', { templateId });
        },

        async create(templateData) {
            return API.callFunction('createResponseTemplate', templateData);
        },

        async update(templateId, updates) {
            return API.callFunction('updateResponseTemplate', { templateId, ...updates });
        },

        async delete(templateId) {
            return API.callFunction('deleteResponseTemplate', { templateId });
        },

        async getCategories() {
            return API.callFunction('getTemplateCategories', {});
        },

        async getUsageStats() {
            return API.callFunction('getTemplateUsageStats', { days: 30 });
        }
    },

    // Email Templates API
    emailTemplates: {
        async getAll() {
            return API.callFunction('getEmailTemplates', { includeInactive: true });
        },

        async get(type) {
            return API.callFunction('getEmailTemplate', { type });
        },

        async update(templateId, updates) {
            return API.callFunction('updateEmailTemplate', { templateId, ...updates });
        },

        async render(type, values) {
            return API.callFunction('renderEmailTemplate', { type, values });
        }
    }
};

// Toast Notifications
const Toast = {
    container: null,

    init() {
        this.container = document.createElement('div');
        this.container.className = 'toast-container';
        document.body.appendChild(this.container);
    },

    show(message, type = 'success') {
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.innerHTML = `
            <span class="icon">${type === 'success' ? '✓' : '✕'}</span>
            <span>${message}</span>
        `;
        this.container.appendChild(toast);

        setTimeout(() => {
            toast.style.opacity = '0';
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    },

    success(message) {
        this.show(message, 'success');
    },

    error(message) {
        this.show(message, 'error');
    }
};

// Modal
const Modal = {
    show(id) {
        const modal = document.getElementById(id);
        if (modal) modal.classList.add('active');
    },

    hide(id) {
        const modal = document.getElementById(id);
        if (modal) modal.classList.remove('active');
    },

    hideAll() {
        document.querySelectorAll('.modal-overlay').forEach(m => m.classList.remove('active'));
    }
};

// Initialize on load
document.addEventListener('DOMContentLoaded', () => {
    API.init();
    if (!API.isLoginPage() && !localStorage.getItem('sessionToken')) {
        const returnTo = encodeURIComponent(window.location.pathname + window.location.search);
        window.location.replace(`login.html?return=${returnTo}`);
        return;
    }
    if (!API.isLoginPage()) {
        Toast.init();
    }
});

// Logout function
function logout() {
    localStorage.removeItem('sessionToken');
    localStorage.removeItem('adminUsername');
    window.location.href = 'login.html';
}
