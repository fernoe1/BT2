/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_TOKEN_ADDRESS: string;
  readonly VITE_GOVERNOR_ADDRESS: string;
  readonly VITE_BOX_ADDRESS: string;
  readonly VITE_PROPOSALS_FROM_BLOCK: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
