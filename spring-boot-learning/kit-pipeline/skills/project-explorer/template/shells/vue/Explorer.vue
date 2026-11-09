<!-- Vue 3 (Vite, Nuxt): the explorer as a component. Nuxt: wrap it in <ClientOnly>. Mount on a dev-only route. -->
<script setup>
import { onMounted, onBeforeUnmount, ref } from "vue";
import { mountExplorer } from "./explorer-engine.js";
import "./explorer.css";
import data from "./explorer-data.js";

const props = defineProps({ repoRoot: { type: String, default: import.meta.env?.VITE_REPO_ROOT } });
const host = ref(null);
let explorer;
onMounted(() => { explorer = mountExplorer(host.value, data, { repoRoot: props.repoRoot }); });
onBeforeUnmount(() => explorer?.destroy());
</script>

<template>
  <div ref="host" />
</template>
