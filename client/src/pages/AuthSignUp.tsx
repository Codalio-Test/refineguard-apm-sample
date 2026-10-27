import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, useAuth } from '@rhino-dev/rhino-react';
import { landingAfterLogin } from '../lib/roleLanding';
import { apiErrorMessage } from '../lib/apiError';
import { AuthCard } from '../components/AuthCard';
import { AuthBackToSignIn, AuthCredentialFields } from '../components/AuthCredentialFields';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { firstError, invitationSchema } from '../lib/validation';

/**
 * Invitation acceptance.
 *
 * Rhino registration is invitation-token based: an administrator invites an
 * address, and the invitee completes the account here. The invitation token is
 * the credential, so there is no open sign-up. The zod schema validates the
 * whole payload — including the password confirmation — before the request.
 */
export default function AuthSignUp() {
  const navigate = useNavigate();
  const { setOrganization } = useAuth();
  const [token, setToken] = useState('');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError('');

    const parsed = invitationSchema.safeParse({
      token,
      name,
      email,
      password,
      password_confirmation: confirmation,
    });
    if (!parsed.success) {
      setError(firstError(parsed.error));
      return;
    }

    setLoading(true);
    try {
      const { data } = await api.post('/auth/register', parsed.data);
      if (data?.organization_slug) setOrganization(data.organization_slug);
      navigate(
        landingAfterLogin({ from: '/fleet-overview', roles: data?.user?.role_slugs }),
        { replace: true },
      );
    } catch (thrown: unknown) {
      setError(apiErrorMessage(thrown, 'The invitation could not be accepted.'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthCard
      formId="signup"
      description="Accept your invitation to BRR-OT.LOCAL"
      onSubmit={submit}
      notice="Registration is invitation-only and stays inside the sealed OT network."
      error={error || undefined}
      footer={
        <>
          <Button form="signup" className="w-full" disabled={loading}>
            {loading ? 'Creating account…' : 'Accept invitation'}
          </Button>
          <AuthBackToSignIn />
        </>
      }
    >
      <div className="space-y-2">
        <Label htmlFor="invite">Invitation token</Label>
        <Input id="invite" value={token} onChange={(event) => setToken(event.target.value)} placeholder="paste the token from your invitation" />
      </div>
      <div className="space-y-2">
        <Label htmlFor="name">Full name</Label>
        <Input id="name" value={name} onChange={(event) => setName(event.target.value)} placeholder="operator.name" />
      </div>
      <AuthCredentialFields
        email={email}
        onEmail={setEmail}
        password={password}
        onPassword={setPassword}
        confirmation={confirmation}
        onConfirmation={setConfirmation}
      />
    </AuthCard>
  );
}
