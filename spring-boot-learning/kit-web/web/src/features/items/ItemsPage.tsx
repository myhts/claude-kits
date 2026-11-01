// REPLACE ME: the sample page. Every list has three states besides "here it is": loading, failed, and empty.
import { ItemForm } from './ItemForm';
import { useItems } from './api';

export function ItemsPage() {
  const items = useItems();
  return (
    <section aria-labelledby="items-heading">
      <h1 id="items-heading">Items</h1>
      <ItemForm />
      {items.isPending && <p>Loading…</p>}
      {items.isError && <p role="alert">Couldn't load the items: {items.error.message}</p>}
      {items.isSuccess && items.data.length === 0 && <p>No items yet.</p>}
      {items.isSuccess && items.data.length > 0 && (
        <ul aria-label="Items">
          {/* Text from users or a model is rendered as text: React escapes it. Never dangerouslySetInnerHTML. */}
          {items.data.map((item) => <li key={item.id}>{item.name}</li>)}
        </ul>
      )}
    </section>
  );
}
