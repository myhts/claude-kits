# UI format: standalone HTML or inside the project's own front end

Both options run the **same engine and the same data file**, so the choice is about where the page lives, not what
it shows. Switching later means copying a wrapper, not rewriting data.

## Detecting the front end

Read every `package.json` in the repo (root and workspaces) and look at dependencies:

| Found | Offer |
|---|---|
| `next` | Next.js page (App Router: `app/dev/explorer/`; Pages Router: `pages/dev/explorer.jsx`) |
| `react` + `vite` / `react-scripts` / `@remix-run/*` | React component on a dev-only route |
| `vue` / `nuxt` | Vue component (Nuxt: inside `<ClientOnly>`) |
| `svelte` / `@sveltejs/kit` | Svelte component (SvelteKit route with `ssr = false`) |
| `@angular/core` | Angular component (below) |
| `astro`, `solid-js`, `preact`, `lit`, `qwik` | the same pattern: mount in the framework's "after mount" hook, destroy on unmount |
| Server-rendered only (Django, Rails, Laravel, Spring MVC templates) or no front end | Standalone HTML only (serve it as a static file if they want it inside the app) |

## The question (part of the first gate)

"Where should the explorer page live?"
1. **Standalone HTML file (recommended)**: `docs/explorer/explorer.html`, one file, opens from disk, no build, code
   links open your editor at the line, works even when the app is broken.
2. **Inside your `<framework>` app**: a dev-only route like `/dev/explorer`, uses your dev server and hot reload, can
   later show live data from your own APIs. Code links open the editor only if `REPO_ROOT` is set in an untracked env file.
3. Both (the standalone file is always buildable from the same data).

## Framework install steps

Copy `template/engine/explorer-engine.js`, `template/engine/explorer.css` and the project's `explorer-data.js` into one
folder inside the app (e.g. `src/dev/explorer/`), plus the wrapper from `template/shells/<framework>/`. Then:

- **Dev-only.** Register the route only in development (`import.meta.env.DEV`, `process.env.NODE_ENV !== "production"`,
  SvelteKit `dev`, Angular `isDevMode()`), or make the page return 404 in production (the Next.js shell does). Never ship
  it to users by accident. Ask if they want it in production builds.
- **Repo root for code links.** `VITE_REPO_ROOT` / `REPO_ROOT` in `.env.local` (check it's gitignored). Without it,
  links fall back to `meta.repoUrl` or plain text.
- **Styles are scoped** to `.xp`; the app's CSS won't leak in much, but a global `* { … }` reset or `svg { … }` rule can.
  Check the page under the app's styles with `check-explorer.mjs http://localhost:<port>/dev/explorer`.
- **Height.** The page fills the viewport below its own header. Under an app header, pass `height` (e.g.
  `"calc(100vh - 64px)"`) to the wrapper.
- **Hash routing.** The engine uses `#flow=…` / `#concept=…` in the URL by default; it doesn't touch the app router.
  Pass `{ hashRouting: false }` if the app uses hash routing itself.
- **TypeScript.** The engine is plain JS; add `// @ts-nocheck` at the top of the copied engine if `checkJs` complains,
  or `declare module "./explorer-engine.js";`.
- **Next.js Pages Router.** Global CSS can only be imported in `pages/_app`: import `explorer.css` there, and load the
  component with `next/dynamic` and `{ ssr: false }`.
- **Angular.**
  ```ts
  @Component({ selector: "app-explorer", standalone: true, template: "<div #host></div>",
    styleUrls: ["./explorer.css"], encapsulation: ViewEncapsulation.None })
  export class ExplorerComponent implements AfterViewInit, OnDestroy {
    @ViewChild("host") host!: ElementRef<HTMLDivElement>;
    private explorer?: { destroy(): void };
    ngAfterViewInit() { this.explorer = mountExplorer(this.host.nativeElement, data); }
    ngOnDestroy() { this.explorer?.destroy(); }
  }
  ```

The standalone file is still worth building in the framework case: `bundle-html.mjs` takes the same data file, and
it's what `check-explorer.mjs` runs on fastest.
