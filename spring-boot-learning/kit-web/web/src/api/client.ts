// The one place that talks HTTP. Every feature calls getJson/postJson; errors come back as ProblemError, built from
// the API's RFC 9457 problem details (application/problem+json), so screens can show the server's own message and
// the invalid fields instead of "something went wrong".

export class ProblemError extends Error {
  constructor(
    readonly status: number,
    readonly title: string,
    readonly detail: string | undefined,
    readonly fields: Record<string, string>,   // field → message, when the API lists them (kit's ApiExceptionHandler)
  ) {
    super(detail ?? title);
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(path, {
    ...init,
    headers: { Accept: 'application/json, application/problem+json', ...init?.headers },
  });
  if (response.ok) {
    return (response.status === 204 ? undefined : await response.json()) as T;
  }
  const type = response.headers.get('content-type') ?? '';
  if (type.includes('application/problem+json')) {
    const p = await response.json();
    throw new ProblemError(response.status, p.title ?? response.statusText, p.detail, p.fields ?? {});
  }
  throw new ProblemError(response.status, response.statusText || 'Request failed', undefined, {});
}

export const getJson = <T>(path: string) => request<T>(path);

export const postJson = <T>(path: string, body: unknown) =>
  request<T>(path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });

/** Retry a failed query once, unless the server said no (4xx): asking again won't change its mind. */
export const retryUnlessClientError = (failures: number, error: Error) =>
  failures < 1 && !(error instanceof ProblemError && error.status >= 400 && error.status < 500);
