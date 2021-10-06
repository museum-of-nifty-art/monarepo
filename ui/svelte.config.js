import preprocess from "svelte-preprocess";
import { mdsvex } from "mdsvex";
import mdsvexConfig from "./mdsvex.config.js";

const config = {
  "extensions": [".svelte", ...mdsvexConfig.extensions],
  preprocess: [mdsvex(mdsvexConfig), preprocess({
    postcss: true
  })]
};

export default config;