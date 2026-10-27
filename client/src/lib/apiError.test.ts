import { describe, expect, it } from "vitest";
import { AxiosError, AxiosHeaders } from "axios";
import { apiErrorMessage } from "./apiError";

function axiosError(status: number, data: unknown): AxiosError {
  const error = new AxiosError("Request failed", undefined, undefined, undefined, {
    status,
    statusText: "Error",
    data,
    headers: {},
    config: { headers: new AxiosHeaders() },
  });
  return error;
}

describe("apiErrorMessage", () => {
  it("flattens a 422 field-error payload", () => {
    const error = axiosError(422, { errors: { title: ["is required"], body: ["is too long"] } });
    expect(apiErrorMessage(error, "fallback")).toBe("is required is too long");
  });

  it("prefers errors over message", () => {
    const error = axiosError(403, { errors: { title: ["nope"] }, message: "ignored" });
    expect(apiErrorMessage(error, "fallback")).toBe("nope");
  });

  it("falls back to the server message", () => {
    expect(apiErrorMessage(axiosError(401, { message: "Invalid credentials" }), "fallback"))
      .toBe("Invalid credentials");
  });

  it("uses an Error message when the failure is not an axios error", () => {
    expect(apiErrorMessage(new Error("boom"), "fallback")).toBe("boom");
  });

  it("returns the fallback for an unknown thrown value", () => {
    expect(apiErrorMessage("boom", "fallback")).toBe("fallback");
    // An axios error with no payload still carries its own message.
    expect(apiErrorMessage(axiosError(500, {}), "fallback")).toBe("Request failed");
  });
});
