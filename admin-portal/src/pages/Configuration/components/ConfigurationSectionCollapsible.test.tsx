import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '../../../test/test-utils';
import userEvent from '@testing-library/user-event';
import { ConfigurationSectionCollapsible } from './ConfigurationSectionCollapsible';

describe('ConfigurationSectionCollapsible', () => {
  it('hides children until expanded', async () => {
    const user = userEvent.setup();
    const onToggle = vi.fn();

    render(
      <ConfigurationSectionCollapsible
        title="Finanzparameter"
        expanded={false}
        onToggle={onToggle}
        isDark={false}
      >
        <p>Parameter-Inhalt</p>
      </ConfigurationSectionCollapsible>,
    );

    expect(screen.queryByText('Parameter-Inhalt')).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: /Finanzparameter/i }));
    expect(onToggle).toHaveBeenCalledTimes(1);
  });

  it('shows children when expanded', () => {
    render(
      <ConfigurationSectionCollapsible
        title="Anzeige"
        expanded
        onToggle={vi.fn()}
        isDark={false}
      >
        <p>Parameter-Inhalt</p>
      </ConfigurationSectionCollapsible>,
    );

    expect(screen.getByText('Parameter-Inhalt')).toBeInTheDocument();
  });

  it('keeps section open when forceExpanded', async () => {
    const user = userEvent.setup();
    const onToggle = vi.fn();

    render(
      <ConfigurationSectionCollapsible
        title="Steuerparameter"
        expanded={false}
        forceExpanded
        onToggle={onToggle}
        isDark={false}
      >
        <p>Steuer-Inhalt</p>
      </ConfigurationSectionCollapsible>,
    );

    expect(screen.getByText('Steuer-Inhalt')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: /Steuerparameter/i }));
    expect(onToggle).not.toHaveBeenCalled();
  });
});
