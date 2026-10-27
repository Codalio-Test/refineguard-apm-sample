/**
 * `/auth/signin` — the required sign-in entry point.
 *
 * The design root already drew the sign-in screen at `/login`; this route is the
 * same screen at the canonical path, so there is exactly one piece of markup and
 * exactly one implementation of the Rhino sign-in call.
 */
export { default } from "./Login";
