import { useState, useEffect } from 'react';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Badge } from '../../components/ui/Badge';
import { TemplateEditor } from './components/TemplateEditor';
import { TemplateList } from './components/TemplateList';
import { EmailTemplateList } from './components/EmailTemplateList';
import { UsageStats } from './components/UsageStats';
import {
  getResponseTemplates,
  getEmailTemplates,
  getTemplateCategories,
  getTemplateUsageStats,
  createResponseTemplate,
  updateResponseTemplate,
  deleteResponseTemplate,
  seedCSRTemplates,
} from './api';
import type {
  ResponseTemplate,
  EmailTemplate,
  TemplateCategory,
  TemplateUsageStats as UsageStatsType,
  CreateTemplateRequest,
  UpdateTemplateRequest,
} from './types';

type TabType = 'response' | 'email' | 'stats';

export function TemplatesPage() {
  // State
  const [activeTab, setActiveTab] = useState<TabType>('response');
  const [templates, setTemplates] = useState<ResponseTemplate[]>([]);
  const [emailTemplates, setEmailTemplates] = useState<EmailTemplate[]>([]);
  const [categories, setCategories] = useState<TemplateCategory[]>([]);
  const [usageStats, setUsageStats] = useState<UsageStatsType | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Editor state
  const [showEditor, setShowEditor] = useState(false);
  const [editingTemplate, setEditingTemplate] = useState<ResponseTemplate | null>(null);

  // Filter state
  const [categoryFilter, setCategoryFilter] = useState<string>('');
  const [searchQuery, setSearchQuery] = useState('');

  // Load data
  useEffect(() => {
    loadData();
  }, []);

  async function loadData() {
    setLoading(true);
    setError(null);

    try {
      // Load templates, emails, and categories (required)
      const [templatesData, emailData, categoriesData] = await Promise.all([
        getResponseTemplates('teamlead', true),
        getEmailTemplates(true),
        getTemplateCategories(),
      ]);

      setTemplates(templatesData);
      setEmailTemplates(emailData);
      setCategories(categoriesData);

      // Load stats optionally (may fail for CSR users without viewAnalytics permission)
      try {
        const statsData = await getTemplateUsageStats(30);
        setUsageStats(statsData);
      } catch (statsError) {
        // Stats are optional - only show error if user tries to view stats tab
        console.warn('Could not load template usage stats:', statsError);
        // Don't set error here - templates are more important
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Fehler beim Laden der Templates');
      console.error('Error loading templates:', err);
    } finally {
      setLoading(false);
    }
  }

  // Filter templates
  const filteredTemplates = templates.filter((t) => {
    if (categoryFilter && t.category !== categoryFilter) return false;
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      return (
        t.title.toLowerCase().includes(query) ||
        t.body.toLowerCase().includes(query) ||
        (t.shortcut?.toLowerCase().includes(query) ?? false)
      );
    }
    return true;
  });

  // Handlers
  async function handleCreate(data: CreateTemplateRequest) {
    try {
      const newTemplate = await createResponseTemplate(data);
      setTemplates((prev) => [...prev, newTemplate]);
      setShowEditor(false);
      setEditingTemplate(null);
    } catch (err) {
      throw err;
    }
  }

  async function handleUpdate(templateId: string, data: UpdateTemplateRequest) {
    try {
      const updated = await updateResponseTemplate(templateId, data);
      setTemplates((prev) => prev.map((t) => (t.id === templateId ? updated : t)));
      setShowEditor(false);
      setEditingTemplate(null);
    } catch (err) {
      throw err;
    }
  }

  async function handleDelete(templateId: string) {
    if (!confirm('Template wirklich löschen?')) return;

    try {
      await deleteResponseTemplate(templateId);
      setTemplates((prev) => prev.filter((t) => t.id !== templateId));
    } catch (err) {
      console.error('Error deleting template:', err);
      alert('Fehler beim Löschen des Templates');
    }
  }

  function handleEdit(template: ResponseTemplate) {
    setEditingTemplate(template);
    setShowEditor(true);
  }

  // Seed templates
  async function handleSeedTemplates() {
    if (!confirm('Standard-Templates importieren? Dies ist nur einmalig möglich.')) return;

    try {
      const result = await seedCSRTemplates();
      alert(`Seed erfolgreich!\n\nKategorien: ${result.categories?.created || 0}\nTextbausteine: ${result.responseTemplates?.created || 0}\nE-Mail Vorlagen: ${result.emailTemplates?.created || 0}`);
      loadData();
    } catch (err) {
      alert('Fehler beim Seeden: ' + (err instanceof Error ? err.message : 'Unbekannter Fehler'));
    }
  }

  // Render
  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin w-8 h-8 border-4 border-fin1-primary border-t-transparent rounded-full"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">CSR Templates</h1>
          <p className="text-gray-500">Textbausteine und E-Mail-Vorlagen verwalten</p>
        </div>
        <div className="flex gap-2">
          {templates.length === 0 && emailTemplates.length === 0 && (
            <Button variant="secondary" onClick={handleSeedTemplates}>
              📥 Standard-Templates laden
            </Button>
          )}
          {activeTab === 'response' && (
            <Button onClick={() => setShowEditor(true)}>+ Neues Template</Button>
          )}
        </div>
      </div>

      {/* Error */}
      {error && (
        <div className="bg-red-50 text-red-600 p-4 rounded-lg">
          {error}
          <button className="ml-4 underline" onClick={loadData}>
            Erneut versuchen
          </button>
        </div>
      )}

      {/* Tabs */}
      <div className="border-b border-gray-200">
        <nav className="flex space-x-8">
          <button
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'response'
                ? 'border-fin1-primary text-fin1-primary'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
            onClick={() => setActiveTab('response')}
          >
            Textbausteine
            <Badge variant="neutral" className="ml-2">
              {templates.length}
            </Badge>
          </button>
          <button
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'email'
                ? 'border-fin1-primary text-fin1-primary'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
            onClick={() => setActiveTab('email')}
          >
            E-Mail Vorlagen
            <Badge variant="neutral" className="ml-2">
              {emailTemplates.length}
            </Badge>
          </button>
          <button
            className={`py-4 px-1 border-b-2 font-medium text-sm ${
              activeTab === 'stats'
                ? 'border-fin1-primary text-fin1-primary'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
            onClick={() => setActiveTab('stats')}
          >
            Statistiken
          </button>
        </nav>
      </div>

      {/* Tab Content */}
      {activeTab === 'response' && (
        <div className="space-y-4">
          {/* Filters */}
          <Card className="p-4">
            <div className="flex gap-4 flex-wrap">
              <div className="flex-1 min-w-[200px]">
                <input
                  type="text"
                  placeholder="Suchen..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                />
              </div>
              <select
                value={categoryFilter}
                onChange={(e) => setCategoryFilter(e.target.value)}
                className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
              >
                <option value="">Alle Kategorien</option>
                {categories.map((cat) => (
                  <option key={cat.key} value={cat.key}>
                    {cat.displayName}
                  </option>
                ))}
              </select>
            </div>
          </Card>

          {/* Template List */}
          <TemplateList
            templates={filteredTemplates}
            categories={categories}
            onEdit={handleEdit}
            onDelete={handleDelete}
          />
        </div>
      )}

      {activeTab === 'email' && (
        <EmailTemplateList templates={emailTemplates} onRefresh={loadData} />
      )}

      {activeTab === 'stats' && (
        usageStats ? (
          <UsageStats stats={usageStats} />
        ) : (
          <Card>
            <div className="text-center py-8">
              <p className="text-gray-500">Statistiken nicht verfügbar</p>
              <p className="text-sm text-gray-400 mt-2">
                Sie haben keine Berechtigung, Statistiken anzuzeigen, oder es sind noch keine Daten vorhanden.
              </p>
            </div>
          </Card>
        )
      )}

      {/* Editor Modal */}
      {showEditor && (
        <TemplateEditor
          template={editingTemplate}
          categories={categories}
          onSave={async (data) => {
            if (editingTemplate) {
              await handleUpdate(editingTemplate.id, data as UpdateTemplateRequest);
            } else {
              await handleCreate(data as CreateTemplateRequest);
            }
          }}
          onClose={() => {
            setShowEditor(false);
            setEditingTemplate(null);
          }}
        />
      )}
    </div>
  );
}
