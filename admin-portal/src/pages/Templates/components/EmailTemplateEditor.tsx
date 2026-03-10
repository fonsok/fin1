import { useState } from 'react';
import { Button } from '../../../components/ui/Button';
import { updateEmailTemplate, renderEmailTemplate } from '../api';
import type { EmailTemplate } from '../types';

interface EmailTemplateEditorProps {
  template: EmailTemplate;
  onSave: () => void;
  onClose: () => void;
}

export function EmailTemplateEditor({ template, onSave, onClose }: EmailTemplateEditorProps) {
  const [subject, setSubject] = useState(template.subject);
  const [body, setBody] = useState(template.bodyTemplate);
  const [isActive, setIsActive] = useState(template.isActive);

  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Preview state
  const [showPreview, setShowPreview] = useState(false);
  const [previewValues, setPreviewValues] = useState<Record<string, string>>({});
  const [preview, setPreview] = useState<{ subject: string; body: string } | null>(null);
  const [loadingPreview, setLoadingPreview] = useState(false);

  async function handleSave() {
    setError(null);
    setSaving(true);

    try {
      await updateEmailTemplate(template.id, {
        subject,
        bodyTemplate: body,
        isActive,
      });
      onSave();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Fehler beim Speichern');
    } finally {
      setSaving(false);
    }
  }

  async function handlePreview() {
    setLoadingPreview(true);
    try {
      const result = await renderEmailTemplate(template.type, previewValues);
      setPreview(result);
    } catch (err) {
      console.error('Preview error:', err);
    } finally {
      setLoadingPreview(false);
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl shadow-xl max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col">
        {/* Header */}
        <div className="p-6 border-b border-gray-200 flex-shrink-0">
          <div className="flex items-center gap-3">
            <span className="text-3xl">{template.icon || '✉️'}</span>
            <div>
              <h2 className="text-xl font-bold text-gray-900">{template.displayName}</h2>
              <span className="text-sm text-gray-500 font-mono">{template.type}</span>
            </div>
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6">
          {error && (
            <div className="bg-red-50 text-red-600 p-3 rounded-lg text-sm mb-4">{error}</div>
          )}

          <div className="grid grid-cols-2 gap-6">
            {/* Editor */}
            <div className="space-y-4">
              <h3 className="font-medium text-gray-900">Vorlage bearbeiten</h3>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Status</label>
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={isActive}
                    onChange={(e) => setIsActive(e.target.checked)}
                    className="rounded border-gray-300"
                  />
                  <span className="text-sm">Aktiv</span>
                </label>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Betreff</label>
                <input
                  type="text"
                  value={subject}
                  onChange={(e) => setSubject(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Inhalt</label>
                <textarea
                  value={body}
                  onChange={(e) => setBody(e.target.value)}
                  rows={12}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent font-mono text-sm"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Platzhalter</label>
                <div className="flex flex-wrap gap-1">
                  {template.availablePlaceholders.map((p) => (
                    <span
                      key={p}
                      className="text-xs bg-blue-50 text-blue-600 px-2 py-1 rounded font-mono cursor-pointer hover:bg-blue-100"
                      onClick={() => setBody((b) => b + p)}
                    >
                      {p}
                    </span>
                  ))}
                </div>
              </div>
            </div>

            {/* Preview */}
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <h3 className="font-medium text-gray-900">Vorschau</h3>
                <Button variant="secondary" size="sm" onClick={() => setShowPreview(!showPreview)}>
                  {showPreview ? 'Ausblenden' : 'Anzeigen'}
                </Button>
              </div>

              {showPreview && (
                <>
                  {/* Preview Values */}
                  <div className="bg-gray-50 p-4 rounded-lg space-y-2">
                    <div className="text-sm font-medium text-gray-700 mb-2">Testwerte:</div>
                    {template.availablePlaceholders.map((p) => {
                      const key = p.replace(/\{\{|\}\}/g, '');
                      return (
                        <div key={p} className="flex items-center gap-2">
                          <span className="text-xs text-gray-500 font-mono w-32 truncate">
                            {p}
                          </span>
                          <input
                            type="text"
                            value={previewValues[key] || ''}
                            onChange={(e) =>
                              setPreviewValues((prev) => ({ ...prev, [key]: e.target.value }))
                            }
                            placeholder={`Wert für ${key}`}
                            className="flex-1 px-2 py-1 text-sm border border-gray-300 rounded"
                          />
                        </div>
                      );
                    })}
                    <Button size="sm" onClick={handlePreview} disabled={loadingPreview}>
                      {loadingPreview ? 'Laden...' : 'Vorschau generieren'}
                    </Button>
                  </div>

                  {/* Rendered Preview */}
                  {preview && (
                    <div className="border border-gray-200 rounded-lg overflow-hidden">
                      <div className="bg-gray-100 px-4 py-2 border-b border-gray-200">
                        <div className="text-sm">
                          <span className="font-medium">Betreff:</span> {preview.subject}
                        </div>
                      </div>
                      <div className="p-4 bg-white">
                        <pre className="text-sm whitespace-pre-wrap font-sans">{preview.body}</pre>
                      </div>
                    </div>
                  )}
                </>
              )}
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-6 border-t border-gray-200 flex justify-end gap-3 flex-shrink-0">
          <Button variant="secondary" onClick={onClose} disabled={saving}>
            Abbrechen
          </Button>
          <Button onClick={handleSave} disabled={saving}>
            {saving ? 'Speichern...' : 'Speichern'}
          </Button>
        </div>
      </div>
    </div>
  );
}
