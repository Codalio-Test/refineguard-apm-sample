/**
 * Shared pieces of the standalone auth forms.
 *
 * The invitation and password-recovery/reset screens present the same
 * email/password/confirmation field group and the same "Back to sign in"
 * affordance, so both live here rather than being duplicated per page.
 */
import { useNavigate } from 'react-router-dom';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Label } from './ui/label';

interface AuthCredentialFieldsProps {
  /** Prefix for the generated input ids (`reset` → `#reset-email`). */
  idPrefix?: string;
  email: string;
  onEmail: (value: string) => void;
  /** When provided, the password and confirmation fields are rendered too. */
  password?: string;
  onPassword?: (value: string) => void;
  confirmation?: string;
  onConfirmation?: (value: string) => void;
  passwordLabel?: string;
  confirmationLabel?: string;
}

function fieldId(prefix: string | undefined, name: string): string {
  return prefix ? `${prefix}-${name}` : name;
}

export function AuthCredentialFields({
  idPrefix,
  email,
  onEmail,
  password,
  onPassword,
  confirmation,
  onConfirmation,
  passwordLabel = 'Password',
  confirmationLabel = 'Confirm password',
}: AuthCredentialFieldsProps) {
  const showPasswords = onPassword !== undefined;

  return (
    <>
      <div className="space-y-2">
        <Label htmlFor={fieldId(idPrefix, 'email')}>Domain email</Label>
        <Input
          id={fieldId(idPrefix, 'email')}
          type="email"
          value={email}
          onChange={(event) => onEmail(event.target.value)}
          placeholder="operator.name@brr-ot.local"
        />
      </div>
      {showPasswords && (
        <>
          <div className="space-y-2">
            <Label htmlFor={fieldId(idPrefix, 'password')}>{passwordLabel}</Label>
            <Input
              id={fieldId(idPrefix, 'password')}
              type="password"
              value={password ?? ''}
              onChange={(event) => onPassword?.(event.target.value)}
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor={fieldId(idPrefix, 'confirmation')}>{confirmationLabel}</Label>
            <Input
              id={fieldId(idPrefix, 'confirmation')}
              type="password"
              value={confirmation ?? ''}
              onChange={(event) => onConfirmation?.(event.target.value)}
            />
          </div>
        </>
      )}
    </>
  );
}

/** The "Back to sign in" button shared by the invite and recovery screens. */
export function AuthBackToSignIn() {
  const navigate = useNavigate();
  return (
    <Button type="button" variant="outline" className="w-full" onClick={() => navigate('/login')}>
      Back to sign in
    </Button>
  );
}
