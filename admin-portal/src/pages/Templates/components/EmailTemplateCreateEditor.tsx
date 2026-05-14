import { useState } from 'react';
import clsx from 'clsx';
import { Button } from '../../../components/ui/Button';
import { useTheme } from '../../../context/ThemeContext';
import { createEmailTemplate } from '../api';

interface EmailTemplateCreateEditorProps {
  onSave: () => void;
  onClose: () => void;
}

export function EmailTemplateCreateEditor({ onSave, onClose }: EmailTemplateCreateEditorProps) {
  const { theme } = useTheme();
  const isDark = theme === 'dark';

  const [type, setType] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [subject, setSubject] = useState('');
  const [bodyTemplate, setBodyTemplate] = useState('');
  const [icon, setIcon] = useState('✉️');
  const [isActive, setIsActive] = useState(true);
  const [placeholdersRaw, setPlaceholdersRaw] = useState('');

  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSave() {
    const normalizedType = type.trim().toLowerCase().replace(/\s+/g, '_');
    const normalizedDisplayName = displayName.trim();
    const normalizedSubject = subject.trim();
    const normalizedBody = bodyTemplate.trim();
    const placeholders = placeholdersRaw
      .split(',')
      .map((p) => p.trim())
      .filter(Boolean);

    if (!normalizedType || !normalizedDisplayName || !normalizedSubject || !normalizedBody) {
      setError('Bitte Typ, Anzeigename, Betreff und Inhalt ausfuellen.');
      return;
    }

    setSaving(true);
    setError(null);
    try {
      await createEmailTemplate({
        type: normalizedType,
        displayName: normalizedDisplayName,
        subject: normalizedSubject,
        bodyTemplate: normalizedBody,
        availablePlaceholders: placeholders,
        icon: icon.trim() || '✉️',
        isActive,
      });
      onSave();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Fehler beim Erstellen');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div
        className={clsx(
          'rounded-xl shadow-xl max-w-3xl w-full max-h-[90vh] overflow-hidden flex flex-col border',
          isDark ? 'bg-slate-900 border-slate-700' : 'bg-white border-gray-200'
        )}
      >
        <div className={clsx('p-6 border-b flex-shrink-0', isDark ? 'border-slate-700' : 'border-gray-200')}>
          <h2 className={clsx('text-xl font-bold', isDark ? 'text-slate-100' : 'text-gray-900')}>
            Neue E-Mail Vorlage
          </h2>
          <p className={clsx('text-sm mt-1', isDark ? 'text-slate-300' : 'text-gray-500')}>
            Neue Vorlage anlegen und direkt in der Liste verfuegbar machen.
          </p>
        </div>

        <div className="flex-1 overflow-y-auto p-6 space-y-4">
          {error && (
            <div className={clsx('p-3 rounded-lg text-sm', isDark ? 'bg-red-950 text-red-200 border border-red-800' : 'bg-red-50 text-red-600')}>
              {error}
            </div>
          )}

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-200' : 'text-gray-700')}>
                Typ (eindeutig)
              </label>
              <input
                type="text"
                value={type}
                onChange={(e) => setType(e.target.value)}
                placeholder="ticket_followup"
                className={clsx(
                  'w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent',
                  isDark ? 'bg-slate-800 border-slate-600 text-slate-100 placeholder:text-slate-400' : 'bg-white border-gray-300 text-gray-900'
                )}
              />
            </div>

            <div>
              <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-200' : 'text-gray-700')}>
                Anzeigename
              </label>
              <input
                type="text"
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                placeholder="Ticket Follow-up"
                className={clsx(
                  'w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent',
                  isDark ? 'bg-slate-800 border-slate-600 text-slate-100 placeholder:text-slate-400' : 'bg-white border-gray-300 text-gray-900'
                )}
              />
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="md:col-span-2">
              <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-200' : 'text-gray-700')}>
                Betreff
              </label>
              <input
                type="text"
                value={subject}
                onChange={(e) => setSubject(e.target.value)}
                className={clsx(
                  'w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent',
                  isDark ? 'bg-slate-800 border-slate-600 text-slate-100 placeholder:text-slate-400' : 'bg-white border-gray-300 text-gray-900'
                )}
              />
            </div>

            <div>
              <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-200' : 'text-gray-700')}>
                Icon
              </label>
              <input
                type="text"
                value={icon}
                onChange={(e) => setIcon(e.target.value)}
                className={clsx(
                  'w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent',
                  isDark ? 'bg-slate-800 border-slate-600 text-slate-100 placeholder:text-slate-400' : 'bg-white border-gray-300 text-gray-900'
                )}
              />
            </div>
          </div>

          <div>
            <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-200' : 'text-gray-700')}>
              Inhalt (Body-Template)
            </label>
            <textarea
              rows={10}
              value={bodyTemplate}
              onChange={(e) => setBodyTemplate(e.target.value)}
              className={clsx(
                'w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent font-mono text-sm',
                isDark ? 'bg-slate-800 border-slate-600 text-slate-100 placeholder:text-slate-400' : 'bg-white border-gray-300 text-gray-900'
              )}
            />
          </div>

          <div>
            <label className={clsx('block text-sm font-medium mb-1', isDark ? 'text-slate-200' : 'text-gray-700')}>
              Platzhalter (optional, kommasepariert)
            </label>
            <input
              type="text"
              value={placeholdersRaw}
              onChange={(e) => setPlaceholdersRaw(e.target.value)}
              placeholder="{{KUNDENNAME}},{{TICKETNUMMER}}"
              className={clsx(
                'w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-fin1-primary focus:border-transparent',
                isDark ? 'bg-slate-800 border-slate-600 text-slate-100 placeholder:text-slate-400' : 'bg-white border-gray-300 text-gray-900'
              )}
            />
          </div>

          <label className="flex items-center gap-2">
            <input
              type="checkbox"
              checked={isActive}
              onChange={(e) => setIsActive(e.target.checked)}
              className={clsx(
                'rounded border',
                isDark ? 'border-slate-500 bg-slate-900' : 'border-gray-300',
              )}
            />
            <span className={clsx('text-sm', isDark ? 'text-slate-200' : 'text-gray-700')}>Aktiv</span>
          </label>
        </div>

        <div className={clsx('p-6 border-t flex justify-end gap-3 flex-shrink-0', isDark ? 'border-slate-700' : 'border-gray-200')}>
          <Button variant="secondary" onClick={onClose} disabled={saving}>
            Abbrechen
          </Button>
          <Button onClick={handleSave} disabled={saving}>
            {saving ? 'Erstelle...' : 'Erstellen'}
          </Button>
        </div>
      </div>
    </div>
  );
}
