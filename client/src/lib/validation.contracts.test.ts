/**
 * Contract tests for the shared form schemas and the error helpers.
 *
 * Each rule is pinned twice: the exact user-facing message, and the boundary
 * value on both sides of it. A schema whose limit, message or refinement drifts
 * therefore fails here, and the trimming behaviour (which is what makes "   "
 * an empty value rather than a valid one) is asserted explicitly.
 */
import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import {
  fieldErrors,
  firstError,
  invitationSchema,
  loginSchema,
  passwordRecoverSchema,
  passwordResetSchema,
  profileSchema,
  workOrderDispatchSchema,
} from './validation';

function issue(path: (string | number)[], message: string, code = z.ZodIssueCode.custom): z.ZodIssue {
  return { code, path, message };
}

function accepted(schema: z.ZodTypeAny, value: unknown): boolean {
  return schema.safeParse(value).success;
}

describe('fieldErrors / firstError', () => {
  it('keys each issue by its joined path and keeps the first message per field', () => {
    const error = new z.ZodError([
      issue(['password_confirmation'], 'Passwords do not match'),
      issue(['nested', 'field'], 'second field message'),
      issue(['nested', 'field'], 'ignored duplicate'),
    ]);

    expect(fieldErrors(error)).toEqual({
      password_confirmation: 'Passwords do not match',
      'nested.field': 'second field message',
    });
  });

  it('falls back to "form" for a root-level issue', () => {
    expect(fieldErrors(new z.ZodError([issue([], 'root problem')]))).toEqual({
      form: 'root problem',
    });
  });

  it('returns an empty map when there are no issues', () => {
    expect(fieldErrors(new z.ZodError([]))).toEqual({});
  });

  it('firstError returns the first message and falls back when there is none', () => {
    const error = new z.ZodError([issue(['a'], 'first'), issue(['b'], 'second')]);
    expect(firstError(error)).toBe('first');
    expect(firstError(new z.ZodError([]))).toBe('Please check the highlighted fields.');
  });
});

describe('loginSchema', () => {
  it('pins the messages for a blank email and password', () => {
    const result = loginSchema.safeParse({ email: '   ', password: '' });
    expect(result.success).toBe(false);
    if (result.success) return;
    expect(fieldErrors(result.error)).toEqual({
      email: 'Enter your domain username or email',
      password: 'Enter your password',
    });
  });

  it('trims the email and accepts any non-empty password', () => {
    expect(accepted(loginSchema, { email: '  operator  ', password: 'x' })).toBe(true);
    const parsed = loginSchema.parse({ email: '  operator  ', password: 'x' });
    expect(parsed.email).toBe('operator');
  });
});

describe('email and password rules used by the invitation and reset forms', () => {
  it('pins the email message and rejects a malformed address', () => {
    const result = passwordRecoverSchema.safeParse({ email: 'nope' });
    expect(result.success).toBe(false);
    if (!result.success) expect(firstError(result.error)).toBe('Enter a valid domain email');
  });

  it('trims the email before validating it', () => {
    expect(accepted(passwordRecoverSchema, { email: '  operator@brr-ot.local  ' })).toBe(true);
    expect(passwordRecoverSchema.parse({ email: ' a@b.local ' }).email).toBe('a@b.local');
  });

  it('accepts exactly eight characters and rejects seven', () => {
    const build = (password: string) =>
      passwordResetSchema.safeParse({
        email: 'a@b.local',
        password,
        password_confirmation: password,
      });

    expect(build('1234567').success).toBe(false);
    expect(build('12345678').success).toBe(true);
    const seven = build('1234567');
    if (!seven.success) {
      expect(fieldErrors(seven.error).password).toBe('Use at least 8 characters');
    }
  });
});

