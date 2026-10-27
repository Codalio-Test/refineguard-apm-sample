// @vitest-environment jsdom
/**
 * Work-order confirmation response handling.
 *
 * The dispatch endpoint nests the created order under `work_order` and reports
 * failures through the shared `{ errors: [...] }` envelope with 409 for an
 * already-dispatched advisory and 422 for a validation failure. These tests feed
 * the component those exact shapes and assert what the operator sees.
 */
import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import React from 'react';
import { cleanup, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { AxiosError, AxiosHeaders, type AxiosResponse } from 'axios';

const state = vi.hoisted(() => ({
  dispatch: {} as Record<string, unknown>,
  context: {} as Record<string, unknown>,
}));

vi.mock('../hooks/useApiQueries', () => ({
  useDispatchWorkOrder: () => state.dispatch,
  useWorkOrderContext: () => state.context,
}));

import WorkOrderConfirmation from './WorkOrderConfirmation';

function axiosFailure(status: number, data: unknown): AxiosError {
  const response = {
    status,
    statusText: '',
    headers: {},
    config: { headers: new AxiosHeaders() },
    data,
  } as unknown as AxiosResponse;
  return new AxiosError('Request failed', String(status), undefined, undefined, response);
}

function renderPage() {
  return render(
    <MemoryRouter initialEntries={[{ pathname: '/work-orders/confirmation', search: '?priority=P2' }]}>
      <WorkOrderConfirmation />
    </MemoryRouter>,
  );
}

const idleMutation = () => ({
  mutate: vi.fn(),
  isPending: false,
  isSuccess: false,
  isError: false,
  error: null,
  data: undefined,
  reset: vi.fn(),
});

describe('WorkOrderConfirmation dispatch outcomes', () => {
  beforeEach(() => {
    state.context = { order: null, advisory: { id: 7, advisory_code: 'ADV-7' }, advisories: [] };
  });
  afterEach(() => cleanup());

  it('reads the external reference from the nested work_order (success + simulated)', () => {
    state.dispatch = {
      ...idleMutation(),
      isSuccess: true,
      data: {
        success: true,
        adapter: 'simulated',
        simulated: true,
        duration_ms: 3,
        budget_ms: null,
        advisory_status: 'Dispatched',
        errors: [],
        work_order: {
          id: 11,
          cmms_type: 'SAP PM',
          external_order_number: 'SAP-WO-000123',
          sync_status: 'Dispatched',
          confirmed_at: null,
        },
      },
    };

    renderPage();

    expect(screen.getByText(/SAP-WO-000123/)).toBeTruthy();
    expect(screen.getAllByText(/SIMULATED/).length).toBeGreaterThan(0);
  });

  it('surfaces a 409 conflict through the shared error helper', () => {
    state.dispatch = {
      ...idleMutation(),
      isError: true,
      error: axiosFailure(409, { errors: ['The advisory has already been dispatched'] }),
    };

    renderPage();

    expect(screen.getByText(/already been dispatched/)).toBeTruthy();
    expect(screen.queryByText(/SAP-WO-/)).toBeNull();
  });

  it('surfaces a 422 validation failure through the shared error helper', () => {
    state.dispatch = {
      ...idleMutation(),
      isError: true,
      error: axiosFailure(422, { errors: ['A maintenance priority is required'] }),
    };

    renderPage();

    expect(screen.getByText(/A maintenance priority is required/)).toBeTruthy();
  });
});
