<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Symfony\Component\Mailer\Exception\TransportExceptionInterface;

class AuthController extends Controller
{
    public function login(Request $request)
    {
        $data = $request->validate([
            'user_identifier' => ['required', 'string', 'max:50'],
            'password' => ['required', 'string', 'max:255'],
        ]);
        $user = User::with('role')->where('user_identifier', $data['user_identifier'])->first();
        // Hash a dummy value for unknown accounts to avoid a fast account-existence check.
        $hash = $user?->password ?? '$2y$12$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.';
        $valid = Hash::check($data['password'], $hash);
        if (! $user || ! $valid || $user->status !== 'active') {
            return response()->json(['message' => 'Invalid user ID or password.'], 401);
        }
        if (! in_array($user->role?->role_name, ['patient', 'staff', 'doctor', 'administrator'], true)) {
            return response()->json(['message' => 'This account does not have a supported role.'], 403);
        }
        if (Hash::needsRehash($user->password)) {
            $user->forceFill(['password' => $data['password']])->save();
        }
        $token = $user->createToken('flutter', ['*'], now()->addHours(12));

        return response()->json(['token' => $token->plainTextToken, 'user' => $user->profile()]);
    }

    public function me(Request $request)
    {
        return response()->json(['user' => $request->user()->profile()]);
    }

    public function logout(Request $request)
    {
        \Illuminate\Support\Facades\DB::table('push_devices')->where('access_token_id', $request->user()->currentAccessToken()->id)->delete();
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Signed out.']);
    }

    public function forgotPassword(Request $request)
    {
        $request->validate(['email' => ['required', 'email', 'max:100']]);

        if (in_array(config('mail.default'), ['log', 'array']) && ! app()->environment('testing')) {
            return response()->json(['message' => 'Password reset email is not configured. Contact the clinic administrator.'], 503);
        }
        try {
            $status = Password::sendResetLink(['email' => $request->input('email'), 'status' => 'active']);
        } catch (TransportExceptionInterface $exception) {
            report($exception);

            return response()->json(['message' => 'The reset email could not be sent. Please contact the clinic administrator or wait a minute and try again.'], 503);
        }

        if ($status === Password::RESET_THROTTLED) {
            return response()->json(['message' => 'Please wait a minute before requesting another reset email.'], 429);
        }

        return response()->json(['message' => 'If an account exists for this email, reset instructions have been sent.']);
    }
}
