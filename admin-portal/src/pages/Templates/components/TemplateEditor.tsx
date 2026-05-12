import { useState } from 'react';
import clsx from 'clsx';
import { Button } from '../../../components/ui/Button';
import { Card } from '../../../components/ui/Card';
import { useTheme } from '../../../context/ThemeContext';
import type { ResponseTemplate, TemplateCategory, CreateTemplateRequest, UpdateTemplateRequest } from '../types';
import { TEMPLATE_CATEGORIES, CSR_ROLES } from '../types';

interface TemplateEditorProps {
  template: ResponseTemplate | null;
  categories: TemplateCategory[];
  onSave: (data: CreateTemplateRequest | UpdateTemplateRequest) => Promise<void>;
  onClose: () => void;
}

export function TemplateEditor({ template, categories, onSave, onClose }: TemplateEditorProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';
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

  const fieldClass = clsx(
    'w-full px-4 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-fin1-primary focus:border-fin1-primary',
    isDark
      ? 'bg-slate-900/90 border border-slate-600 text-slate-100 placeholder:text-slate-500'
      : 'border border-gray-300 text-gray-900 bg-white placeholder:text-gray-400',
  );

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <Card className="max-w-2xl w-full max-h-[90vh] overflow-y-auto shadow-xl" padding="none">
        <form onSubmit={handleSubmit}>
          {/* Header */}
          <div className={clsx('p-6 border-b', isDark ? 'border-slate-600' : 'border-gray-200')}>
            <h2 className={clsx('text-xl font-bold', isDark ? 'text-slate-100' : 'text-gray-900')}>
              {isEdit ? 'Template bearbeiten' : 'Neues Template'}
            </h2>
          </div>

          {/* Content */}
          <div className="p-6 space-y-4">
            {error && (
              <div
                className={clsx(
                  'p-3 rounded-lg text-sm border',
                  isDark
                    ? 'bg-red-950/50 border-red-800/80 text-red-200'
                    : 'bg-red-50 border-transparent text-red-600',
                )}
              >
                {error}
              </div>
            )}

            {/* Title */}
            <div>
              <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
                Titel *
              </label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="z.B. Begrüßung - Technisches Problem"
                className={fieldClass}
                required
              />
            </div>

            {/* Category & Type */}
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
                  Kategorie
                </label>
                <select
                  value={category}
                  onChange={(e) => setCategory(e.target.value)}
                  className={fieldClass}
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
                <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
                  Typ
                </label>
                <div className="flex gap-4 pt-2">
                  <label className={clsx('flex items-center cursor-pointer', isDark ? 'text-slate-200' : 'text-gray-900')}>
                    <input
                      type="radio"
                      checked={!isEmail}
                      onChange={() => setIsEmail(false)}
                      className="mr-2 accent-fin1-primary"
                    />
                    Chat Snippet
                  </label>
                  <label className={clsx('flex items-center cursor-pointer', isDark ? 'text-slate-200' : 'text-gray-900')}>
                    <input
                      type="radio"
                      checked={isEmail}
                      onChange={() => setIsEmail(true)}
                      className="mr-2 accent-fin1-primary"
                    />
                    E-Mail
                  </label>
                </div>
              </div>
            </div>

            {/* Subject (for email) */}
            {isEmail && (
              <div>
                <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
                  Betreff
                </label>
                <input
                  type="text"
                  value={subject}
                  onChange={(e) => setSubject(e.target.value)}
                  placeholder="E-Mail Betreff"
                  className={fieldClass}
                />
              </div>
            )}

            {/* Shortcut */}
            <div>
              <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
                Shortcut (optional)
              </label>
              <div className="flex items-center gap-2">
                <span className={isDark ? 'text-slate-500' : 'text-gray-400'}>/</span>
                <input
                  type="text"
                  value={shortcut}
                  onChange={(e) => setShortcut(e.target.value.replace(/[^a-z0-9_]/gi, ''))}
                  placeholder="z.B. begruessung"
                  className={clsx(fieldClass, 'flex-1 font-mono')}
                />
              </div>
              <p className={clsx('text-xs mt-1', isDark ? 'text-slate-400' : 'text-gray-500')}>
                Schnellzugriff mit /shortcut im Chat
              </p>
            </div>

            {/* Body */}
            <div>
              <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
                Inhalt *
              </label>
              <textarea
                value={body}
                onChange={(e) => setBody(e.target.value)}
                placeholder="Guten Tag {{KUNDENNAME}},&#10;&#10;vielen Dank für Ihre Nachricht...&#10;&#10;Mit freundlichen Grüßen,&#10;{{AGENTNAME}}"
                rows={8}
                className={clsx(fieldClass, 'font-mono text-sm')}
                required
              />
              <p className={clsx('text-xs mt-1', isDark ? 'text-slate-400' : 'text-gray-500')}>
                Platzhalter wie {'{{KUNDENNAME}}'} werden automatisch erkannt
              </p>
            </div>

            {/* Placeholders Preview */}
            {extractedPlaceholders.length > 0 && (
              <div>
                <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-300' : 'text-gray-700')}>
                  Erkannte Platzhalter
                </label>
                <div className="flex flex-wrap gap-2">
                  {extractedPlaceholders.map((p) => (
                    <span
                      key={p}
                      className={clsx(
                        'text-sm px-3 py-1 rounded font-mono border',
                        isDark
                          ? 'bg-blue-950/50 text-blue-200 border-blue-800/80'
                          : 'bg-blue-50 text-blue-600 border-transparent',
                      )}
                    >
                      {p}
                    </span>
                  ))}
                </div>
              </div>
            )}

            {/* Roles */}
            <div>
              <label className={clsx('block text-sm font-medium mb-2', isDark ? 'text-slate-300' : 'text-gray-700')}>
                Verfügbar für Rollen
              </label>
              <div className="flex flex-wrap gap-2">
                {CSR_ROLES.map((role) => (
                  <label
                    key={role.key}
                    className={clsx(
                      'flex items-center px-3 py-1 rounded-full text-sm cursor-pointer border transition-colors',
                      selectedRoles.includes(role.key)
                        ? 'bg-fin1-primary text-white border-fin1-primary'
                        : isDark
                          ? 'bg-slate-800/90 text-slate-200 border-slate-600 hover:border-fin1-primary'
                          : 'bg-white text-gray-600 border-gray-300 hover:border-fin1-primary',
                    )}
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
              <p className={clsx('text-xs mt-1', isDark ? 'text-slate-400' : 'text-gray-500')}>
                Leer = für alle Rollen verfügbar
              </p>
            </div>
          </div>

          {/* Footer */}
          <div className={clsx('p-6 border-t flex justify-end gap-3', isDark ? 'border-slate-600' : 'border-gray-200')}>
            <Button type="button" variant="secondary" onClick={onClose} disabled={saving}>
              Abbrechen
            </Button>
            <Button type="submit" disabled={saving}>
              {saving ? 'Speichern...' : isEdit ? 'Aktualisieren' : 'Erstellen'}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
