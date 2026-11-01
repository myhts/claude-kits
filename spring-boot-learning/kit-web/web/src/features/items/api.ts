// REPLACE ME: the sample feature. A feature folder owns its API calls, its query keys and its screens.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { getJson, postJson } from '../../api/client';

const PATH = '/api/v1/items';

export type Item = { id: number; name: string };
export type NewItem = { name: string };

// Query keys in one place, so a mutation invalidates exactly what it changed.
const keys = { all: ['items'] as const };

export function useItems() {
  return useQuery({ queryKey: keys.all, queryFn: () => getJson<Item[]>(PATH) });
}

export function useCreateItem() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (item: NewItem) => postJson<Item>(PATH, item),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: keys.all }),   // refetch the list: the server is the truth
  });
}
