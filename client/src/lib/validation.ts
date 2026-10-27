/**
 * Zod schemas for every form in the console.
 *
 * The forms are validated on submit with one schema each, so the rules live in
 * one place instead of being spread across `required` attributes the browser
 * silently enforces (and which never run in tests).
 */
import { z } from 'zod';

/** Extract the first message per field, keyed by the field path. */
export function fieldErrors(error: z.ZodError): Record<string, string> {
  const result: Record<string, string> = {};
  for (const issue of error.issues) {
    const key = issue.path.join('.') || 'form';
    if (!result[key]) result[key] = issue.message;
  }
  return result;
}

/** First error, or null — handy for the single-message auth cards. */
export function firstError(error: z.ZodError): string {
  return error.issues[0]?.message ?? 'Please check the highlighted fields.';
}

export const loginSchema = z.object({
  email: z.string().trim().min(1, 'Enter your domain username or email'),
  password: z.string().min(1, 'Enter your password'),
});
export type LoginValues = z.infer<typeof loginSchema>;

const passwordRule = z
  .string()
  .min(8, 'Use at least 8 characters');

const emailRule = z.string().trim().email('Enter a valid domain email');

/** The password-confirmation refinement shared by the invitation and reset forms. */
function confirmedPassword<T extends { password: string; password_confirmation: string }>(
  schema: z.ZodType<T>,
): z.ZodEffects<z.ZodType<T>, T, T> {
  return schema.refine((values) => values.password === values.password_confirmation, {
    path: ['password_confirmation'],
    message: 'Passwords do not match',
  });
}

export const invitationSchema = confirmedPassword(
  z.object({
    token: z.string().trim().min(1, 'Paste the invitation token'),
    name: z.string().trim().min(2, 'Enter your full name'),
    email: emailRule,
    password: passwordRule,
    password_confirmation: z.string().min(1, 'Confirm your password'),
  }),
);
export type InvitationValues = z.infer<typeof invitationSchema>;

export const passwordRecoverSchema = z.object({
  email: emailRule,
});
export type PasswordRecoverValues = z.infer<typeof passwordRecoverSchema>;

export const passwordResetSchema = confirmedPassword(
  z.object({
    email: emailRule,
    password: passwordRule,
    password_confirmation: z.string().min(1, 'Confirm your password'),
  }),
);
export type PasswordResetValues = z.infer<typeof passwordResetSchema>;

export const profileSchema = z.object({
  display_name: z.string().trim().min(2, 'Enter a display name'),
  email: emailRule,
});
export type ProfileValues = z.infer<typeof profileSchema>;

export const workOrderDispatchSchema = z.object({
  priority: z.string().trim().min(1, 'Choose a maintenance priority'),
  required_by: z
    .string()
    .trim()
    .optional()
    .refine((value) => !value || !Number.isNaN(Date.parse(value)), 'Enter a valid date'),
});
export type WorkOrderDispatchValues = z.infer<typeof workOrderDispatchSchema>;
