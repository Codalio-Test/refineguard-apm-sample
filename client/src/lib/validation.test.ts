import { describe, expect, it } from "vitest";
import {
  fieldErrors,
  firstError,
  invitationSchema,
  loginSchema,
  passwordRecoverSchema,
  passwordResetSchema,
  profileSchema,
  workOrderDispatchSchema,
} from "./validation";

describe("loginSchema", () => {
  it("accepts a username and password", () => {
    expect(loginSchema.safeParse({ email: "operator", password: "secret" }).success).toBe(true);
  });

  it("rejects blanks", () => {
    const result = loginSchema.safeParse({ email: "  ", password: "" });
    expect(result.success).toBe(false);
    if (!result.success) expect(firstError(result.error)).toContain("username");
  });
});

describe("invitationSchema", () => {
  it("accepts a complete invitation", () => {
    const result = invitationSchema.safeParse({
      token: "tok",
      name: "Ada Lovelace",
      email: "ada@brr-ot.local",
      password: "password1",
      password_confirmation: "password1",
    });
    expect(result.success).toBe(true);
  });

  it("requires the confirmation to match", () => {
    const result = invitationSchema.safeParse({
      token: "tok",
      name: "Ada Lovelace",
      email: "ada@brr-ot.local",
      password: "password1",
      password_confirmation: "password2",
    });
    expect(result.success).toBe(false);
    if (!result.success) expect(fieldErrors(result.error).password_confirmation).toMatch(/do not match/);
  });

  it("enforces the minimum password length and a real email", () => {
    const result = invitationSchema.safeParse({
      token: "tok",
      name: "Ada",
      email: "not-an-email",
      password: "short",
      password_confirmation: "short",
    });
    expect(result.success).toBe(false);
    if (!result.success) {
      const errors = fieldErrors(result.error);
      expect(errors.email).toMatch(/valid domain email/);
      expect(errors.password).toMatch(/8 characters/);
    }
  });
});

describe("passwordRecoverSchema / passwordResetSchema", () => {
  it("validates the recovery email", () => {
    expect(passwordRecoverSchema.safeParse({ email: "a@b.local" }).success).toBe(true);
    expect(passwordRecoverSchema.safeParse({ email: "nope" }).success).toBe(false);
  });

  it("requires matching passwords on reset", () => {
    const mismatch = passwordResetSchema.safeParse({
      email: "a@b.local",
      password: "password1",
      password_confirmation: "password2",
    });
    expect(mismatch.success).toBe(false);

    const ok = passwordResetSchema.safeParse({
      email: "a@b.local",
      password: "password1",
      password_confirmation: "password1",
    });
    expect(ok.success).toBe(true);
  });
});

describe("profileSchema", () => {
  it("requires a display name and email", () => {
    expect(profileSchema.safeParse({ display_name: "Ada", email: "a@b.local" }).success).toBe(true);
    expect(profileSchema.safeParse({ display_name: "", email: "a@b.local" }).success).toBe(false);
  });
});

describe("workOrderDispatchSchema", () => {
  it("requires a priority", () => {
    expect(workOrderDispatchSchema.safeParse({ priority: "" }).success).toBe(false);
    expect(workOrderDispatchSchema.safeParse({ priority: "P2" }).success).toBe(true);
  });

  it("accepts an omitted required-by and rejects a malformed one", () => {
    expect(workOrderDispatchSchema.safeParse({ priority: "P2", required_by: "" }).success).toBe(true);
    expect(workOrderDispatchSchema.safeParse({ priority: "P2", required_by: "2026-01-01" }).success).toBe(true);
    expect(workOrderDispatchSchema.safeParse({ priority: "P2", required_by: "not-a-date" }).success).toBe(false);
  });
});
