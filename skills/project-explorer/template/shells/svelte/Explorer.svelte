<!-- Svelte / SvelteKit: the explorer as a component. SvelteKit: put it in a route with `export const ssr = false`
     in +page.js, and guard the route with `import { dev } from "$app/environment"`. -->
<script>
  import { onMount } from "svelte";
  import { mountExplorer } from "./explorer-engine.js";
  import "./explorer.css";
  import data from "./explorer-data.js";

  export let repoRoot = import.meta.env?.VITE_REPO_ROOT;
  let host;
  onMount(() => {
    const explorer = mountExplorer(host, data, { repoRoot });
    return () => explorer.destroy();
  });
</script>

<div bind:this={host}></div>
