// REPLACE ME: the sample form. The server validates (it's the source of truth); the form shows what it says.
import { useId, useState, type FormEvent } from 'react';
import { ProblemError } from '../../api/client';
import { useCreateItem } from './api';

export function ItemForm() {
  const [name, setName] = useState('');
  const create = useCreateItem();
  const nameId = useId();
  const problem = create.error instanceof ProblemError ? create.error : undefined;
  const nameError = problem?.fields.name;

  function submit(event: FormEvent) {
    event.preventDefault();
    create.mutate({ name }, { onSuccess: () => setName('') });
  }

  return (
    <form onSubmit={submit} noValidate aria-label="Add an item">
      <label htmlFor={nameId}>Name</label>
      <input
        id={nameId}
        value={name}
        onChange={(e) => setName(e.target.value)}
        aria-invalid={nameError ? true : undefined}
        aria-describedby={nameError ? `${nameId}-error` : undefined}
      />
      {nameError && <span id={`${nameId}-error`} className="field-error">{nameError}</span>}
      <button type="submit" disabled={create.isPending}>{create.isPending ? 'Adding…' : 'Add'}</button>
      {create.error && <p role="alert">{create.error.message}</p>}
    </form>
  );
}
