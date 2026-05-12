import { describe, it, expect, vi, beforeEach } from 'vitest';
import { useReducer } from 'react';
import { render, screen, waitFor } from '../../test/test-utils';
import userEvent from '@testing-library/user-event';
import { ConfigurationPage } from './ConfigurationPage';
import { PARAMETER_DEFINITIONS } from './parameterDefinitions';
import { formatCurrency, formatPercentage } from '../../utils/format';
import { useConfigurationPage } from './hooks/useConfigurationPage';
import { getAppWithholdsLabel } from '../../constants/branding';

vi.mock('./hooks/useConfigurationPage');

function buildSortedTaxParams(): [string, Omit<(typeof PARAMETER_DEFINITIONS)[string], 'value'>][] {
  const entries = Object.entries(PARAMETER_DEFINITIONS).filter(([, def]) => def.category === 'tax');
  const sortOrder: Record<string, number> = {
    vatRate: 0,
    taxCollectionMode: 1,
    withholdingTaxRate: 2,
    solidaritySurchargeRate: 3,
  };
  return entries.sort(([a], [b]) => (sortOrder[a] ?? 99) - (sortOrder[b] ?? 99));
}

function formatValueForTest(key: string, value: number | string | boolean): string {
  const def = PARAMETER_DEFINITIONS[key];
  if (!def) return String(value ?? '');

  if (def.type === 'boolean') {
    const on = value === true || value === 'true' || value === 1 || value === '1';
    return on ? 'Aktiv' : 'Deaktiviert';
  }
  if (def.type === 'string') {
    if (key === 'taxCollectionMode') {
      return value === 'customer_self_reports'
        ? 'Kunde führt selbst ab'
        : getAppWithholdsLabel({ appName: 'FIN1' });
    }
    return String(value ?? '');
  }

  const num = Number(value);
  switch (def.type) {
    case 'percentage':
      return formatPercentage(num);
    case 'percent_display':
      return `${Number.isFinite(num) ? num : 0} %`;
    case 'currency':
      return formatCurrency(num);
    default:
      return String(value ?? '');
  }
}

type TestState = {
  editingParam: string | null;
  editValue: string;
  config: Record<string, number | string | boolean>;
};

const initialTestState: TestState = {
  editingParam: null,
  editValue: '',
  config: {
    taxCollectionMode: 'customer_self_reports',
    vatRate: 0.19,
    withholdingTaxRate: 0.25,
    solidaritySurchargeRate: 0.055,
  },
};

let testState: TestState = { ...initialTestState };

function ConfigurationPageTestHarness() {
  const [, bump] = useReducer((n: number) => n + 1, 0);

  vi.mocked(useConfigurationPage).mockImplementation(() => ({
    isDark: false,
    isLoading: false,
    error: null,
    queryClient: { invalidateQueries: vi.fn() } as unknown as ReturnType<typeof useConfigurationPage>['queryClient'],
    showPending: false,
    setShowPending: vi.fn(),
    config: testState.config,
    pendingData: undefined,
    pendingCount: 0,
    financialParams: [],
    taxParams: buildSortedTaxParams(),
    systemParams: [],
    displayParams: [],
    editingParam: testState.editingParam,
    editValue: testState.editValue,
    changeReason: '',
    setChangeReason: vi.fn(),
    crossLimitError: null,
    editError: null,
    requestChangeMutation: {
      isPending: false,
      isError: false,
      isSuccess: false,
    } as unknown as ReturnType<typeof useConfigurationPage>['requestChangeMutation'],
    handleStartEdit: (key: string, currentValue: number | string | boolean) => {
      testState.editingParam = key;
      testState.editValue = String(currentValue);
      bump();
    },
    handleSaveChange: vi.fn(),
    handleCancelEdit: () => {
      testState.editingParam = null;
      testState.editValue = '';
      bump();
    },
    formatValue: formatValueForTest,
    onFinancialEditValueChange: (value: string, _key: string) => {
      void _key;
      testState.editValue = value;
      bump();
    },
    onDisplayEditValueChange: vi.fn(),
  }) as ReturnType<typeof useConfigurationPage>);

  return <ConfigurationPage />;
}

describe('ConfigurationPage (Steuerparameter integration)', () => {
  beforeEach(() => {
    testState = {
      editingParam: null,
      editValue: '',
      config: { ...initialTestState.config },
    };
    vi.clearAllMocks();
  });

  it('shows tax detail section collapsed by default when customer self reports', () => {
    render(<ConfigurationPageTestHarness />);

    expect(screen.getByRole('heading', { name: 'Steuerparameter' })).toBeInTheDocument();
    expect(screen.getByText('Umsatzsteuer (MwSt.)')).toBeInTheDocument();
    expect(screen.getByText('Abgeltungsteuer')).toBeInTheDocument();
    expect(screen.queryByText('Abgeltungsteuersatz')).not.toBeInTheDocument();
    expect(screen.queryByText('Kirchensteuer')).not.toBeInTheDocument();
  });

  it('expands tax details when user selects platform withholds while editing tax mode', async () => {
    const user = userEvent.setup();
    render(<ConfigurationPageTestHarness />);

    const select = screen.getByRole('combobox');
    expect(select).toHaveValue('customer_self_reports');
    await user.selectOptions(select, 'platform_withholds');

    await waitFor(() => {
      expect(screen.getByText('Abgeltungsteuersatz')).toBeInTheDocument();
    });
    expect(screen.getByText('Abgeltungsteuersatz')).toBeInTheDocument();
    expect(screen.getByText('Solidaritätszuschlag')).toBeInTheDocument();
    expect(screen.getByText('Kirchensteuer')).toBeInTheDocument();
  });

  it('shows expanded tax details when config already uses platform withholds', () => {
    testState.config = {
      ...testState.config,
      taxCollectionMode: 'platform_withholds',
    };
    render(<ConfigurationPageTestHarness />);

    expect(screen.getByText('Abgeltungsteuer')).toBeInTheDocument();
    expect(screen.getByText('Abgeltungsteuersatz')).toBeInTheDocument();
    expect(screen.getByText('Kirchensteuer')).toBeInTheDocument();
  });

  it('keeps selected tax mode after simulated reload with persisted config', async () => {
    const user = userEvent.setup();
    const { rerender } = render(<ConfigurationPageTestHarness />);

    const select = screen.getByRole('combobox');
    expect(select).toHaveValue('customer_self_reports');
    await user.selectOptions(select, 'platform_withholds');
    expect(screen.getByRole('combobox')).toHaveValue('platform_withholds');

    // Simulate persisted value after save + page reload.
    testState.config = {
      ...testState.config,
      taxCollectionMode: 'platform_withholds',
    };
    testState.editingParam = null;
    testState.editValue = '';
    rerender(<ConfigurationPageTestHarness />);

    expect(screen.getByRole('combobox')).toHaveValue('platform_withholds');
    expect(screen.getByText('Abgeltungsteuersatz')).toBeInTheDocument();
    expect(screen.getByText('Kirchensteuer')).toBeInTheDocument();
  });
});
