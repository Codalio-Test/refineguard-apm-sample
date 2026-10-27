import { useEffect, useState } from 'react';
import { useModelIndex } from '@rhino-dev/rhino-react';
import type { Asset } from '@/types/rhino';

/**
 * `/assets/:assetId/*` routes carry the asset TAG (e.g. P-204A), never a primary
 * key. The API resolves member endpoints by `asset_tag` (the model declares
 * `rhino_route_key :asset_tag`), and this hook resolves the tag to the record
 * once per page so related-resource queries can reuse the numeric id.
 */
export function useAssetByTag(tag?: string) {
  const { data: response, isLoading, error } = useModelIndex<Asset>(
    'assets',
    { filters: { asset_tag: tag }, perPage: 1 },
    { enabled: Boolean(tag) },
  );

  const asset = response?.data?.[0] ?? null;
  return { asset, isLoading: Boolean(tag) && isLoading, error };
}

/** The numeric primary key for a tag-keyed asset (used in FK payloads). */
export function assetRecordId(asset: Asset | null): number | null {
  if (!asset) return null;
  if (typeof asset.record_id === 'number') return asset.record_id;
  return typeof asset.id === 'number' ? asset.id : null;
}

export function useDebounced<T>(value: T, delay = 300): T {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debounced;
}
