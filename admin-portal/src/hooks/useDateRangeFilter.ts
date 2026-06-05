import { useMemo, useState, useCallback } from 'react';
import {
  type DateRangePreset,
  dateRangePresetToApiParams,
  isDateRangeFilterActive,
} from '../utils/dateRangePreset';

export function useDateRangeFilter(initialPreset: DateRangePreset = 'all') {
  const [datePreset, setDatePreset] = useState<DateRangePreset>(initialPreset);
  const [dateFromInput, setDateFromInput] = useState('');
  const [dateToInput, setDateToInput] = useState('');

  const apiParams = useMemo(
    () => dateRangePresetToApiParams(datePreset, dateFromInput, dateToInput),
    [datePreset, dateFromInput, dateToInput],
  );

  const hasActiveDateRange = isDateRangeFilterActive(datePreset, dateFromInput, dateToInput);

  const resetDateRange = useCallback(() => {
    setDatePreset('all');
    setDateFromInput('');
    setDateToInput('');
  }, []);

  const onPresetChange = useCallback((preset: DateRangePreset) => {
    setDatePreset(preset);
    if (preset !== 'custom') {
      setDateFromInput('');
      setDateToInput('');
    }
  }, []);

  return {
    datePreset,
    dateFromInput,
    dateToInput,
    setDateFromInput,
    setDateToInput,
    apiParams,
    hasActiveDateRange,
    resetDateRange,
    onPresetChange,
  };
}
