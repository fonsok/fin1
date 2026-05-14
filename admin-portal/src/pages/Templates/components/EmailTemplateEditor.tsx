import { useState } from 'react';
import clsx from 'clsx';
import { Button } from '../../../components/ui/Button';
import { Card } from '../../../components/ui/Card';
import { useTheme } from '../../../context/ThemeContext';
import { updateEmailTemplate, renderEmailTemplate } from '../api';
import type { EmailTemplate } from '../types';

import { adminLabel, adminMuted, adminPrimary, adminStrong } from '../../../utils/adminThemeClasses';
interface EmailTemplateEditorProps {
  template: EmailTemplate;
  onSave: () => void;
  onClose: () => void;
}

export function EmailTemplateEditor({ template, onSave, onClose }: EmailTemplateEditorProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const fieldClass = clsx(
    'w-full px-4 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary focus:border-fin1-primary',
    isDark
      ? 'bg-slate-900/90 border border-slate-600 text-slate-100 placeholder:text-slate-500'
      : 'border border-gray-300 text-gray-900 bg-white',
  );

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
      <Card className="max-w-4xl w-full max-h-[90vh] overflow-hidden flex flex-col shadow-xl" padding="none">
        {/* Header */}
        <div className={clsx('p-6 border-b flex-shrink-0', isDark ? 'border-slate-600' : 'border-gray-200')}>
          <div className="flex items-center gap-3">
            <span className="text-3xl">{template.icon || '✉️'}</span>
            <div>
              <h2 className={clsx('text-xl font-bold', adminPrimary(isDark))}>
                {template.displayName}
              </h2>
              <span className={clsx('text-sm font-mono', adminMuted(isDark))}>
                {template.type}
              </span>
            </div>
          </div>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-6">
          {error && (
            <div
              className={clsx(
                'p-3 rounded-lg text-sm mb-4 border',
                isDark
                  ? 'bg-red-950/50 border-red-800/80 text-red-200'
                  : 'bg-red-50 border-transparent text-red-600',
              )}
            >
              {error}
            </div>
          )}

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Editor */}
            <div className="space-y-4">
              <h3 className={clsx('font-medium', adminPrimary(isDark))}>
                Vorlage bearbeiten
              </h3>

              <div>
                <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>
                  Status
                </label>
                <label className={clsx('flex items-center gap-2 cursor-pointer text-sm', isDark ? 'text-slate-200' : 'text-gray-900')}>
                  <input
                    type="checkbox"
                    checked={isActive}
                    onChange={(e) => setIsActive(e.target.checked)}
                    className={clsx('rounded accent-fin1-primary', isDark ? 'border-slate-600' : 'border-gray-300')}
                  />
                  Aktiv
                </label>
              </div>

              <div>
                <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>
                  Betreff
                </label>
                <input
                  type="text"
                  value={subject}
                  onChange={(e) => setSubject(e.target.value)}
                  className={fieldClass}
                />
              </div>

              <div>
                <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>
                  Inhalt
                </label>
                <textarea
                  value={body}
                  onChange={(e) => setBody(e.target.value)}
                  rows={12}
                  className={clsx(fieldClass, 'font-mono text-sm')}
                />
              </div>

              <div>
                <label className={clsx('block text-sm font-medium mb-1', adminLabel(isDark))}>
                  Platzhalter
                </label>
                <div className="flex flex-wrap gap-1">
                  {template.availablePlaceholders.map((p) => (
                    <span
                      key={p}
                      className={clsx(
                        'text-xs px-2 py-1 rounded font-mono cursor-pointer border',
                        isDark
                          ? 'bg-blue-950/50 text-blue-200 border-blue-800/80 hover:bg-blue-950/80'
                          : 'bg-blue-50 text-blue-600 border-transparent hover:bg-blue-100',
                      )}
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
                <h3 className={clsx('font-medium', adminPrimary(isDark))}>
                  Vorschau
                </h3>
                <Button variant="secondary" size="sm" onClick={() => setShowPreview(!showPreview)}>
                  {showPreview ? 'Ausblenden' : 'Anzeigen'}
                </Button>
              </div>

              {showPreview && (
                <>
                  {/* Preview Values */}
                  <div
                    className={clsx(
                      'p-4 rounded-lg space-y-2 border',
                      isDark ? 'bg-slate-900/50 border-slate-600' : 'bg-gray-50 border-transparent',
                    )}
                  >
                    <div className={clsx('text-sm font-medium mb-2', adminStrong(isDark))}>
                      Testwerte:
                    </div>
                    {template.availablePlaceholders.map((p) => {
                      const key = p.replace(/\{\{|\}\}/g, '');
                      return (
                        <div key={p} className="flex items-center gap-2">
                          <span className={clsx('text-xs font-mono w-32 truncate', adminMuted(isDark))}>
                            {p}
                          </span>
                          <input
                            type="text"
                            value={previewValues[key] || ''}
                            onChange={(e) =>
                              setPreviewValues((prev) => ({ ...prev, [key]: e.target.value }))
                            }
                            placeholder={`Wert für ${key}`}
                            className={clsx(fieldClass, 'flex-1 py-1 text-sm')}
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
                    <div
                      className={clsx(
                        'rounded-lg overflow-hidden border',
                        isDark ? 'border-slate-600' : 'border-gray-200',
                      )}
                    >
                      <div
                        className={clsx(
                          'px-4 py-2 border-b text-sm',
                          isDark
                            ? 'bg-slate-800 border-slate-600 text-slate-200'
                            : 'bg-gray-100 border-gray-200 text-gray-900',
                        )}
                      >
                        <span className="font-medium">Betreff:</span> {preview.subject}
                      </div>
                      <div className={clsx('p-4', isDark ? 'bg-slate-950/80 text-slate-100' : 'bg-white text-gray-900')}>
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
        <div className={clsx('p-6 border-t flex justify-end gap-3 flex-shrink-0', isDark ? 'border-slate-600' : 'border-gray-200')}>
          <Button variant="secondary" onClick={onClose} disabled={saving}>
            Abbrechen
          </Button>
          <Button onClick={handleSave} disabled={saving}>
            {saving ? 'Speichern...' : 'Speichern'}
          </Button>
        </div>
      </Card>
    </div>
  );
}