describe('invitationSchema', () => {
  const base = {
    token: 'tok',
    name: 'Ada Lovelace',
    email: 'ada@brr-ot.local',
    password: 'password1',
    password_confirmation: 'password1',
  };

  it('accepts a complete invitation', () => {
    expect(invitationSchema.safeParse(base).success).toBe(true);
  });

  it('pins every required-field message', () => {
    const result = invitationSchema.safeParse({
      token: ' ',
      name: ' a ',
      email: 'nope',
      password: '1234567',
      password_confirmation: '',
    });
    expect(result.success).toBe(false);
    if (result.success) return;
    expect(fieldErrors(result.error)).toEqual({
      token: 'Paste the invitation token',
      name: 'Enter your full name',
      email: 'Enter a valid domain email',
      password: 'Use at least 8 characters',
      password_confirmation: 'Confirm your password',
    });
  });

  it('trims the token and the name', () => {
    expect(invitationSchema.parse({ ...base, token: '  tok  ', name: ' Ada  ' })).toMatchObject({
      token: 'tok',
      name: 'Ada',
    });
    expect(invitationSchema.safeParse({ ...base, name: ' A ' }).success).toBe(false);
  });

  it('reports a mismatch on the confirmation field', () => {
    const result = invitationSchema.safeParse({ ...base, password_confirmation: 'password2' });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(fieldErrors(result.error)).toEqual({
        password_confirmation: 'Passwords do not match',
      });
    }
  });
});

describe('passwordResetSchema', () => {
  it('accepts matching passwords and reports a mismatch', () => {
    expect(
      accepted(passwordResetSchema, {
        email: 'a@b.local',
        password: 'password1',
        password_confirmation: 'password1',
      }),
    ).toBe(true);

    const mismatch = passwordResetSchema.safeParse({
      email: 'a@b.local',
      password: 'password1',
      password_confirmation: 'password2',
    });
    expect(mismatch.success).toBe(false);
    if (!mismatch.success) {
      expect(fieldErrors(mismatch.error).password_confirmation).toBe('Passwords do not match');
    }
  });

  it('requires the confirmation to be present', () => {
    const result = passwordResetSchema.safeParse({
      email: 'a@b.local',
      password: 'password1',
      password_confirmation: '',
    });
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(fieldErrors(result.error).password_confirmation).toBe('Confirm your password');
    }
  });
});

describe('profileSchema', () => {
  it('pins the display-name message and the two-character minimum', () => {
    const blank = profileSchema.safeParse({ display_name: '  ', email: '' });
    expect(blank.success).toBe(false);
    if (!blank.success) {
      expect(fieldErrors(blank.error)).toEqual({
        display_name: 'Enter a display name',
        email: 'Enter a valid domain email',
      });
    }

    expect(accepted(profileSchema, { display_name: 'Ab', email: 'a@b.local' })).toBe(true);
    expect(profileSchema.safeParse({ display_name: ' A ', email: 'a@b.local' }).success).toBe(false);
    expect(profileSchema.parse({ display_name: '  Ada  ', email: 'a@b.local' }).display_name).toBe('Ada');
  });
});

describe('workOrderDispatchSchema', () => {
  it('pins the priority message and trims it', () => {
    const blank = workOrderDispatchSchema.safeParse({ priority: '   ' });
    expect(blank.success).toBe(false);
    if (!blank.success) {
      expect(firstError(blank.error)).toBe('Choose a maintenance priority');
    }
    expect(workOrderDispatchSchema.parse({ priority: '  P2  ' }).priority).toBe('P2');
  });

  it('treats an omitted or blank required-by as absent and rejects an unparsable date', () => {
    expect(accepted(workOrderDispatchSchema, { priority: 'P2' })).toBe(true);
    expect(accepted(workOrderDispatchSchema, { priority: 'P2', required_by: '' })).toBe(true);
    expect(accepted(workOrderDispatchSchema, { priority: 'P2', required_by: '   ' })).toBe(true);
    expect(accepted(workOrderDispatchSchema, { priority: 'P2', required_by: '2026-01-01' })).toBe(true);

    const bad = workOrderDispatchSchema.safeParse({ priority: 'P2', required_by: 'not-a-date' });
    expect(bad.success).toBe(false);
    if (!bad.success) expect(firstError(bad.error)).toBe('Enter a valid date');
  });

  it('trims the required-by value it keeps', () => {
    expect(workOrderDispatchSchema.parse({ priority: 'P2', required_by: ' 2026-01-01 ' }).required_by).toBe(
      '2026-01-01',
    );
  });
});
