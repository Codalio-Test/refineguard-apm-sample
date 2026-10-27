import { useState, type FormEvent } from 'react';
import { useSearchParams } from 'react-router-dom';
import { api } from '@rhino-dev/rhino-react';
import { apiErrorMessage } from '../lib/apiError';
import { AuthCard } from '../components/AuthCard';
import { AuthBackToSignIn, AuthCredentialFields } from '../components/AuthCredentialFields';
import { Button } from '../components/ui/button';
import { firstError, passwordRecoverSchema, passwordResetSchema } from '../lib/validation';

/**
 * Password recovery and reset in one screen.
 *
 * Without a `?token=`, it starts a recovery (`POST /auth/password/recover`);
 * with one, it completes the reset (`POST /auth/password/reset`). Which fields
 * are required — and the password rules — come from the matching zod schema.
 */
export default function AuthResetPassword() {
  const [searchParams] = useSearchParams();
  const token = searchParams.get('token') ?? '';

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [done, setDone] = useState('');

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError('');
    setDone('');

    if (token) {
      const parsed = passwordResetSchema.safeParse({
        email,
        password,
        password_confirmation: confirmation,
      });
      if (!parsed.success) {
        setError(firstError(parsed.error));
        return;
      }
      await send('/auth/password/reset', { token, ...parsed.data },
                 'Password updated. You can sign in with your new credentials.');
      return;
    }

    const parsed = passwordRecoverSchema.safeParse({ email });
    if (!parsed.success) {
      setError(firstError(parsed.error));
      return;
    }
    await send('/auth/password/recover', parsed.data,
               'A recovery instruction has been issued for that address.');
  };

  const send = async (path: string, body: object, message: string) => {
    setLoading(true);
    try {
      await api.post(path, body);
      setDone(message);
    } catch (thrown: unknown) {
      setError(apiErrorMessage(thrown, 'The request could not be completed.'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthCard
      formId="reset"
      description={token ? 'Choose a new password' : 'Recover access to BRR-OT.LOCAL'}
      onSubmit={submit}
      notice={done || 'Recovery is brokered by the local LDAP identity service.'}
      error={error || undefined}
      footer={
        <>
          <Button form="reset" className="w-full" disabled={loading}>
            {loading ? 'Submitting…' : token ? 'Set new password' : 'Send recovery instructions'}
          </Button>
          <AuthBackToSignIn />
        </>
      }
    >
      <AuthCredentialFields
        idPrefix="reset"
        email={email}
        onEmail={setEmail}
        {...(token
          ? {
              password,
              onPassword: setPassword,
              confirmation,
              onConfirmation: setConfirmation,
              passwordLabel: 'New password',
              confirmationLabel: 'Confirm new password',
            }
          : {})}
      />
    </AuthCard>
  );
}
