import '../api/api_client.dart';

/// Every error code the API can return, mapped to something a person can act
/// on. The acceptance criterion is "no raw error strings", so this map is the
/// only thing the UI is allowed to show.
///
/// Errors state what happened and what to do next. No apologies, no
/// exclamation marks.
abstract final class AuthMessages {
  static const _byCode = <String, String>{
    // --- sign up ---
    'AUTH_EMAIL_TAKEN':
        'این ایمیل قبلاً ثبت شده است. وارد شو یا رمز عبورت را بازیابی کن.',
    'AUTH_WEAK_PASSWORD': 'رمز عبور شرایط لازم را ندارد.',

    // --- sign in ---
    'AUTH_INVALID_CREDENTIALS': 'ایمیل یا رمز عبور درست نیست.',
    'AUTH_EMAIL_NOT_VERIFIED':
        'ایمیلت هنوز تأیید نشده. لینک تأیید را در ایمیلت باز کن.',
    'AUTH_ACCOUNT_LOCKED':
        'به‌خاطر تلاش‌های ناموفق، حساب موقتاً قفل شده. کمی بعد دوباره تلاش کن.',
    'AUTH_ACCOUNT_DISABLED': 'این حساب غیرفعال است.',
    'AUTH_USE_PROVIDER_SIGNIN':
        'این حساب با گوگل ساخته شده. با دکمه «ادامه با گوگل» وارد شو.',

    // --- federated ---
    'AUTH_LINK_REQUIRES_PASSWORD':
        'این ایمیل قبلاً با رمز عبور ثبت شده. یک‌بار رمزت را وارد کن تا گوگل به همان حساب وصل شود.',
    'AUTH_PROVIDER_EMAIL_UNVERIFIED':
        'ایمیل حساب گوگل تأیید نشده است. با روش دیگری وارد شو.',
    'AUTH_PROVIDER_NOT_CONFIGURED':
        'ورود با گوگل روی سرور فعال نیست.',
    'AUTH_PROVIDER_UNAVAILABLE':
        'ارتباط با گوگل برقرار نشد. دوباره تلاش کن.',

    // --- tokens / session ---
    'AUTH_TOKEN_MISSING': 'دوباره وارد شو.',
    'AUTH_TOKEN_INVALID': 'نشست معتبر نیست. دوباره وارد شو.',
    'AUTH_TOKEN_EXPIRED': 'نشست منقضی شده. دوباره وارد شو.',
    'AUTH_REFRESH_INVALID': 'نشست معتبر نیست. دوباره وارد شو.',
    'AUTH_REFRESH_EXPIRED': 'نشست منقضی شده. دوباره وارد شو.',
    'AUTH_REFRESH_REVOKED': 'این نشست باطل شده. دوباره وارد شو.',

    // --- one-time tokens ---
    'AUTH_VERIFY_TOKEN_INVALID': 'این لینک تأیید معتبر نیست.',
    'AUTH_VERIFY_TOKEN_EXPIRED': 'این لینک تأیید منقضی شده. لینک تازه بگیر.',
    'AUTH_RESET_TOKEN_INVALID': 'کد بازیابی درست نیست.',
    'AUTH_RESET_TOKEN_EXPIRED': 'کد بازیابی منقضی شده. کد تازه بگیر.',

    // --- generic ---
    'RATE_LIMITED': 'تلاش‌ها زیاد بود. کمی صبر کن و دوباره امتحان کن.',
    'VALIDATION_ERROR': 'اطلاعات واردشده کامل یا درست نیست.',
    'NOT_FOUND': 'پیدا نشد.',
    'CONFLICT': 'این عملیات با وضعیت فعلی حساب سازگار نیست.',
    'FORBIDDEN': 'اجازه این کار را نداری.',
    'INTERNAL': 'خطای سرور. کمی بعد دوباره تلاش کن.',

    // --- client-side ---
    ClientErrorCode.network:
        'به سرور وصل نشد. اتصال اینترنتت را بررسی کن.',
    ClientErrorCode.timeout: 'سرور پاسخ نداد. دوباره تلاش کن.',
    ClientErrorCode.badResponse: 'پاسخ سرور قابل خواندن نبود.',
    ClientErrorCode.cancelled: 'ورود لغو شد.',

    // --- google plugin ---
    'GOOGLE_CANCELED': 'ورود با گوگل لغو شد.',
    'GOOGLE_MISCONFIGURED':
        'ورود با گوگل روی این نسخه پیکربندی نشده است.',
    'GOOGLE_NO_ID_TOKEN':
        'گوگل توکن شناسایی نداد. پیکربندی serverClientId را بررسی کن.',
    // google_sign_in_web returns supportsAuthenticate() == false: Google's
    // web SDK requires its own rendered button, not a programmatic call.
    // Say which platform does work rather than leaving a dead end.
    'GOOGLE_UNSUPPORTED':
        'ورود با گوگل در نسخه وب کار نمی‌کند. از نسخه اندروید استفاده کن.',
  };

  /// Never returns null. An unmapped code still produces a usable sentence
  /// rather than leaking the code or an exception string.
  static String of(Object error) {
    if (error is ApiException) {
      final mapped = _byCode[error.code];
      if (mapped != null) return mapped;
      return 'خطای پیش‌بینی‌نشده رخ داد. دوباره تلاش کن.';
    }
    return 'خطای پیش‌بینی‌نشده رخ داد. دوباره تلاش کن.';
  }

  /// True when the failure is one the user can fix by re-entering something,
  /// as opposed to one that should bounce them to the sign-in screen.
  static bool isSessionEnding(Object error) =>
      error is ApiException &&
      const {
        'AUTH_TOKEN_INVALID',
        'AUTH_TOKEN_EXPIRED',
        'AUTH_REFRESH_INVALID',
        'AUTH_REFRESH_EXPIRED',
        'AUTH_REFRESH_REVOKED',
        'AUTH_ACCOUNT_DISABLED',
      }.contains(error.code);
}
