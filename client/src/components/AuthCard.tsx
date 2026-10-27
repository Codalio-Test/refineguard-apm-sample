/**
 * The shared chrome for the standalone auth screens (sign in, invitation
 * acceptance, password recovery/reset).
 *
 * One card composition — logo header, description, form, status alert, footer —
 * so the three auth pages differ only in their fields and copy.
 */
import type { FormEvent, ReactNode } from 'react';
import { LockKeyhole, ShieldCheck } from 'lucide-react';
import { Alert, AlertDescription } from './ui/alert';
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from './ui/card';

interface AuthCardProps {
  formId: string;
  description: string;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
  children: ReactNode;
  /** Shown when there is no error. */
  notice: string;
  /** Shown instead of the notice when set. */
  error?: string;
  footer: ReactNode;
}

export function AuthCard({
  formId,
  description,
  onSubmit,
  children,
  notice,
  error,
  footer,
}: AuthCardProps) {
  return (
    <div className="w-full min-w-0 overflow-x-hidden">
      <div className="flex flex-col gap-4 w-full min-w-0">
        <section className="grid min-h-screen place-items-center bg-background p-4">
          <Card className="w-full max-w-md border-border shadow-md">
            <CardHeader className="text-center">
              <div className="mx-auto mb-3 flex h-12 w-12 items-center justify-center rounded-lg bg-primary text-primary-foreground">
                <ShieldCheck className="h-6 w-6" />
              </div>
              <CardTitle className="text-2xl">RefineGuard APM</CardTitle>
              <CardDescription>{description}</CardDescription>
            </CardHeader>
            <CardContent>
              <form id={formId} className="space-y-4" onSubmit={onSubmit} noValidate>
                {children}
                <Alert variant={error ? 'destructive' : 'default'}>
                  <LockKeyhole className="h-4 w-4" />
                  <AlertDescription>{error || notice}</AlertDescription>
                </Alert>
              </form>
            </CardContent>
            <CardFooter className="flex flex-col gap-3">{footer}</CardFooter>
          </Card>
        </section>
      </div>
    </div>
  );
}
