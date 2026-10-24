import { inject } from '@angular/core';
import { CanMatchFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

export const authGuard: CanMatchFn = async () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  if (await auth.ensureSession()) {
    return true;
  }
  const target = router.currentNavigation()?.extractedUrl.toString() ?? '/';
  return router.createUrlTree(['/login'], {
    queryParams: target !== '/' && !target.startsWith('/login') ? { redirect: target } : {},
  });
};

export const guestGuard: CanMatchFn = async () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  return (await auth.ensureSession()) ? router.createUrlTree(['/']) : true;
};
