import js from "@eslint/js"
import globals from "globals"

// Development tooling only: nothing here ships, and the gem still has no npm
// dependency at runtime — the controllers are plain ES modules that
// importmap-rails serves as they are.
//
// What earns the Node dependency is the class of bug Ruby's tooling cannot
// see. `stimulus_contract_spec` checks that every action, target and value a
// component names exists in the JavaScript; it says nothing about whether the
// JavaScript itself refers to something that does not exist. The install
// generator shipped exactly that for a year — `registerShadcnControllers(application)`
// against an undefined binding — and it took a browser to find it.
export default [
  js.configs.recommended,
  {
    files: [ "app/javascript/**/*.js" ],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: { ...globals.browser }
    },
    rules: {
      // The one that would have caught the generator's bug, and the reason
      // this file exists. `recommended` already sets it; it is repeated here
      // so that removing it is a decision rather than an upgrade.
      "no-undef": "error",
      // An unused argument is usually a signature kept for the reader — a
      // Stimulus action that ignores its event, a callback matching a shape.
      // An unused *variable* is dead code.
      "no-unused-vars": [ "error", { args: "none" } ]
    }
  }
]
