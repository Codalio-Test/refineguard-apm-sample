/**
 * Tag-keyed asset context resolution.
 *
 * `/assets/:assetId/*` carries the asset TAG, while foreign-key payloads need the
 * numeric primary key. `assetRecordId` is the one place that translation happens;
 * getting it wrong sends `id = "P-204A"` to a numeric FK column.
 */
import { describe, expect, it, vi } from 'vitest';

vi.mock('@rhino-dev/rhino-react', () => ({
  useModelIndex: () => ({ data: { data: [], pagination: null }, isLoading: false, error: null }),
}));

import { assetRecordId, useAssetByTag } from './useAssetByTag';

describe('assetRecordId (AC-148)', () => {
  it('prefers the numeric primary key the API emits alongside the tag', () => {
    expect(assetRecordId({ id: 'P-204A', record_id: 42 })).toBe(42);
  });

  it('accepts a numeric id when the API serves the raw primary key', () => {
    expect(assetRecordId({ id: 42 })).toBe(42);
  });

  it('returns null when no numeric key is available', () => {
    expect(assetRecordId(null)).toBeNull();
    expect(assetRecordId({ id: 'P-204A' })).toBeNull();
  });

  it('exposes a tag-keyed lookup hook', () => {
    expect(typeof useAssetByTag).toBe('function');
  });
});
