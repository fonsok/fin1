import '@testing-library/jest-dom';
import { cleanup } from '@testing-library/react';
import { afterEach, vi } from 'vitest';

// Cleanup after each test
afterEach(() => {
  cleanup();
});

// Mock localStorage (ThemeProvider liest fin1-admin-theme → fest 'light' für stabile Klassen-Assertions)
const localStorageMock = {
  getItem: vi.fn((key: string) => (key === 'fin1-admin-theme' ? 'light' : null)),
  setItem: vi.fn(),
  removeItem: vi.fn(),
  clear: vi.fn(),
};
Object.defineProperty(window, 'localStorage', { value: localStorageMock });

// Mock sessionStorage
const sessionStorageMock = {
  getItem: vi.fn(),
  setItem: vi.fn(),
  removeItem: vi.fn(),
  clear: vi.fn(),
};
Object.defineProperty(window, 'sessionStorage', { value: sessionStorageMock });

// Mock fetch
global.fetch = vi.fn();

// Reset mocks between tests (getItem-Implementation beibehalten → Theme bleibt 'light')
afterEach(() => {
  vi.clearAllMocks();
  localStorageMock.getItem.mockImplementation((key: string) =>
    key === 'fin1-admin-theme' ? 'light' : null,
  );
  localStorageMock.setItem.mockReset();
  localStorageMock.removeItem.mockReset();
  sessionStorageMock.getItem.mockReset();
  sessionStorageMock.setItem.mockReset();
  sessionStorageMock.removeItem.mockReset();
});
