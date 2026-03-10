import { useState } from 'react';
import { Button } from '../../../components/ui/Button';
import type { ResponseTemplate, TemplateCategory, CreateTemplateRequest, UpdateTemplateRequest } from '../types';
import { TEMPLATE_CATEGORIES, CSR_ROLES } from '../types';

interface TemplateEditorProps {
  template: ResponseTemplate | null;
  categories: TemplateCategory[];
  onSave: (data: CreateTemplateRequest | UpdateTemplateRequest) => Promise<void>;
  onClose: () => void;
}

export function TemplateEditor({ template, categories, onSave, onClose }: TemplateEditorProps) {
  const isEdit = Boolean(template);

  // Form state
  const [title, setTitle] = useState(template?.title || '');
  const [category, setCategory] = useState(template?.category || 'general');
  const [body, setBody] = useState(template?.body || '');
  const [subject, setSubject] = useState(template?.subject || '');
  const [shortcut, setShortcut] = useState(template?.shortcut || '');
  const [isEmail, setIsEmail] = useState(template?.isEmail || false);
  const [selectedRoles, setSelectedRoles] = useState<string[]>([]);

  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Extract placeholders from body
  const extractedPlaceholders = [...new Set(body.match(/\{\{[A-Z_]+\}\}/g) || [])];

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (!title.trim() || !body.trim()) {
      setError('Titel und Inhalt sind erforderlich');
      return;
    }

    setSaving(true);

    try {
      const data: CreateTemplateRequest | UpdateTemplateRequest = {
        title,
        categoryKey: category,
        body,
        isEmail,
        placeholders: extractedPlaceholders,
        ...(shortcut && { shortcut }),
        ...(isEmail && subject && { subject }),
        ...(selectedRoles.length > 0 && { availableForRoles: selectedRoles }),
      };

      await onSave(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Fehler beim Speichern');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <form onSubmit={handleSubmit}>
          {/* Header */}
          <div className="p-6 border-b border-gray-200">
            <h2 className="text-xl font-bold text-gray-900">
              {isEdit ? 'Template bearbeiten' : 'Neues Template'}
            </h2>
          </div>

          {/* Content */}
          <div className="p-6 space-y-4">
            {error && (
              <div className="bg-red-50 text-red-600 p-3 rounded-lg text-sm">{error}</div>
            )}

            {/* Title */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Titel *</label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="z.B. Begrüßung - Technisches Problem"
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                required
              />
            </div>

            {/* Category & Type */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Kategorie</label>
                <select
                  value={category}
                  onChange={(e) => setCategory(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                >
                  {categories.length > 0
                    ? categories.map((cat) => (
                        <option key={cat.key} value={cat.key}>
                          {cat.icon} {cat.displayName}
                        </option>
                      ))
                    : TEMPLATE_CATEGORIES.map((cat) => (
                        <option key={cat.key} value={cat.key}>
                          {cat.icon} {cat.label}
                        </option>
                      ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Typ</label>
                <div className="flex gap-4 pt-2">
                  <label className="flex items-center">
                    <input
                      type="radio"
                      checked={!isEmail}
                      onChange={() => setIsEmail(false)}
                      className="mr-2"
                    />
                    Chat Snippet
                  </label>
                  <label className="flex items-center">
                    <input
                      type="radio"
                      checked={isEmail}
                      onChange={() => setIsEmail(true)}
                      className="mr-2"
                    />
                    E-Mail
                  </label>
                </div>
              </div>
            </div>

            {/* Subject (for email) */}
            {isEmail && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Betreff</label>
                <input
                  type="text"
                  value={subject}
                  onChange={(e) => setSubject(e.target.value)}
                  placeholder="E-Mail Betreff"
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                />
              </div>
            )}

            {/* Shortcut */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Shortcut (optional)
              </label>
              <div className="flex items-center gap-2">
                <span className="text-gray-400">/</span>
                <input
                  type="text"
                  value={shortcut}
                  onChange={(e) => setShortcut(e.target.value.replace(/[^a-z0-9_]/gi, ''))}
                  placeholder="z.B. begruessung"
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent font-mono"
                />
              </div>
              <p className="text-xs text-gray-500 mt-1">Schnellzugriff mit /shortcut im Chat</p>
            </div>

            {/* Body */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Inhalt *</label>
              <textarea
                value={body}
                onChange={(e) => setBody(e.target.value)}
                placeholder="Guten Tag {{KUNDENNAME}},&#10;&#10;vielen Dank für Ihre Nachricht...&#10;&#10;Mit freundlichen Grüßen,&#10;{{AGENTNAME}}"
                rows={8}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent font-mono text-sm"
                required
              />
              <p className="text-xs text-gray-500 mt-1">
                Platzhalter wie {'{{KUNDENNAME}}'} werden automatisch erkannt
              </p>
            </div>

            {/* Placeholders Preview */}
            {extractedPlaceholders.length > 0 && (
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Erkannte Platzhalter
                </label>
                <div className="flex flex-wrap gap-2">
                  {extractedPlaceholders.map((p) => (
                    <span
                      key={p}
                      className="text-sm bg-blue-50 text-blue-600 px-3 py-1 rounded font-mono"
                    >
                      {p}
                    </span>
                  ))}
                </div>
              </div>
            )}

            {/* Roles */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Verfügbar für Rollen
              </label>
              <div className="flex flex-wrap gap-2">
                {CSR_ROLES.map((role) => (
                  <label
                    key={role.key}
                    className={`flex items-center px-3 py-1 rounded-full text-sm cursor-pointer border transition-colors ${
                      selectedRoles.includes(role.key)
                        ? 'bg-fin1-primary text-white border-fin1-primary'
                        : 'bg-white text-gray-600 border-gray-300 hover:border-fin1-primary'
                    }`}
                  >
                    <input
                      type="checkbox"
                      checked={selectedRoles.includes(role.key)}
                      onChange={(e) =>
                        setSelectedRoles(
                          e.target.checked
                            ? [...selectedRoles, role.key]
                            : selectedRoles.filter((r) => r !== role.key)
                        )
                      }
                      className="sr-only"
                    />
                    {role.label}
                  </label>
                ))}
              </div>
              <p className="text-xs text-gray-500 mt-1">
                Leer = für alle Rollen verfügbar
              </p>
            </div>
          </div>

          {/* Footer */}
          <div className="p-6 border-t border-gray-200 flex justify-end gap-3">
            <Button type="button" variant="secondary" onClick={onClose} disabled={saving}>
              Abbrechen
            </Button>
            <Button type="submit" disabled={saving}>
              {saving ? 'Speichern...' : isEdit ? 'Aktualisieren' : 'Erstellen'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
