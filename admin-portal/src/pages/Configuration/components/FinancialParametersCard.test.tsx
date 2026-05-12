import { describe, it, expect, vi } from 'vitest';
import type { ComponentProps } from 'react';
import { render, screen } from '../../../test/test-utils';
import { FinancialParametersCard } from './FinancialParametersCard';
import { PARAMETER_DEFINITIONS } from '../parameterDefinitions';
import { getAppWithholdsLabel } from '../../../constants/branding';

function createProps(overrides?: Partial<ComponentProps<typeof FinancialParametersCard>>) {
  return {
    financialParams: [
      ['taxCollectionMode', PARAMETER_DEFINITIONS.taxCollectionMode],
      ['vatRate', PARAMETER_DEFINITIONS.vatRate],
      ['withholdingTaxRate', PARAMETER_DEFINITIONS.withholdingTaxRate],
      ['solidaritySurchargeRate', PARAMETER_DEFINITIONS.solidaritySurchargeRate],
    ] as [string, Omit<(typeof PARAMETER_DEFINITIONS)[string], 'value'>][],
    title: 'Steuerparameter',
    config: {
      taxCollectionMode: 'customer_self_reports',
      vatRate: 0.19,
      withholdingTaxRate: 0.25,
      solidaritySurchargeRate: 0.055,
    },
    isDark: false,
    editingParam: null,
    editValue: '',
    changeReason: '',
    crossLimitError: null,
    editError: null,
    pendingRequests: [],
    onEditValueChange: vi.fn(),
    onChangeReason: vi.fn(),
    onSave: vi.fn(),
    onCancel: vi.fn(),
    onStartEdit: vi.fn(),
    formatValue: (key: string, value: number | string | boolean) => {
      if (key === 'taxCollectionMode') {
        return value === 'platform_withholds'
          ? getAppWithholdsLabel({ appName: 'FIN1' })
          : 'Kunde führt selbst ab';
      }
      return String(value);
    },
    isSaving: false,
    isError: false,
    isSuccess: false,
    ...overrides,
  };
}

describe('FinancialParametersCard tax collapse behavior', () => {
  it('hides tax detail fields by default for customer self reporting', () => {
    render(<FinancialParametersCard {...createProps()} />);

    expect(screen.getByText('Umsatzsteuer (MwSt.)')).toBeInTheDocument();
    expect(screen.getByText('Abgeltungsteuer')).toBeInTheDocument();
    expect(screen.queryByText('Abgeltungsteuersatz')).not.toBeInTheDocument();
    expect(screen.queryByText('Solidaritätszuschlag')).not.toBeInTheDocument();
    expect(screen.queryByText('Kirchensteuer')).not.toBeInTheDocument();
  });

  it('shows tax detail fields when platform withholds taxes', () => {
    render(
      <FinancialParametersCard
        {...createProps({
          config: {
            taxCollectionMode: 'platform_withholds',
            vatRate: 0.19,
            withholdingTaxRate: 0.25,
            solidaritySurchargeRate: 0.055,
          },
        })}
      />,
    );

    expect(screen.getByText('Umsatzsteuer (MwSt.)')).toBeInTheDocument();
    expect(screen.getByText('Abgeltungsteuer')).toBeInTheDocument();
    expect(screen.getByText('Abgeltungsteuersatz')).toBeInTheDocument();
    expect(screen.getByText('Solidaritätszuschlag')).toBeInTheDocument();
    expect(screen.getByText('Kirchensteuer')).toBeInTheDocument();
  });

  it('expands tax details immediately while editing tax mode before save', () => {
    render(
      <FinancialParametersCard
        {...createProps({
          editingParam: 'taxCollectionMode',
          editValue: 'platform_withholds',
        })}
      />,
    );

    expect(screen.getByText('Umsatzsteuer (MwSt.)')).toBeInTheDocument();
    expect(screen.getByText('Abgeltungsteuer')).toBeInTheDocument();
    expect(screen.getByText('Abgeltungsteuersatz')).toBeInTheDocument();
    expect(screen.getByText('Solidaritätszuschlag')).toBeInTheDocument();
    expect(screen.getByText('Kirchensteuer')).toBeInTheDocument();
  });

  it('disables tax mode dropdown when a pending change exists', () => {
    render(
      <FinancialParametersCard
        {...createProps({
          pendingRequests: [
            {
              id: 'req-1',
              parameterName: 'taxCollectionMode',
              oldValue: 'customer_self_reports',
              newValue: 'platform_withholds',
              reason: 'Test',
              requesterId: 'u1',
              requesterEmail: 'admin@fin1.de',
              requesterRole: 'admin',
              createdAt: '2026-01-01T00:00:00.000Z',
              expiresAt: '2026-01-08T00:00:00.000Z',
            },
          ],
        })}
      />,
    );

    expect(screen.getByRole('combobox')).toBeDisabled();
  });
});
