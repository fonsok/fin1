import React from 'react';
import {
  render as rtlRender,
  screen,
  fireEvent,
  waitFor,
  within,
  act,
  cleanup,
  renderHook,
  type RenderOptions,
} from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { ThemeProvider } from '../context/ThemeContext';

type Wrapper = React.ComponentType<{ children: React.ReactNode }>;

function createTestQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  });
}

export interface CustomRenderOptions extends Omit<RenderOptions, 'wrapper'> {
  wrapper?: Wrapper;
  /** Eigener Client für Cache-Assertions; sonst frischer Test-Client. */
  queryClient?: QueryClient;
}

/** RTL-`render` inkl. `QueryClientProvider`, `ThemeProvider`; optionaler zusätzlicher Wrapper. */
export function render(ui: React.ReactElement, options?: CustomRenderOptions) {
  const { wrapper: Inner, queryClient: queryClientOpt, ...rest } = options ?? {};
  const queryClient = queryClientOpt ?? createTestQueryClient();
  const Wrapper = ({ children }: { children: React.ReactNode }) => (
    <MemoryRouter>
      <QueryClientProvider client={queryClient}>
        <ThemeProvider>
          {Inner ? <Inner>{children}</Inner> : children}
        </ThemeProvider>
      </QueryClientProvider>
    </MemoryRouter>
  );
  return rtlRender(ui, { wrapper: Wrapper, ...rest });
}

export { screen, fireEvent, waitFor, within, act, cleanup, renderHook };
