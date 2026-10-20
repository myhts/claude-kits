// Safety in code, not just in a README: e2e tests create data, so they only ever run against a stack on this
// machine. Another host needs an explicit, named opt-in (E2E_ALLOWED_HOSTS), and is never assumed.
const LOCAL = new Set(['localhost', '127.0.0.1', '[::1]']);

export function assertAllowedTarget(baseUrl: string): void {
  const { hostname, protocol } = new URL(baseUrl);
  const extra = (process.env.E2E_ALLOWED_HOSTS ?? '').split(',').map((h) => h.trim()).filter(Boolean);
  if (!/^https?:$/.test(protocol)) throw new Error(`e2e: unsupported URL ${baseUrl}`);
  if (LOCAL.has(hostname) || extra.includes(hostname)) return;
  throw new Error(
    `e2e: refusing to run against ${hostname}. These tests write data. Only this machine is allowed ` +
      `(add a host to E2E_ALLOWED_HOSTS only for an environment you own and may write to).`,
  );
}
