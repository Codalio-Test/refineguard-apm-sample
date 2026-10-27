import { useState, type FormEvent } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '@rhino-dev/rhino-react';
import { landingAfterLogin } from '../lib/roleLanding';
import { AuthCard } from '../components/AuthCard';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { firstError, loginSchema } from '../lib/validation';

/**
 * `/login` and `/auth/signin` — the required sign-in screen.
 *
 * The credentials are validated with the shared zod schema before the Rhino
 * `login()` call, and the identity slots are driven by the returned session
 * rather than any hardcoded operator.
 */
export default function Login() {
  const navigate = useNavigate();
  const location = useLocation();
  const { login, setOrganization } = useAuth();
  const [user, setUser] = useState('');
  const [pass, setPass] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setError('');

    const parsed = loginSchema.safeParse({ email: user, password: pass });
    if (!parsed.success) {
      setError(firstError(parsed.error));
      return;
    }

    setLoading(true);
    const result = await login(parsed.data.email, parsed.data.password);
    if (!result.success) {
      setLoading(false);
      setError(result.error ?? 'Authentication failed. Verify your domain credentials.');
      return;
    }

    if (result.organization_slug) setOrganization(result.organization_slug);
    const from = (location.state as { from?: { pathname?: string } } | null)?.from?.pathname;
    navigate(landingAfterLogin({ from, roles: result.user?.role_slugs }), { replace: true });
  };

  return (
    <AuthCard
      formId="login"
      description="Sign in to BRR-OT.LOCAL"
      onSubmit={submit}
      notice="Authentication remains inside the sealed OT network."
      error={error || undefined}
      footer={
        <Button form="login" className="w-full" disabled={loading}>
          {loading ? 'Authenticating…' : 'Secure sign in'}
        </Button>
      }
    >
      <div className="space-y-2">
        <Label htmlFor="user">Domain username</Label>
        <Input
          id="user"
          value={user}
          onChange={(event) => setUser(event.target.value)}
          placeholder="operator.name"
        />
      </div>
      <div className="space-y-2">
        <Label htmlFor="pass">Password</Label>
        <Input
          id="pass"
          type="password"
          value={pass}
          onChange={(event) => setPass(event.target.value)}
        />
      </div>
    </AuthCard>
  );
}
