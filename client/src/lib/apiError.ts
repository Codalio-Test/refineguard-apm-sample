/**
 * Turn an unknown thrown value from an API call into a displayable message.
 *
 * Typed so callers never need `catch (err: any)`: Rhino/axios failures are
 * inspected through the axios type guard, and anything else falls back to the
 * provided message. Every custom endpoint answers failures with the single
 * `{ "errors": ["message", ...] }` envelope; the engine's own validation
 * failures still use `{ "errors": { field: [...] } }`, so both are flattened.
 */
import axios from 'axios';

interface ApiErrorPayload {
  errors?: string[] | Record<string, string[]>;
  message?: string;
}

function flattenErrors(errors: ApiErrorPayload['errors']): string[] {
  if (Array.isArray(errors)) return errors.filter((entry): entry is string => Boolean(entry));
  if (errors && typeof errors === 'object') return Object.values(errors).flat();
  return [];
}

export function apiErrorMessage(error: unknown, fallback: string): string {
  if (axios.isAxiosError<ApiErrorPayload>(error)) {
    const data = error.response?.data;
    const flattened = flattenErrors(data?.errors);
    if (flattened.length > 0) return flattened.join(' ');
    if (data?.message) return data.message;
  }
  if (error instanceof Error && error.message) return error.message;
  return fallback;
}
