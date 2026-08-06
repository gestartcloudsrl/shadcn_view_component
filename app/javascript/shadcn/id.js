// Unique DOM ids for the ARIA wiring between triggers and their content.
//
// Deliberately not `crypto.randomUUID()`: that is only defined in a secure
// context, so over plain HTTP — a LAN IP, a staging box, `rails s` reached from
// another device — it is `undefined` and every controller that called it threw
// in `connect()`, silently killing the component. A counter is enough; these ids
// only have to be unique within one document.

let counter = 0

export function uniqueId(prefix = "shadcn") {
  counter += 1
  return `${prefix}-${counter}`
}
